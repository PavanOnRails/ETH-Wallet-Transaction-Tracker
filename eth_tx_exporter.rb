# frozen_string_literal: true

require 'httparty'
require 'csv'
require 'time'
require 'rodc'

# ETH Wallet Transaction Exporter
#
# This script fetches and exports all Ethereum wallet transactions (normal, internal, ERC-20, ERC-721)
# using the Etherscan API. Results are exported to a CSV file.
#
# Usage:
#   ETHERSCAN_API_KEY=yourkey ruby eth_tx_exporter.rb <wallet_address>
#
# Dependencies: httparty, csv, rodc
#
# Environment:
#   ETHERSCAN_API_KEY - Your Etherscan API key
#
ETHERSCAN_API_KEY = ENV['ETHERSCAN_API_KEY']

##
# EthTxExporter fetches and exports Ethereum wallet transactions from Etherscan.
#
# Example:
#   exporter = EthTxExporter.new('0x...')
#   exporter.export_csv('output.csv')
class EthTxExporter
  ETHERSCAN_BASE = 'https://api.etherscan.io/v2/api?chainid=1'
  HEADERS = [
    'Transaction Hash', 'Date & Time', 'From Address', 'To Address', 'Transaction Type',
    'Asset Contract Address', 'Asset Symbol / Name', 'Token ID', 'Value / Amount', 'Gas Fee (ETH)'
  ].freeze
  ACTIONS = {
    normal: 'txlist',
    internal: 'txlistinternal',
    erc20: 'tokentx',
    erc721: 'tokennfttx'
  }.freeze

  ##
  # Initialize exporter for a given Ethereum address.
  #
  # address - Ethereum wallet address as a string.
  # Raises if ETHERSCAN_API_KEY is not set.
  def initialize(address)
    @address = address
    return if ETHERSCAN_API_KEY && !ETHERSCAN_API_KEY.empty?

    raise 'ETHERSCAN_API_KEY environment variable not set.'
  end

  ##
  # Fetch transactions for a given Etherscan action.
  #
  # action - String, one of the supported Etherscan actions.
  # Returns an array of transaction hashes, or [] on error.
  # Warns on HTTP/API errors.
  def fetch_transactions(action)
    params = {
      module: 'account',
      address: @address,
      apikey: ETHERSCAN_API_KEY,
      action: action
    }
    begin
      response = HTTParty.get(ETHERSCAN_BASE, query: params, timeout: 15)
      if response.code != 200
        warn "HTTP error for action '#{action}': #{response.code}"
        return []
      end
      data = response.parsed_response
      unless data.is_a?(Hash) && data['status'] == '1'
        warn "API error for action '#{action}': #{data['message'] || data.inspect}"
        return []
      end
      data['result']
    rescue StandardError => e
      warn "Exception fetching '#{action}': #{e.message}"
      []
    end
  end

  ##
  # Fetches and combines all transaction types (normal, internal, ERC-20, ERC-721).
  #
  # Returns an array of hashes, each representing a transaction.
  def process
    all_txs = []
    tx_data = {}
    ACTIONS.each do |type, action|
      tx_data[type] = fetch_transactions(action)
    end

    all_txs.concat format_normal(tx_data[:normal])
    all_txs.concat format_internal(tx_data[:internal])
    all_txs.concat format_erc20(tx_data[:erc20])
    all_txs.concat format_erc721(tx_data[:erc721])
    all_txs
  end

  ##
  # Formatters for each transaction type.
  # Each returns an array of hashes for the given transaction type.
  ##
  # Format normal (external) ETH transactions.
  # txs - Array of transaction hashes.
  # Returns array of formatted hashes.
  def format_normal(txs)
    Array(txs).map do |tx|
      {
        'Transaction Hash' => tx['hash'],
        'Date & Time' => format_time(tx['timeStamp']),
        'From Address' => tx['from'],
        'To Address' => tx['to'],
        'Transaction Type' => tx['input'] == '0x' ? 'ETH transfer' : 'Contract Interaction',
        'Asset Contract Address' => '',
        'Asset Symbol / Name' => 'ETH',
        'Token ID' => '',
        'Value / Amount' => safe_div(tx['value'], 1e18),
        'Gas Fee (ETH)' => safe_gas_fee(tx['gasUsed'], tx['gasPrice'])
      }
    end
  end

  ##
  # Format internal ETH transactions.
  # txs - Array of transaction hashes.
  # Returns array of formatted hashes.
  def format_internal(txs)
    Array(txs).map do |tx|
      {
        'Transaction Hash' => tx['hash'],
        'Date & Time' => format_time(tx['timeStamp']),
        'From Address' => tx['from'],
        'To Address' => tx['to'],
        'Transaction Type' => 'Internal Transfer',
        'Asset Contract Address' => '',
        'Asset Symbol / Name' => 'ETH',
        'Token ID' => '',
        'Value / Amount' => safe_div(tx['value'], 1e18),
        'Gas Fee (ETH)' => ''
      }
    end
  end

  ##
  # Format ERC-20 token transactions.
  # txs - Array of transaction hashes.
  # Returns array of formatted hashes.
  def format_erc20(txs)
    Array(txs).map do |tx|
      {
        'Transaction Hash' => tx['hash'],
        'Date & Time' => format_time(tx['timeStamp']),
        'From Address' => tx['from'],
        'To Address' => tx['to'],
        'Transaction Type' => 'ERC-20',
        'Asset Contract Address' => tx['contractAddress'],
        'Asset Symbol / Name' => tx['tokenSymbol'],
        'Token ID' => '',
        'Value / Amount' => safe_div(tx['value'], 10**begin
          tx['tokenDecimal'].to_i
        rescue StandardError
          0
        end),
        'Gas Fee (ETH)' => ''
      }
    end
  end

  ##
  # Format ERC-721 (NFT) token transactions.
  # txs - Array of transaction hashes.
  # Returns array of formatted hashes.
  def format_erc721(txs)
    Array(txs).map do |tx|
      {
        'Transaction Hash' => tx['hash'],
        'Date & Time' => format_time(tx['timeStamp']),
        'From Address' => tx['from'],
        'To Address' => tx['to'],
        'Transaction Type' => 'ERC-721',
        'Asset Contract Address' => tx['contractAddress'],
        'Asset Symbol / Name' => tx['tokenName'],
        'Token ID' => tx['tokenID'],
        'Value / Amount' => 1,
        'Gas Fee (ETH)' => ''
      }
    end
  end

  ##
  # Helpers
  ##
  # Convert a timestamp to UTC string.
  # timestamp - Unix timestamp (string or int).
  # Returns formatted string or empty string on error.
  def format_time(timestamp)
    Time.at(timestamp.to_i).utc.strftime('%Y-%m-%d %H:%M:%S')
  rescue StandardError
    ''
  end

  ##
  # Safely divide val by denom, returns 0 on error.
  def safe_div(val, denom)
    Float(val) / denom
  rescue StandardError
    0
  end

  ##
  # Safely compute gas fee in ETH, returns 0 on error.
  def safe_gas_fee(gas_used, gas_price)
    (gas_used.to_i * gas_price.to_i) / 1e18
  rescue StandardError
    0
  end

  ##
  # Export all transactions to a CSV file.
  # filename - Output CSV file path.
  # Warns on file errors.
  def export_csv(filename)
    txs = process
    begin
      CSV.open(filename, 'w', write_headers: true, headers: HEADERS) do |csv|
        txs.each { |tx| csv << HEADERS.map { |h| tx[h] } }
      end
      puts "Exported #{txs.size} transactions to #{filename}"
    rescue StandardError => e
      warn "Failed to write CSV: #{e.message}"
    end
  end
end

# Usage:
#   ETHERSCAN_API_KEY=yourkey ruby eth_tx_exporter.rb <wallet_address>
if __FILE__ == $PROGRAM_NAME
  if ARGV.size != 1
    puts 'Usage: ETHERSCAN_API_KEY=yourkey ruby eth_tx_exporter.rb <ethereum_wallet_address>'
    exit 1
  end
  address = ARGV[0]
  begin
    exporter = EthTxExporter.new(address)
    exporter.export_csv("#{address}_transactions.csv")
  rescue StandardError => e
    warn "Error: #{e.message}"
    exit 2
  end
end

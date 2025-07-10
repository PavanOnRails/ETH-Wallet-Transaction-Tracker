
require 'httparty'
require 'csv'
require 'time'

# Load API key from environment variable for security
ETHERSCAN_API_KEY = ENV['ETHERSCAN_API_KEY']

class EthTxExporter
  ETHERSCAN_BASE = 'https://api.etherscan.io/v2/api?chainid=1'
  HEADERS = [
    'Transaction Hash', 'Date & Time', 'From Address', 'To Address', 'Transaction Type',
    'Asset Contract Address', 'Asset Symbol / Name', 'Token ID', 'Value / Amount', 'Gas Fee (ETH)'
  ]
  ACTIONS = {
    normal: 'txlist',
    internal: 'txlistinternal',
    erc20: 'tokentx',
    erc721: 'tokennfttx'
  }

  def initialize(address)
    @address = address
    unless ETHERSCAN_API_KEY && !ETHERSCAN_API_KEY.empty?
      raise "ETHERSCAN_API_KEY environment variable not set."
    end
  end

  # Fetch transactions for a given action, with error handling
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

  # Process and combine all transaction types
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

  # Formatters for each transaction type
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
        'Value / Amount' => safe_div(tx['value'], 10 ** (tx['tokenDecimal'].to_i rescue 0)),
        'Gas Fee (ETH)' => ''
      }
    end
  end

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

  # Helpers
  def format_time(ts)
    Time.at(ts.to_i).utc.strftime('%Y-%m-%d %H:%M:%S') rescue ''
  end

  def safe_div(val, denom)
    Float(val) / denom rescue 0
  end

  def safe_gas_fee(gas_used, gas_price)
    (gas_used.to_i * gas_price.to_i) / 1e18 rescue 0
  end

  # Export transactions to CSV with error handling
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
if __FILE__ == $0
  if ARGV.size != 1
    puts "Usage: ETHERSCAN_API_KEY=yourkey ruby eth_tx_exporter.rb <ethereum_wallet_address>"
    exit 1
  end
  address = ARGV[0]
  begin
    exporter = EthTxExporter.new(address)
    exporter.export_csv("#{address}_transactions.csv")
  rescue => e
    warn "Error: #{e.message}"
    exit 2
  end
end
require 'httparty'
require 'csv'
require 'time'

ETHERSCAN_API_KEY = 'J63D8EW6TS7FA5ZT5T9448FEFJ6Q92AS28'

class EthTxExporter
  ETHERSCAN_BASE = 'https://api.etherscan.io/v2/api?chainid=1'

  def initialize(address)
    @address = address
  end

  def fetch_transactions(action)
    params = {
      module: 'account',
      address: @address,
      apikey: ETHERSCAN_API_KEY,
      action: action
    }
    response = HTTParty.get(ETHERSCAN_BASE, query: params)
    data = response.parsed_response
    return [] unless data['status'] == '1'
    data['result']
  end

  def process
    normal = fetch_transactions('txlist')
    internal = fetch_transactions('txlistinternal')
    erc20 = fetch_transactions('tokentx')
    erc721 = fetch_transactions('tokennfttx')

    all_txs = []

    # External (Normal) Transfers
    normal.each do |tx|
      all_txs << {
        'Transaction Hash' => tx['hash'],
        'Date & Time' => Time.at(tx['timeStamp'].to_i).utc.strftime('%Y-%m-%d %H:%M:%S'),
        'From Address' => tx['from'],
        'To Address' => tx['to'],
        'Transaction Type' => tx['input'] == '0x' ? 'ETH transfer' : 'Contract Interaction',
        'Asset Contract Address' => '',
        'Asset Symbol / Name' => 'ETH',
        'Token ID' => '',
        'Value / Amount' => tx['value'].to_f / 1e18,
        'Gas Fee (ETH)' => tx['gasUsed'].to_i * tx['gasPrice'].to_i / 1e18
      }
    end

    # Internal Transfers
    internal.each do |tx|
      all_txs << {
        'Transaction Hash' => tx['hash'],
        'Date & Time' => Time.at(tx['timeStamp'].to_i).utc.strftime('%Y-%m-%d %H:%M:%S'),
        'From Address' => tx['from'],
        'To Address' => tx['to'],
        'Transaction Type' => 'Internal Transfer',
        'Asset Contract Address' => '',
        'Asset Symbol / Name' => 'ETH',
        'Token ID' => '',
        'Value / Amount' => tx['value'].to_f / 1e18,
        'Gas Fee (ETH)' => ''
      }
    end

    # ERC-20
    erc20.each do |tx|
      all_txs << {
        'Transaction Hash' => tx['hash'],
        'Date & Time' => Time.at(tx['timeStamp'].to_i).utc.strftime('%Y-%m-%d %H:%M:%S'),
        'From Address' => tx['from'],
        'To Address' => tx['to'],
        'Transaction Type' => 'ERC-20',
        'Asset Contract Address' => tx['contractAddress'],
        'Asset Symbol / Name' => tx['tokenSymbol'],
        'Token ID' => '',
        'Value / Amount' => tx['value'].to_f / (10 ** tx['tokenDecimal'].to_i),
        'Gas Fee (ETH)' => ''
      }
    end

    # ERC-721
    erc721.each do |tx|
      all_txs << {
        'Transaction Hash' => tx['hash'],
        'Date & Time' => Time.at(tx['timeStamp'].to_i).utc.strftime('%Y-%m-%d %H:%M:%S'),
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

    all_txs
  end

  def export_csv(filename)
    txs = process
    headers = [
      'Transaction Hash', 'Date & Time', 'From Address', 'To Address', 'Transaction Type',
      'Asset Contract Address', 'Asset Symbol / Name', 'Token ID', 'Value / Amount', 'Gas Fee (ETH)'
    ]
    CSV.open(filename, 'w', write_headers: true, headers: headers) do |csv|
      txs.each { |tx| csv << headers.map { |h| tx[h] } }
    end
    puts "Exported #{txs.size} transactions to #{filename}"
  end
end

# Usage:
# ruby eth_tx_exporter.rb <wallet_address>
if __FILE__ == $0
  if ARGV.size != 1
    puts "Usage: ruby eth_tx_exporter.rb <ethereum_wallet_address>"
    exit 1
  end
  address = ARGV[0]
  exporter = EthTxExporter.new(address)
  exporter.export_csv("#{address}_transactions.csv")
end
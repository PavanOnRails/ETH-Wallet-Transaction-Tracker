# frozen_string_literal: true

require 'spec_helper'
require_relative '../eth_tx_exporter'

describe EthTxExporter do
  let(:address) { '0x0000000000000000000000000000000000000000' }
  let(:exporter) { described_class.new(address) }


  before do
    ENV['ETHERSCAN_API_KEY'] = 'dummykey'
  end

  describe '#initialize' do
    it 'raises if ETHERSCAN_API_KEY is not set' do
      ENV.delete('ETHERSCAN_API_KEY')
      expect { described_class.new(address) }.to raise_error(RuntimeError)
    end
    it 'does not raise if ETHERSCAN_API_KEY is set' do
      ENV['ETHERSCAN_API_KEY'] = 'dummykey'
      expect { described_class.new(address) }.not_to raise_error
    end
  end

  describe '#fetch_transactions' do
    it 'returns [] on HTTP error' do
      allow(HTTParty).to receive(:get).and_return(double(code: 500, parsed_response: {}))
      expect(exporter.fetch_transactions('txlist')).to eq([])
    end
    it 'returns [] on API error' do
      allow(HTTParty).to receive(:get).and_return(double(code: 200,
                                                         parsed_response: {
                                                           'status' => '0', 'message' => 'error'
                                                         }))
      expect(exporter.fetch_transactions('txlist')).to eq([])
    end
    it 'returns result on success' do
      allow(HTTParty).to receive(:get).and_return(double(code: 200,
                                                         parsed_response: {
                                                           'status' => '1', 'result' => [1, 2, 3]
                                                         }))
      expect(exporter.fetch_transactions('txlist')).to eq([1, 2, 3])
    end
  end

  describe '#format_time' do
    it 'formats valid timestamp' do
      expect(exporter.format_time('1600000000')).to eq('2020-09-13 12:26:40')
    end
    it 'returns empty string on error' do
      expect(exporter.format_time(nil)).to eq('')
    end
  end

  describe '#safe_div' do
    it 'divides safely' do
      expect(exporter.safe_div('10', 2)).to eq(5.0)
    end
    it 'returns 0 on error' do
      expect(exporter.safe_div('foo', 2)).to eq(0)
    end
  end

  describe '#safe_gas_fee' do
    it 'calculates gas fee' do
      expect(exporter.safe_gas_fee('21000', '1000000000')).to eq(0.000021)
    end
    it 'returns 0 on error' do
      expect(exporter.safe_gas_fee(nil, nil)).to eq(0)
    end
  end

  describe '#format_normal' do
    it 'formats normal txs' do
      txs = [{ 'hash' => 'h', 'timeStamp' => '1', 'from' => 'a', 'to' => 'b', 'input' => '0x',
               'value' => '1000000000000000000', 'gasUsed' => '21000', 'gasPrice' => '1000000000' }]
      result = exporter.format_normal(txs).first
      expect(result['Transaction Hash']).to eq('h')
      expect(result['Transaction Type']).to eq('ETH transfer')
      expect(result['Value / Amount']).to eq(1.0)
      expect(result['Gas Fee (ETH)']).to eq(0.000021)
    end
  end

  describe '#format_internal' do
    it 'formats internal txs' do
      txs = [{ 'hash' => 'h', 'timeStamp' => '1', 'from' => 'a', 'to' => 'b', 'value' => '1000000000000000000' }]
      result = exporter.format_internal(txs).first
      expect(result['Transaction Type']).to eq('Internal Transfer')
      expect(result['Value / Amount']).to eq(1.0)
    end
  end

  describe '#format_erc20' do
    it 'formats erc20 txs' do
      txs = [{ 'hash' => 'h', 'timeStamp' => '1', 'from' => 'a', 'to' => 'b', 'contractAddress' => 'c',
               'tokenSymbol' => 'TKN', 'tokenDecimal' => '18', 'value' => '1000000000000000000' }]
      result = exporter.format_erc20(txs).first
      expect(result['Transaction Type']).to eq('ERC-20')
      expect(result['Asset Symbol / Name']).to eq('TKN')
      expect(result['Value / Amount']).to eq(1.0)
    end
  end

  describe '#format_erc721' do
    it 'formats erc721 txs' do
      txs = [{ 'hash' => 'h', 'timeStamp' => '1', 'from' => 'a', 'to' => 'b', 'contractAddress' => 'c',
               'tokenName' => 'NFT', 'tokenID' => '42' }]
      result = exporter.format_erc721(txs).first
      expect(result['Transaction Type']).to eq('ERC-721')
      expect(result['Asset Symbol / Name']).to eq('NFT')
      expect(result['Token ID']).to eq('42')
      expect(result['Value / Amount']).to eq(1)
    end
  end
end

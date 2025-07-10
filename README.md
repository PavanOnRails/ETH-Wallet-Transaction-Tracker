# ETH-Wallet-Transaction-Tracker

A Ruby script to fetch and export all Ethereum wallet transactions (normal, internal, ERC-20, ERC-721) using the Etherscan API. Results are exported to a CSV file.

## Prerequisites

- Ruby (>= 2.7 recommended)
- Bundler (for dependency management)
- Etherscan API key

## Install Ruby (if not already installed)

On Ubuntu/Debian:

```bash
sudo apt update
sudo apt install ruby-full build-essential
```

On macOS (with Homebrew):

```bash
brew install ruby
```

## Setup

1. Clone the repository:

   ```bash
   git clone <repo-url>
   cd ETH-Wallet-Transaction-Tracker
   ```

2. Install dependencies:

   ```bash
   gem install bundler
   bundle install
   ```

3. (Optional) Run tests:

   ```bash
   bundle exec rspec
   ```

## Usage

1. Get your Etherscan API key from <https://etherscan.io/myapikey>

2. Run the script with your wallet address:

   ```bash
   ETHERSCAN_API_KEY=yourkey ruby eth_tx_exporter.rb <wallet_address>
   ```

   - Replace `yourkey` with your Etherscan API key.
   - Replace `<wallet_address>` with the Ethereum address you want to export transactions for.

3. The output CSV will be saved as `<wallet_address>_transactions.csv` in the current directory.

## Example

```bash
ETHERSCAN_API_KEY=abcdef123456 ruby eth_tx_exporter.rb 0x0000000000000000000000000000000000000000
```

## Development & Linting

- To check code style:

  ```bash
  bundle exec rubocop
  ```

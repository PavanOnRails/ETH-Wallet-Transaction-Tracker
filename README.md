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
   git clone https://github.com/PavanOnRails/ETH-Wallet-Transaction-Tracker.git
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

1. Get your Etherscan API key from https://etherscan.io/apidashboard

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

## Assumptions

- The Etherscan API is available and reliable for all supported transaction types (normal, internal, ERC-20, ERC-721).
- The user provides a valid Ethereum wallet address and a valid Etherscan API key.
- All transaction data can be fetched and processed in a single run (suitable for small to medium wallets).
- The script is intended for command-line use and outputs a single CSV file per wallet address.
- The CSV format is sufficient for most users' analysis and reporting needs.

## Architecture Decisions

- **Single-file Ruby Script:** The project is implemented as a single Ruby script for simplicity and ease of use, making it easy to run and maintain for individual users.
- **Modular Transaction Processing:** The code separates transaction fetching and formatting by type (normal, internal, ERC-20, ERC-721) for clarity and extensibility.
- **Error Handling:** Robust error and exception handling is included for all network and file operations to ensure the script fails gracefully and provides useful feedback.
- **Environment-based Configuration:** The Etherscan API key is loaded from an environment variable for security and flexibility.
- **Testing and Linting:** RSpec is used for unit testing and RuboCop for code style, supporting maintainability and code quality.
- **No Persistent Storage:** All data is processed in-memory and exported to CSV, which is suitable for small to medium datasets. For larger-scale or production use, a database would be recommended.

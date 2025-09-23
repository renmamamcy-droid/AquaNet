# AquaNet - Fishing Rights NFT Platform

## Overview

AquaNet is a decentralized platform built on the Stacks blockchain that enables the creation, management, and trading of fishing rights as NFTs. The platform transforms traditional fishing licenses into tradeable digital assets, creating a transparent and efficient marketplace for fishing access rights.

## System Architecture

The AquaNet system consists of two main smart contracts:

### 1. Fishing License Contract (`fishing-license.clar`)
- **Core Functionality**: Manages the issuance and lifecycle of fishing licenses as NFTs
- **Key Features**:
  - Issue new fishing licenses with specific parameters
  - Track license validity and expiration dates
  - Manage fishing quotas and catch limits
  - Handle license renewals and modifications
  - Enforce fishing regulations and compliance

### 2. License Marketplace Contract (`license-marketplace.clar`)
- **Core Functionality**: Facilitates trading and transfer of fishing license NFTs
- **Key Features**:
  - List fishing licenses for sale or lease
  - Execute secure peer-to-peer transactions
  - Handle price discovery and bidding systems
  - Manage ownership transfers and escrow
  - Track trading history and market analytics

## Key Features

- **Digital Fishing Licenses**: Transform traditional paper licenses into secure NFTs
- **Tradeable Rights**: Enable buying, selling, and leasing of fishing access rights
- **Quota Management**: Track and enforce fishing quotas and catch limits
- **Regulatory Compliance**: Built-in mechanisms to ensure legal compliance
- **Market Transparency**: Open marketplace with transparent pricing and history
- **Conservation Integration**: Support for sustainable fishing practices

## License Types Supported

### Commercial Fishing Licenses
- **Deep Sea Fishing**: Rights for commercial ocean fishing operations
- **Coastal Fishing**: Access to specific coastal zones and waters
- **Species-Specific**: Licenses for particular fish species or quotas
- **Seasonal Permits**: Time-limited fishing rights for specific seasons

### Recreational Fishing Licenses
- **General Fishing**: Basic recreational fishing permits
- **Tournament Licenses**: Rights for competitive fishing events
- **Charter Operations**: Commercial licenses for recreational fishing charters
- **Special Access**: Permits for restricted or premium fishing areas

## Use Cases

- **License Digitization**: Convert existing paper licenses to NFTs
- **Rights Trading**: Enable efficient trading of fishing access rights
- **Quota Management**: Track and transfer fishing quotas between operators
- **Conservation Funding**: Generate revenue for marine conservation efforts
- **Market Access**: Provide smaller operators access to valuable fishing rights
- **Compliance Monitoring**: Automated tracking of fishing activities and limits

## Getting Started

### Prerequisites
- Clarinet CLI tool installed
- Stacks wallet for testing
- Node.js for running tests
- Understanding of NFT and blockchain concepts

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd AquaNet

# Install dependencies
npm install

# Check contract syntax
clarinet check

# Run tests
npm test
```

### Basic Usage

1. **Issue License**: Create a new fishing license NFT with specific parameters
2. **List for Sale**: Put fishing licenses on the marketplace for trading
3. **Transfer Rights**: Securely transfer ownership of fishing rights
4. **Track Compliance**: Monitor quota usage and regulatory compliance

## Contract API

### Fishing License Contract
- `issue-license`: Create a new fishing license NFT
- `renew-license`: Extend the validity of an existing license
- `update-quota`: Modify fishing quotas or catch limits
- `verify-compliance`: Check license validity and compliance status

### License Marketplace
- `list-license`: Put a license up for sale or lease
- `buy-license`: Purchase a fishing license from another user
- `transfer-license`: Transfer ownership of a license
- `get-market-data`: Retrieve marketplace statistics and pricing

## Regulatory Framework

- **Compliance Integration**: Built-in checks for local fishing regulations
- **Quota Enforcement**: Automated tracking of catch limits and quotas
- **Reporting Systems**: Generate compliance reports for regulatory authorities
- **Conservation Support**: Integration with marine conservation programs

## Security Considerations

- All license data is stored securely on-chain
- Ownership transfers are cryptographically secured
- Built-in fraud prevention mechanisms
- Emergency pause functionality for critical issues
- Comprehensive audit trails for all transactions

## Environmental Impact

- **Sustainable Practices**: Promotes responsible fishing through quota management
- **Conservation Funding**: Platform fees can support marine conservation
- **Data Transparency**: Open data supports fisheries research and management
- **Efficiency Gains**: Reduces administrative overhead and paper waste

## Testing

The project includes comprehensive test suites covering:
- License issuance and management workflows
- Marketplace trading functionality
- Compliance and regulatory checks
- Edge cases and error conditions
- Integration between contracts

## Contributing

Please read our contributing guidelines and ensure all tests pass before submitting pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This platform is designed to work within existing legal frameworks for fishing rights and regulations. Users must ensure compliance with all applicable local, national, and international fishing laws and regulations. The platform does not grant actual fishing rights but rather facilitates the management and trading of existing legally-issued licenses.

# AfterlifeVault

A decentralized smart contract platform for secure cross-chain digital asset inheritance.

## Overview

AfterlifeVault is a Clarity smart contract that enables automatic distribution of digital assets across multiple blockchains in case of extended account inactivity. It implements a trustee-based verification system to ensure secure and reliable asset transfers to designated heirs.

## Features

- Multi-chain asset distribution
- Configurable dormancy detection
- Trustee-based verification system
- Support for STX, fungible tokens, and NFTs
- Cross-chain bridge integration
- Flexible heir allocation system

## Contract Architecture

### Core Components

- **Dormancy Detection**: Monitors account activity through periodic checkpoints
- **Trustee System**: Requires multiple trustee approvals for distribution
- **Asset Management**: Handles various digital assets including STX, FTs, and NFTs
- **Cross-Chain Bridge**: Facilitates asset transfers across different blockchains

### Security Features

- Multi-signature requirement for distributions
- Configurable dormancy threshold
- Admin-only privileged operations
- Transaction verification system

## Setup and Usage

### Initial Setup

```clarity
(contract-call? afterlife-vault setup u52560) ;; Set dormancy period to ~365 days
```

### Adding Trustees

```clarity
(contract-call? afterlife-vault add-trustee 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Configuring Heirs

```clarity
(contract-call? afterlife-vault add-heir 
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
    (list 
        {asset: "stx", share: u50}
        {asset: "citycoins", share: u30}))
```

### Cross-Chain Setup

```clarity
(contract-call? afterlife-vault configure-network 
    "ethereum"
    'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR 
    u12
    true)
```

## Error Codes

- `ERR-UNAUTHORIZED (u100)`: Unauthorized access attempt
- `ERR-SETUP-COMPLETE (u101)`: Contract already initialized
- `ERR-INVALID-HEIR (u102)`: Invalid heir address
- `ERR-TRUSTEE-QUORUM (u103)`: Insufficient trustee approvals
- `ERR-INACTIVE (u104)`: Account still active
- `ERR-CHAIN-INVALID (u105)`: Unsupported blockchain
- `ERR-BRIDGE-FAIL (u106)`: Bridge operation failed
- `ERR-MAX-REACHED (u107)`: List capacity exceeded
- `ERR-NO-BRIDGE (u108)`: Bridge contract not configured

## Best Practices

1. Always maintain regular account activity to prevent unintended distributions
2. Select trustees carefully and ensure they understand their responsibilities
3. Keep heir information and allocation percentages up to date
4. Test distributions with small amounts first
5. Regularly verify cross-chain bridge configurations

## Contributing

Contributions are welcome! Please submit issues and pull requests to improve the contract's functionality and security.


# BitFlow Protocol - Bitcoin Liquidity Engine for Stacks L2

## Overview

BitFlow is a decentralized liquidity protocol enabling Bitcoin-native yield generation through secure Stacks Layer 2 smart contracts. Designed as a Bitcoin DeFi primitive, it combines Bitcoin's security with Stacks L2 efficiency to create a non-custodial liquidity pool solution with institutional-grade risk management.

## Key Features

### Core Protocol Mechanics

- **Satoshi-Native Accounting**: All operations use Bitcoin's native unit (satoshi)
- **Dynamic APY Engine**: Market-responsive yield calculation (500-10,000 basis points range)
- **Compound Yield System**: Block-height based accrual (Stacks L2 block time: ~10 minutes)
- **sBTC Integration**: Compatible with Bitcoin cross-chain bridge operations

### Security Architecture

- **Multi-Layered Access Control**
  - Contract owner privileges
  - Authorized operator system
  - Emergency circuit breakers
- **Transaction Safeguards**
  - Minimum deposit: 0.01 BTC (1M sats)
  - Maximum user deposit: 10 BTC
  - Total pool cap: 1,000 BTC

### Compliance Framework

- Activity logging with immutable audit trails
- Regulatory-friendly deposit limits
- Withdrawal cooldown enforcement
- Transparent yield history snapshots

## Technical Specifications

### Protocol Constants

| Parameter                   | Value      | Description                             |
| --------------------------- | ---------- | --------------------------------------- |
| `blocks-per-year`           | 52,560     | Stacks L2 blocks/year (10min intervals) |
| `basis-points-denominator`  | 10,000     | Precision for percentage calculations   |
| `emergency-cooldown-period` | 144 blocks | 24h security lock (1 block = 10 mins)   |

### Error Code Registry

| Code    | Description                                                     |
| ------- | --------------------------------------------------------------- |
| 100-112 | Range of specific error conditions (authorization, limits, etc) |

## Key Functions

### User Operations

1. **Deposit BTC**

   - Parameters: `amount` (satoshi)
   - Requirements: Active pool, within deposit limits
   - Effect: Updates user balance + initiates yield accrual

2. **Withdraw BTC**

   - Parameters: `amount` (satoshi)
   - Validation: Sufficient balance, active pool status
   - Effect: Reduces user position + updates liquidity pool

3. **Claim Yield**
   - Automatic yield calculation since last action
   - Resets accumulated yield to zero
   - Updates total protocol yield paid

### Administrative Functions

- **Pool Configuration**

  - Toggle pool activation
  - Set yield rate (basis points)
  - Adjust deposit parameters

- **Security Controls**
  - Emergency pause/resume system
  - Operator management
  - Protocol cooldown enforcement

## Event System

### Logged Activities

| Event Type       | Data Captured                     |
| ---------------- | --------------------------------- |
| DEPOSIT/WITHDRAW | User, amount, block height        |
| YIELD_CLAIM      | User, yield amount                |
| PROTOCOL_CHANGE  | Parameter updates, status changes |

## Audit Trails

- Immutable yield rate snapshots
- Historical user position tracking
- Permanent event registry (non-prunable)

## Security Model

### Protection Layers

1. **Transaction Validation**

   - Deposit/withdrawal amount checks
   - Pool capacity enforcement
   - Time-locked emergency actions

2. **Access Control**

   - Owner-restricted critical functions
   - Operator allowlist system
   - Multi-factor parameter changes

3. **Financial Safeguards**
   - Anti-drainage mechanisms
   - Yield calculation sanity checks
   - Reserve verification system

## Development Guide

### Contract Interactions

```clarity
;; Sample Deposit Call
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bitflow deposit u50000000)

;; Yield Claim Example
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bitflow claim-yield)
```

### Testing Framework

- Comprehensive test suite covering:
  - Yield calculation accuracy
  - Edge case handling (max deposits, full pool)
  - Security scenario simulations
  - Failure mode verification

## Compliance Features

### Regulatory Alignment

- User activity monitoring hooks
- Withdrawal pattern analysis
- Sanctions screening integration points
- Tax reporting-ready event logs

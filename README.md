# EduVault: Decentralized Scholarship Fund

EduVault is a blockchain-based platform that revolutionizes educational funding through decentralized scholarship management, transparent governance, and yield generation mechanisms.

## Overview

EduVault creates a sustainable ecosystem where donors, educators, and alumni collaborate to support student education through a smart contract-powered scholarship fund. The platform incorporates DAO governance, performance-based disbursement, and yield generation through staking.

## Key Features

### 1. Smart Contract-Based Scholarship Management
- Automated fund distribution based on verifiable academic criteria
- Performance tracking for GPA and attendance
- Multi-stage verification process
- Transparent fund allocation and disbursement

### 2. Decentralized Governance
- DAO structure for stakeholder participation
- Democratic decision-making process for:
  - Fund allocation
  - Eligibility criteria modification
  - System parameter updates
- Weighted voting based on stake and contribution
- Proposal creation and voting mechanisms

### 3. Staking and Yield Generation
- Staking mechanism for donations
- Annual yield generation (default 5%)
- Minimum lock periods for stability
- Reward calculation based on stake amount and duration
- Flexible unstaking options with reward distribution

## Technical Architecture

### Smart Contract Components

#### Data Structures
- Stakeholder Management
- Student Records
- Scholarship Rounds
- Proposal System
- Voting Mechanism

#### Core Functions

##### Stakeholder Operations
```clarity
register-stakeholder (role)
donate ()
stake-tokens (amount)
unstake-tokens (amount)
```

##### Student Management
```clarity
register-student (gpa, attendance, graduation-year)
```

##### Governance
```clarity
create-proposal (type, description, value, target-round)
cast-vote (proposal-id, vote-for)
```

##### Read Operations
```clarity
get-proposal (proposal-id)
get-stakeholder-info (address)
get-student-info (address)
get-pending-rewards (address)
```

## System Requirements

### Minimum Stake Requirements
- Minimum donation: 1,000,000 microSTX
- Minimum voting power: 1,000,000 microSTX
- Minimum lock period: ~1 year (52,560 blocks)

### Academic Criteria
- GPA tracking (0-400 scale, multiplied by 100)
- Attendance tracking (0-100%)
- Graduation year validation

## Getting Started

### For Donors
1. Send a minimum donation of 1,000,000 microSTX
2. Register as a stakeholder with the "donor" role
3. Optionally stake tokens for yield generation
4. Participate in governance through proposal voting

### For Students
1. Register with current GPA and attendance records
2. Maintain required academic standards
3. Track scholarship eligibility and disbursements
4. Submit necessary verification documentation

### For Educators and Alumni
1. Register as stakeholders with appropriate roles
2. Participate in governance
3. Help verify student credentials
4. Contribute to fund management decisions

## Governance Participation

### Proposal Types
1. Fund Distribution
2. Parameter Changes
3. Governance Updates

### Voting Process
1. Proposal Creation
   - Must meet minimum voting power requirement
   - Include clear description and parameters
2. Voting Period
   - 24-hour duration (~144 blocks)
   - Weighted voting based on stake
3. Execution
   - Requires quorum (50% of total voting power)
   - Automatic execution upon approval

## Security Features

- Role-based access control
- Stake-weighted voting
- Minimum lock periods
- Value validation
- Oracle integration for external data
- Error handling and input validation

## Error Codes

- `100`: Owner-only operation
- `101`: Invalid amount
- `102`: Not eligible
- `103`: Already disbursed
- `104`: Not stakeholder
- `105`: Proposal not found
- `106`: Already voted
- `107`: Proposal ended
- `108`: Threshold not met
- `109`: Insufficient stake
- `110`: Lock period active
- `111`: Invalid role
- `112`: Invalid proposal type
- `113`: Invalid description
- `114`: Invalid graduation year
- `115`: Invalid target round
- `116`: Invalid proposal value

## Contributing

We welcome contributions to EduVault! Please read our contributing guidelines before submitting pull requests.


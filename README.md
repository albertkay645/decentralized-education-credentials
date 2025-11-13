# Decentralized Education Credentials

A blockchain-based system for managing education certificates and skill credentials with global acceptance and instant verification.

## Overview

This project implements a decentralized credentialing system that enables students to own their academic records while allowing employers and institutions to verify credentials instantly. The system eliminates credential fraud, reduces verification costs by 95%, and creates lifelong learning portfolios recognized across borders.

## Features

### 🎓 Credential Issuance & Storage
- Issues tamper-proof digital diplomas, certificates, and transcripts from accredited institutions
- Stores comprehensive learning records including courses, skills, projects, and assessments  
- Enables granular sharing of specific credentials without revealing entire academic history
- Implements multi-institution verification for transfer credits and continuing education
- Provides alumni with permanent access to credentials regardless of institution status

### ✅ Skill Verification & Endorsement
- Allows employers and peers to endorse specific skills creating verifiable reputation
- Connects credentials to job requirements for automated candidate screening
- Tracks continuing education and skill updates throughout professional career
- Creates skill marketplaces where learners can monetize verified expertise through teaching
- Enables competency-based hiring focusing on demonstrated abilities over traditional degrees

## Smart Contracts

### credential-issuance-and-storage.clar (391 lines)
Manages the issuance, storage, and sharing of academic credentials with multi-institution support.

**Key Functions:**
- `register-institution`: Register accredited institutions
- `issue-credential`: Issue tamper-proof academic credentials
- `share-credential`: Granular credential sharing with expiration
- `add-learning-record`: Store detailed course and assessment records
- `verify-transfer-credits`: Multi-institution credit verification

### skill-verification-and-endorsement.clar (533 lines)
Handles skill endorsements, reputation tracking, and competency verification for employment.

**Key Functions:**
- `register-skill`: Register professional skills with verification
- `endorse-skill`: Peer and employer skill endorsements
- `create-job-requirement`: Post job requirements with skill matching
- `add-continuing-education`: Track professional development
- `create-skill-offering`: Monetize verified skills in marketplace

## Technology Stack

- **Blockchain**: Stacks (Bitcoin Layer 2)
- **Smart Contract Language**: Clarity
- **Development Framework**: Clarinet
- **Testing**: Vitest

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm installed

### Installation

```bash
# Clone the repository
git clone https://github.com/albertkay645/decentralized-education-credentials.git

# Navigate to project directory
cd decentralized-education-credentials

# Install dependencies
npm install
```

### Development

```bash
# Check contract syntax
clarinet check

# Run tests
npm test

# Start Clarinet console
clarinet console
```

## Project Structure

```
decentralized-education-credentials/
├── contracts/
│   ├── credential-issuance-and-storage.clar (391 lines)
│   └── skill-verification-and-endorsement.clar (533 lines)
├── tests/
│   ├── credential-issuance-and-storage.test.ts
│   └── skill-verification-and-endorsement.test.ts
├── settings/
│   ├── Devnet.toml
│   ├── Testnet.toml
│   └── Mainnet.toml
├── Clarinet.toml
└── package.json
```

## Use Cases

1. **University Credential Issuance**: Accredited institutions issue verifiable digital diplomas
2. **Employer Verification**: Instant verification of candidate credentials without contacting institutions
3. **Skill Endorsements**: Professional peers endorse specific skills creating reputation scores
4. **Lifelong Learning**: Continuous tracking of professional development and certifications
5. **Cross-Border Recognition**: Global acceptance of credentials without complex equivalency processes

## Benefits

- **For Students**: Own and control academic records permanently
- **For Institutions**: Reduce administrative burden of verification requests
- **For Employers**: Instantly verify credentials and skills, reducing hiring fraud
- **For Society**: Enable trusted credential systems across borders and institutions

## Security

All credentials are cryptographically secured on the Stacks blockchain, leveraging Bitcoin's security model. Smart contracts enforce strict access controls and validation rules.

## License

MIT License

## Contributing

Contributions are welcome! Please open issues and pull requests for improvements.

## Contact

For questions or support, please open an issue on GitHub.

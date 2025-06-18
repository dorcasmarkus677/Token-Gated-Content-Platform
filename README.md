# 🔐 Token Gated Content Platform

A decentralized platform built on Stacks blockchain that enables creators to publish exclusive content accessible only to NFT holders. Perfect for premium content, exclusive communities, and token-gated experiences! 🚀

## ✨ Features

- 🎨 **NFT-Gated Access**: Only verified NFT holders can access premium content
- 📝 **Content Management**: Creators can publish, update, and manage their exclusive content
- 🔍 **Access Tracking**: Monitor who accesses your content and when
- 🤝 **Interactive Content**: Users can interact with content (comments, likes, etc.)
- ⚙️ **Admin Controls**: Platform owner can authorize/revoke NFT contracts
- 📊 **Analytics**: Track content performance and user engagement

## 🏗️ Smart Contracts

### Main Contract: `token-gated-content.clar`
The core platform contract handling content creation, access control, and user interactions.

### Mock NFT Contract: `mock-nft.clar`
A sample NFT contract for testing and demonstration purposes.

## 🚀 Getting Started

### Prerequisites
- Clarinet installed
- Stacks wallet for testing

### Installation

```bash
git clone <your-repo>
cd token-gated-content-platform
clarinet check
```

## 📖 Usage Guide

### For Platform Admins

#### Authorize NFT Contract
```clarity
(contract-call? .token-gated-content authorize-nft-contract 'SP000000000000000000002Q6VF78.nft-contract)
```

#### Update Platform Fee
```clarity
(contract-call? .token-gated-content update-platform-fee u300)
```

### For Content Creators

#### Create Exclusive Content
```clarity
(contract-call? .token-gated-content create-content 
  "Premium Tutorial" 
  "Advanced blockchain development guide" 
  "QmHash123..." 
  'SP000000000000000000002Q6VF78.authorized-nft)
```

#### Toggle Content Status
```clarity
(contract-call? .token-gated-content toggle-content-status u1)
```

### For NFT Holders

#### Access Content
```clarity
(contract-call? .token-gated-content access-content u1 u42)
```

#### Interact with Content
```clarity
(contract-call? .token-gated-content interact-with-content 
  u1 
  u42 
  "comment" 
  "Great content!")
```

### Read-Only Functions

#### Check Content Info
```clarity
(contract-call? .token-gated-content get-content-info u1)
```

#### Verify Access Rights
```clarity
(contract-call? .token-gated-content can-access-content 
  'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE 
  u1 
  u42)
```

#### Check NFT Ownership
```clarity
(contract-call? .token-gated-content verify-nft-ownership 
  'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE 
  u42)
```

## 🧪 Testing

### Run Tests
```bash
clarinet test
```

### Deploy Locally
```bash
clarinet integrate
```

## 🔧 Configuration

### Environment Variables
- `PLATFORM_FEE`: Default platform fee percentage (250 = 2.5%)
- `CONTRACT_OWNER`: Platform administrator address

### Customization
- Modify content metadata fields in `content-registry` map
- Adjust access control logic in `access-content` function
- Extend interaction types in `interact-with-content`

## 📊 Data Structures

### Content Registry
- Content ID, creator, title, description
- Content hash (IPFS/Arweave), NFT contract
- Creation timestamp, active status

### Access Tracking
- User access logs with timestamps
- Interaction history and analytics
- NFT ownership verification

##

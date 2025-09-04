# IPFS Setup Instructions

## Overview
This app uses IPFS (InterPlanetary File System) for decentralized storage of NFT images and metadata. We're using Pinata as our IPFS provider for reliable pinning and fast access.

## Required Setup

### 1. Get Pinata API Keys

1. Go to [Pinata Cloud](https://pinata.cloud)
2. Create a free account
3. Go to your account settings
4. Generate API keys:
   - **Pinata API Key**: Your public API key
   - **Pinata Secret API Key**: Your secret API key

### 2. Update IPFS Service Configuration

Edit `lib/shared/services/ipfs_service.dart` and replace the placeholder values:

```dart
// Replace these with your actual Pinata API keys
static const String _pinataApiKey = 'YOUR_PINATA_API_KEY';
static const String _pinataSecretKey = 'YOUR_PINATA_SECRET_KEY';
```

### 3. Test IPFS Connection

The app includes a test function to verify IPFS connectivity. You can test it by:

1. Running the app
2. Going to Event Creation screen
3. Completing all steps to reach the final step
4. Clicking "Test Web3 Connection" button
5. Check console logs for IPFS test results

## Features

### What gets uploaded to IPFS:

1. **NFT Images**: Event images are uploaded to IPFS for decentralized storage
2. **Event Metadata**: Complete event information including boundaries, dates, etc.
3. **NFT Metadata**: Individual NFT metadata following OpenSea standards

### Fallback Strategy:

If IPFS upload fails, the app automatically falls back to Supabase storage to ensure functionality.

## IPFS URLs

- **Gateway**: `https://gateway.pinata.cloud/ipfs/`
- **API**: `https://api.pinata.cloud`

## File Structure

```
lib/shared/services/
├── ipfs_service.dart          # Main IPFS service
├── web3_service.dart          # Web3 blockchain service
└── test_web3_integration.dart # Integration tests
```

## Testing

The app includes comprehensive tests for:
- IPFS service initialization
- File upload functionality
- Metadata creation
- Error handling and fallbacks

## Security Notes

- Never commit your actual API keys to version control
- Use environment variables in production
- Consider using Pinata's JWT authentication for enhanced security

## Support

If you encounter issues with IPFS:
1. Check your API keys are correct
2. Verify your Pinata account has sufficient quota
3. Check network connectivity
4. Review console logs for detailed error messages

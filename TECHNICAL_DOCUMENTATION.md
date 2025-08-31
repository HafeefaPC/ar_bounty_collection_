# FaceReflector - Technical Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Technical Architecture](#technical-architecture)
3. [System Components](#system-components)
4. [Data Flow Architecture](#data-flow-architecture)
5. [API Specifications](#api-specifications)
6. [Security Implementation](#security-implementation)
7. [Performance Considerations](#performance-considerations)
8. [Deployment Architecture](#deployment-architecture)
9. [Testing Strategy](#testing-strategy)
10. [Monitoring and Logging](#monitoring-and-logging)

## Project Overview

FaceReflector is an AR-powered event goodies application that combines Flutter mobile development, blockchain technology, and augmented reality to create interactive location-based NFT claiming experiences.

### Key Technologies
- **Frontend**: Flutter 3.8.1+ with Dart 3.0+
- **Backend**: Supabase (PostgreSQL + Real-time subscriptions)
- **Blockchain**: Solidity smart contracts on Avalanche Fuji testnet
- **AR**: Camera integration with location-based boundary detection
- **Wallet Integration**: WalletConnect v2 with Reown AppKit
- **Storage**: IPFS via Pinata for decentralized metadata storage

## Technical Architecture

### High-Level Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │    Supabase     │    │   Blockchain    │
│                 │    │                 │    │                 │
│ • AR View       │◄──►│ • PostgreSQL   │◄──►│ • EventFactory  │
│ • Wallet Connect│    │ • Real-time    │    │ • BoundaryNFT   │
│ • Location      │    │ • Auth         │    │ • IPFS Storage  │
│ • Camera        │    │ • Storage      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Architecture Layers

#### 1. Presentation Layer (Flutter)
- **State Management**: Riverpod for reactive state management
- **Navigation**: GoRouter for declarative routing
- **UI Components**: Custom retro-themed widgets with pixelated design
- **Responsive Design**: Adaptive layouts for different screen sizes

#### 2. Business Logic Layer
- **Services**: AR, Wallet, Smart Contract, and Supabase services
- **Providers**: Riverpod providers for state management
- **Models**: Event, Boundary, and User data models
- **Validators**: Form validation and business rule enforcement

#### 3. Data Layer
- **Local Storage**: SharedPreferences and SQLite for offline data
- **Remote Storage**: Supabase for real-time data synchronization
- **Blockchain**: Web3Dart for smart contract interactions
- **File Storage**: IPFS for decentralized metadata storage

#### 4. Infrastructure Layer
- **Authentication**: Wallet-based authentication via Supabase
- **Real-time**: WebSocket connections for live updates
- **Push Notifications**: Local notifications for proximity alerts
- **Analytics**: User behavior tracking and event metrics

## System Components

### 1. Flutter Application Structure

```
lib/
├── core/                    # Core application logic
│   ├── providers/          # Riverpod providers
│   ├── routing/            # GoRouter configuration
│   └── theme/              # App theme and styling
├── features/               # Feature modules
│   ├── ar_view/           # AR camera and boundary detection
│   ├── event_creation/    # Event creation workflow
│   ├── event_joining/     # Event participation
│   ├── wallet/            # Wallet connection and management
│   └── splash/            # App initialization
├── shared/                 # Shared components
│   ├── models/            # Data models
│   ├── services/          # Business logic services
│   └── providers/         # Shared providers
└── main.dart              # Application entry point
```

### 2. Smart Contract Architecture

#### EventFactory Contract
- **Purpose**: Manages event creation and lifecycle
- **Key Functions**:
  - `createEvent()`: Deploy new events with metadata
  - `joinEvent()`: Allow users to participate
  - `getEventByCode()`: Retrieve event by unique code
  - `incrementClaimedCount()`: Track NFT claims

#### BoundaryNFT Contract
- **Purpose**: ERC-721 NFT implementation for boundaries
- **Key Functions**:
  - `mintBoundaryNFT()`: Create new boundary NFTs
  - `claimBoundaryNFT()`: Claim NFTs with location verification
  - `batchMintBoundaryNFTs()`: Bulk minting for efficiency
  - `getNFTMetadata()`: Retrieve NFT information

### 3. Database Schema

#### Core Tables
- **events**: Event information and blockchain data
- **boundaries**: NFT boundary locations and metadata
- **users**: Wallet-based user accounts
- **event_participants**: User participation tracking
- **nft_claims**: Claim verification and blockchain transactions
- **user_proximity_logs**: Location verification data

#### Key Features
- **PostGIS Integration**: Spatial queries for location-based operations
- **Row Level Security**: Fine-grained access control
- **Real-time Subscriptions**: Live updates for AR view
- **JSONB Fields**: Flexible metadata storage

## Data Flow Architecture

### 1. Event Creation Flow

```
User Input → Form Validation → Smart Contract Deployment → Database Storage → IPFS Upload
     ↓              ↓                ↓                    ↓              ↓
Event Details → Validation Rules → Blockchain TX → Supabase Insert → Metadata Hash
```

#### Detailed Steps:
1. **Form Collection**: User inputs event details (name, description, venue, dates)
2. **Area Selection**: Google Maps integration for boundary drawing
3. **Smart Contract Deployment**: 
   - Deploy EventFactory contract
   - Create event with geographic coordinates
   - Generate unique event code
4. **Database Storage**: Save event to Supabase with blockchain references
5. **NFT Minting**: Batch mint boundary NFTs for all locations
6. **IPFS Storage**: Upload event metadata and images

### 2. Event Participation Flow

```
Event Code → Validation → User Registration → AR View → Location Detection → NFT Claiming
     ↓           ↓            ↓              ↓           ↓              ↓
Code Check → Event Exists → Join Event → Camera Init → GPS Check → Smart Contract
```

#### Detailed Steps:
1. **Code Validation**: Verify event code exists and is active
2. **User Registration**: Add user to event participants
3. **AR View Initialization**: 
   - Initialize camera and sensors
   - Load event boundaries
   - Set up real-time location tracking
4. **Proximity Detection**: 
   - Monitor GPS coordinates
   - Calculate distance to boundaries
   - Trigger AR overlays when within range
5. **NFT Claiming**: 
   - Verify location proof
   - Execute smart contract transaction
   - Update database and UI

### 3. AR Boundary Detection Flow

```
GPS Data → Distance Calculation → Proximity Check → AR Overlay → User Interaction → Claim
   ↓              ↓                ↓              ↓            ↓              ↓
Location → Haversine Formula → Radius Check → 3D Positioning → Tap Event → Blockchain
```

#### Technical Implementation:
- **Location Services**: High-accuracy GPS with Geolocator
- **Distance Calculation**: Haversine formula for precise measurements
- **AR Positioning**: Vector3 coordinates for 3D space positioning
- **Sensor Integration**: Gyroscope and magnetometer for device orientation
- **Performance Optimization**: Caching and throttling for smooth AR experience

## API Specifications

### 1. Supabase API Endpoints

#### Events
```typescript
// Create event
POST /rest/v1/events
{
  "name": "string",
  "description": "string",
  "organizer_wallet_address": "string",
  "latitude": "number",
  "longitude": "number",
  "venue_name": "string",
  "event_code": "string",
  "nft_supply_count": "number"
}

// Get event by code
GET /rest/v1/events?event_code=eq.{code}

// Update event
PATCH /rest/v1/events?id=eq.{id}
```

#### Boundaries
```typescript
// Get nearby boundaries
GET /rest/v1/rpc/get_nearby_boundaries
{
  "user_lat": "number",
  "user_lng": "number",
  "search_radius_meters": "number"
}

// Claim boundary
PATCH /rest/v1/boundaries?id=eq.{id}
{
  "is_claimed": true,
  "claimed_by": "string",
  "claimed_at": "timestamp"
}
```

### 2. Smart Contract Functions

#### EventFactory
```solidity
function createEvent(
    string calldata name,
    string calldata description,
    string calldata venue,
    uint256 startTime,
    uint256 endTime,
    uint256 totalNFTs,
    string calldata metadataURI,
    string calldata eventCode,
    int256 latitude,
    int256 longitude,
    uint256 radius
) external returns (uint256);

function getEventByCode(string calldata eventCode) 
    external view returns (Event memory);
```

#### BoundaryNFT
```solidity
function claimBoundaryNFT(
    uint256 tokenId,
    ClaimProof calldata proof
) external;

function batchMintBoundaryNFTs(
    uint256 eventId,
    string[] calldata names,
    string[] calldata descriptions,
    string[] calldata imageURIs,
    int256[] calldata latitudes,
    int256[] calldata longitudes,
    uint256[] calldata radiuses,
    string[] calldata tokenURIs,
    bytes32[] calldata merkleRoots
) external returns (uint256[] memory);
```

## Security Implementation

### 1. Authentication & Authorization

#### Wallet-Based Authentication
- **WalletConnect v2**: Secure wallet connection protocol
- **JWT Tokens**: Supabase JWT with wallet address claims
- **Role-Based Access**: Organizer vs. participant permissions

#### Smart Contract Security
- **Access Control**: OpenZeppelin AccessControl for role management
- **Reentrancy Protection**: Guards against reentrancy attacks
- **Input Validation**: Comprehensive parameter validation
- **Merkle Proofs**: Location verification using cryptographic proofs

### 2. Data Security

#### Database Security
- **Row Level Security**: Fine-grained access control policies
- **SQL Injection Prevention**: Parameterized queries
- **Data Encryption**: Sensitive data encryption at rest
- **Audit Logging**: Comprehensive activity tracking

#### Location Verification
- **GPS Accuracy**: Minimum accuracy requirements
- **Time Windows**: Proof freshness validation
- **Merkle Trees**: Cryptographic location verification
- **Rate Limiting**: Prevent abuse and spam

### 3. Privacy Protection

#### User Data
- **Minimal Collection**: Only essential data collection
- **Local Storage**: Sensitive data stored locally when possible
- **Anonymization**: Optional user identification
- **Data Retention**: Configurable data retention policies

## Performance Considerations

### 1. Mobile Performance

#### AR Optimization
- **Frame Rate**: Target 60 FPS for smooth AR experience
- **Memory Management**: Efficient image caching and disposal
- **Battery Optimization**: Sensor usage optimization
- **Network Efficiency**: Minimal API calls and data transfer

#### Location Services
- **GPS Accuracy**: Balance between accuracy and battery life
- **Update Frequency**: Adaptive location update intervals
- **Offline Support**: Local caching for offline functionality
- **Background Processing**: Efficient background location updates

### 2. Blockchain Performance

#### Gas Optimization
- **Batch Operations**: Bulk NFT minting and claiming
- **Efficient Storage**: Optimized data structures
- **Event Logging**: Minimal on-chain data storage
- **Layer 2 Consideration**: Future scalability improvements

#### Network Selection
- **Avalanche Fuji**: Fast and cost-effective testnet
- **Mainnet Migration**: Production deployment strategy
- **Multi-Chain Support**: Future cross-chain compatibility

### 3. Database Performance

#### Query Optimization
- **Spatial Indexes**: PostGIS spatial indexing for location queries
- **Connection Pooling**: Efficient database connection management
- **Real-time Subscriptions**: WebSocket optimization
- **Caching Strategy**: Redis integration for future scalability

## Deployment Architecture

### 1. Development Environment

#### Local Development
```bash
# Flutter setup
flutter pub get
flutter run

# Smart contract development
cd contracts
npm install
npx hardhat compile
npx hardhat test

# Database setup
# Use Supabase local development
supabase start
```

#### Testing Environment
- **Flutter Testing**: Unit and widget tests
- **Smart Contract Testing**: Hardhat test suite
- **Integration Testing**: End-to-end testing with testnet
- **Performance Testing**: Load testing for AR components

### 2. Production Deployment

#### Mobile App Deployment
- **Android**: Google Play Store with staged rollouts
- **iOS**: App Store with TestFlight beta testing
- **Code Signing**: Proper certificate management
- **Update Strategy**: In-app updates and store releases

#### Smart Contract Deployment
- **Testnet**: Avalanche Fuji for testing
- **Mainnet**: Avalanche C-Chain for production
- **Verification**: Contract verification on block explorers
- **Monitoring**: Blockchain monitoring and alerting

#### Backend Deployment
- **Supabase**: Managed PostgreSQL service
- **IPFS**: Pinata managed IPFS service
- **CDN**: Global content delivery network
- **Monitoring**: Performance monitoring and alerting

### 3. CI/CD Pipeline

#### Automated Testing
```yaml
# GitHub Actions workflow
name: FaceReflector CI/CD
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter test
      - run: flutter build apk
```

#### Deployment Stages
1. **Development**: Local development and testing
2. **Staging**: Testnet deployment and integration testing
3. **Production**: Mainnet deployment with monitoring

## Testing Strategy

### 1. Testing Pyramid

#### Unit Tests (70%)
- **Models**: Data model validation and serialization
- **Services**: Business logic and API interactions
- **Providers**: State management and data flow
- **Utilities**: Helper functions and calculations

#### Integration Tests (20%)
- **API Integration**: Supabase and blockchain interactions
- **Wallet Integration**: WalletConnect functionality
- **Location Services**: GPS and sensor integration
- **AR Components**: Camera and overlay functionality

#### End-to-End Tests (10%)
- **User Flows**: Complete event creation and participation
- **Cross-Platform**: iOS and Android compatibility
- **Performance**: AR performance and battery usage
- **Security**: Authentication and authorization flows

### 2. Testing Tools

#### Flutter Testing
```dart
// Example unit test
void main() {
  group('Event Model Tests', () {
    test('should create event from JSON', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Event',
        'description': 'Test Description'
      };
      
      final event = Event.fromJson(json);
      
      expect(event.id, 'test-id');
      expect(event.name, 'Test Event');
    });
  });
}
```

#### Smart Contract Testing
```javascript
// Example Hardhat test
describe('EventFactory', function() {
  it('should create event successfully', async function() {
    const eventFactory = await EventFactory.deploy();
    
    const tx = await eventFactory.createEvent(
      'Test Event',
      'Test Description',
      'Test Venue',
      startTime,
      endTime,
      50,
      'ipfs://metadata',
      'TEST01',
      latitude,
      longitude,
      100
    );
    
    expect(tx).to.emit(eventFactory, 'EventCreated');
  });
});
```

### 3. Test Data Management

#### Mock Data
- **Test Events**: Predefined event configurations
- **Test Boundaries**: Sample boundary locations
- **Test Users**: Mock wallet addresses and profiles
- **Test Transactions**: Sample blockchain transactions

#### Test Environment
- **Local Supabase**: Isolated test database
- **Testnet Contracts**: Deployed test smart contracts
- **Mock Services**: Simulated external service responses
- **Test Wallets**: Development wallet accounts

## Monitoring and Logging

### 1. Application Monitoring

#### Performance Metrics
- **AR Performance**: Frame rates and rendering times
- **Location Accuracy**: GPS precision and update frequency
- **Network Latency**: API response times and success rates
- **Battery Usage**: Power consumption optimization

#### Error Tracking
- **Crash Reporting**: Automatic crash detection and reporting
- **Error Logging**: Comprehensive error logging and categorization
- **User Feedback**: In-app error reporting and feedback collection
- **Performance Alerts**: Automated alerting for performance issues

### 2. Blockchain Monitoring

#### Smart Contract Monitoring
- **Transaction Success**: Monitor transaction success rates
- **Gas Usage**: Track gas consumption and optimization
- **Event Logging**: Monitor smart contract events
- **Contract Health**: Automated health checks and alerts

#### Network Monitoring
- **Blockchain Status**: Monitor network health and performance
- **Gas Prices**: Track gas price fluctuations
- **Network Congestion**: Monitor transaction backlogs
- **Node Health**: Ensure reliable network connectivity

### 3. Infrastructure Monitoring

#### Database Monitoring
- **Query Performance**: Monitor slow queries and optimization
- **Connection Pooling**: Track database connection usage
- **Storage Usage**: Monitor database growth and optimization
- **Real-time Performance**: WebSocket connection monitoring

#### API Monitoring
- **Response Times**: Track API endpoint performance
- **Error Rates**: Monitor API error frequencies
- **Rate Limiting**: Track API usage and limits
- **Uptime Monitoring**: Ensure service availability

### 4. Logging Strategy

#### Log Levels
- **DEBUG**: Detailed debugging information
- **INFO**: General application information
- **WARNING**: Potential issues and warnings
- **ERROR**: Error conditions and failures
- **CRITICAL**: Critical system failures

#### Log Categories
- **User Actions**: User interactions and decisions
- **System Events**: Application lifecycle events
- **Performance Data**: Timing and resource usage
- **Security Events**: Authentication and authorization
- **Business Logic**: Event creation and participation

#### Log Storage
- **Local Logs**: Device-local log storage
- **Remote Logs**: Centralized log aggregation
- **Log Rotation**: Automatic log file management
- **Log Analysis**: Automated log analysis and alerting

---

This technical documentation provides a comprehensive overview of the FaceReflector project architecture, implementation details, and operational considerations. For specific implementation questions or additional details, please refer to the source code or contact the development team.


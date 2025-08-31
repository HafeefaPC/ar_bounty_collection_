# FaceReflector - User Flow Documentation

## Table of Contents
1. [Overview](#overview)
2. [Event Creation User Flow](#event-creation-user-flow)
3. [Event Participation User Flow](#event-participation-user-flow)
4. [User Journey Maps](#user-journey-maps)
5. [User Experience Considerations](#user-experience-considerations)
6. [Error Handling and Edge Cases](#error-handling-and-edge-cases)

## Overview

FaceReflector serves two primary user types with distinct workflows:

1. **Event Organizers**: Create and manage AR-powered events with NFT boundaries
2. **Event Participants**: Join events and claim NFTs by exploring real-world locations

Both user types interact with the app through a unified interface that adapts based on their role and current context.

## Event Creation User Flow

### High-Level Flow Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   App Launch    │───►│ Wallet Connect  │───►│  Main Options   │───►│ Create Event    │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │                       │
                                ▼                       ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │ Wallet Options  │    │  Event History  │    │ Event Details   │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
                                                                              │
                                                                              ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │  Area Selection │◄───│ Boundary Config │◄───│ Boundary Place  │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │                       │
                                ▼                       ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │ Smart Contract  │───►│   NFT Minting   │───►│  Event Created  │
                       │   Deployment    │    │                 │    │                 │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Detailed Step-by-Step Flow

#### Step 1: App Launch and Wallet Connection
```
User opens app → Splash screen → Wallet connection screen
     ↓
User connects wallet (Core, MetaMask, Trust Wallet, etc.)
     ↓
Wallet connected successfully → Navigate to main options
```

**User Actions:**
- Tap "Connect Wallet" button
- Select preferred wallet from WalletConnect modal
- Approve connection in wallet app
- View connected wallet address

**System Actions:**
- Initialize WalletConnect session
- Authenticate with Supabase using wallet address
- Store wallet connection state locally
- Navigate to wallet options screen

#### Step 2: Main Options Selection
```
Wallet options screen → User selects "Create Event"
     ↓
Navigate to event creation workflow
```

**User Actions:**
- View wallet connection status
- Select "CREATE EVENT" option
- Navigate to event creation screen

**System Actions:**
- Display wallet connection status
- Show available options (Join Event, Create Event, Boundary History)
- Handle navigation to selected feature

#### Step 3: Event Details Input
```
Event creation screen → Step 1: Event Details
     ↓
User fills out event information form
     ↓
Form validation and completion
```

**User Actions:**
- Enter event name (required)
- Enter event description (required)
- Select start date and time
- Select end date and time
- Enter venue/location (required)
- Set NFT supply count (default: 50)
- Upload NFT image (required)

**System Actions:**
- Validate form inputs in real-time
- Show validation errors
- Enable/disable next step button
- Store form data in local state

**Validation Rules:**
- Event name: Minimum 3 characters
- Description: Minimum 10 characters
- Dates: End date must be after start date
- NFT count: 1-1000 NFTs
- Image: Required, max 1024x1024, 85% quality

#### Step 4: Area Selection
```
Step 2: Area Selection → Google Maps integration
     ↓
User selects event area center and radius
     ↓
Area configuration complete
```

**User Actions:**
- View Google Maps interface
- Search for specific location or use current location
- Tap on map to set event area center
- Adjust area radius using slider (50-500 meters)
- Confirm area selection

**System Actions:**
- Initialize Google Maps with current location
- Handle map interactions and area selection
- Calculate and display selected area
- Store geographic coordinates and radius
- Enable next step when area is selected

**Map Features:**
- Current location detection
- Location search functionality
- Area radius visualization
- Interactive map controls

#### Step 5: Boundary Configuration
```
Step 3: Boundary Configuration → Claim radius setup
     ↓
User configures how participants claim NFTs
     ↓
Configuration complete
```

**User Actions:**
- Set claim radius (1-5 meters)
- Review event summary
- Confirm configuration

**System Actions:**
- Display boundary configuration options
- Show event summary preview
- Calculate total event area coverage
- Enable next step

**Configuration Options:**
- Claim radius: Distance users must be within to claim NFTs
- Event summary: Overview of all configured settings

#### Step 6: Boundary Placement
```
Step 4: Boundary Placement → NFT location setup
     ↓
User places individual NFT boundaries
     ↓
All boundaries placed
```

**User Actions:**
- View map with event area overlay
- Place boundaries by tapping map or using current location
- Use "ADD AT CURRENT LOCATION" button for quick placement
- Clear all boundaries if needed
- Monitor placement progress

**System Actions:**
- Display event area and placed boundaries
- Track boundary placement count
- Show progress indicator
- Validate minimum boundary requirements
- Enable final step when all boundaries are placed

**Placement Tools:**
- Manual map tapping
- Current location placement
- Bulk placement options
- Clear all functionality

#### Step 7: Smart Contract Deployment
```
Create Event button → Smart contract deployment
     ↓
Blockchain transaction execution
     ↓
Event created on blockchain
```

**User Actions:**
- Tap "CREATE EVENT" button
- Approve transaction in wallet
- Wait for blockchain confirmation

**System Actions:**
- Validate all required data
- Deploy EventFactory contract (if first time)
- Create event on blockchain
- Generate unique event code
- Store blockchain transaction hash

**Blockchain Operations:**
- Contract deployment (if needed)
- Event creation transaction
- Event code generation
- Metadata storage

#### Step 8: NFT Minting
```
Event created → Boundary NFT minting
     ↓
Batch mint all boundary NFTs
     ↓
Minting complete
```

**User Actions:**
- Wait for NFT minting process
- View minting progress

**System Actions:**
- Mint boundary NFTs for all placed locations
- Update database with NFT token IDs
- Store IPFS metadata hashes
- Complete event setup

**Minting Process:**
- Batch minting for efficiency
- IPFS metadata upload
- Database synchronization
- Event activation

#### Step 9: Event Completion
```
Event created successfully → Event code display
     ↓
User can share event code
     ↓
Navigate to main options
```

**User Actions:**
- View generated event code
- Copy event code to clipboard
- Share event code with participants
- Continue to main options

**System Actions:**
- Display success message
- Show unique event code
- Provide copy functionality
- Navigate to main options

**Event Code Features:**
- Unique 6-character alphanumeric code
- Easy to share and remember
- Links directly to event

## Event Participation User Flow

### High-Level Flow Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   App Launch    │───►│ Wallet Connect  │───►│  Main Options   │───►│   Join Event    │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │                       │
                                ▼                       ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │ Wallet Options  │    │  Event History  │    │  Event Code     │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
                                                                              │
                                                                              ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │   AR View       │◄───│  Event Join     │◄───│  Code Entry     │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │                       │
                                ▼                       ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │ Location Detect │───►│  NFT Claiming   │───►│  Success View   │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Detailed Step-by-Step Flow

#### Step 1: App Launch and Wallet Connection
```
User opens app → Splash screen → Wallet connection screen
     ↓
User connects wallet (Core, MetaMask, Trust Wallet, etc.)
     ↓
Wallet connected successfully → Navigate to main options
```

**User Actions:**
- Tap "Connect Wallet" button
- Select preferred wallet from WalletConnect modal
- Approve connection in wallet app
- View connected wallet address

**System Actions:**
- Initialize WalletConnect session
- Authenticate with Supabase using wallet address
- Store wallet connection state locally
- Navigate to wallet options screen

#### Step 2: Main Options Selection
```
Wallet options screen → User selects "Join Event"
     ↓
Navigate to event joining workflow
```

**User Actions:**
- View wallet connection status
- Select "JOIN EVENT" option
- Navigate to event join screen

**System Actions:**
- Display wallet connection status
- Show available options (Join Event, Create Event, Boundary History)
- Handle navigation to selected feature

#### Step 3: Event Code Entry
```
Event join screen → Event code input
     ↓
User enters event code or uses demo
     ↓
Code validation and event loading
```

**User Actions:**
- Enter 6-character event code
- Use "TRY DEMO EVENT (TECH24)" button
- Submit code for validation

**System Actions:**
- Validate event code format
- Check if event exists and is active
- Load event details and boundaries
- Navigate to AR view on success

**Code Entry Options:**
- Manual code entry
- Demo event (TECH24)
- Auto-join from deep link

#### Step 4: Event Validation and Join
```
Code submission → Event validation
     ↓
Event found → User joins event
     ↓
Navigate to AR view
```

**User Actions:**
- Wait for event validation
- View event details if successful
- Handle validation errors if any

**System Actions:**
- Query Supabase for event by code
- Verify event is active and not expired
- Add user to event participants
- Load event boundaries and metadata
- Navigate to AR view with event context

**Validation Checks:**
- Event code exists
- Event is currently active
- Event dates are valid
- User hasn't already joined

#### Step 5: AR View Initialization
```
AR view screen → Camera and sensor initialization
     ↓
Event boundaries loaded
     ↓
Location services started
```

**User Actions:**
- Grant camera permissions
- Grant location permissions
- Wait for AR system initialization

**System Actions:**
- Initialize device camera
- Set up location services
- Load event boundaries
- Initialize AR positioning system
- Start real-time location tracking

**Initialization Process:**
- Camera setup and configuration
- GPS initialization and calibration
- Sensor calibration (gyroscope, magnetometer)
- Boundary data loading
- AR overlay preparation

#### Step 6: Location Detection and Proximity
```
AR view active → Real-time location tracking
     ↓
Distance calculation to boundaries
     ↓
Proximity alerts and AR overlays
```

**User Actions:**
- Walk around event area
- Follow proximity hints
- Move closer to boundaries

**System Actions:**
- Track GPS coordinates in real-time
- Calculate distance to all boundaries
- Show proximity hints and directions
- Display AR overlays when within range
- Log proximity data for verification

**Proximity Features:**
- Real-time distance updates
- Directional hints
- Visual proximity indicators
- AR boundary overlays

#### Step 7: AR Boundary Interaction
```
User within claim radius → AR boundary overlay
     ↓
User taps boundary to claim
     ↓
Claim verification process
```

**User Actions:**
- Move within 2 meters of boundary
- View AR boundary overlay
- Tap boundary to initiate claim
- Approve blockchain transaction

**System Actions:**
- Detect user within claim radius
- Display AR boundary overlay
- Handle tap interactions
- Verify location proof
- Execute smart contract transaction

**AR Interaction:**
- 3D boundary positioning
- Interactive tap detection
- Visual feedback and animations
- Claim progress indicators

#### Step 8: NFT Claiming Process
```
Claim initiated → Location verification
     ↓
Smart contract transaction
     ↓
NFT transfer and confirmation
```

**User Actions:**
- Wait for location verification
- Approve transaction in wallet
- View transaction progress

**System Actions:**
- Generate location proof (Merkle tree)
- Verify user is within claim radius
- Execute BoundaryNFT.claimBoundaryNFT()
- Transfer NFT from organizer to user
- Update database and UI

**Claim Process:**
- Location proof generation
- Blockchain transaction execution
- NFT ownership transfer
- Database synchronization
- Success confirmation

#### Step 9: Success and Progress Tracking
```
NFT claimed successfully → Success animation
     ↓
Progress updated
     ↓
Continue exploring or view collection
```

**User Actions:**
- View success animation
- Check updated progress
- Continue exploring for more boundaries
- View claimed NFT collection

**System Actions:**
- Display confetti animation
- Update claimed boundaries count
- Mark boundary as claimed
- Update user progress
- Sync with blockchain

**Success Features:**
- Confetti celebration animation
- Progress tracking updates
- NFT collection view
- Boundary history

## User Journey Maps

### Event Organizer Journey Map

```
Timeline: 0-30 minutes
Goal: Create and deploy AR event with NFT boundaries

┌─────────────┬─────────────┬─────────────┬─────────────┬─────────────┐
│   Launch    │   Connect   │   Create    │   Deploy    │   Complete  │
│     App     │   Wallet    │   Event     │  Contracts  │    Event    │
└─────────────┴─────────────┴─────────────┴─────────────┴─────────────┘
      │             │             │             │             │
      ▼             ▼             ▼             ▼             ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   Splash    │ │  Wallet    │ │ Event Form  │ │ Blockchain  │ │ Event Code  │
│   Screen    │ │ Connection │ │ 4 Steps    │ │ Deployment  │ │ Generated   │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘

Emotional Journey:
Frustration → Relief → Engagement → Excitement → Satisfaction

Pain Points:
- Wallet connection complexity
- Form validation errors
- Blockchain transaction delays
- Technical setup requirements

Delight Moments:
- Successful wallet connection
- Interactive map experience
- Smart contract deployment
- Event code generation
```

### Event Participant Journey Map

```
Timeline: 0-60 minutes
Goal: Join event and claim NFTs through AR exploration

┌─────────────┬─────────────┬─────────────┬─────────────┬─────────────┐
│   Launch    │   Connect   │   Join      │   Explore   │   Claim    │
│     App     │   Wallet    │   Event     │   AR View   │    NFTs    │
└─────────────┴─────────────┴─────────────┴─────────────┴─────────────┘
      │             │             │             │             │
      ▼             ▼             ▼             ▼             ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   Splash    │ │  Wallet    │ │ Event Code  │ │ AR Camera   │ │ Success &   │
│   Screen    │ │ Connection │ │  Entry      │ │ & Location  │ │ Progress    │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘

Emotional Journey:
Curiosity → Relief → Anticipation → Excitement → Achievement

Pain Points:
- Wallet connection setup
- Event code entry errors
- Location permission issues
- AR performance problems

Delight Moments:
- Successful event join
- AR boundary discovery
- Proximity hints
- NFT claiming success
```

## User Experience Considerations

### Accessibility Features

#### Visual Accessibility
- **High Contrast**: Retro theme with strong color contrast
- **Large Text**: Scalable text sizes for readability
- **Icon Labels**: Clear text labels for all icons
- **Color Independence**: Information not conveyed by color alone

#### Motor Accessibility
- **Large Touch Targets**: Minimum 44x44 pixel touch areas
- **Gesture Alternatives**: Multiple ways to perform actions
- **Haptic Feedback**: Vibration feedback for interactions
- **Voice Commands**: Future voice control integration

#### Cognitive Accessibility
- **Clear Navigation**: Simple, intuitive navigation structure
- **Progress Indicators**: Clear progress through multi-step processes
- **Error Prevention**: Validation and confirmation dialogs
- **Help System**: Contextual help and tooltips

### Performance Optimization

#### Loading States
- **Skeleton Screens**: Placeholder content while loading
- **Progress Indicators**: Clear loading progress feedback
- **Lazy Loading**: Load content as needed
- **Caching**: Local storage for frequently accessed data

#### Responsive Design
- **Adaptive Layouts**: Different layouts for screen sizes
- **Orientation Support**: Portrait and landscape modes
- **Device Adaptation**: Optimize for different device capabilities
- **Performance Monitoring**: Track and optimize performance metrics

### Error Handling

#### User-Friendly Error Messages
- **Clear Language**: Simple, non-technical error descriptions
- **Actionable Solutions**: Provide specific steps to resolve issues
- **Contextual Help**: Link to relevant help documentation
- **Retry Options**: Easy retry mechanisms for failed operations

#### Graceful Degradation
- **Offline Support**: Basic functionality without internet
- **Fallback Options**: Alternative paths when features fail
- **Data Persistence**: Save progress to prevent data loss
- **Recovery Mechanisms**: Automatic retry and recovery

## Error Handling and Edge Cases

### Common Error Scenarios

#### Wallet Connection Issues
```
Error: Wallet connection failed
Cause: Network issues, wallet app not responding
Solution: Retry connection, check wallet app status
Fallback: Skip wallet connection, use limited features
```

#### Location Permission Denied
```
Error: Location access denied
Cause: User denied location permissions
Solution: Guide user to enable permissions in settings
Fallback: Manual location entry, reduced AR functionality
```

#### Blockchain Transaction Failures
```
Error: Transaction failed or reverted
Cause: Insufficient gas, network congestion, contract errors
Solution: Retry with higher gas, wait for network improvement
Fallback: Store claim locally, retry later
```

#### Event Not Found
```
Error: Invalid event code
Cause: Typo, expired event, wrong network
Solution: Verify code, check event status
Fallback: Show similar events, contact organizer
```

### Edge Case Handling

#### Network Connectivity Issues
- **Offline Mode**: Cache essential data locally
- **Sync Queue**: Queue operations for when online
- **Connection Retry**: Automatic reconnection attempts
- **Data Validation**: Verify data integrity after sync

#### Device Compatibility
- **Camera Issues**: Fallback to location-only mode
- **GPS Accuracy**: Handle low-accuracy location data
- **Memory Constraints**: Optimize for low-memory devices
- **Battery Optimization**: Balance functionality and battery life

#### User Behavior Patterns
- **Rapid Tapping**: Prevent duplicate actions
- **Navigation Confusion**: Clear breadcrumbs and back buttons
- **Form Abandonment**: Auto-save progress
- **Session Timeout**: Graceful session expiration handling

---

This user flow documentation provides comprehensive coverage of both event creation and participation workflows, including detailed step-by-step processes, user journey maps, and considerations for user experience and error handling. The documentation serves as a guide for developers, designers, and stakeholders to understand the complete user experience of the FaceReflector application.


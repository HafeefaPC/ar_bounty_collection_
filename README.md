# FaceReflector - AR-Powered Event Goodies App

An innovative Flutter application that combines Augmented Reality (AR) technology with Web3 concepts to create interactive event experiences where users can claim virtual goodies by exploring real-world locations.

## 🌟 Features

### For Event Organizers
- **Event Creation**: Create events with custom boundaries and goodies
- **Smart Contract Deployment**: Automatically deploy NFT contracts for each event
- **Map Integration**: Draw boundaries on Google Maps to define claimable areas
- **NFT Management**: Configure NFT metadata and IPFS storage
- **Real-time Management**: Monitor event progress and user engagement

### For Event Participants
- **AR Experience**: Immersive AR view with real-time boundary detection
- **Proximity Detection**: Get hints about how close you are to claimable boundaries
- **Progress Tracking**: See your progress through claimed vs total boundaries
- **NFT Claiming**: Claim real NFTs when you reach boundaries
- **Wallet Integration**: Connect your wallet using WalletConnect

### Core Features
- **Location-based AR**: Boundaries only appear when you're within 2 meters
- **Blockchain Integration**: Real smart contracts for NFT minting and claiming
- **IPFS Storage**: Decentralized metadata storage via Pinata
- **Cross-platform**: iOS and Android support

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK** (3.8.1 or higher)
2. **Dart SDK** (3.0 or higher)
3. **Android Studio** or **VS Code**
4. **Google Maps API Key**
5. **Supabase Account** (for backend)
6. **Pinata Account** (for IPFS)
7. **Wallet** (for testing)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/face_reflector.git
   cd face_reflector
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Google Maps**
   - Get a Google Maps API key from [Google Cloud Console](https://console.cloud.google.com/)
   - Add the key to `android/app/src/main/AndroidManifest.xml`

4. **Configure Supabase**
   - Create a Supabase project at [supabase.com](https://supabase.com)
   - Update your credentials in the app

5. **Run the app**
   ```bash
   flutter run
   ```

## 📱 Usage

### For Event Organizers

1. **Connect Wallet**: Use WalletConnect to connect your wallet
2. **Create Event**: 
   - Fill in event details
   - Use the map to draw boundaries
   - Deploy smart contract automatically
   - Configure NFT metadata
3. **Share Event Code**: Share the generated event code with participants

### For Event Participants

1. **Connect Wallet**: Use WalletConnect to connect your wallet
2. **Join Event**: Enter the event code provided by organizers
3. **Explore**: Walk around the event area with your phone
4. **Claim NFTs**: When you're within 2 meters of a boundary, claim real NFTs
5. **Track Progress**: See your claimed NFTs and overall progress

## 🛠️ Technical Architecture

### Frontend (Flutter)
- **State Management**: Riverpod for reactive state management
- **Navigation**: GoRouter for declarative routing
- **AR**: AR Flutter Plugin for ARKit/ARCore integration
- **Maps**: Google Maps Flutter for location services
- **Blockchain**: Web3Dart for smart contract interactions
- **Wallet**: WalletConnect for wallet integration

### Backend (Supabase)
- **Database**: PostgreSQL with real-time subscriptions
- **Authentication**: Wallet-based authentication
- **Storage**: Supabase Storage for images

### Blockchain
- **Smart Contracts**: Solidity contracts for NFT minting
- **Deployment**: Automated contract deployment
- **IPFS**: Pinata for metadata storage
- **Network**: Supports multiple EVM chains

## 🔧 Configuration

### Environment Variables
Configure your credentials in the app for:
- Supabase URL and keys
- Google Maps API key
- Pinata IPFS credentials
- WalletConnect project ID

## 🚀 Deployment

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

If you encounter any issues, create a new issue with detailed information.

---

**Note**: This application uses real blockchain technology. Ensure proper security measures and testing before production use.
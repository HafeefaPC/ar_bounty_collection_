# FaceReflector - AR-Powered Event Goodies App

An innovative Flutter application that combines Augmented Reality (AR) technology with Web3 concepts to create interactive event experiences where users can claim virtual goodies by exploring real-world locations.

## 🌟 Features

### For Event Organizers
- **Event Creation**: Create events with custom boundaries and goodies
- **Map Integration**: Draw boundaries on Google Maps to define claimable areas
- **Image Upload**: Add custom images that appear in AR when users reach boundaries
- **Real-time Management**: Monitor event progress and user engagement

### For Event Participants
- **AR Experience**: Immersive AR view with real-time boundary detection
- **Proximity Detection**: Get hints about how close you are to claimable boundaries
- **Progress Tracking**: See your progress through claimed vs total boundaries
- **Interactive Claims**: Tap to claim boundaries when you're within range
- **Wallet Integration**: Connect your wallet to receive goodies (simulated for demo)

### Core Features
- **Location-based AR**: Boundaries only appear when you're within 2 meters
- **Proximity Hints**: Smart hints guide users toward boundaries
- **Confetti Celebrations**: Visual feedback when claiming boundaries
- **Offline Support**: Works with cached data when offline
- **Cross-platform**: iOS and Android support

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK** (3.8.1 or higher)
2. **Dart SDK** (3.0 or higher)
3. **Android Studio** or **VS Code**
4. **Google Maps API Key**
5. **Supabase Account** (for backend)

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
   - Add the key to `android/app/src/main/AndroidManifest.xml`:
     ```xml
     <meta-data
       android:name="com.google.android.geo.API_KEY"
     android:value="AIzaSyAFZ2WLSrzRZzw-HvXm3DtlgBLiycAxN0k"/>
   ```

4. **Configure Supabase**
   - Create a Supabase project at [supabase.com](https://supabase.com)
   - Update `lib/shared/services/supabase_service.dart` with your credentials:
   ```dart
   url: 'YOUR_SUPABASE_URL',
   anonKey: 'YOUR_SUPABASE_ANON_KEY',
   ```

5. **Set up database tables**
   Run the following SQL in your Supabase SQL editor:

   ```sql
   -- Events table
   CREATE TABLE events (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     name TEXT NOT NULL,
     description TEXT NOT NULL,
     organizer_wallet_address TEXT NOT NULL,
     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
     start_date TIMESTAMP WITH TIME ZONE,
     end_date TIMESTAMP WITH TIME ZONE,
     latitude DOUBLE PRECISION NOT NULL,
     longitude DOUBLE PRECISION NOT NULL,
     venue_name TEXT NOT NULL,
     event_code TEXT UNIQUE NOT NULL
   );

   -- Boundaries table
   CREATE TABLE boundaries (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     name TEXT NOT NULL,
     description TEXT NOT NULL,
     image_url TEXT NOT NULL,
     latitude DOUBLE PRECISION NOT NULL,
     longitude DOUBLE PRECISION NOT NULL,
     radius DOUBLE PRECISION DEFAULT 1.0,
     is_claimed BOOLEAN DEFAULT FALSE,
     claimed_by TEXT,
     claimed_at TIMESTAMP WITH TIME ZONE,
     event_id UUID REFERENCES events(id) ON DELETE CASCADE,
     position JSONB,
     rotation JSONB,
     scale JSONB
   );

   -- Users table
   CREATE TABLE users (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     wallet_address TEXT UNIQUE NOT NULL,
     username TEXT,
     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
     last_login TIMESTAMP WITH TIME ZONE
   );

   -- Goodies table
   CREATE TABLE goodies (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     name TEXT NOT NULL,
     description TEXT NOT NULL,
     logo_url TEXT NOT NULL,
     latitude DOUBLE PRECISION NOT NULL,
     longitude DOUBLE PRECISION NOT NULL,
     claim_radius DOUBLE PRECISION DEFAULT 15.0,
     is_claimed BOOLEAN DEFAULT FALSE,
     claimed_by TEXT,
     claimed_at TIMESTAMP WITH TIME ZONE,
     event_id UUID REFERENCES events(id) ON DELETE CASCADE
   );

   -- Enable Row Level Security
   ALTER TABLE events ENABLE ROW LEVEL SECURITY;
   ALTER TABLE boundaries ENABLE ROW LEVEL SECURITY;
   ALTER TABLE users ENABLE ROW LEVEL SECURITY;
   ALTER TABLE goodies ENABLE ROW LEVEL SECURITY;

   -- Create policies
   CREATE POLICY "Events are viewable by everyone" ON events FOR SELECT USING (true);
   CREATE POLICY "Events can be created by authenticated users" ON events FOR INSERT WITH CHECK (true);
   CREATE POLICY "Events can be updated by organizers" ON events FOR UPDATE USING (organizer_wallet_address = current_user);

   CREATE POLICY "Boundaries are viewable by everyone" ON boundaries FOR SELECT USING (true);
   CREATE POLICY "Boundaries can be created by event organizers" ON boundaries FOR INSERT WITH CHECK (true);
   CREATE POLICY "Boundaries can be updated when claimed" ON boundaries FOR UPDATE USING (true);

   CREATE POLICY "Users can view their own data" ON users FOR SELECT USING (wallet_address = current_user);
   CREATE POLICY "Users can insert their own data" ON users FOR INSERT WITH CHECK (wallet_address = current_user);

   CREATE POLICY "Goodies are viewable by everyone" ON goodies FOR SELECT USING (true);
   CREATE POLICY "Goodies can be created by event organizers" ON goodies FOR INSERT WITH CHECK (true);
   CREATE POLICY "Goodies can be updated when claimed" ON goodies FOR UPDATE USING (true);
   ```

6. **Set up storage bucket**
   - In Supabase, go to Storage and create a bucket called `images`
   - Set the bucket to public
   - Update the storage policy to allow uploads

7. **Run the app**
   ```bash
   flutter run
   ```

## 📱 Usage

### For Event Organizers

1. **Connect Wallet**: Use the simulated wallet connection
2. **Create Event**: 
   - Fill in event details
   - Use the map to draw boundaries
   - Add images for each boundary
   - Set descriptions for what users will see
3. **Share Event Code**: Share the generated event code with participants

### For Event Participants

1. **Connect Wallet**: Use the simulated wallet connection
2. **Join Event**: Enter the event code provided by organizers
3. **Explore**: Walk around the event area with your phone
4. **Claim Boundaries**: When you're within 2 meters of a boundary, tap to claim
5. **Track Progress**: See your claimed boundaries and overall progress

## 🛠️ Technical Architecture

### Frontend (Flutter)
- **State Management**: Riverpod for reactive state management
- **Navigation**: GoRouter for declarative routing
- **AR**: AR Flutter Plugin for ARKit/ARCore integration
- **Maps**: Google Maps Flutter for location services
- **UI**: Material Design 3 with custom theming

### Backend (Supabase)
- **Database**: PostgreSQL with real-time subscriptions
- **Authentication**: Supabase Auth (wallet-based)
- **Storage**: Supabase Storage for images
- **API**: Auto-generated REST API

### Key Services
- `ARService`: Handles AR functionality and boundary detection
- `SupabaseService`: Manages all backend operations
- `WalletService`: Simulates wallet connections
- `EventService`: Manages event data and operations

## 🔧 Configuration

### Environment Variables
Create a `.env` file in the root directory:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

### Permissions
The app requires the following permissions:
- **Camera**: For AR functionality
- **Location**: For GPS-based boundary detection
- **Storage**: For image uploads

## 🎨 Customization

### Theming
Modify `lib/core/theme/app_theme.dart` to customize colors, fonts, and styling.

### AR Assets
Add custom 3D models and animations to `assets/animations/` for enhanced AR experiences.

### Localization
The app supports multiple languages. Add translations to `lib/core/localization/`.

## 🚀 Deployment

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues:

1. Check the [Issues](https://github.com/yourusername/face_reflector/issues) page
2. Create a new issue with detailed information
3. Join our [Discord](https://discord.gg/your-server) for community support

## 🔮 Roadmap

- [ ] Real Web3 wallet integration
- [ ] NFT goodies and rewards
- [ ] Social features and leaderboards
- [ ] Advanced AR effects and animations
- [ ] Multi-language support
- [ ] Offline mode improvements
- [ ] Analytics dashboard for organizers

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- AR Flutter Plugin contributors
- Supabase for the backend infrastructure
- Google Maps for location services

---

**Note**: This is a demo application. For production use, implement proper security measures, real wallet integration, and comprehensive testing.

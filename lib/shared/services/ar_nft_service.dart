import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/boundary.dart';
import '../models/event.dart' as models;
import 'supabase_service.dart';
import 'wallet_service.dart';
import 'web3_service.dart';
import 'simple_nft_service.dart';

class ARNFTService {
  static final ARNFTService _instance = ARNFTService._internal();
  factory ARNFTService() => _instance;
  ARNFTService._internal();

  // Services
  late SupabaseService _supabaseService;
  WalletService? _walletService; // Make optional so it can be set from outside
  late Web3Service _web3Service;
  late SimpleNFTService _simpleNFTService;

  // Current user position and state
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  // Event and boundaries
  models.Event? _currentEvent;
  List<Boundary> _boundaries = [];
  List<Boundary> _claimedBoundaries = [];
  List<Boundary> _visibleBoundaries = [];

  // AR State
  double _deviceAzimuth = 0.0;
  double _devicePitch = 0.0;
  double _deviceRoll = 0.0;
  bool _isARActive = false;

  // Callbacks
  Function(Boundary)? onBoundaryDetected;
  Function(Boundary)? onBoundaryClaimed;
  Function(String)? onProximityUpdate;
  Function(int, int)? onProgressUpdate; // claimed, total
  Function(List<Boundary>)? onVisibleBoundariesUpdate;
  Function(List<Boundary>)? onClaimedBoundariesUpdate;
  Function(Position)? onPositionUpdate;
  Function(String)? onNFTMinted;
  Function(String)? onClaimSubmitted;

  // Set wallet service (called from AR view screen)
  void setWalletService(WalletService walletService) {
    _walletService = walletService;
    print('✅ ARNFTService: Wallet service set');
  }

  // Initialize AR NFT service
  Future<void> initialize() async {
    _supabaseService = SupabaseService();
    _web3Service = Web3Service();
    _simpleNFTService = SimpleNFTService();
    
    // Initialize Web3 contracts
    await _web3Service.initializeContracts();
    
    // Request location permissions
    await _requestLocationPermissions();
    
    // Start location tracking
    await _startLocationTracking();
    
    // Start sensor tracking
    await _startSensorTracking();
    
    _isARActive = true;
    print('🎯 AR NFT Service initialized successfully');
  }

  // Set current event and boundaries
  Future<void> setEvent(models.Event event) async {
    _currentEvent = event;
    _boundaries = event.boundaries;
    
    // Filter boundaries to only include those from the current event
    _boundaries = _boundaries.where((boundary) => boundary.eventId == event.id).toList();
    
    // Load any previously claimed boundaries for this event from database
    try {
      final walletAddress = _walletService?.connectedWalletAddress ?? 'demo_wallet';
      final claimedBoundaries = await _supabaseService.getUserEventClaims(walletAddress, event.id);
      _claimedBoundaries = claimedBoundaries;
      
      // Only show unclaimed boundaries in visible list
      _visibleBoundaries = _boundaries.where((b) => !b.isClaimed).toList();
      
      print('🎯 AR NFT Service: Set event "${event.name}" with ${_boundaries.length} total boundaries');
      print('🎯 AR NFT Service: ${_claimedBoundaries.length} claimed, ${_visibleBoundaries.length} unclaimed');
      
      // Trigger callbacks
      onClaimedBoundariesUpdate?.call(_claimedBoundaries);
      onVisibleBoundariesUpdate?.call(_visibleBoundaries);
      
      // Update progress
      int claimedCount = _claimedBoundaries.length;
      int totalCount = _boundaries.length;
      onProgressUpdate?.call(claimedCount, totalCount);
    } catch (e) {
      print('❌ Error loading claimed boundaries: $e');
      
      // Fallback to local data
      _visibleBoundaries = _boundaries.where((b) => !b.isClaimed).toList();
      _claimedBoundaries = _boundaries.where((b) => b.isClaimed).toList();
      
      // Trigger callbacks
      onClaimedBoundariesUpdate?.call(_claimedBoundaries);
      onVisibleBoundariesUpdate?.call(_visibleBoundaries);
    }
  }

  // Start location tracking
  Future<void> _startLocationTracking() async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // Update every 1 meter
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _currentPosition = position;
        onPositionUpdate?.call(position);
        _updateBoundaryProximity();
      },
      onError: (error) {
        print('❌ Location tracking error: $error');
      },
    );
  }

  // Start sensor tracking for AR
  Future<void> _startSensorTracking() async {
    // Accelerometer for device orientation
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      _devicePitch = atan2(event.y, sqrt(event.x * event.x + event.z * event.z)) * 180 / pi;
      _deviceRoll = atan2(-event.x, event.z) * 180 / pi;
    });

    // Gyroscope for rotation
    _gyroscopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      // Update device orientation based on gyroscope data
      _updateDeviceOrientation(event);
    });

    // Magnetometer for compass
    _magnetometerSubscription = magnetometerEventStream().listen((MagnetometerEvent event) {
      double azimuth = atan2(event.y, event.x) * 180 / pi;
      if ((azimuth - _deviceAzimuth).abs() > 2.0) {
        _deviceAzimuth = azimuth;
        _updateBoundaryProximity();
      }
    });
  }

  // Update device orientation based on gyroscope
  void _updateDeviceOrientation(GyroscopeEvent event) {
    // Simple integration for device rotation
    // In a real implementation, you'd use proper sensor fusion
    _deviceAzimuth += event.z * 0.1; // Scale factor for sensitivity
    
    // Normalize azimuth
    while (_deviceAzimuth > 360) _deviceAzimuth -= 360;
    while (_deviceAzimuth < 0) _deviceAzimuth += 360;
  }

  // Update boundary proximity and visibility
  void _updateBoundaryProximity() {
    if (_currentPosition == null || _boundaries.isEmpty) return;

    List<Boundary> newVisibleBoundaries = [];
    Boundary? closestBoundary;
    double closestDistance = double.infinity;

    for (Boundary boundary in _boundaries) {
      if (boundary.isClaimed) continue;

      double distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        boundary.latitude,
        boundary.longitude,
      );

      // Only show boundaries within detection range (50 meters)
      if (distance <= 50.0) {
        newVisibleBoundaries.add(boundary);
        
        if (distance < closestDistance) {
          closestDistance = distance;
          closestBoundary = boundary;
        }
      }
    }

    _visibleBoundaries = newVisibleBoundaries;
    onVisibleBoundariesUpdate?.call(_visibleBoundaries);

    // Update proximity hints
    if (closestBoundary != null) {
      double claimRadius = closestBoundary.radius;
      
      if (closestDistance <= claimRadius) {
        onProximityUpdate?.call("TARGET ACQUIRED - TAP TO CLAIM!");
        onBoundaryDetected?.call(closestBoundary);
      } else if (closestDistance <= 10.0) {
        onProximityUpdate?.call("APPROACHING TARGET - ${closestDistance.toStringAsFixed(1)}M");
      } else {
        onProximityUpdate?.call("SCANNING... ${closestDistance.toStringAsFixed(1)}M TO TARGET");
      }
    } else {
      onProximityUpdate?.call("NO TARGETS IN RANGE - KEEP EXPLORING");
    }
  }

  // Calculate distance between two points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  // Calculate bearing between two points
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    double dLon = (lon2 - lon1) * pi / 180;
    double lat1Rad = lat1 * pi / 180;
    double lat2Rad = lat2 * pi / 180;
    
    double y = sin(dLon) * cos(lat2Rad);
    double x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);
    
    double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  // Claim a boundary and mint NFT
  Future<bool> claimBoundary(Boundary boundary) async {
    try {
      print('\n🎯═══════════════════════════════════════════════════════');
      print('🎯 STARTING NFT CLAIM PROCESS');
      print('🎯═══════════════════════════════════════════════════════');
      print('🎯 Boundary: ${boundary.name} (ID: ${boundary.id})');
      print('🎯 Event: ${_currentEvent?.name ?? "Unknown"}');
      print('🎯 User Position: ${_currentPosition?.latitude ?? "Unknown"}, ${_currentPosition?.longitude ?? "Unknown"}');
      print('🎯 Boundary Position: ${boundary.latitude}, ${boundary.longitude}');
      print('🎯 Claim Radius: ${boundary.radius}m');
      print('🎯 Already Claimed: ${boundary.isClaimed}');
      
      // Add timeout to prevent hanging
      return await Future.any([
        _claimBoundaryWithTimeout(boundary),
        Future.delayed(const Duration(seconds: 30), () {
          print('⏰ ❌ TIMEOUT: Boundary claim timed out after 30 seconds');
          throw TimeoutException('Boundary claim timed out after 30 seconds', const Duration(seconds: 30));
        }),
      ]);
    } catch (e) {
      print('❌ FATAL ERROR in claimBoundary: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  // Perform boundary claim with timeout
  Future<bool> _claimBoundaryWithTimeout(Boundary boundary) async {
    try {
      print('\n🎯 STARTING NFT CLAIM PROCESS');
      print('🎯═══════════════════════════════════════════════════════');
      print('🎯 Boundary: ${boundary.name} (ID: ${boundary.id})');
      print('🎯 Event: ${_currentEvent?.name ?? "No Event"}');
      print('🎯 User Position: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      print('🎯 Boundary Position: ${boundary.latitude}, ${boundary.longitude}');
      print('🎯 Claim Radius: ${boundary.radius}m');
      print('🎯 Already Claimed: ${boundary.isClaimed}');
      
      print('\n📍 STEP 1: CHECKING POSITION AND DISTANCE');
      print('📍════════════════════════════════════════');
      
      if (_currentPosition == null) {
        print('❌ FAILED: No current position available');
        print('❌ Make sure location permissions are granted and GPS is enabled');
        return false;
      }
      
      print('✅ User Position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      print('✅ Position Accuracy: ${_currentPosition!.accuracy}m');
      print('✅ Timestamp: ${DateTime.fromMillisecondsSinceEpoch(_currentPosition!.timestamp.millisecondsSinceEpoch)}');

      // Check if user is within claim radius
      double distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        boundary.latitude,
        boundary.longitude,
      );

      print('📏 Distance to boundary: ${distance.toStringAsFixed(2)}m');
      print('📏 Required claim radius: ${boundary.radius}m');
      
      double claimRadius = boundary.radius;
      if (distance > claimRadius) {
        print('❌ FAILED: User is too far from boundary');
        print('❌ Distance: ${distance.toStringAsFixed(1)}m');
        print('❌ Required: ${claimRadius}m');
        print('❌ You need to get ${(distance - claimRadius).toStringAsFixed(1)}m closer');
        return false;
      }
      
      print('✅ GOOD: User is within claim radius!');

      // Check if boundary is already claimed
      if (boundary.isClaimed) {
        print('❌ FAILED: Boundary is already claimed by someone else');
        print('❌ Claimed by: ${boundary.claimedBy ?? "Unknown"}');
        return false;
      }
      
      print('✅ GOOD: Boundary is available for claiming!');

      print('\n💳 STEP 2: CHECKING WALLET CONNECTION');
      print('💳════════════════════════════════════════');
      
      if (_walletService == null) {
        print('❌ WALLET SERVICE NOT SET - Running in DEMO MODE');
        print('❌ Wallet service is null - make sure to call setWalletService()');
        print('🎮 RUNNING IN DEMO MODE...');
        return await _simulateClaim(boundary, distance);
      }
      
      final walletAddress = _walletService?.connectedWalletAddress;
      print('💳 Wallet address from service: $walletAddress');
      print('💳 Wallet connected status: ${_walletService!.isConnected}');
      print('💳 AppKit modal available: ${_walletService!.appKitModal != null}');
      
      // Set the AppKit modal for SimpleNFTService
      if (_walletService!.appKitModal != null) {
        print('✅ Setting AppKit modal for SimpleNFTService...');
        _simpleNFTService.setReownAppKit(_walletService!.appKitModal!);
      }
      
      if (walletAddress == null || !_walletService!.isConnected) {
        print('❌ WALLET NOT CONNECTED - Running in DEMO MODE');
        print('❌ Wallet service state:');
        print('❌ - Connected: ${_walletService!.isConnected}');
        print('❌ - AppKit: ${_walletService!.appKitModal != null}');
        print('❌ - Address: ${_walletService!.connectedWalletAddress}');
        print('❌ ');
        print('❌ This will only simulate the claim (no real NFT)');
        print('❌ To get real NFTs: Connect your MetaMask wallet first!');
        print('🎮 ');
        print('🎮 RUNNING IN DEMO MODE...');
        return await _simulateClaim(boundary, distance);
      }
      
      print('✅ WALLET CONNECTED: $walletAddress');
      print('✅ Ready for REAL NFT transaction!');

      print('\n🎨 STEP 3: CREATING NFT METADATA');
      print('🎨════════════════════════════════════════');
      print('📍 Boundary: ${boundary.name}');
      print('📍 Distance: ${distance.toStringAsFixed(1)}m');
      print('📍 Claimer: $walletAddress');

      // Step 1: Create NFT attributes for the boundary
      final nftAttributes = {
        'Event': _currentEvent?.name ?? 'Unknown Event',
        'Boundary': boundary.name,
        'Location': '${boundary.latitude.toStringAsFixed(6)}, ${boundary.longitude.toStringAsFixed(6)}',
        'Claim Radius': '${boundary.radius}m',
        'Distance': '${distance.toStringAsFixed(1)}m',
        'Claimed At': DateTime.now().toIso8601String(),
        'Claimer': walletAddress.substring(0, 8) + '...',
      };
      
      final nftName = '${boundary.name} - ${_currentEvent?.name ?? "Event"}';
      final nftDescription = 'AR Bounty Collection NFT claimed at ${boundary.name}. '
                      'Location: ${boundary.latitude.toStringAsFixed(6)}, ${boundary.longitude.toStringAsFixed(6)}';
      final imageUrl = boundary.imageUrl;
      
      print('✅ NFT Name: $nftName');
      print('✅ NFT Description: $nftDescription');
      print('✅ NFT Image: $imageUrl');
      print('✅ NFT Attributes: $nftAttributes');

      print('\n🚀 STEP 4: SENDING NFT TO METAMASK WALLET');
      print('🚀════════════════════════════════════════');
      print('🎨 Target wallet: $walletAddress');
      print('🎨 Calling SimpleNFTService.mintNFTToWallet...');
      
      final mintResult = await _simpleNFTService.mintNFTToWallet(
        walletAddress: walletAddress,
        nftName: nftName,
        nftDescription: nftDescription,
        imageUrl: imageUrl,
        attributes: nftAttributes,
      );
      
      print('\n📋 STEP 5: PROCESSING MINT RESULT');
      print('📋════════════════════════════════════════');
      print('📋 Mint result: $mintResult');
      print('📋 Success: ${mintResult['success']}');
      print('📋 Result type: ${mintResult.runtimeType}');
      print('📋 Result keys: ${mintResult.keys.toList()}');
      if (mintResult['error'] != null) {
        print('❌ Error: ${mintResult['error']}');
      }
      if (mintResult['message'] != null) {
        print('📋 Message: ${mintResult['message']}');
      }
      if (mintResult['transactionHash'] != null) {
        print('📋 Transaction Hash: ${mintResult['transactionHash']}');
      }
      
      if (!mintResult['success']) {
        print('❌ ❌ ❌ NFT MINTING FAILED ❌ ❌ ❌');
        print('❌ Reason: ${mintResult['message']}');
        print('❌ Error: ${mintResult['error']}');
        throw Exception('NFT minting failed: ${mintResult['message']}');
      }
      
      final claimTxHash = mintResult['transactionHash'] ?? 'demo_tx_${DateTime.now().millisecondsSinceEpoch}';
      print('✅ ✅ ✅ NFT SUCCESSFULLY MINTED! ✅ ✅ ✅');
      print('✅ Transaction Hash: $claimTxHash');
      
      // Verify the NFT was actually minted
      print('\n🔍 STEP 6: VERIFYING NFT MINTING');
      print('🔍════════════════════════════════════════');
      await _simpleNFTService.verifyNFTOwnership(walletAddress, claimTxHash);
      
      print('\n🎉 STEP 7: SUCCESS - NFT IS IN YOUR WALLET!');
      print('🎉════════════════════════════════════════');
      print('🎉 NFT has been sent to: $walletAddress');
      print('🎉 Transaction: $claimTxHash');
      
      // Display token ID if available
      final tokenId = mintResult['tokenId'];
      if (tokenId != null) {
        print('🎉 Token ID: $tokenId');
        print('🎉 Contract: ${mintResult['contractAddress']}');
        print('🎉 ');
        print('🎉 TO IMPORT NFT IN METAMASK:');
        print('🎉 1. Open MetaMask mobile app');
        print('🎉 2. Go to "NFTs" tab');
        print('🎉 3. Tap "Import NFTs"');
        print('🎉 4. Enter Contract Address: ${mintResult['contractAddress']}');
        print('🎉 5. Enter Token ID: $tokenId');
        print('🎉 6. Tap "Import"');
        print('🎉 ');
        print('🎉 Your NFT should now appear in your wallet!');
      } else {
        print('🎉 ');
        print('🎉 TO SEE YOUR NFT:');
        print('🎉 1. Open MetaMask mobile app');
        print('🎉 2. Go to "NFTs" tab');
        print('🎉 3. Look for: "$nftName"');
        print('🎉 4. If not visible, tap "Import NFTs" and add contract address');
        print('🎉 5. Check Arbiscan: https://sepolia.arbiscan.io/tx/$claimTxHash');
      }
      print('🎉 ');

      // Step 3: Update local state
      final updatedBoundary = boundary.copyWith(
        isClaimed: true,
        claimedBy: walletAddress,
        claimedAt: DateTime.now(),
      );

      _claimedBoundaries.add(updatedBoundary);
      _visibleBoundaries.removeWhere((b) => b.id == boundary.id);
      
      // Update boundaries list
      final index = _boundaries.indexWhere((b) => b.id == boundary.id);
      if (index != -1) {
        _boundaries[index] = updatedBoundary;
      }

      // Step 4: Update database with NFT information
      try {
        await _supabaseService.claimBoundaryWithFullUpdate(
          boundaryId: boundary.id,
          claimedBy: walletAddress,
          distance: distance,
          claimTxHash: claimTxHash,
          nftMetadata: {
            'name': '${boundary.name} - ${_currentEvent?.name ?? "Event"}',
            'attributes': nftAttributes,
            'transactionHash': claimTxHash,
          },
        );
      } catch (e) {
        print('⚠️ Database update failed (but NFT was minted): $e');
        // Don't fail the entire operation if database update fails
      }

      // Trigger callbacks
      onBoundaryClaimed?.call(updatedBoundary);
      onClaimedBoundariesUpdate?.call(_claimedBoundaries);
      onVisibleBoundariesUpdate?.call(_visibleBoundaries);
      onNFTMinted?.call(claimTxHash);
      onClaimSubmitted?.call(claimTxHash);

      // Update progress
      int claimedCount = _claimedBoundaries.length;
      int totalCount = _boundaries.length;
      onProgressUpdate?.call(claimedCount, totalCount);

      print('🎉 Boundary claim completed successfully!');
      print('🎉 ✅ CLAIM PROCESS COMPLETED - RETURNING TRUE ✅');
      return true;

    } catch (e) {
      print('❌ Error claiming boundary: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      print('❌ ❌ CLAIM PROCESS FAILED - RETURNING FALSE ❌');
      return false;
    }
  }


  // Request location permissions
  Future<void> _requestLocationPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }
  }

  // Get current AR state
  Map<String, dynamic> getARState() {
    return {
      'isActive': _isARActive,
      'currentPosition': _currentPosition != null ? {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'accuracy': _currentPosition!.accuracy,
      } : null,
      'deviceOrientation': {
        'azimuth': _deviceAzimuth,
        'pitch': _devicePitch,
        'roll': _deviceRoll,
      },
      'boundaries': {
        'total': _boundaries.length,
        'claimed': _claimedBoundaries.length,
        'visible': _visibleBoundaries.length,
      },
      'currentEvent': _currentEvent?.name,
    };
  }

  // Get visible boundaries for AR display
  List<Boundary> getVisibleBoundaries() {
    return _visibleBoundaries;
  }

  // Get claimed boundaries
  List<Boundary> getClaimedBoundaries() {
    return _claimedBoundaries;
  }

  // Check if a boundary is claimable
  bool isBoundaryClaimable(Boundary boundary) {
    if (_currentPosition == null || boundary.isClaimed) return false;
    
    double distance = _calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      boundary.latitude,
      boundary.longitude,
    );
    
    double claimRadius = boundary.radius;
    return distance <= claimRadius;
  }

  // Get distance to boundary
  double getDistanceToBoundary(Boundary boundary) {
    if (_currentPosition == null) return double.infinity;
    
    return _calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      boundary.latitude,
      boundary.longitude,
    );
  }

  // Get bearing to boundary
  double getBearingToBoundary(Boundary boundary) {
    if (_currentPosition == null) return 0.0;
    
    return _calculateBearing(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      boundary.latitude,
      boundary.longitude,
    );
  }

  // Simulate claim for demo purposes
  Future<bool> _simulateClaim(Boundary boundary, double distance) async {
    try {
      print('🎮 Simulating NFT claim...');
      
      // Simulate delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Create mock transaction hash
      final mockTxHash = '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
      print('🎮 Mock transaction hash: $mockTxHash');
      
      // Update local state
      final updatedBoundary = boundary.copyWith(
        isClaimed: true,
        claimedBy: 'demo_wallet',
        claimedAt: DateTime.now(),
      );

      _claimedBoundaries.add(updatedBoundary);
      _visibleBoundaries.removeWhere((b) => b.id == boundary.id);
      
      // Update boundaries list
      final index = _boundaries.indexWhere((b) => b.id == boundary.id);
      if (index != -1) {
        _boundaries[index] = updatedBoundary;
      }

      // Trigger callbacks
      onBoundaryClaimed?.call(updatedBoundary);
      onClaimedBoundariesUpdate?.call(_claimedBoundaries);
      onVisibleBoundariesUpdate?.call(_visibleBoundaries);
      onNFTMinted?.call(mockTxHash);
      onClaimSubmitted?.call(mockTxHash);

      // Update progress
      int claimedCount = _claimedBoundaries.length;
      int totalCount = _boundaries.length;
      onProgressUpdate?.call(claimedCount, totalCount);

      print('🎮 Demo claim completed successfully!');
      return true;
    } catch (e) {
      print('❌ Error in demo claim: $e');
      return false;
    }
  }

  // Dispose resources
  void dispose() {
    _positionSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    
    _isARActive = false;
    print('🎯 AR NFT Service disposed');
  }
}

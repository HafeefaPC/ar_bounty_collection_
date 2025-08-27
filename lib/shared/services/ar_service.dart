import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/boundary.dart';
import '../models/event.dart';
import 'supabase_service.dart';

class ARService {
  static final ARService _instance = ARService._internal();
  factory ARService() => _instance;
  ARService._internal();

  // Current user position
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // Event and boundaries
  Event? _currentEvent;
  List<Boundary> _boundaries = [];
  List<Boundary> _claimedBoundaries = [];
  List<Boundary> _visibleBoundaries = [];

  // Services
  late SupabaseService _supabaseService;

  // Callbacks
  Function(Boundary)? onBoundaryDetected;
  Function(Boundary)? onBoundaryClaimed;
  Function(String)? onProximityUpdate;
  Function(int, int)? onProgressUpdate; // claimed, total
  Function(List<Boundary>)? onVisibleBoundariesUpdate;
  Function(List<Boundary>)? onClaimedBoundariesUpdate;
  Function(Position)? onPositionUpdate;

  // Initialize AR session
  Future<void> initializeAR() async {
    _supabaseService = SupabaseService();
    
    // Request location permissions
    await _requestLocationPermissions();
    
    // Start location tracking
    await _startLocationTracking();
  }

  // Set current event and boundaries
  void setEvent(Event event) {
    _currentEvent = event;
    _boundaries = event.boundaries;
    
    // Separate claimed and unclaimed boundaries
    _claimedBoundaries = _boundaries.where((b) => b.isClaimed).toList();
    _visibleBoundaries = _boundaries.where((b) => !b.isClaimed).toList();
    
    // Trigger callbacks
    onClaimedBoundariesUpdate?.call(_claimedBoundaries);
    onVisibleBoundariesUpdate?.call(_visibleBoundaries);
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
        _checkBoundaries();
        _updateBoundaryVisibility();
      },
      onError: (error) {
        print('Error getting location: $error');
        onProximityUpdate?.call('Location error: $error');
      },
    );
  }

  // Check boundaries for proximity
  void _checkBoundaries() {
    if (_currentPosition == null || _visibleBoundaries.isEmpty) {
      print('No position or unclaimed boundaries available');
      onProximityUpdate?.call('No unclaimed boundaries found for this event');
      return;
    }

    print('Checking ${_visibleBoundaries.length} unclaimed boundaries at position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    
    Boundary? closestBoundary;
    double closestDistance = double.infinity;
    String proximityHint = 'Exploring event area...';

    for (Boundary boundary in _visibleBoundaries) {
      if (boundary.isClaimed) {
        print('Boundary ${boundary.name} is already claimed');
        continue;
      }

      double distance = boundary.distanceFrom(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      
      print('Distance to ${boundary.name}: ${distance.toStringAsFixed(2)}m (radius: ${boundary.radius}m)');

      // Track closest boundary
      if (distance < closestDistance) {
        closestDistance = distance;
        closestBoundary = boundary;
      }

      // Check if within claiming distance (2 meters) or visible distance (5 meters)
      if (distance <= boundary.radius) {
        print('Within claiming distance of ${boundary.name}!');
        onBoundaryDetected?.call(boundary);
        onProximityUpdate?.call('Boundary detected! Tap to claim!');
        return; // Found a claimable boundary, exit early
      } else if (distance <= 5.0) {
        // Show boundary within 5 meters but not yet claimable
        print('Boundary ${boundary.name} visible at ${distance.toStringAsFixed(2)}m');
        onBoundaryDetected?.call(boundary);
        onProximityUpdate?.call('Getting closer! Move within 2m to claim.');
        return;
      }
    }

    // If no boundary is within claiming distance, show proximity hint for closest one
    if (closestBoundary != null) {
      proximityHint = closestBoundary!.getProximityHint(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      print('Closest boundary: ${closestBoundary!.name} at ${closestDistance.toStringAsFixed(2)}m');
    } else {
      proximityHint = 'No unclaimed boundaries found';
    }

    onProximityUpdate?.call(proximityHint);

    // Update progress
    int claimed = _claimedBoundaries.length;
    onProgressUpdate?.call(claimed, _boundaries.length);
  }

  // Update boundary visibility based on user position
  void _updateBoundaryVisibility() {
    if (_currentPosition == null) return;

    List<Boundary> newlyVisible = [];
    
    for (Boundary boundary in _boundaries) {
      bool shouldBeVisible = boundary.shouldBeVisible(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      
      if (shouldBeVisible && !_visibleBoundaries.contains(boundary)) {
        newlyVisible.add(boundary);
      }
    }

    if (newlyVisible.isNotEmpty) {
      _visibleBoundaries.addAll(newlyVisible);
      onVisibleBoundariesUpdate?.call(_visibleBoundaries);
    }
  }

  // Claim boundary
  Future<void> claimBoundary(Boundary boundary) async {
    if (_currentPosition == null) return;

    // Verify user is still within claiming distance
    if (!boundary.isWithinClaimingDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    )) {
      onProximityUpdate?.call("You moved too far! Get closer to claim.");
      return;
    }

    try {
      // Get user wallet address (you should implement this based on your wallet service)
      String walletAddress = "user_wallet_address"; // Replace with actual wallet
      
      // Claim boundary in database
      await _supabaseService.claimBoundary(boundary.id, walletAddress);
      
      // Mark as claimed locally
      Boundary claimedBoundary = boundary.claim(walletAddress);
      _claimedBoundaries.add(claimedBoundary);
      
      // Remove from visible boundaries
      _visibleBoundaries.removeWhere((b) => b.id == boundary.id);
      
      // Update the boundary in the main list
      int index = _boundaries.indexWhere((b) => b.id == boundary.id);
      if (index != -1) {
        _boundaries[index] = claimedBoundary;
      }

      // Log proximity for analytics
      await _supabaseService.logUserProximity(
        userWalletAddress: walletAddress,
        boundaryId: boundary.id,
        eventId: boundary.eventId,
        distanceMeters: boundary.distanceFrom(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );

      // Trigger callbacks
      onBoundaryClaimed?.call(claimedBoundary);
      onClaimedBoundariesUpdate?.call(_claimedBoundaries);
      onVisibleBoundariesUpdate?.call(_visibleBoundaries);

      // Update progress
      int claimed = _claimedBoundaries.length;
      onProgressUpdate?.call(claimed, _boundaries.length);

      // Show success message
      onProximityUpdate?.call("Boundary claimed successfully! 🎉");

    } catch (e) {
      print('Error claiming boundary: $e');
      onProximityUpdate?.call("Failed to claim boundary. Try again.");
    }
  }

  // Get boundaries that should be visible in AR (within 2 meters)
  List<Boundary> getVisibleBoundaries() {
    if (_currentPosition == null) return [];
    
    return _boundaries.where((boundary) {
      return boundary.shouldBeVisible(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }).toList();
  }

  // Get claimed boundaries for this user
  List<Boundary> getClaimedBoundaries() {
    return _claimedBoundaries;
  }

  // Get all boundaries with their claim status
  List<Boundary> getAllBoundaries() {
    return _boundaries;
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
      throw Exception('Location permissions are permanently denied');
    }
  }

  // Get current user position
  Position? get currentPosition => _currentPosition;

  // Get claimed boundaries
  List<Boundary> get claimedBoundaries => _claimedBoundaries;

  // Get all boundaries
  List<Boundary> get boundaries => _boundaries;

  // Get current event
  Event? get currentEvent => _currentEvent;

  // Dispose resources
  void dispose() {
    _positionSubscription?.cancel();
    _accelerometerSubscription?.cancel();
  }

  // Calculate distance between two points
  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  // Get direction to boundary
  static double getDirectionToBoundary(double userLat, double userLng, double boundaryLat, double boundaryLng) {
    return Geolocator.bearingBetween(userLat, userLng, boundaryLat, boundaryLng);
  }
}


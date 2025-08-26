import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/boundary.dart';
import '../models/event.dart';

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

  // Callbacks
  Function(Boundary)? onBoundaryDetected;
  Function(Boundary)? onBoundaryClaimed;
  Function(String)? onProximityUpdate;
  Function(int, int)? onProgressUpdate; // claimed, total

  // Initialize AR session
  Future<void> initializeAR() async {
    // Request location permissions
    await _requestLocationPermissions();
    
    // Start location tracking
    await _startLocationTracking();
  }

  // Set current event and boundaries
  void setEvent(Event event) {
    _currentEvent = event;
    _boundaries = event.boundaries;
  }

  // Start location tracking
  Future<void> _startLocationTracking() async {
    try {
      // Get initial position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('Initial position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      _checkBoundaries();
      
      // Start position stream
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1, // Update every 1 meter
        ),
      ).listen((Position position) {
        _currentPosition = position;
        print('Position updated: ${position.latitude}, ${position.longitude}');
        _checkBoundaries();
      });

      // Start accelerometer for movement detection
      _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
        // Detect significant movement
        double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        if (magnitude > 15) { // Threshold for movement
          _checkBoundaries();
        }
      });
    } catch (e) {
      print('Error starting location tracking: $e');
      onProximityUpdate?.call('Error getting location: $e');
    }
  }

  // Check boundaries for proximity
  void _checkBoundaries() {
    if (_currentPosition == null || _boundaries.isEmpty) {
      print('No position or boundaries available');
      onProximityUpdate?.call('No boundaries found for this event');
      return;
    }

    print('Checking ${_boundaries.length} boundaries at position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    
    Boundary? closestBoundary;
    double closestDistance = double.infinity;
    String proximityHint = 'Exploring event area...';

    for (Boundary boundary in _boundaries) {
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

      // Check if within claiming distance (2 meters)
      if (distance <= boundary.radius) {
        print('Within claiming distance of ${boundary.name}!');
        onBoundaryDetected?.call(boundary);
        onProximityUpdate?.call('Boundary detected! Tap to claim!');
        return; // Found a claimable boundary, exit early
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
      proximityHint = 'No boundaries found';
    }

    onProximityUpdate?.call(proximityHint);

    // Update progress
    int claimed = _boundaries.where((b) => b.isClaimed).length;
    onProgressUpdate?.call(claimed, _boundaries.length);
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
      // Mark as claimed locally
      Boundary claimedBoundary = boundary.claim("user_wallet_address"); // Replace with actual wallet
      _claimedBoundaries.add(claimedBoundary);
      
      // Update the boundary in the list
      int index = _boundaries.indexWhere((b) => b.id == boundary.id);
      if (index != -1) {
        _boundaries[index] = claimedBoundary;
      }

      // Trigger callback
      onBoundaryClaimed?.call(claimedBoundary);

      // Update progress
      int claimed = _boundaries.where((b) => b.isClaimed).length;
      onProgressUpdate?.call(claimed, _boundaries.length);

      // Show success message
      onProximityUpdate?.call("Boundary claimed successfully! 🎉");

    } catch (e) {
      print('Error claiming boundary: $e');
      onProximityUpdate?.call("Failed to claim boundary. Try again.");
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


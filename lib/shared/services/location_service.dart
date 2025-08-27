import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/boundary.dart';
import '../models/event.dart';
import 'supabase_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  StreamSubscription<Position>? _locationSubscription;
  Timer? _proximityCheckTimer;
  
  Position? _currentPosition;
  String? _currentWalletAddress;
  Event? _currentEvent;
  List<Boundary> _nearbyBoundaries = [];
  
  // Notification tracking to prevent spam
  final Map<String, int> _lastNotificationDistance = {};
  
  // Callbacks
  Function(List<Boundary>)? onBoundariesUpdated;
  Function(String)? onProximityNotification;
  Function(double)? onProgressUpdate;

  Future<void> initialize() async {
    // Initialize notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(initSettings);
    
    // Request permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions permanently denied');
    }

    // Notification permissions
    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  Future<void> startLocationTracking({
    required String walletAddress,
    required Event event,
  }) async {
    _currentWalletAddress = walletAddress;
    _currentEvent = event;
    
    // Stop any existing tracking
    await stopLocationTracking();
    
    // Start location updates
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen(_onLocationUpdate);
    
    // Start proximity checking timer
    _proximityCheckTimer = Timer.periodic(
      const Duration(seconds: 10), // Check every 10 seconds
      (_) => _checkProximity(),
    );
  }

  Future<void> stopLocationTracking() async {
    await _locationSubscription?.cancel();
    _proximityCheckTimer?.cancel();
    
    _locationSubscription = null;
    _proximityCheckTimer = null;
    _currentPosition = null;
    _currentWalletAddress = null;
    _currentEvent = null;
    _nearbyBoundaries.clear();
  }

  void _onLocationUpdate(Position position) {
    _currentPosition = position;
    
    if (_currentEvent != null && _currentWalletAddress != null) {
      // Update boundary visibility in database
      _supabaseService.updateBoundaryVisibility(
        position.latitude,
        position.longitude,
        _currentWalletAddress!,
      );
      
      // Check proximity immediately
      _checkProximity();
    }
  }

  Future<void> _checkProximity() async {
    if (_currentPosition == null || 
        _currentEvent == null || 
        _currentWalletAddress == null) {
      return;
    }

    try {
      // Get nearby boundaries from database
      final nearbyData = await _supabaseService.getNearbyBoundaries(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _currentWalletAddress!,
        maxDistance: 1000.0, // 1km max distance
      );

      // Convert to Boundary objects
      final boundaries = nearbyData.map((data) {
        return Boundary(
          id: data['boundary_id'],
          name: data['boundary_name'],
          description: data['boundary_description'],
          imageUrl: data['image_url'],
          latitude: data['latitude'],
          longitude: data['longitude'],
          radius: 2.0, // Default radius
          isClaimed: data['is_claimed'],
          claimedBy: data['claimed_by'],
          eventId: _currentEvent!.id,
          isVisible: data['is_visible'],
        );
      }).toList();

      // Update nearby boundaries
      _nearbyBoundaries = boundaries;
      
      // Notify UI
      onBoundariesUpdated?.call(boundaries);

      // Check for proximity notifications
      for (final boundary in boundaries) {
        if (boundary.isClaimed) continue; // Skip claimed boundaries
        
        final distance = boundary.distanceFrom(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );

        // Log proximity for analytics
        await _supabaseService.logUserProximity(
          userWalletAddress: _currentWalletAddress!,
          boundaryId: boundary.id,
          eventId: _currentEvent!.id,
          distanceMeters: distance,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
        );

        // Check notification distances
        for (final notificationDistance in _currentEvent!.notificationDistances) {
          if (distance <= notificationDistance) {
            final lastDistance = _lastNotificationDistance[boundary.id];
            
            // Only notify if we haven't already notified for this distance
            if (lastDistance == null || lastDistance > notificationDistance) {
              _lastNotificationDistance[boundary.id] = notificationDistance;
              
              // Show notification
              await _showProximityNotification(boundary, distance, notificationDistance);
              
              // Notify UI
              onProximityNotification?.call(
                boundary.getNotificationMessage(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  _currentEvent!.notificationDistances,
                ) ?? '',
              );
              
              break; // Only show one notification per boundary
            }
          }
        }

        // Update progress
        final progress = boundary.calculateProgress(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        onProgressUpdate?.call(progress);
      }
    } catch (e) {
      print('Error checking proximity: $e');
    }
  }

  Future<void> _showProximityNotification(
    Boundary boundary,
    double actualDistance,
    int notificationDistance,
  ) async {
    String title = 'Boundary Nearby!';
    String body = '';

    if (notificationDistance <= 5) {
      body = "You're very close to '${boundary.name}'! Only ${actualDistance.round()}m away!";
    } else if (notificationDistance <= 20) {
      body = "Getting closer to '${boundary.name}'! You're ${actualDistance.round()}m away.";
    } else {
      body = "You're ${actualDistance.round()}m away from '${boundary.name}'. Keep exploring!";
    }

    const androidDetails = AndroidNotificationDetails(
      'proximity_channel',
      'Proximity Notifications',
      channelDescription: 'Notifications when near boundaries',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      boundary.id.hashCode,
      title,
      body,
      details,
    );
  }

  // Get current position
  Position? get currentPosition => _currentPosition;

  // Get nearby boundaries
  List<Boundary> get nearbyBoundaries => _nearbyBoundaries;

  // Get visible boundaries (within 2 meters)
  List<Boundary> get visibleBoundaries {
    return _nearbyBoundaries.where((boundary) => boundary.isVisible).toList();
  }

  // Get claimable boundaries (within claim radius)
  List<Boundary> get claimableBoundaries {
    if (_currentPosition == null) return [];
    
    return _nearbyBoundaries.where((boundary) {
      if (boundary.isClaimed) return false;
      
      return boundary.isWithinClaimingDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }).toList();
  }

  // Calculate distance to a boundary
  double? getDistanceToBoundary(Boundary boundary) {
    if (_currentPosition == null) return null;
    
    return boundary.distanceFrom(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
  }

  // Get progress towards a boundary
  double? getProgressToBoundary(Boundary boundary) {
    if (_currentPosition == null) return null;
    
    return boundary.calculateProgress(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
  }

  // Check if user is within claiming distance of a boundary
  bool isWithinClaimingDistance(Boundary boundary) {
    if (_currentPosition == null) return false;
    
    return boundary.isWithinClaimingDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
  }

  // Check if boundary should be visible
  bool shouldBoundaryBeVisible(Boundary boundary) {
    if (_currentPosition == null) return false;
    
    return boundary.shouldBeVisible(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
  }

  // Get proximity hint for a boundary
  String? getProximityHint(Boundary boundary) {
    if (_currentPosition == null) return null;
    
    return boundary.getProximityHint(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
  }

  // Get notification message for a boundary
  String? getNotificationMessage(Boundary boundary) {
    if (_currentPosition == null || _currentEvent == null) return null;
    
    return boundary.getNotificationMessage(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _currentEvent!.notificationDistances,
    );
  }

  // Dispose resources
  void dispose() {
    stopLocationTracking();
  }
}

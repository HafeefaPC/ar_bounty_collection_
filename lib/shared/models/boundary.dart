import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:math'; // Added for sin, cos, atan2, sqrt

class Boundary {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final double radius; // in meters
  final bool isClaimed;
  final String? claimedBy;
  final DateTime? claimedAt;
  final String eventId;
  final Vector3 position; // AR position
  final Vector3 rotation; // AR rotation
  final Vector3 scale; // AR scale

  Boundary({
    String? id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    this.radius = 2.0, // Default 2 meters
    this.isClaimed = false,
    this.claimedBy,
    this.claimedAt,
    required this.eventId,
    Vector3? position,
    Vector3? rotation,
    Vector3? scale,
  }) : 
    id = id ?? const Uuid().v4(),
    position = position ?? Vector3(0, 0, -2),
    rotation = rotation ?? Vector3(0, 0, 0),
    scale = scale ?? Vector3(1, 1, 1);

  Boundary copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    double? latitude,
    double? longitude,
    double? radius,
    bool? isClaimed,
    String? claimedBy,
    DateTime? claimedAt,
    String? eventId,
    Vector3? position,
    Vector3? rotation,
    Vector3? scale,
  }) {
    return Boundary(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      isClaimed: isClaimed ?? this.isClaimed,
      claimedBy: claimedBy ?? this.claimedBy,
      claimedAt: claimedAt ?? this.claimedAt,
      eventId: eventId ?? this.eventId,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
    );
  }

  Boundary claim(String walletAddress) {
    return copyWith(
      isClaimed: true,
      claimedBy: walletAddress,
      claimedAt: DateTime.now(),
    );
  }

  // Calculate distance from user's current position
  double distanceFrom(double userLat, double userLng) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    double lat1 = latitude * (pi / 180);
    double lat2 = userLat * (pi / 180);
    double deltaLat = (userLat - latitude) * (pi / 180);
    double deltaLng = (userLng - longitude) * (pi / 180);

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Check if user is within claiming distance
  bool isWithinClaimingDistance(double userLat, double userLng) {
    return distanceFrom(userLat, userLng) <= radius;
  }

  // Get proximity hint (how close user is)
  String getProximityHint(double userLat, double userLng) {
    double distance = distanceFrom(userLat, userLng);
    
    if (distance <= radius) {
      return "You're here! Tap to claim!";
    } else if (distance <= radius * 2) {
      return "Very close! Keep moving...";
    } else if (distance <= radius * 5) {
      return "Getting warmer...";
    } else if (distance <= radius * 10) {
      return "You're in the right area!";
    } else {
      return "Keep exploring the event area";
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'isClaimed': isClaimed,
      'claimedBy': claimedBy,
      'claimedAt': claimedAt?.toIso8601String(),
      'eventId': eventId,
      'position': {
        'x': position.x,
        'y': position.y,
        'z': position.z,
      },
      'rotation': {
        'x': rotation.x,
        'y': rotation.y,
        'z': rotation.z,
      },
      'scale': {
        'x': scale.x,
        'y': scale.y,
        'z': scale.z,
      },
    };
  }

  factory Boundary.fromJson(Map<String, dynamic> json) {
    // Handle both old format (individual columns) and new format (JSONB)
    Map<String, dynamic>? positionData = json['position'];
    Map<String, dynamic>? rotationData = json['rotation'];
    Map<String, dynamic>? scaleData = json['scale'];
    
    return Boundary(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      radius: json['radius']?.toDouble() ?? 2.0,
      isClaimed: json['isClaimed'] ?? false,
      claimedBy: json['claimedBy'],
      claimedAt: json['claimedAt'] != null ? DateTime.parse(json['claimedAt']) : null,
      eventId: json['eventId'],
      position: Vector3(
        positionData?['x']?.toDouble() ?? json['position_x']?.toDouble() ?? 0.0,
        positionData?['y']?.toDouble() ?? json['position_y']?.toDouble() ?? 0.0,
        positionData?['z']?.toDouble() ?? json['position_z']?.toDouble() ?? -2.0,
      ),
      rotation: Vector3(
        rotationData?['x']?.toDouble() ?? json['rotation_x']?.toDouble() ?? 0.0,
        rotationData?['y']?.toDouble() ?? json['rotation_y']?.toDouble() ?? 0.0,
        rotationData?['z']?.toDouble() ?? json['rotation_z']?.toDouble() ?? 0.0,
      ),
      scale: Vector3(
        scaleData?['x']?.toDouble() ?? json['scale_x']?.toDouble() ?? 1.0,
        scaleData?['y']?.toDouble() ?? json['scale_y']?.toDouble() ?? 1.0,
        scaleData?['z']?.toDouble() ?? json['scale_z']?.toDouble() ?? 1.0,
      ),
    );
  }
}

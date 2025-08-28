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
  // New fields for enhanced boundary management
  final String? nftTokenId;
  final Map<String, dynamic>? nftMetadata;
  final double claimProgress;
  final bool isVisible;

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
    this.nftTokenId,
    this.nftMetadata,
    this.claimProgress = 0.0,
    this.isVisible = true,
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
    String? nftTokenId,
    Map<String, dynamic>? nftMetadata,
    double? claimProgress,
    bool? isVisible,
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
      nftTokenId: nftTokenId ?? this.nftTokenId,
      nftMetadata: nftMetadata ?? this.nftMetadata,
      claimProgress: claimProgress ?? this.claimProgress,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Boundary claim(String walletAddress) {
    return copyWith(
      isClaimed: true,
      claimedBy: walletAddress,
      claimedAt: DateTime.now(),
      claimProgress: 100.0,
    );
  }

  Boundary updateProgress(double progress) {
    return copyWith(
      claimProgress: progress.clamp(0.0, 100.0),
    );
  }

  Boundary updateNotificationDistance(int distance) {
    return copyWith(
      // lastNotificationDistance: distance, // Removed as per edit hint
    );
  }

  Boundary updateVisibility(bool visible) {
    return copyWith(
      isVisible: visible,
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

  // Check if boundary should be visible (within 5 meters)
  bool shouldBeVisible(double userLat, double userLng) {
    return distanceFrom(userLat, userLng) <= 5.0;
  }

  // Get proximity hint (how close user is)
  String getProximityHint(double userLat, double userLng) {
    double distance = distanceFrom(userLat, userLng);
    
    if (distance <= radius) {
      return "You're here! Tap to claim!";
    } else if (distance <= 5.0) {
      return "Getting closer! Move within 2m to claim.";
    } else if (distance <= 10.0) {
      return "You're in the right area!";
    } else if (distance <= 20.0) {
      return "Getting warmer...";
    } else if (distance <= 50.0) {
      return "Keep exploring the event area";
    } else {
      return "Explore to find NFT boundaries";
    }
  }

  // Get notification message based on distance
  String? getNotificationMessage(double userLat, double userLng, List<int> notificationDistances) {
    double distance = distanceFrom(userLat, userLng);
    
    for (int notificationDistance in notificationDistances) {
      if (distance <= notificationDistance) { // Removed lastNotificationDistance check
        if (notificationDistance <= 5) {
          return "You're very close to a boundary! Only ${notificationDistance}m away!";
        } else if (notificationDistance <= 20) {
          return "Getting closer! You're ${notificationDistance}m from a boundary.";
        } else {
          return "You're ${notificationDistance}m away from a boundary. Keep exploring!";
        }
      }
    }
    return null;
  }

  // Calculate progress percentage based on distance
  double calculateProgress(double userLat, double userLng) {
    double distance = distanceFrom(userLat, userLng);
    
    if (distance <= radius) {
      return 100.0;
    } else if (distance <= 10.0) {
      return 80.0;
    } else if (distance <= 50.0) {
      return 60.0;
    } else if (distance <= 100.0) {
      return 40.0;
    } else {
      return 20.0;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'is_claimed': isClaimed,
      'claimed_by': claimedBy,
      'claimed_at': claimedAt?.toIso8601String(),
      'event_id': eventId,
      'nft_token_id': nftTokenId,
      'nft_metadata': nftMetadata,
      'claim_progress': claimProgress,
      'is_visible': isVisible,
      'ar_position': {
        'x': position.x,
        'y': position.y,
        'z': position.z,
      },
      'ar_rotation': {
        'x': rotation.x,
        'y': rotation.y,
        'z': rotation.z,
      },
      'ar_scale': {
        'x': scale.x,
        'y': scale.y,
        'z': scale.z,
      },
    };
  }

  factory Boundary.fromJson(Map<String, dynamic> json) {
    // Handle both old format (individual columns) and new format (JSONB)
    Map<String, dynamic>? positionData = json['ar_position'] ?? json['position'];
    Map<String, dynamic>? rotationData = json['ar_rotation'] ?? json['rotation'];
    Map<String, dynamic>? scaleData = json['ar_scale'] ?? json['scale'];
    
    return Boundary(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['image_url'] ?? json['imageUrl'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      radius: json['radius']?.toDouble() ?? 2.0,
      isClaimed: json['is_claimed'] ?? json['isClaimed'] ?? false,
      claimedBy: json['claimed_by'] ?? json['claimedBy'],
      claimedAt: json['claimed_at'] != null ? DateTime.parse(json['claimed_at']) : 
                 json['claimedAt'] != null ? DateTime.parse(json['claimedAt']) : null,
      eventId: json['event_id'] ?? json['eventId'],
      nftTokenId: json['nft_token_id'] ?? json['nftTokenId'],
      nftMetadata: json['nft_metadata'] ?? json['nftMetadata'],
      claimProgress: json['claim_progress']?.toDouble() ?? json['claimProgress']?.toDouble() ?? 0.0,
      isVisible: json['is_visible'] ?? json['isVisible'] ?? true,
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

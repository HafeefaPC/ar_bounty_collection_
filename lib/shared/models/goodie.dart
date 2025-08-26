import 'package:uuid/uuid.dart';

class Goodie {
  final String id;
  final String name;
  final String description;
  final String logoUrl;
  final double latitude;
  final double longitude;
  final double claimRadius; // in meters
  final bool isClaimed;
  final String? claimedBy;
  final DateTime? claimedAt;
  final String eventId;

  Goodie({
    String? id,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.latitude,
    required this.longitude,
    this.claimRadius = 15.0, // Default 15 meters
    this.isClaimed = false,
    this.claimedBy,
    this.claimedAt,
    required this.eventId,
  }) : id = id ?? const Uuid().v4();

  Goodie copyWith({
    String? id,
    String? name,
    String? description,
    String? logoUrl,
    double? latitude,
    double? longitude,
    double? claimRadius,
    bool? isClaimed,
    String? claimedBy,
    DateTime? claimedAt,
    String? eventId,
  }) {
    return Goodie(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      claimRadius: claimRadius ?? this.claimRadius,
      isClaimed: isClaimed ?? this.isClaimed,
      claimedBy: claimedBy ?? this.claimedBy,
      claimedAt: claimedAt ?? this.claimedAt,
      eventId: eventId ?? this.eventId,
    );
  }

  Goodie claim(String walletAddress) {
    return copyWith(
      isClaimed: true,
      claimedBy: walletAddress,
      claimedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'logoUrl': logoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'claimRadius': claimRadius,
      'isClaimed': isClaimed,
      'claimedBy': claimedBy,
      'claimedAt': claimedAt?.toIso8601String(),
      'eventId': eventId,
    };
  }

  factory Goodie.fromJson(Map<String, dynamic> json) {
    return Goodie(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      logoUrl: json['logoUrl'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      claimRadius: json['claimRadius']?.toDouble() ?? 15.0,
      isClaimed: json['isClaimed'] ?? false,
      claimedBy: json['claimedBy'],
      claimedAt: json['claimedAt'] != null ? DateTime.parse(json['claimedAt']) : null,
      eventId: json['eventId'],
    );
  }
}


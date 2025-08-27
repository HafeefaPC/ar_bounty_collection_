import 'package:uuid/uuid.dart';
import 'goodie.dart';
import 'boundary.dart';

class Event {
  final String id;
  final String name;
  final String description;
  final String organizerWalletAddress;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final double latitude;
  final double longitude;
  final String venueName;
  final List<Goodie> goodies;
  final List<Boundary> boundaries;
  final String eventCode;
  // New fields for enhanced event creation
  final int nftSupplyCount;
  final String? eventImageUrl;
  final String? boundaryDescription;
  final List<int> notificationDistances;
  final double visibilityRadius;

  Event({
    String? id,
    required this.name,
    required this.description,
    required this.organizerWalletAddress,
    required this.latitude,
    required this.longitude,
    required this.venueName,
    List<Goodie>? goodies,
    List<Boundary>? boundaries,
    DateTime? createdAt,
    this.startDate,
    this.endDate,
    String? eventCode,
    this.nftSupplyCount = 50,
    this.eventImageUrl,
    this.boundaryDescription,
    List<int>? notificationDistances,
    this.visibilityRadius = 2.0,
  }) : 
    id = id ?? const Uuid().v4(),
    goodies = goodies ?? [],
    boundaries = boundaries ?? [],
    createdAt = createdAt ?? DateTime.now(),
    eventCode = eventCode ?? _generateEventCode(),
    notificationDistances = notificationDistances ?? [100, 50, 20, 10, 5];

  static String _generateEventCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch + 
                   (DateTime.now().microsecondsSinceEpoch % 1000);
    return String.fromCharCodes(
      Iterable.generate(6, (index) {
        final seed = random + index * 1000;
        return chars.codeUnitAt(seed % chars.length);
      })
    );
  }

  Event copyWith({
    String? id,
    String? name,
    String? description,
    String? organizerWalletAddress,
    DateTime? createdAt,
    DateTime? startDate,
    DateTime? endDate,
    double? latitude,
    double? longitude,
    String? venueName,
    List<Goodie>? goodies,
    List<Boundary>? boundaries,
    String? eventCode,
    int? nftSupplyCount,
    String? eventImageUrl,
    String? boundaryDescription,
    List<int>? notificationDistances,
    double? visibilityRadius,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      organizerWalletAddress: organizerWalletAddress ?? this.organizerWalletAddress,
      createdAt: createdAt ?? this.createdAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      venueName: venueName ?? this.venueName,
      goodies: goodies ?? this.goodies,
      boundaries: boundaries ?? this.boundaries,
      eventCode: eventCode ?? this.eventCode,
      nftSupplyCount: nftSupplyCount ?? this.nftSupplyCount,
      eventImageUrl: eventImageUrl ?? this.eventImageUrl,
      boundaryDescription: boundaryDescription ?? this.boundaryDescription,
      notificationDistances: notificationDistances ?? this.notificationDistances,
      visibilityRadius: visibilityRadius ?? this.visibilityRadius,
    );
  }

  // Helper methods for event management
  bool get isActive {
    final now = DateTime.now();
    return (startDate == null || now.isAfter(startDate!)) && 
           (endDate == null || now.isBefore(endDate!));
  }

  int get claimedBoundariesCount {
    return boundaries.where((b) => b.isClaimed).length;
  }

  int get availableBoundariesCount {
    return boundaries.where((b) => !b.isClaimed).length;
  }

  double get claimPercentage {
    if (boundaries.isEmpty) return 0.0;
    return (claimedBoundariesCount / boundaries.length) * 100;
  }

  bool get isFullyClaimed {
    return claimedBoundariesCount >= nftSupplyCount;
  }

  // Get next notification distance based on current distance
  int? getNextNotificationDistance(double currentDistance) {
    for (int distance in notificationDistances) {
      if (currentDistance <= distance) {
        return distance;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'organizer_wallet_address': organizerWalletAddress,
      'created_at': createdAt.toIso8601String(),
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'venue_name': venueName,
      'event_code': eventCode,
      'nft_supply_count': nftSupplyCount,
      'event_image_url': eventImageUrl,
      'boundary_description': boundaryDescription,
      'notification_distances': notificationDistances,
      'visibility_radius': visibilityRadius,
      'goodies': goodies.map((g) => g.toJson()).toList(),
      'boundaries': boundaries.map((b) => b.toJson()).toList(),
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      organizerWalletAddress: json['organizer_wallet_address'] ?? json['organizerWalletAddress'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : 
                 json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : 
               json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      venueName: json['venue_name'] ?? json['venueName'],
      eventCode: json['event_code'] ?? json['eventCode'],
      nftSupplyCount: json['nft_supply_count'] ?? json['nftSupplyCount'] ?? 50,
      eventImageUrl: json['event_image_url'] ?? json['eventImageUrl'],
      boundaryDescription: json['boundary_description'] ?? json['boundaryDescription'],
      notificationDistances: json['notification_distances'] != null 
          ? List<int>.from(json['notification_distances'])
          : json['notificationDistances'] != null 
              ? List<int>.from(json['notificationDistances'])
              : [100, 50, 20, 10, 5],
      visibilityRadius: json['visibility_radius']?.toDouble() ?? json['visibilityRadius']?.toDouble() ?? 2.0,
      goodies: json['goodies'] != null 
          ? (json['goodies'] as List).map((g) => Goodie.fromJson(g)).toList()
          : [],
      boundaries: json['boundaries'] != null 
          ? (json['boundaries'] as List).map((b) => Boundary.fromJson(b)).toList()
          : [],
    );
  }
}


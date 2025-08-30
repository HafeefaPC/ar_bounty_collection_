import 'package:uuid/uuid.dart';

class User {
  final String id;
  final String walletAddress;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final List<String> claimedGoodieIds;
  final List<String> createdEventIds;

  User({
    String? id,
    required this.walletAddress,
    this.displayName,
    this.avatarUrl,
    DateTime? createdAt,
    List<String>? claimedGoodieIds,
    List<String>? createdEventIds,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    claimedGoodieIds = claimedGoodieIds ?? [],
    createdEventIds = createdEventIds ?? [];

  User copyWith({
    String? id,
    String? walletAddress,
    String? displayName,
    String? avatarUrl,
    DateTime? createdAt,
    List<String>? claimedGoodieIds,
    List<String>? createdEventIds,
  }) {
    return User(
      id: id ?? this.id,
      walletAddress: walletAddress ?? this.walletAddress,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      claimedGoodieIds: claimedGoodieIds ?? this.claimedGoodieIds,
      createdEventIds: createdEventIds ?? this.createdEventIds,
    );
  }

  User addClaimedGoodie(String goodieId) {
    return copyWith(
      claimedGoodieIds: [...claimedGoodieIds, goodieId],
    );
  }

  User addCreatedEvent(String eventId) {
    return copyWith(
      createdEventIds: [...createdEventIds, eventId],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletAddress': walletAddress,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'claimedGoodieIds': claimedGoodieIds,
      'createdEventIds': createdEventIds,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      walletAddress: json['walletAddress'],
      displayName: json['displayName'],
      avatarUrl: json['avatarUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      claimedGoodieIds: List<String>.from(json['claimedGoodieIds'] ?? []),
      createdEventIds: List<String>.from(json['createdEventIds'] ?? []),
    );
  }
}


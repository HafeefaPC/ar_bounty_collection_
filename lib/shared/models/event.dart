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
  }) : 
    id = id ?? const Uuid().v4(),
    goodies = goodies ?? [],
    boundaries = boundaries ?? [],
    createdAt = createdAt ?? DateTime.now(),
    eventCode = eventCode ?? _generateEventCode();

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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'organizerWalletAddress': organizerWalletAddress,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'venueName': venueName,
      'goodies': goodies.map((g) => g.toJson()).toList(),
      'boundaries': boundaries.map((b) => b.toJson()).toList(),
      'eventCode': eventCode,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      organizerWalletAddress: json['organizer_wallet_address'] ?? json['organizerWalletAddress'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : 
                 json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : 
               json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      latitude: (json['latitude'] is int) ? (json['latitude'] as int).toDouble() : json['latitude'].toDouble(),
      longitude: (json['longitude'] is int) ? (json['longitude'] as int).toDouble() : json['longitude'].toDouble(),
      venueName: json['venue_name'] ?? json['venueName'] ?? '',
      goodies: json['goodies'] != null ? (json['goodies'] as List).map((g) => Goodie.fromJson(g)).toList() : [],
      boundaries: json['boundaries'] != null ? (json['boundaries'] as List).map((b) => Boundary.fromJson(b)).toList() : [],
      eventCode: json['event_code'] ?? json['eventCode'] ?? '',
    );
  }
}


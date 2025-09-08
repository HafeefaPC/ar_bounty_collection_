
/// Represents an NFT (Non-Fungible Token) with all its metadata
class NFT {
  final String tokenId;
  final String name;
  final String description;
  final String imageUrl;
  final String tokenURI;
  final String owner;
  final int eventId;
  final double latitude;
  final double longitude;
  final double radius;
  final DateTime? mintTimestamp;
  final DateTime? claimTimestamp;
  final String? claimer;
  final String? merkleRoot;
  final bool isClaimed;
  final String? eventName;
  final String? eventDescription;
  final String? eventVenue;

  const NFT({
    required this.tokenId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.tokenURI,
    required this.owner,
    required this.eventId,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.mintTimestamp,
    this.claimTimestamp,
    this.claimer,
    this.merkleRoot,
    this.isClaimed = false,
    this.eventName,
    this.eventDescription,
    this.eventVenue,
  });

  /// Create NFT from blockchain metadata
  factory NFT.fromBlockchainMetadata({
    required String tokenId,
    required String owner,
    required Map<String, dynamic> metadata,
  }) {
    return NFT(
      tokenId: tokenId,
      name: metadata['name'] ?? 'Unknown NFT',
      description: metadata['description'] ?? 'No description available',
      imageUrl: metadata['imageURI'] ?? metadata['image'] ?? '',
      tokenURI: metadata['tokenURI'] ?? '',
      owner: owner,
      eventId: metadata['eventId'] ?? 0,
      latitude: _parseCoordinate(metadata['latitude']),
      longitude: _parseCoordinate(metadata['longitude']),
      radius: _parseRadius(metadata['radius']),
      mintTimestamp: _parseTimestamp(metadata['mintTimestamp']),
      claimTimestamp: _parseTimestamp(metadata['claimTimestamp']),
      claimer: metadata['claimer'],
      merkleRoot: metadata['merkleRoot'],
      isClaimed: metadata['claimTimestamp'] != null && metadata['claimTimestamp'] != 0,
      eventName: metadata['eventName'],
      eventDescription: metadata['eventDescription'],
      eventVenue: metadata['eventVenue'],
    );
  }

  /// Parse coordinate from blockchain integer (scaled by 1e6)
  static double _parseCoordinate(dynamic coord) {
    if (coord == null) return 0.0;
    if (coord is int) return coord / 1000000.0;
    if (coord is double) return coord / 1000000.0;
    if (coord is String) return double.tryParse(coord) ?? 0.0;
    return 0.0;
  }

  /// Parse radius from blockchain integer
  static double _parseRadius(dynamic radius) {
    if (radius == null) return 0.0;
    if (radius is int) return radius.toDouble();
    if (radius is double) return radius;
    if (radius is String) return double.tryParse(radius) ?? 0.0;
    return 0.0;
  }

  /// Parse timestamp from blockchain integer
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    int ts;
    if (timestamp is int) {
      ts = timestamp;
    } else if (timestamp is double) {
      ts = timestamp.toInt();
    } else if (timestamp is String) {
      ts = int.tryParse(timestamp) ?? 0;
    } else {
      return null;
    }
    
    if (ts == 0) return null;
    
    // Handle both seconds and milliseconds timestamps
    if (ts > 1000000000000) {
      // Milliseconds timestamp
      return DateTime.fromMillisecondsSinceEpoch(ts);
    } else {
      // Seconds timestamp
      return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    }
  }

  /// Create a copy of this NFT with updated fields
  NFT copyWith({
    String? tokenId,
    String? name,
    String? description,
    String? imageUrl,
    String? tokenURI,
    String? owner,
    int? eventId,
    double? latitude,
    double? longitude,
    double? radius,
    DateTime? mintTimestamp,
    DateTime? claimTimestamp,
    String? claimer,
    String? merkleRoot,
    bool? isClaimed,
    String? eventName,
    String? eventDescription,
    String? eventVenue,
  }) {
    return NFT(
      tokenId: tokenId ?? this.tokenId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      tokenURI: tokenURI ?? this.tokenURI,
      owner: owner ?? this.owner,
      eventId: eventId ?? this.eventId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      mintTimestamp: mintTimestamp ?? this.mintTimestamp,
      claimTimestamp: claimTimestamp ?? this.claimTimestamp,
      claimer: claimer ?? this.claimer,
      merkleRoot: merkleRoot ?? this.merkleRoot,
      isClaimed: isClaimed ?? this.isClaimed,
      eventName: eventName ?? this.eventName,
      eventDescription: eventDescription ?? this.eventDescription,
      eventVenue: eventVenue ?? this.eventVenue,
    );
  }

  /// Convert NFT to JSON
  Map<String, dynamic> toJson() {
    return {
      'tokenId': tokenId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'tokenURI': tokenURI,
      'owner': owner,
      'eventId': eventId,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'mintTimestamp': mintTimestamp?.millisecondsSinceEpoch,
      'claimTimestamp': claimTimestamp?.millisecondsSinceEpoch,
      'claimer': claimer,
      'merkleRoot': merkleRoot,
      'isClaimed': isClaimed,
      'eventName': eventName,
      'eventDescription': eventDescription,
      'eventVenue': eventVenue,
    };
  }

  /// Create NFT from JSON
  factory NFT.fromJson(Map<String, dynamic> json) {
    return NFT(
      tokenId: json['tokenId'] ?? '',
      name: json['name'] ?? 'Unknown NFT',
      description: json['description'] ?? 'No description available',
      imageUrl: json['imageUrl'] ?? '',
      tokenURI: json['tokenURI'] ?? '',
      owner: json['owner'] ?? '',
      eventId: json['eventId'] ?? 0,
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      radius: (json['radius'] ?? 0.0).toDouble(),
      mintTimestamp: json['mintTimestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['mintTimestamp'])
          : null,
      claimTimestamp: json['claimTimestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['claimTimestamp'])
          : null,
      claimer: json['claimer'],
      merkleRoot: json['merkleRoot'],
      isClaimed: json['isClaimed'] ?? false,
      eventName: json['eventName'],
      eventDescription: json['eventDescription'],
      eventVenue: json['eventVenue'],
    );
  }

  /// Get display name for the NFT
  String get displayName {
    if (name.isNotEmpty) return name;
    if (eventName != null && eventName!.isNotEmpty) {
      return '$eventName NFT #$tokenId';
    }
    return 'NFT #$tokenId';
  }

  /// Get display description for the NFT
  String get displayDescription {
    if (description.isNotEmpty) return description;
    if (eventDescription != null && eventDescription!.isNotEmpty) {
      return eventDescription!;
    }
    return 'A boundary NFT from event #$eventId';
  }

  /// Get formatted location string
  String get locationString {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  /// Get formatted radius string
  String get radiusString {
    if (radius < 1000) {
      return '${radius.toStringAsFixed(0)}m';
    } else {
      return '${(radius / 1000).toStringAsFixed(1)}km';
    }
  }

  /// Check if NFT has valid image URL
  bool get hasValidImage {
    return imageUrl.isNotEmpty && 
           (imageUrl.startsWith('http') || imageUrl.startsWith('ipfs://'));
  }

  /// Get image URL with proper formatting
  String get formattedImageUrl {
    if (imageUrl.startsWith('ipfs://')) {
      return imageUrl.replaceFirst('ipfs://', 'https://ipfs.io/ipfs/');
    }
    return imageUrl;
  }

  @override
  String toString() {
    return 'NFT(tokenId: $tokenId, name: $name, owner: $owner, eventId: $eventId, isClaimed: $isClaimed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NFT && other.tokenId == tokenId;
  }

  @override
  int get hashCode => tokenId.hashCode;
}

/// Represents a collection of NFTs owned by a user
class NFTCollection {
  final String owner;
  final List<NFT> nfts;
  final int totalCount;
  final DateTime lastUpdated;

  const NFTCollection({
    required this.owner,
    required this.nfts,
    required this.totalCount,
    required this.lastUpdated,
  });

  /// Get claimed NFTs
  List<NFT> get claimedNFTs => nfts.where((nft) => nft.isClaimed).toList();

  /// Get unclaimed NFTs
  List<NFT> get unclaimedNFTs => nfts.where((nft) => !nft.isClaimed).toList();

  /// Get NFTs by event ID
  List<NFT> getNFTsByEvent(int eventId) {
    return nfts.where((nft) => nft.eventId == eventId).toList();
  }

  /// Get unique event IDs
  List<int> get uniqueEventIds {
    return nfts.map((nft) => nft.eventId).toSet().toList()..sort();
  }

  /// Check if collection is empty
  bool get isEmpty => nfts.isEmpty;

  /// Check if collection has NFTs
  bool get isNotEmpty => nfts.isNotEmpty;

  /// Get collection summary
  Map<String, dynamic> get summary {
    return {
      'owner': owner,
      'totalCount': totalCount,
      'claimedCount': claimedNFTs.length,
      'unclaimedCount': unclaimedNFTs.length,
      'uniqueEvents': uniqueEventIds.length,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'NFTCollection(owner: $owner, totalCount: $totalCount, claimedCount: ${claimedNFTs.length}, unclaimedCount: ${unclaimedNFTs.length})';
  }
}

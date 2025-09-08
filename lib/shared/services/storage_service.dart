import 'dart:convert';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:face_reflector/shared/models/user.dart';
import 'package:face_reflector/shared/models/goodie.dart';
import 'package:face_reflector/shared/models/nft.dart';

class StorageService {
  static Database? _database;
  static const String _userKey = 'user';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'face_reflector.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE claimed_goodies (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        logoUrl TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        claimRadius REAL NOT NULL,
        eventId TEXT NOT NULL,
        claimedAt TEXT NOT NULL,
        eventName TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE claimed_nfts (
        tokenId TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        imageUrl TEXT NOT NULL,
        tokenURI TEXT NOT NULL,
        owner TEXT NOT NULL,
        eventId INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius REAL NOT NULL,
        mintTimestamp INTEGER,
        claimTimestamp INTEGER,
        claimer TEXT,
        merkleRoot TEXT,
        isClaimed INTEGER NOT NULL DEFAULT 0,
        eventName TEXT,
        eventDescription TEXT,
        eventVenue TEXT,
        claimedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE claimed_nfts (
          tokenId TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          imageUrl TEXT NOT NULL,
          tokenURI TEXT NOT NULL,
          owner TEXT NOT NULL,
          eventId INTEGER NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          radius REAL NOT NULL,
          mintTimestamp INTEGER,
          claimTimestamp INTEGER,
          claimer TEXT,
          merkleRoot TEXT,
          isClaimed INTEGER NOT NULL DEFAULT 0,
          eventName TEXT,
          eventDescription TEXT,
          eventVenue TEXT,
          claimedAt TEXT NOT NULL
        )
      ''');
    }
  }

  // User storage
  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  // Claimed goodies storage
  Future<void> saveClaimedGoodie(Goodie goodie) async {
    final db = await database;
    await db.insert(
      'claimed_goodies',
      {
        'id': goodie.id,
        'name': goodie.name,
        'description': goodie.description,
        'logoUrl': goodie.logoUrl,
        'latitude': goodie.latitude,
        'longitude': goodie.longitude,
        'claimRadius': goodie.claimRadius,
        'eventId': goodie.eventId,
        'claimedAt': goodie.claimedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'eventName': 'Event', // You might want to store event name separately
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Goodie>> getClaimedGoodies() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('claimed_goodies');
    
    return List.generate(maps.length, (i) {
      return Goodie(
        id: maps[i]['id'],
        name: maps[i]['name'],
        description: maps[i]['description'],
        logoUrl: maps[i]['logoUrl'],
        latitude: maps[i]['latitude'],
        longitude: maps[i]['longitude'],
        claimRadius: maps[i]['claimRadius'],
        eventId: maps[i]['eventId'],
        isClaimed: true,
        claimedAt: DateTime.parse(maps[i]['claimedAt']),
      );
    });
  }

  Future<void> removeClaimedGoodie(String goodieId) async {
    final db = await database;
    await db.delete(
      'claimed_goodies',
      where: 'id = ?',
      whereArgs: [goodieId],
    );
  }

  Future<bool> isGoodieClaimed(String goodieId) async {
    final db = await database;
    final result = await db.query(
      'claimed_goodies',
      where: 'id = ?',
      whereArgs: [goodieId],
    );
    return result.isNotEmpty;
  }

  // Settings storage
  Future<void> saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  Future<T?> getSetting<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.get(key) as T?;
  }

  Future<void> removeSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // Clear all data
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    final db = await database;
    await db.delete('claimed_goodies');
    await db.delete('claimed_nfts');
  }

  // Claimed NFTs storage
  Future<void> saveClaimedNFT(NFT nft, String walletAddress) async {
    final db = await database;
    await db.insert(
      'claimed_nfts',
      {
        'tokenId': nft.tokenId,
        'name': nft.name,
        'description': nft.description,
        'imageUrl': nft.imageUrl,
        'tokenURI': nft.tokenURI,
        'owner': walletAddress,
        'eventId': nft.eventId,
        'latitude': nft.latitude,
        'longitude': nft.longitude,
        'radius': nft.radius,
        'mintTimestamp': nft.mintTimestamp?.millisecondsSinceEpoch,
        'claimTimestamp': nft.claimTimestamp?.millisecondsSinceEpoch,
        'claimer': nft.claimer,
        'merkleRoot': nft.merkleRoot,
        'isClaimed': nft.isClaimed ? 1 : 0,
        'eventName': nft.eventName,
        'eventDescription': nft.eventDescription,
        'eventVenue': nft.eventVenue,
        'claimedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<NFT>> getClaimedNFTsByWallet(String walletAddress) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'claimed_nfts',
      where: 'owner = ?',
      whereArgs: [walletAddress.toLowerCase()],
      orderBy: 'claimedAt DESC',
    );
    
    return List.generate(maps.length, (i) {
      return NFT(
        tokenId: maps[i]['tokenId'],
        name: maps[i]['name'],
        description: maps[i]['description'],
        imageUrl: maps[i]['imageUrl'],
        tokenURI: maps[i]['tokenURI'],
        owner: maps[i]['owner'],
        eventId: maps[i]['eventId'],
        latitude: maps[i]['latitude'],
        longitude: maps[i]['longitude'],
        radius: maps[i]['radius'],
        mintTimestamp: maps[i]['mintTimestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(maps[i]['mintTimestamp'])
            : null,
        claimTimestamp: maps[i]['claimTimestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(maps[i]['claimTimestamp'])
            : null,
        claimer: maps[i]['claimer'],
        merkleRoot: maps[i]['merkleRoot'],
        isClaimed: maps[i]['isClaimed'] == 1,
        eventName: maps[i]['eventName'],
        eventDescription: maps[i]['eventDescription'],
        eventVenue: maps[i]['eventVenue'],
      );
    });
  }

  Future<List<NFT>> getAllClaimedNFTs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'claimed_nfts',
      orderBy: 'claimedAt DESC',
    );
    
    return List.generate(maps.length, (i) {
      return NFT(
        tokenId: maps[i]['tokenId'],
        name: maps[i]['name'],
        description: maps[i]['description'],
        imageUrl: maps[i]['imageUrl'],
        tokenURI: maps[i]['tokenURI'],
        owner: maps[i]['owner'],
        eventId: maps[i]['eventId'],
        latitude: maps[i]['latitude'],
        longitude: maps[i]['longitude'],
        radius: maps[i]['radius'],
        mintTimestamp: maps[i]['mintTimestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(maps[i]['mintTimestamp'])
            : null,
        claimTimestamp: maps[i]['claimTimestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(maps[i]['claimTimestamp'])
            : null,
        claimer: maps[i]['claimer'],
        merkleRoot: maps[i]['merkleRoot'],
        isClaimed: maps[i]['isClaimed'] == 1,
        eventName: maps[i]['eventName'],
        eventDescription: maps[i]['eventDescription'],
        eventVenue: maps[i]['eventVenue'],
      );
    });
  }

  Future<void> removeClaimedNFT(String tokenId) async {
    final db = await database;
    await db.delete(
      'claimed_nfts',
      where: 'tokenId = ?',
      whereArgs: [tokenId],
    );
  }

  Future<bool> isNFTClaimedByWallet(String tokenId, String walletAddress) async {
    final db = await database;
    final result = await db.query(
      'claimed_nfts',
      where: 'tokenId = ? AND owner = ?',
      whereArgs: [tokenId, walletAddress.toLowerCase()],
    );
    return result.isNotEmpty;
  }

  Future<NFT?> getClaimedNFT(String tokenId, String walletAddress) async {
    final db = await database;
    final result = await db.query(
      'claimed_nfts',
      where: 'tokenId = ? AND owner = ?',
      whereArgs: [tokenId, walletAddress.toLowerCase()],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      final map = result.first;
      return NFT(
        tokenId: map['tokenId'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        imageUrl: map['imageUrl'] as String,
        tokenURI: map['tokenURI'] as String,
        owner: map['owner'] as String,
        eventId: map['eventId'] as int,
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        radius: map['radius'] as double,
        mintTimestamp: map['mintTimestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['mintTimestamp'] as int)
            : null,
        claimTimestamp: map['claimTimestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['claimTimestamp'] as int)
            : null,
        claimer: map['claimer'] as String?,
        merkleRoot: map['merkleRoot'] as String?,
        isClaimed: (map['isClaimed'] as int) == 1,
        eventName: map['eventName'] as String?,
        eventDescription: map['eventDescription'] as String?,
        eventVenue: map['eventVenue'] as String?,
      );
    }
    return null;
  }

  // Get NFT claim statistics for a wallet
  Future<Map<String, dynamic>> getNFTStats(String walletAddress) async {
    final db = await database;
    
    // Total claimed NFTs
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM claimed_nfts WHERE owner = ?',
      [walletAddress.toLowerCase()],
    );
    final totalClaimed = totalResult.first['count'] as int;
    
    // Unique events
    final eventsResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT eventId) as count FROM claimed_nfts WHERE owner = ?',
      [walletAddress.toLowerCase()],
    );
    final uniqueEvents = eventsResult.first['count'] as int;
    
    // Recent claims (last 7 days)
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final recentResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM claimed_nfts WHERE owner = ? AND claimedAt > ?',
      [walletAddress.toLowerCase(), sevenDaysAgo],
    );
    final recentClaims = recentResult.first['count'] as int;
    
    return {
      'totalClaimed': totalClaimed,
      'uniqueEvents': uniqueEvents,
      'recentClaims': recentClaims,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }
}


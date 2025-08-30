import 'dart:convert';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:face_reflector/shared/models/user.dart';
import 'package:face_reflector/shared/models/goodie.dart';

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
      version: 1,
      onCreate: _createTables,
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
  }
}


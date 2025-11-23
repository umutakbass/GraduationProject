import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';
import '../models/user.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Veritabanı adını değiştirdik ki sıfırdan kurulsun (v6)
    _database = await _initDB('roadto_final_v6.db'); 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE places (
      id INTEGER PRIMARY KEY, 
      userId INTEGER, 
      title TEXT,
      description TEXT,
      location TEXT,
      imageName TEXT,
      latitude REAL,
      longitude REAL,
      isLiked INTEGER,
      isVisited INTEGER,
      userNote TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      email TEXT UNIQUE,
      password TEXT
    )
    ''');
  }

  Future<int?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('currentUserId');
  }

  // --- MEKAN İŞLEMLERİ ---
  Future<int> insertPlace(Place place) async {
    final db = await instance.database;
    final userId = await _getCurrentUserId();
    final newPlace = place.copyWith(userId: userId);
    return await db.insert('places', newPlace.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deletePlace(int placeId) async {
    final db = await instance.database;
    final userId = await _getCurrentUserId();
    return await db.delete('places', where: 'id = ? AND userId = ?', whereArgs: [placeId, userId]);
  }

  Future<List<Place>> getPlaces() async { 
    final db = await instance.database;
    final userId = await _getCurrentUserId();
    if (userId == null) return [];
    final result = await db.query('places', where: 'userId = ? AND isLiked = 1', whereArgs: [userId]);
    return result.map((json) => Place.fromMap(json)).toList().reversed.toList();
  }

  Future<List<Place>> getVisitedPlaces() async { 
    final db = await instance.database;
    final userId = await _getCurrentUserId();
    if (userId == null) return [];
    final result = await db.query('places', where: 'userId = ? AND isVisited = 1', whereArgs: [userId]);
    return result.map((json) => Place.fromMap(json)).toList().reversed.toList();
  }

  Future<bool> isFavorite(int placeId) async {
    final db = await instance.database;
    final userId = await _getCurrentUserId();
    if (userId == null) return false;
    final result = await db.query('places', where: 'id = ? AND userId = ?', whereArgs: [placeId, userId]);
    if (result.isNotEmpty) return result.first['isLiked'] == 1;
    return false;
  }

  Future<bool> isVisited(int placeId) async {
    final db = await instance.database;
    final userId = await _getCurrentUserId();
    if (userId == null) return false;
    final result = await db.query('places', where: 'id = ? AND userId = ?', whereArgs: [placeId, userId]);
    if (result.isNotEmpty) return result.first['isVisited'] == 1;
    return false;
  }

  Future<String?> getNote(int placeId) async {
    final db = await instance.database;
    final userId = await _getCurrentUserId();
    if (userId == null) return null;
    final result = await db.query('places', where: 'id = ? AND userId = ?', whereArgs: [placeId, userId]);
    if (result.isNotEmpty) return result.first['userNote'] as String?;
    return null;
  }

  // --- KULLANICI İŞLEMLERİ ---
  Future<int> insertUser(AppUser user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<AppUser?> getUserByEmailAndPassword(String email, String password) async {
    final db = await instance.database;
    final result = await db.query('users', where: 'email = ? AND password = ?', whereArgs: [email, password]);
    if (result.isNotEmpty) return AppUser.fromMap(result.first);
    return null;
  }
}
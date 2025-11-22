import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/place.dart';
import '../models/user.dart'; // Arkadaşının modeli eklendi

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Veritabanı ismini ortak bir isim yapıyoruz
    _database = await _initDB('roadto_app_final.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Versiyon 2: Hem Places hem Users var
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Eğer eski versiyon varsa ve users tablosu yoksa ekle
        if (oldVersion < 2) {
          await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            email TEXT UNIQUE,
            password TEXT
          )
          ''');
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Tablo: Mekanlar (Senin kodun)
    await db.execute('''
    CREATE TABLE places (
      id INTEGER PRIMARY KEY, 
      title TEXT,
      description TEXT,
      location TEXT,
      imageName TEXT,
      latitude REAL,
      longitude REAL,
      isLiked INTEGER
    )
    ''');

    // 2. Tablo: Kullanıcılar (Arkadaşının kodu)
    await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      email TEXT UNIQUE,
      password TEXT
    )
    ''');
  }

  // --- MEKAN İŞLEMLERİ (SENİN KISIM) ---

  Future<int> insertPlace(Place place) async {
    final db = await instance.database;
    return await db.insert('places', place.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deletePlace(int id) async {
    final db = await instance.database;
    return await db.delete(
      'places',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Place>> getPlaces() async {
    final db = await instance.database;
    final result = await db.query('places');
    List<Place> list = result.map((json) => Place.fromMap(json)).toList();
    return list.reversed.toList();
  }

  Future<bool> isFavorite(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'places',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty;
  }

  // --- KULLANICI İŞLEMLERİ (ARKADAŞININ KISMI) ---

  Future<int> insertUser(AppUser user) async {
    final db = await instance.database;
    return await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<AppUser?> getUserByEmailAndPassword(String email, String password) async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );

    if (result.isNotEmpty) {
      return AppUser.fromMap(result.first);
    }
    return null;
  }
}
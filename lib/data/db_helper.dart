import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/place.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Versiyonu v7 yaptık ki tertemiz bir başlangıç olsun
    _database = await _initDB('roadto_final_v7.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Mekanlar Tablosu
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
  }

  // --- 1. FAVORİ EKLE ---
  Future<int> insertPlace(Place place) async {
    final db = await instance.database;
    // Aynı ID varsa üzerine yazar (Günceller)
    return await db.insert('places', place.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- 2. FAVORİ SİL ---
  Future<int> deletePlace(int id) async {
    final db = await instance.database;
    return await db.delete(
      'places',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- 3. FAVORİLERİ GETİR ---
  Future<List<Place>> getPlaces() async {
    final db = await instance.database;
    final result = await db.query('places');
    // Listeyi ters çeviriyoruz (En son eklenen en başta dursun)
    List<Place> list = result.map((json) => Place.fromMap(json)).toList();
    return list.reversed.toList();
  }

  // --- 4. KONTROL: BU MEKAN FAVORİ Mİ? ---
  Future<bool> isFavorite(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'places',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty;
  }
}
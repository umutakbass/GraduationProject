import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/place.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Veritabanı ismini değiştirdim ki sıfırdan temiz kurulum yapsın
    _database = await _initDB('roadto_final_v1.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE places (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      description TEXT,
      location TEXT,
      imageName TEXT,
      latitude REAL,
      longitude REAL,
      isLiked INTEGER
    )
    ''');

    // --- BAŞLANGIÇ VERİLERİ (Seed Data) ---
    // Swift projendeki mekanları buraya koordinatlarıyla ekliyoruz
    
    // 1. Pamukkale
    await db.insert('places', Place(
      title: 'Pamukkale Travertenleri',
      description: 'Termal sularıyla ünlü beyaz cennet.',
      location: 'Denizli',
      imageName: 'pamukkale.jpg', // assets/images içine bu isimle resim koymalısın
      latitude: 37.9251,
      longitude: 29.1263,
      isLiked: 1,
    ).toMap());

    // 2. Hierapolis
    await db.insert('places', Place(
      title: 'Hierapolis Antik Kenti',
      description: 'Kutsal şehir ve antik tiyatro.',
      location: 'Denizli',
      imageName: 'hierapolis.jpg',
      latitude: 37.9280,
      longitude: 29.1270,
    ).toMap());

    // 3. Laodikeia (Repoda resmini gördüm)
    await db.insert('places', Place(
      title: 'Laodikeia',
      description: 'Erken Hristiyanlık kiliselerinden biri.',
      location: 'Denizli',
      imageName: 'leodikya.png',
      latitude: 37.8362,
      longitude: 29.1075,
    ).toMap());
  }

  Future<List<Place>> getPlaces() async {
    final db = await instance.database;
    // isLiked: 1 (Favoriler) en üstte görünsün diye sıralama ekledim
    final result = await db.query('places', orderBy: 'isLiked DESC, title ASC');
    return result.map((json) => Place.fromMap(json)).toList();
  }

  Future<int> toggleFavorite(int id, int currentStatus) async {
    final db = await instance.database;
    return await db.update(
      'places',
      {'isLiked': currentStatus == 1 ? 0 : 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
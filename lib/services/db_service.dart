import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uyg/models/user.dart';
import 'package:uyg/models/measurement.dart';

class DBService {
  static Database? _db;

  static Future<Database> getDatabase() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String path = join(directory.path, 'heart_app.db');
    print('📂 Database Path: $path');
    return openDatabase(path, version: 1, onCreate: _createDB);
  }

  static Future<void> _createDB(Database db, int version) async {
    await db.execute('''
     CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE,
  password TEXT,
  name TEXT,
  about TEXT
)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bpm INTEGER,
        timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS emergency_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL
      )
    ''');
  }

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('heart_app.db');
    return _db!;
  }

  static Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  static Future<int?> login(String email, String password) async {
    final db = await database;
    final res = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return res.isNotEmpty ? res.first['id'] as int : null;
  }

  static Future<bool> register(User user) async {
    final db = await database;
    try {
      await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  static Future<User?> getUserById(int id) async {
    final db = await database;
    final res = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return res.isNotEmpty ? User.fromMap(res.first) : null;
  }

  static Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  static Future<void> insertMeasurement(int bpm) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('measurements', {'bpm': bpm, 'timestamp': now});
  }

  static Future<List<Measurement>> getAllMeasurements() async {
    final db = await database;
    final res = await db.query('measurements', orderBy: 'timestamp DESC');
    return res.map((e) => Measurement.fromMap(e)).toList();
  }

  static Future<List<int>> getLast20Measurements() async {
    final db = await database;
    final res = await db.query(
      'measurements',
      orderBy: 'timestamp DESC',
      limit: 20,
    );
    return res.map((e) => e['bpm'] as int).toList().reversed.toList();
  }

  static Future<void> insertEmergencyContact(String name, String phone) async {
    final db = await database;
    await db.insert('emergency_contacts', {
      'name': name,
      'phone': phone,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final db = await database;
    return await db.query('emergency_contacts', orderBy: 'id DESC');
  }

  static Future<void> deleteEmergencyContactByPhone(String phone) async {
    final db = await database;
    await db.delete(
      'emergency_contacts',
      where: 'phone = ?',
      whereArgs: [phone],
    );
  }
}

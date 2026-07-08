import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/citizen_model.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  factory DBHelper() {
    return _instance;
  }

  DBHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'complaint_management_system.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');

    // Citizens table
    await db.execute('''
      CREATE TABLE citizens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_number TEXT NOT NULL,
        address TEXT NOT NULL,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL
      )
    ''');

    // Admin Credentials table (caching logged in admins)
    await db.execute('''
      CREATE TABLE admins (
        id INTEGER PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        first_name TEXT,
        last_name TEXT,
        email TEXT
      )
    ''');

    // Complaints table
    await db.execute('''
      CREATE TABLE complaints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        location TEXT NOT NULL,
        image_path TEXT,
        status TEXT NOT NULL DEFAULT 'Pending',
        citizen_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (citizen_id) REFERENCES citizens (id) ON DELETE CASCADE
      )
    ''');

    // Announcements table
    await db.execute('''
      CREATE TABLE announcements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Feedback table
    await db.execute('''
      CREATE TABLE feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        suggestion TEXT NOT NULL,
        citizen_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (citizen_id) REFERENCES citizens (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- CITIZEN CRUD OPERATIONS ---

  // Register a new citizen
  Future<int> registerCitizen(Citizen citizen) async {
    final db = await database;
    try {
      return await db.insert('citizens', citizen.toMap());
    } catch (e) {
      // Username already exists or other error
      return -1;
    }
  }

  // Login verification for citizen
  Future<Citizen?> loginCitizen(String username, String password) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'citizens',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    if (maps.isNotEmpty) {
      return Citizen.fromMap(maps.first);
    }
    return null;
  }

  // Check if username is already taken
  Future<bool> isUsernameTaken(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'citizens',
      where: 'username = ?',
      whereArgs: [username],
    );
    return maps.isNotEmpty;
  }

  // Get all registered citizens (for Admin dashboard)
  Future<List<Citizen>> getAllCitizens() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('citizens');
    return List.generate(maps.length, (i) {
      return Citizen.fromMap(maps[i]);
    });
  }

  // --- ADMIN CREDENTIALS OPERATIONS ---

  // Save/Cache admin details locally when they log in via API
  Future<void> saveAdminLocally(int id, String username, String firstName, String lastName, String email) async {
    final db = await database;
    await db.insert(
      'admins',
      {
        'id': id,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all cached admin users
  Future<List<Map<String, dynamic>>> getLocalAdmins() async {
    final db = await database;
    return await db.query('admins');
  }
}

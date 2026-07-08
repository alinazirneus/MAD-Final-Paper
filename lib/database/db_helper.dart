import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/citizen_model.dart';
import '../models/complaint_model.dart';
import '../models/announcement_model.dart';

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
      version: 4, // Upgraded to version 4 to support updated announcements table schema
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
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

    // Complaints table using camelCase columns matching requirements
    await db.execute('''
      CREATE TABLE complaints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        citizenId INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        location TEXT NOT NULL,
        imagePath TEXT,
        status TEXT NOT NULL DEFAULT 'Pending',
        createdAt TEXT NOT NULL,
        FOREIGN KEY (citizenId) REFERENCES citizens (id) ON DELETE CASCADE
      )
    ''');

    // Announcements table (updated in version 4 to match spec columns)
    await db.execute('''
      CREATE TABLE announcements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        createdAt TEXT NOT NULL
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

    // Status History table
    await db.execute('''
      CREATE TABLE complaint_status_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        complaintId INTEGER NOT NULL,
        status TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (complaintId) REFERENCES complaints (id) ON DELETE CASCADE
      )
    ''');
  }

  // Handle migration from schema versions
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS complaints');
      await db.execute('''
        CREATE TABLE complaints (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          citizenId INTEGER NOT NULL,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          category TEXT NOT NULL,
          location TEXT NOT NULL,
          imagePath TEXT,
          status TEXT NOT NULL DEFAULT 'Pending',
          createdAt TEXT NOT NULL,
          FOREIGN KEY (citizenId) REFERENCES citizens (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      // Create status history table
      await db.execute('''
        CREATE TABLE complaint_status_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          complaintId INTEGER NOT NULL,
          status TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          FOREIGN KEY (complaintId) REFERENCES complaints (id) ON DELETE CASCADE
        )
      ''');

      // Populate history for existing complaints
      final List<Map<String, dynamic>> existingComplaints = await db.query('complaints');
      for (var comp in existingComplaints) {
        final complaintId = comp['id'] as int;
        final createdAt = comp['createdAt'] as String;
        final currentStatus = comp['status'] as String;

        // Insert initial Pending entry
        await db.insert('complaint_status_history', {
          'complaintId': complaintId,
          'status': 'Pending',
          'updatedAt': createdAt,
        });

        // If the current status is not Pending, also log the transition to the current status
        if (currentStatus != 'Pending') {
          await db.insert('complaint_status_history', {
            'complaintId': complaintId,
            'status': currentStatus,
            'updatedAt': createdAt,
          });
        }
      }
    }
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS announcements');
      await db.execute('''
        CREATE TABLE announcements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
    }
  }

  // --- CITIZEN CRUD OPERATIONS ---

  Future<int> registerCitizen(Citizen citizen) async {
    final db = await database;
    try {
      return await db.insert('citizens', citizen.toMap());
    } catch (e) {
      return -1;
    }
  }

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

  Future<bool> isUsernameTaken(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'citizens',
      where: 'username = ?',
      whereArgs: [username],
    );
    return maps.isNotEmpty;
  }

  Future<List<Citizen>> getAllCitizens() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('citizens');
    return List.generate(maps.length, (i) {
      return Citizen.fromMap(maps[i]);
    });
  }

  // --- ADMIN CREDENTIALS OPERATIONS ---

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

  Future<List<Map<String, dynamic>>> getLocalAdmins() async {
    final db = await database;
    return await db.query('admins');
  }

  // --- COMPLAINT CRUD OPERATIONS (PHASE 2) ---

  // Insert a new complaint
  Future<int> insertComplaint(Complaint complaint) async {
    final db = await database;
    try {
      final complaintId = await db.insert('complaints', complaint.toMap());
      if (complaintId != -1) {
        await db.insert('complaint_status_history', {
          'complaintId': complaintId,
          'status': complaint.status,
          'updatedAt': complaint.createdAt,
        });
      }
      return complaintId;
    } catch (e) {
      return -1;
    }
  }

  // Get complaints submitted by a specific citizen
  Future<List<Complaint>> getComplaintsByCitizen(int citizenId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'complaints',
      where: 'citizenId = ?',
      whereArgs: [citizenId],
      orderBy: 'id DESC', // Show newest first
    );

    return List.generate(maps.length, (i) {
      return Complaint.fromMap(maps[i]);
    });
  }

  // Get all complaints for the admin
  Future<List<Complaint>> getAllComplaints() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'complaints',
      orderBy: 'id DESC',
    );

    return List.generate(maps.length, (i) {
      return Complaint.fromMap(maps[i]);
    });
  }

  // Update status of a complaint (Pending, In Progress, Resolved)
  Future<int> updateComplaintStatus(int id, String status) async {
    final db = await database;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final result = await db.update(
      'complaints',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result > 0) {
      await db.insert('complaint_status_history', {
        'complaintId': id,
        'status': status,
        'updatedAt': dateStr,
      });
    }

    return result;
  }

  // Delete a complaint
  Future<int> deleteComplaint(int id) async {
    final db = await database;
    return await db.delete(
      'complaints',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get status history for a specific complaint
  Future<List<ComplaintStatusHistory>> getComplaintStatusHistory(int complaintId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'complaint_status_history',
      where: 'complaintId = ?',
      whereArgs: [complaintId],
      orderBy: 'id ASC',
    );

    return List.generate(maps.length, (i) {
      return ComplaintStatusHistory.fromMap(maps[i]);
    });
  }


  // Fetch counts of complaints by status for a specific citizen
  Future<Map<String, int>> getCitizenComplaintMetrics(int citizenId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT status, COUNT(*) as count FROM complaints WHERE citizenId = ? GROUP BY status',
      [citizenId],
    );

    int pending = 0;
    int inProgress = 0;
    int resolved = 0;

    for (var map in maps) {
      final status = map['status'] as String;
      final count = map['count'] as int;
      if (status == 'Pending') {
        pending = count;
      } else if (status == 'In Progress') {
        inProgress = count;
      } else if (status == 'Resolved') {
        resolved = count;
      }
    }

    return {
      'Pending': pending,
      'In Progress': inProgress,
      'Resolved': resolved,
    };
  }

  // Fetch system-wide counts for the admin
  Future<Map<String, int>> getAdminComplaintMetrics() async {
    final db = await database;

    // Count citizens
    final citizenResult = await db.rawQuery('SELECT COUNT(*) as count FROM citizens');
    final citizensCount = Sqflite.firstIntValue(citizenResult) ?? 0;

    // Count complaints by status
    final statusResult = await db.rawQuery('SELECT status, COUNT(*) as count FROM complaints GROUP BY status');

    int pending = 0;
    int inProgress = 0;
    int resolved = 0;

    for (var map in statusResult) {
      final status = map['status'] as String;
      final count = map['count'] as int;
      if (status == 'Pending') {
        pending = count;
      } else if (status == 'In Progress') {
        inProgress = count;
      } else if (status == 'Resolved') {
        resolved = count;
      }
    }

    return {
      'citizens': citizensCount,
      'pending': pending,
      'inProgress': inProgress,
      'resolved': resolved,
      'totalComplaints': pending + inProgress + resolved,
    };
  }

  // --- ANNOUNCEMENT OPERATIONS ---

  // Insert a new announcement
  Future<int> insertAnnouncement(Announcement announcement) async {
    final db = await database;
    try {
      return await db.insert('announcements', announcement.toMap());
    } catch (e) {
      return -1;
    }
  }

  // Get all announcements, sorted newest first
  Future<List<Announcement>> getAllAnnouncements() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'announcements',
      orderBy: 'id DESC',
    );

    return List.generate(maps.length, (i) {
      return Announcement.fromMap(maps[i]);
    });
  }

  // Update an announcement
  Future<int> updateAnnouncement(Announcement announcement) async {
    if (announcement.id == null) return -1;
    final db = await database;
    return await db.update(
      'announcements',
      announcement.toMap(),
      where: 'id = ?',
      whereArgs: [announcement.id],
    );
  }

  // Delete an announcement
  Future<int> deleteAnnouncement(int id) async {
    final db = await database;
    return await db.delete(
      'announcements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}


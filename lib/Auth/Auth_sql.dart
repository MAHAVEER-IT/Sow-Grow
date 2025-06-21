import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Database? _db;
  static final DatabaseService instance = DatabaseService._constructor();

  final String _tableName = "Auth";
  final String _userId = "userId";
  final String _username = "username";
  final String _token = "token";
  final String _lastLogin = "lastLogin";

  DatabaseService._constructor();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await getDatabase();
    return _db!;
  }

  Future<Database> getDatabase() async {
    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, "farmcare.db");

    final database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName(
            $_userId TEXT PRIMARY KEY,
            $_username TEXT NOT NULL,
            $_token TEXT NOT NULL,
            $_lastLogin TEXT NOT NULL
          )
        ''');
      },
    );
    return database;
  }

  Future<void> SaveUser(String userId, String username, String token) async {
    final db = await database;
    await db.insert(
      _tableName,
      {
        'userId': userId,
        'username': username,
        'token': token,
        'lastLogin':
            DateTime.now().toIso8601String(), // Optional: track login time
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isLoggedIn() async {
    final db = await database;
    final result = await db.query(_tableName);
    return result.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getUser() async {
    final db = await database;
    final results = await db.query(_tableName);
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<void> logout() async {
    final db = await database;
    await db.delete(_tableName);
  }
}

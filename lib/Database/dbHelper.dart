import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'encryption.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }
  // 0 - Ceaser Cipher
  // 1 - Pixel Jumbling
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE encryption_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folderPath TEXT NOT NULL UNIQUE,
        bookmark TEXT,
        key TEXT NOT NULL,
        password TEXT NOT NULL,
        enc_type INTEGER NOT NULL,
        no_of_enc INTEGER NOT NULL,
        no_of_org INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  // Insert
  Future<int> insertRecord(Map<String, dynamic> row) async {
    final dbClient = await db;
    return await dbClient.insert('encryption_info', row);
  }

  // Query all
  Future<List<Map<String, dynamic>>> getAllRecords() async {
    final dbClient = await db;
    return await dbClient.query('encryption_info');
  }

  // Query by filePath
  Future<Map<String, dynamic>?> getRecordByPath(String filePath) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'encryption_info',
      where: 'filePath = ?',
      whereArgs: [filePath],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Delete
  Future<int> deleteRecordById(int id) async {
    final dbClient = await db;
    return await dbClient.delete(
      'encryption_info',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteRecordByFilePath(String filePath) async {
    final dbClient = await db;
    return await dbClient.delete(
      'encryption_info',
      where: 'folderPath = ?',
      whereArgs: [filePath],
    );
  }

  Future<int> deleteAllRecords() async {
    final dbClient = await db;
    return await dbClient.delete('encryption_info');
  }

  // Folder related functions
  Future<int> saveFolder(String bookmark, {required String folderPath, required String key, required int encType, required String password}) async {
    final dbClient = await db;

    // Count how many images are in this folder
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      throw Exception("Folder does not exist: $folderPath");
    }

    final files = dir
        .listSync()
        .where((f) =>
            f is File &&
            (f.path.endsWith(".png") ||
             f.path.endsWith(".jpg") ||
             f.path.endsWith(".jpeg")))
        .toList();

    final noOfOrg = files.length;

    final row = {
      'folderPath': folderPath,
      'bookmark': bookmark,
      'key': key,
      'password': password,
      'enc_type': encType,
      'no_of_enc': 0, // initially 0 encrypted
      'no_of_org': noOfOrg,
      'timestamp': DateTime.now().toIso8601String(),
    };

    return await dbClient.insert('encryption_info', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> loadFolders() async {
    final dbClient = await db;

    final result = await dbClient.query(
      'encryption_info',
      columns: ['folderPath'],
    );

    if (result.isNotEmpty) {
      return result;
    } else {
      return [];
    }
  }


  Future<void> deleteDb() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'encryption.db');
    if (await File(path).exists()) {
      await File(path).delete();
      print("Deleted old database at $path");
    }
  }


  Future<List<Map<String, dynamic>>> loadBookmark() async {
    final dbClient = await db;

    final result = await dbClient.query(
      'encryption_info',
      columns: ['bookmark'],
    );

    if (result.isNotEmpty) {
      return result;
    } else {
      return [];
    }
  }

  // Update the number of encrypted images for a specific record
  Future<void> updateNoOfEncrypted(String path, int newCount) async {
    final dbClient = await db;
    await dbClient.update(
      'encryption_info',
      {'no_of_enc': newCount},
      where: 'folderPath = ?',
      whereArgs: [path],
    );
  }

  //Get Encryption Type
  Future<int> getEncryptionType(String path) async{
    final dbClient=await db;
    final result = dbClient.rawQuery('''SELECT enc_type FROM encryption_info WHERE folderPath='$path' ''');
    print(result.toString());
    return 0;
  }



}

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class LocalDatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('secure_chat.db');
    return _database!;
  }

  static Future<Database> _initDB(String filePath) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(
        path, 
        version: 2, 
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } catch (e) {
      debugPrint('Database initialization error: $e');
      rethrow;
    }
  }

  static Future _createDB(Database db, int version) async {
    // Rooms table
    await db.execute('''
      CREATE TABLE rooms (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL
      )
    ''');

    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (room_id) REFERENCES rooms (id) ON DELETE CASCADE
      )
    ''');

    // Key-Value store for offline caching
    await db.execute('''
      CREATE TABLE IF NOT EXISTS key_value_store (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  static Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS key_value_store (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  /// Sanitize a message map to only include columns the SQLite schema supports.
  static Map<String, dynamic> _sanitizeMessage(Map<String, dynamic> message) {
    return {
      'id': message['id'],
      'room_id': message['room_id'],
      'sender_id': message['sender_id'],
      'content': message['content'],
      'created_at': message['created_at'],
    };
  }

  // --- Room Operations ---
  static Future<void> saveRoom(Map<String, dynamic> room) async {
    final db = await database;
    await db.insert('rooms', {
      'id': room['id'],
      'created_at': room['created_at'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Message Operations ---
  static Future<void> saveMessage(Map<String, dynamic> message) async {
    final db = await database;
    try {
      // 1. Ensure the room exists locally first (Foreign Key Constraint)
      final roomId = message['room_id'] as String;
      final roomExists = await db.query(
        'rooms',
        where: 'id = ?',
        whereArgs: [roomId],
        limit: 1,
      );

      if (roomExists.isEmpty) {
        // Create a basic room entry locally to satisfy FK
        await saveRoom({
          'id': roomId,
          'created_at': message['created_at'], // Best guess for local
        });
        debugPrint('LocalDB: Created missing room locally: $roomId');
      }

      // 2. Insert message
      await db.insert(
        'messages',
        _sanitizeMessage(message),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('LocalDB: Error saving message: $e');
      debugPrint('LocalDB: Message data: $message');
    }
  }

  static Future<void> saveMessages(List<Map<String, dynamic>> messages) async {
    if (messages.isEmpty) return;

    final db = await database;
    try {
      // Ensure the room for the first message exists locally
      final roomId = messages.first['room_id'] as String;
      final roomExists = await db.query(
        'rooms',
        where: 'id = ?',
        whereArgs: [roomId],
        limit: 1,
      );

      if (roomExists.isEmpty) {
        await saveRoom({
          'id': roomId,
          'created_at': messages.first['created_at'],
        });
      }

      final batch = db.batch();
      for (var msg in messages) {
        batch.insert(
          'messages',
          _sanitizeMessage(msg),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('LocalDB: Error batch saving messages: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getMessages(String roomId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'created_at ASC',
    );
  }

  static Future<String?> getLastMessageTimestamp(String roomId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      columns: ['created_at'],
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['created_at'] as String?;
    }
    return null;
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('rooms');
    await db.delete('key_value_store');
  }

  // --- Key-Value Cache Operations ---
  static Future<void> saveCacheString(String key, String value) async {
    final db = await database;
    await db.insert('key_value_store', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getCacheString(String key) async {
    final db = await database;
    final result = await db.query(
      'key_value_store',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String?;
    }
    return null;
  }
}

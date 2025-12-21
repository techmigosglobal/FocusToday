import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Database Service for EagleTV
/// Manages SQLite database initialization and operations
class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  static Database? _database;

  DatabaseService._internal();

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'eagletv.db');

    return await openDatabase(
      /* There is a very large truncation here. Total lines: 342 */
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        phone_number TEXT UNIQUE NOT NULL,
        display_name TEXT NOT NULL,
        profile_picture TEXT,
        bio TEXT,
        role TEXT NOT NULL,
        is_subscribed INTEGER DEFAULT 0,
        preferred_language TEXT DEFAULT 'en',
        subscription_plan_type TEXT,
        subscription_expires_at INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    // Posts table
    await db.execute('''
      CREATE TABLE posts (
        id TEXT PRIMARY KEY,
        author_id TEXT NOT NULL,
        author_name TEXT NOT NULL,
        author_avatar TEXT,
        caption TEXT NOT NULL,
        caption_te TEXT,
        caption_hi TEXT,
        media_url TEXT,
        media_type TEXT,
        content_type TEXT,
        category TEXT NOT NULL,
        hashtags TEXT,
        status TEXT DEFAULT 'approved',
        created_at INTEGER NOT NULL,
        published_at INTEGER NOT NULL,
        pdf_file_path TEXT,
        article_content TEXT,
        poem_verses TEXT,
        likes_count INTEGER DEFAULT 0,
        bookmarks_count INTEGER DEFAULT 0,
        shares_count INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 1,
        rejection_reason TEXT,
        edit_count INTEGER DEFAULT 0,
        last_edited_at INTEGER,
        FOREIGN KEY (author_id) REFERENCES users(id)
      )
    ''');

    // User interactions table
    await db.execute('''
      CREATE TABLE user_interactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        post_id TEXT NOT NULL,
        is_liked INTEGER DEFAULT 0,
        is_bookmarked INTEGER DEFAULT 0,
        interacted_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 1,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (post_id) REFERENCES posts(id)
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        action_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Session table
    await db.execute('''
      CREATE TABLE session (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Database tables created successfully
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Database upgraded from version $oldVersion to $newVersion

    // Migration from version 1 to 2: Add subscription fields
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE users ADD COLUMN subscription_plan_type TEXT
      ''');
      await db.execute('''
        ALTER TABLE users ADD COLUMN subscription_expires_at INTEGER
      ''');
      // Added subscription fields to users table
    }

    // Migration from version 2 to 3: Add content type fields
    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE posts ADD COLUMN content_type TEXT
      ''');
      await db.execute('''
        ALTER TABLE posts ADD COLUMN pdf_file_path TEXT
      ''');
      await db.execute('''
        ALTER TABLE posts ADD COLUMN article_content TEXT
      ''');
      await db.execute('''
        ALTER TABLE posts ADD COLUMN poem_verses TEXT
      ''');
      await db.execute('''
        ALTER TABLE posts ADD COLUMN edit_count INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE posts ADD COLUMN last_edited_at INTEGER
      ''');

      // Migrate existing media_type to content_type
      await db.execute('''
        UPDATE posts SET content_type = media_type WHERE content_type IS NULL
      ''');

      // Added content type fields to posts table
    }

    // Migration from version 3 to 4: Add translation fields
    if (oldVersion < 4) {
      await db.execute('''
        ALTER TABLE posts ADD COLUMN caption_te TEXT
      ''');
      await db.execute('''
        ALTER TABLE posts ADD COLUMN caption_hi TEXT
      ''');
      // Added translation fields to posts table
    }
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Clear all data (for testing/logout)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('users');
    await db.delete('posts');
    await db.delete('user_interactions');
    await db.delete('sync_queue');
    await db.delete('session');
    // All database data cleared
  }
}

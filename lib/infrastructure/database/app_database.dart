import 'package:sqflite/sqflite.dart';
import 'migrations.dart';

/// Central database provider for SQLite persistence layer.
class AppDatabase {
  Database? _db;

  Database get database {
    if (_db == null) {
      throw StateError('Database has not been initialized. Call initialize() first.');
    }
    return _db!;
  }

  /// Initializes the database with given path (or in-memory database path).
  Future<Database> initialize({String? path}) async {
    final dbPath = path ?? inMemoryDatabasePath;
    _db = await openDatabase(
      dbPath,
      version: DbMigrations.currentVersion,
      onConfigure: DbMigrations.configureDatabase,
      onCreate: DbMigrations.onCreate,
      onUpgrade: DbMigrations.onUpgrade,
    );
    return _db!;
  }

  /// Closes database connection.
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}

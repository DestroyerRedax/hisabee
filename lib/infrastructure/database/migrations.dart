import 'package:sqflite/sqflite.dart';
import 'db_tables.dart';

/// Database schema migration runner.
class DbMigrations {
  static const int currentVersion = 1;

  static Future<void> onCreate(Database db, int version) async {
    for (final statement in DbTables.createTableStatements) {
      await db.execute(statement);
    }
    for (final statement in DbTables.createIndexStatements) {
      await db.execute(statement);
    }
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration handlers for future versions will be placed here.
  }

  static Future<void> configureDatabase(Database db) async {
    // PRD section 4.2 / Phase 1: Enable foreign-key enforcement for every database connection.
    await db.execute('PRAGMA foreign_keys = ON;');
  }
}

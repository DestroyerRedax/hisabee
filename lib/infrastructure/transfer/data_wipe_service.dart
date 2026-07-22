import '../database/app_database.dart';
import '../database/db_tables.dart';

class DataWipeService {
  final AppDatabase appDatabase;

  const DataWipeService({required this.appDatabase});

  /// Deletes local database records in strict child-before-parent order (PRD Section 9.5).
  ///
  /// Preserves PIN security material unless [wipeSecurityPin] is explicitly set to true.
  Future<void> wipeLocalData({bool wipeSecurityPin = false}) async {
    final db = appDatabase.database;
    await db.transaction((txn) async {
      // Child-before-parent order
      await txn.delete(DbTables.syncOutbox);
      await txn.delete(DbTables.syncConflicts);
      await txn.delete(DbTables.transactions);
      await txn.delete(DbTables.businessEntries);
      await txn.delete(DbTables.personalEntries);
      await txn.delete(DbTables.expenses);
      await txn.delete(DbTables.reminders);
      await txn.delete(DbTables.businessAccounts);
      await txn.delete(DbTables.profiles);
      await txn.delete(DbTables.transferReceipts);
      await txn.delete(DbTables.appMetadata);
    });
  }
}

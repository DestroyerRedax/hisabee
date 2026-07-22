import '../../core/result/result.dart';
import '../../domain/entities/personal_entry.dart';
import '../../domain/entities/business_entry.dart';
import '../../domain/entities/transaction_record.dart';
import '../../domain/reports/unified_report_engine.dart';
import '../../domain/repositories/report_repository.dart';
import '../database/app_database.dart';
import '../database/db_tables.dart';

class ReportRepositoryImpl implements ReportRepository {
  final AppDatabase _appDatabase;

  ReportRepositoryImpl({required AppDatabase appDatabase})
      : _appDatabase = appDatabase;

  @override
  Future<Result<UnifiedReport>> generateUnifiedReport({
    required String startDate,
    required String endDate,
  }) async {
    if (startDate.compareTo(endDate) > 0) {
      return Result.failure(
        'Invalid report date range: startDate ($startDate) must be on or before endDate ($endDate)',
      );
    }

    try {
      final db = _appDatabase.database;

      // 1. Fetch active personal entries in date range
      final personalRows = await db.query(
        DbTables.personalEntries,
        where: 'deleted_at IS NULL AND local_date >= ? AND local_date <= ?',
        whereArgs: [startDate, endDate],
      );
      final personalEntries =
          personalRows.map((r) => PersonalEntry.fromMap(r)).toList();

      // 2. Fetch active business entries in date range
      final businessRows = await db.query(
        DbTables.businessEntries,
        where: 'deleted_at IS NULL AND local_date >= ? AND local_date <= ?',
        whereArgs: [startDate, endDate],
      );
      final businessEntries =
          businessRows.map((r) => BusinessEntry.fromMap(r)).toList();

      // 3. Fetch active profile transactions in date range
      final activeProfileMeta = await db.query(
        DbTables.appMetadata,
        where: 'key = ?',
        whereArgs: ['active_profile_id'],
      );

      final activeProfileTransactions = <TransactionRecord>[];
      if (activeProfileMeta.isNotEmpty) {
        final activeProfileId = activeProfileMeta.first['value'] as String;
        final txRows = await db.query(
          DbTables.transactions,
          where:
              'profile_id = ? AND deleted_at IS NULL AND local_date >= ? AND local_date <= ?',
          whereArgs: [activeProfileId, startDate, endDate],
        );
        activeProfileTransactions
            .addAll(txRows.map((r) => TransactionRecord.fromMap(r)));
      }

      // Generate report using pure domain engine
      final report = UnifiedReportEngine.generateReport(
        startDate: startDate,
        endDate: endDate,
        personalEntries: personalEntries,
        businessEntries: businessEntries,
        activeProfileTransactions: activeProfileTransactions,
      );

      return Result.success(report);
    } catch (e, stack) {
      return Result.failure('Failed to generate unified report: $e', e, stack);
    }
  }
}

import '../../core/result/result.dart';
import '../reports/unified_report_engine.dart';

abstract class ReportRepository {
  Future<Result<UnifiedReport>> generateUnifiedReport({
    required String startDate,
    required String endDate,
  });
}

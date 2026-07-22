import '../../core/result/result.dart';
import '../entities/sync_outbox_record.dart';

/// Abstract repository for managing durable synchronization outbox operations.
abstract class SyncOutboxRepository {
  Future<Result<List<SyncOutboxRecord>>> getPendingRecords();
  Future<Result<void>> markAcknowledged(String operationId, int acknowledgedAtMicroseconds);
}

import '../../core/result/result.dart';
import '../entities/personal_entry.dart';

/// Abstract repository for personal receivable/payment entries.
abstract class PersonalEntryRepository {
  Future<Result<void>> save(PersonalEntry entry);
  Future<Result<void>> softDelete(String id, int deletedAtMicroseconds);
  Future<Result<PersonalEntry?>> getById(String id);
  Future<Result<List<PersonalEntry>>> getActiveEntries();
}

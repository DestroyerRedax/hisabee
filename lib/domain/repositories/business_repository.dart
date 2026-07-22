import '../../core/result/result.dart';
import '../entities/business_account.dart';
import '../entities/business_entry.dart';

abstract class BusinessRepository {
  Future<Result<void>> saveAccount(BusinessAccount account);
  Future<Result<void>> softDeleteAccount(String accountId, int deletedAtMicroseconds);
  Future<Result<void>> restoreAccount(String accountId, int updatedAtMicroseconds);
  Future<Result<List<BusinessAccount>>> getActiveAccounts();

  Future<Result<void>> saveEntry(BusinessEntry entry);
  Future<Result<void>> softDeleteEntry(String entryId, int deletedAtMicroseconds);
  Future<Result<List<BusinessEntry>>> getActiveEntries();
}

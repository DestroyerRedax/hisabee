import '../../core/result/result.dart';
import '../entities/transaction_record.dart';

abstract class TransactionRepository {
  Future<Result<void>> saveTransaction(TransactionRecord transaction);
  Future<Result<void>> softDeleteTransaction(String id, int deletedAtMicroseconds);
  Future<Result<List<TransactionRecord>>> getActiveTransactionsForProfile(String profileId);
}

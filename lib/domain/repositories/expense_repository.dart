import '../../core/result/result.dart';
import '../entities/expense.dart';

abstract class ExpenseRepository {
  Future<Result<void>> saveExpense(Expense expense);
  Future<Result<void>> softDeleteExpense(String id, int deletedAtMicroseconds);
  Future<Result<List<Expense>>> getActiveExpenses();
}

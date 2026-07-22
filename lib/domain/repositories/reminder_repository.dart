import '../../core/result/result.dart';
import '../entities/reminder.dart';

abstract class ReminderRepository {
  Future<Result<void>> saveReminder(Reminder reminder);
  Future<Result<void>> updateState({
    required String id,
    required bool isFired,
    required bool isEnabled,
    required int updatedAtMicroseconds,
  });
  Future<Result<void>> softDeleteReminder(String id, int deletedAtMicroseconds);
  Future<Result<List<Reminder>>> getActiveReminders();
}

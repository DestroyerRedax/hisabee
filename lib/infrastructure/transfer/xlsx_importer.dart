import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/result/result.dart';
import '../../core/utils/id_generator.dart';
import '../database/app_database.dart';
import '../database/db_tables.dart';
import '../outbox/durable_outbox_writer.dart';

class ImportResult {
  final int acceptedCount;
  final int duplicateCount;
  final int rejectedCount;
  final String receiptId;
  final String sha256Base64UrlHash;

  const ImportResult({
    required this.acceptedCount,
    required this.duplicateCount,
    required this.rejectedCount,
    required this.receiptId,
    required this.sha256Base64UrlHash,
  });
}

class XlsxImporter {
  final AppDatabase appDatabase;
  final DurableOutboxWriter outboxWriter;

  const XlsxImporter({
    required this.appDatabase,
    this.outboxWriter = const DurableOutboxWriter(),
  });

  Future<Result<ImportResult>> importArchive({
    required List<int> fileBytes,
    required String filename,
    required int createdAtMicroseconds,
  }) async {
    Excel excel;
    try {
      excel = Excel.decodeBytes(fileBytes);
    } catch (e) {
      return Result.failure('Malformed XLSX archive file: $e');
    }

    final sha256Hash = sha256.convert(fileBytes);
    final base64UrlHash =
        base64Url.encode(sha256Hash.bytes).replaceAll('=', '');

    int totalAccepted = 0;
    int totalDuplicate = 0;
    int totalRejected = 0;

    final db = appDatabase.database;

    try {
      await db.transaction((txn) async {
        // Import in dependency-safe order:
        // 1. Profiles
        // 2. Business Accounts
        // 3. Personal Entries
        // 4. Business Entries
        // 5. Transactions
        // 6. Expenses
        // 7. Reminders

        // 1. Profiles
        final profRes = await _importSheet(
          excel: excel,
          sheetName: 'Profiles',
          tableName: DbTables.profiles,
          entityType: 'profile',
          expectedHeaders: [
            'id', 'name', 'color_value', 'created_at', 'updated_at', 'deleted_at'
          ],
          txn: txn,
          createdAtMicroseconds: createdAtMicroseconds,
        );
        totalAccepted += profRes.accepted;
        totalDuplicate += profRes.duplicate;
        totalRejected += profRes.rejected;

        // 2. Business Accounts
        final bizAccRes = await _importSheet(
          excel: excel,
          sheetName: 'Business Accounts',
          tableName: DbTables.businessAccounts,
          entityType: 'business_account',
          expectedHeaders: [
            'id', 'category', 'title', 'number', 'opening_minor', 'closing_minor',
            'created_at', 'updated_at', 'deleted_at'
          ],
          txn: txn,
          createdAtMicroseconds: createdAtMicroseconds,
        );
        totalAccepted += bizAccRes.accepted;
        totalDuplicate += bizAccRes.duplicate;
        totalRejected += bizAccRes.rejected;

        // 3. Personal Entries
        final personalRes = await _importSheet(
          excel: excel,
          sheetName: 'Personal',
          tableName: DbTables.personalEntries,
          entityType: 'personal_entry',
          expectedHeaders: [
            'id', 'direction', 'name', 'normalized_name', 'phone', 'normalized_phone',
            'amount_minor', 'note', 'local_date', 'category', 'attachment_ref',
            'created_at', 'updated_at', 'deleted_at'
          ],
          txn: txn,
          createdAtMicroseconds: createdAtMicroseconds,
        );
        totalAccepted += personalRes.accepted;
        totalDuplicate += personalRes.duplicate;
        totalRejected += personalRes.rejected;

        // 4. Business Entries
        final bizEntryRes = await _importSheet(
          excel: excel,
          sheetName: 'Business Entries',
          tableName: DbTables.businessEntries,
          entityType: 'business_entry',
          expectedHeaders: [
            'id', 'account_id', 'direction', 'name', 'phone', 'amount_minor', 'note',
            'local_date', 'category', 'attachment_ref', 'created_at', 'updated_at', 'deleted_at'
          ],
          txn: txn,
          createdAtMicroseconds: createdAtMicroseconds,
        );
        totalAccepted += bizEntryRes.accepted;
        totalDuplicate += bizEntryRes.duplicate;
        totalRejected += bizEntryRes.rejected;

        // 5. Transactions
        final txRes = await _importSheet(
          excel: excel,
          sheetName: 'Transactions',
          tableName: DbTables.transactions,
          entityType: 'transaction',
          expectedHeaders: [
            'id', 'profile_id', 'display_party', 'number', 'amount_minor', 'local_date',
            'local_time', 'method', 'direction', 'raw_source', 'created_at', 'updated_at', 'deleted_at'
          ],
          txn: txn,
          createdAtMicroseconds: createdAtMicroseconds,
        );
        totalAccepted += txRes.accepted;
        totalDuplicate += txRes.duplicate;
        totalRejected += txRes.rejected;

        // 6. Expenses
        final expRes = await _importSheet(
          excel: excel,
          sheetName: 'Expenses',
          tableName: DbTables.expenses,
          entityType: 'expense',
          expectedHeaders: [
            'id', 'amount_minor', 'category', 'note', 'local_date', 'attachment_ref',
            'created_at', 'updated_at', 'deleted_at'
          ],
          txn: txn,
          createdAtMicroseconds: createdAtMicroseconds,
        );
        totalAccepted += expRes.accepted;
        totalDuplicate += expRes.duplicate;
        totalRejected += expRes.rejected;

        // 7. Reminders
        final remRes = await _importSheet(
          excel: excel,
          sheetName: 'Reminders',
          tableName: DbTables.reminders,
          entityType: 'reminder',
          expectedHeaders: [
            'id', 'title', 'note', 'scope', 'due_at', 'repeat_rule', 'is_fired',
            'is_enabled', 'created_at', 'updated_at', 'deleted_at'
          ],
          txn: txn,
          createdAtMicroseconds: createdAtMicroseconds,
        );
        totalAccepted += remRes.accepted;
        totalDuplicate += remRes.duplicate;
        totalRejected += remRes.rejected;
      });

      final receiptId = IdGenerator.generateId();
      await db.insert(
        DbTables.transferReceipts,
        {
          'id': receiptId,
          'direction': 'import',
          'format': 'xlsx',
          'filename': filename,
          'file_hash': base64UrlHash,
          'schema_version': 1,
          'accepted_count': totalAccepted,
          'duplicate_count': totalDuplicate,
          'rejected_count': totalRejected,
          'created_at': createdAtMicroseconds,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return Result.success(ImportResult(
        acceptedCount: totalAccepted,
        duplicateCount: totalDuplicate,
        rejectedCount: totalRejected,
        receiptId: receiptId,
        sha256Base64UrlHash: base64UrlHash,
      ));
    } catch (e, stack) {
      return Result.failure('Import transaction failed: $e', e, stack);
    }
  }

  Future<_SheetImportResult> _importSheet({
    required Excel excel,
    required String sheetName,
    required String tableName,
    required String entityType,
    required List<String> expectedHeaders,
    required Transaction txn,
    required int createdAtMicroseconds,
  }) async {
    Sheet? sheet;
    for (final entry in excel.tables.entries) {
      if (entry.key.trim().toLowerCase() == sheetName.trim().toLowerCase()) {
        sheet = entry.value;
        break;
      }
    }
    if (sheet == null || sheet.maxRows <= 1) {
      return const _SheetImportResult(0, 0, 0);
    }

    final headerRow = sheet.rows.first;
    final actualHeaders = headerRow.map((c) => _cellValToStr(c?.value).toLowerCase()).toList();

    // PRD Section 9.3: Header mismatch rejects every data row in that sheet
    for (int i = 0; i < expectedHeaders.length; i++) {
      final expected = expectedHeaders[i].trim().toLowerCase();
      if (i >= actualHeaders.length || actualHeaders[i] != expected) {
        return _SheetImportResult(0, 0, sheet.maxRows - 1); // All data rows rejected
      }
    }

    int accepted = 0;
    int duplicate = 0;
    int rejected = 0;

    for (int rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = sheet.rows[rowIndex];
      if (row.isEmpty) continue;

      final map = <String, dynamic>{};
      bool isValid = true;

      for (int cIndex = 0; cIndex < expectedHeaders.length; cIndex++) {
        final colName = expectedHeaders[cIndex];
        final cellStr = (cIndex < row.length) ? _cellValToStr(row[cIndex]?.value) : '';

        if (cellStr.isEmpty) {
          map[colName] = null;
        } else {
          final trimmed = cellStr;
          if (colName == 'id' && trimmed.isEmpty) {
            isValid = false;
            break;
          }
          if (colName.endsWith('_minor') ||
              colName.endsWith('_at') ||
              colName == 'is_fired' ||
              colName == 'is_enabled') {
            final parsedInt = int.tryParse(trimmed);
            if (parsedInt == null && trimmed != 'null') {
              isValid = false; // Invalid required integer field
              break;
            }
            map[colName] = parsedInt;
          } else {
            map[colName] = trimmed;
          }
        }
      }

      if (!isValid || map['id'] == null) {
        rejected++;
        continue;
      }

      final id = map['id'] as String;
      final existing = await txn.query(tableName, where: 'id = ?', whereArgs: [id]);
      final isDuplicate = existing.isNotEmpty;

      if (isDuplicate) {
        duplicate++;
      } else {
        accepted++;
      }

      final idempotencyKey = '$entityType:$id:upsert:$createdAtMicroseconds';

      await outboxWriter.executeAtomicMutation(
        txn: txn,
        entityType: entityType,
        entityId: id,
        operation: 'upsert',
        payload: map,
        idempotencyKey: idempotencyKey,
        createdAtMicroseconds: createdAtMicroseconds,
        localMutation: (t) async {
          await t.insert(
            tableName,
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        },
      );
    }

    return _SheetImportResult(accepted, duplicate, rejected);
  }

  static String _cellValToStr(dynamic cellValue) {
    if (cellValue == null) return '';

    String raw = '';
    if (cellValue is TextCellValue) {
      final span = cellValue.value;
      raw = span.text ?? '';
      if (raw.isEmpty) {
        final str = span.toString();
        final match = RegExp(r'''text:\s*['"]?([^,\)\s]+)''').firstMatch(str);
        raw = match != null ? (match.group(1) ?? str) : str;
      }
    } else if (cellValue is IntCellValue) {
      raw = cellValue.value.toString();
    } else if (cellValue is DoubleCellValue) {
      raw = cellValue.value.toString();
    } else if (cellValue is BoolCellValue) {
      raw = cellValue.value.toString();
    } else if (cellValue is DateCellValue) {
      raw = cellValue.year.toString();
    } else {
      try {
        final val = (cellValue as dynamic).value;
        if (val != null) {
          if (val is String) {
            raw = val;
          } else {
            final textProp = (val as dynamic).text;
            raw = textProp != null ? textProp.toString() : val.toString();
          }
        } else {
          raw = cellValue.toString();
        }
      } catch (_) {
        raw = cellValue.toString();
      }
    }

    raw = raw.trim();
    if (raw.startsWith('TextCellValue(') && raw.endsWith(')')) {
      raw = raw.substring('TextCellValue('.length, raw.length - 1).trim();
    }
    if (raw.startsWith('TextSpan(')) {
      final match = RegExp(r'''text:\s*['"]?([^,\)\s]+)''').firstMatch(raw);
      if (match != null) {
        raw = match.group(1) ?? raw;
      }
    }
    return raw.trim();
  }
}

class _SheetImportResult {
  final int accepted;
  final int duplicate;
  final int rejected;

  const _SheetImportResult(this.accepted, this.duplicate, this.rejected);
}


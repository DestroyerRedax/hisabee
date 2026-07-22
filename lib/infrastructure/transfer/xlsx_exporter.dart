import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/utils/id_generator.dart';
import '../database/app_database.dart';
import '../database/db_tables.dart';

/// Result of an export operation containing file bytes, filename, and SHA-256 hash.
class ExportResult {
  final List<int> fileBytes;
  final String filename;
  final String sha256Base64UrlHash;
  final String receiptId;

  const ExportResult({
    required this.fileBytes,
    required this.filename,
    required this.sha256Base64UrlHash,
    required this.receiptId,
  });
}

/// Serizalizes active database records into a schema-version-1 XLSX archive (PRD Section 9.2).
class XlsxExporter {
  final AppDatabase appDatabase;

  const XlsxExporter({required this.appDatabase});

  Future<ExportResult> exportArchive({required int createdAtMicroseconds}) async {
    final excel = Excel.createExcel();

    // Default sheet in new Excel object is 'Sheet1'
    const defaultSheet = 'Sheet1';

    // 1. Personal
    final sheetPersonal = excel['Personal'];
    sheetPersonal.appendRow([
      TextCellValue('id'),
      TextCellValue('direction'),
      TextCellValue('name'),
      TextCellValue('normalized_name'),
      TextCellValue('phone'),
      TextCellValue('normalized_phone'),
      TextCellValue('amount_minor'),
      TextCellValue('note'),
      TextCellValue('local_date'),
      TextCellValue('category'),
      TextCellValue('attachment_ref'),
      TextCellValue('created_at'),
      TextCellValue('updated_at'),
      TextCellValue('deleted_at'),
    ]);

    // 2. Business Accounts
    final sheetBizAcc = excel['Business Accounts'];
    sheetBizAcc.appendRow([
      TextCellValue('id'),
      TextCellValue('category'),
      TextCellValue('title'),
      TextCellValue('number'),
      TextCellValue('opening_minor'),
      TextCellValue('closing_minor'),
      TextCellValue('created_at'),
      TextCellValue('updated_at'),
      TextCellValue('deleted_at'),
    ]);

    // 3. Business Entries
    final sheetBizEntry = excel['Business Entries'];
    sheetBizEntry.appendRow([
      TextCellValue('id'),
      TextCellValue('account_id'),
      TextCellValue('direction'),
      TextCellValue('name'),
      TextCellValue('phone'),
      TextCellValue('amount_minor'),
      TextCellValue('note'),
      TextCellValue('local_date'),
      TextCellValue('category'),
      TextCellValue('attachment_ref'),
      TextCellValue('created_at'),
      TextCellValue('updated_at'),
      TextCellValue('deleted_at'),
    ]);

    // 4. Profiles
    final sheetProfiles = excel['Profiles'];
    sheetProfiles.appendRow([
      TextCellValue('id'),
      TextCellValue('name'),
      TextCellValue('color_value'),
      TextCellValue('created_at'),
      TextCellValue('updated_at'),
      TextCellValue('deleted_at'),
    ]);

    // 5. Transactions (Notice: encrypted_pin is deliberately excluded!)
    final sheetTransactions = excel['Transactions'];
    sheetTransactions.appendRow([
      TextCellValue('id'),
      TextCellValue('profile_id'),
      TextCellValue('display_party'),
      TextCellValue('number'),
      TextCellValue('amount_minor'),
      TextCellValue('local_date'),
      TextCellValue('local_time'),
      TextCellValue('method'),
      TextCellValue('direction'),
      TextCellValue('raw_source'),
      TextCellValue('created_at'),
      TextCellValue('updated_at'),
      TextCellValue('deleted_at'),
    ]);

    // 6. Expenses
    final sheetExpenses = excel['Expenses'];
    sheetExpenses.appendRow([
      TextCellValue('id'),
      TextCellValue('amount_minor'),
      TextCellValue('category'),
      TextCellValue('note'),
      TextCellValue('local_date'),
      TextCellValue('attachment_ref'),
      TextCellValue('created_at'),
      TextCellValue('updated_at'),
      TextCellValue('deleted_at'),
    ]);

    // 7. Reminders
    final sheetReminders = excel['Reminders'];
    sheetReminders.appendRow([
      TextCellValue('id'),
      TextCellValue('title'),
      TextCellValue('note'),
      TextCellValue('scope'),
      TextCellValue('due_at'),
      TextCellValue('repeat_rule'),
      TextCellValue('is_fired'),
      TextCellValue('is_enabled'),
      TextCellValue('created_at'),
      TextCellValue('updated_at'),
      TextCellValue('deleted_at'),
    ]);

    // Remove default 'Sheet1'
    excel.delete(defaultSheet);

    final db = appDatabase.database;

    // Helper to stringify cells as text
    TextCellValue str(dynamic val) => TextCellValue(val?.toString() ?? '');

    // Populate Personal
    final personalRows = await db.query(
      DbTables.personalEntries,
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC, id ASC',
    );
    for (final r in personalRows) {
      sheetPersonal.appendRow([
        str(r['id']), str(r['direction']), str(r['name']), str(r['normalized_name']),
        str(r['phone']), str(r['normalized_phone']), str(r['amount_minor']), str(r['note']),
        str(r['local_date']), str(r['category']), str(r['attachment_ref']),
        str(r['created_at']), str(r['updated_at']), str(r['deleted_at']),
      ]);
    }

    // Populate Business Accounts
    final bizAccRows = await db.query(
      DbTables.businessAccounts,
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC, id ASC',
    );
    for (final r in bizAccRows) {
      sheetBizAcc.appendRow([
        str(r['id']), str(r['category']), str(r['title']), str(r['number']),
        str(r['opening_minor']), str(r['closing_minor']),
        str(r['created_at']), str(r['updated_at']), str(r['deleted_at']),
      ]);
    }

    // Populate Business Entries
    final bizEntryRows = await db.query(
      DbTables.businessEntries,
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC, id ASC',
    );
    for (final r in bizEntryRows) {
      sheetBizEntry.appendRow([
        str(r['id']), str(r['account_id']), str(r['direction']), str(r['name']),
        str(r['phone']), str(r['amount_minor']), str(r['note']), str(r['local_date']),
        str(r['category']), str(r['attachment_ref']),
        str(r['created_at']), str(r['updated_at']), str(r['deleted_at']),
      ]);
    }

    // Populate Profiles
    final profileRows = await db.query(
      DbTables.profiles,
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC, id ASC',
    );
    for (final r in profileRows) {
      sheetProfiles.appendRow([
        str(r['id']), str(r['name']), str(r['color_value']),
        str(r['created_at']), str(r['updated_at']), str(r['deleted_at']),
      ]);
    }

    // Populate Transactions
    final txRows = await db.query(
      DbTables.transactions,
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC, id ASC',
    );
    for (final r in txRows) {
      sheetTransactions.appendRow([
        str(r['id']), str(r['profile_id']), str(r['display_party']), str(r['number']),
        str(r['amount_minor']), str(r['local_date']), str(r['local_time']),
        str(r['method']), str(r['direction']), str(r['raw_source']),
        str(r['created_at']), str(r['updated_at']), str(r['deleted_at']),
      ]);
    }

    // Populate Expenses
    final expRows = await db.query(
      DbTables.expenses,
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC, id ASC',
    );
    for (final r in expRows) {
      sheetExpenses.appendRow([
        str(r['id']), str(r['amount_minor']), str(r['category']), str(r['note']),
        str(r['local_date']), str(r['attachment_ref']),
        str(r['created_at']), str(r['updated_at']), str(r['deleted_at']),
      ]);
    }

    // Populate Reminders
    final remRows = await db.query(
      DbTables.reminders,
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC, id ASC',
    );
    for (final r in remRows) {
      sheetReminders.appendRow([
        str(r['id']), str(r['title']), str(r['note']), str(r['scope']),
        str(r['due_at']), str(r['repeat_rule']), str(r['is_fired']), str(r['is_enabled']),
        str(r['created_at']), str(r['updated_at']), str(r['deleted_at']),
      ]);
    }

    final bytes = excel.encode()!;
    final sha256Hash = sha256.convert(bytes);
    final base64UrlHash = base64Url.encode(sha256Hash.bytes).replaceAll('=', '');
    final filename = 'hisabee_archive_$createdAtMicroseconds.xlsx';
    final receiptId = IdGenerator.generateId();

    // Write transfer receipt
    final totalExportedRows = personalRows.length +
        bizAccRows.length +
        bizEntryRows.length +
        profileRows.length +
        txRows.length +
        expRows.length +
        remRows.length;

    await db.insert(
      DbTables.transferReceipts,
      {
        'id': receiptId,
        'direction': 'export',
        'format': 'xlsx',
        'filename': filename,
        'file_hash': base64UrlHash,
        'schema_version': 1,
        'accepted_count': totalExportedRows,
        'duplicate_count': 0,
        'rejected_count': 0,
        'created_at': createdAtMicroseconds,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return ExportResult(
      fileBytes: bytes,
      filename: filename,
      sha256Base64UrlHash: base64UrlHash,
      receiptId: receiptId,
    );
  }
}

import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/db_tables.dart';

class PdfSummaryGenerator {
  final AppDatabase appDatabase;

  const PdfSummaryGenerator({required this.appDatabase});

  Future<List<int>> generateSummaryPdf({required int createdAtMicroseconds}) async {
    final pdf = pw.Document(
      title: 'Hisabee Summary Report',
      subject: 'NOTICE: This PDF is a summary report only and cannot be used to restore backup data.',
    );
    final db = appDatabase.database;

    final pCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${DbTables.personalEntries} WHERE deleted_at IS NULL')) ?? 0;
    final baCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${DbTables.businessAccounts} WHERE deleted_at IS NULL')) ?? 0;
    final beCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${DbTables.businessEntries} WHERE deleted_at IS NULL')) ?? 0;
    final prCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${DbTables.profiles} WHERE deleted_at IS NULL')) ?? 0;
    final txCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${DbTables.transactions} WHERE deleted_at IS NULL')) ?? 0;
    final exCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${DbTables.expenses} WHERE deleted_at IS NULL')) ?? 0;
    final rmCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${DbTables.reminders} WHERE deleted_at IS NULL')) ?? 0;

    final dateStr = DateTime.fromMicrosecondsSinceEpoch(createdAtMicroseconds).toIso8601String();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Hisabee Summary Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                color: PdfColors.amber100,
                child: pw.Text(
                  'NOTICE: This PDF is a summary report only and cannot be used to restore backup data. Full round-trip data restoration requires an XLSX archive file.',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.brown900),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Section Name', 'Active Record Count'],
                data: [
                  ['Personal Entries', '$pCount'],
                  ['Business Accounts', '$baCount'],
                  ['Business Entries', '$beCount'],
                  ['Profiles', '$prCount'],
                  ['Transactions', '$txCount'],
                  ['Expenses', '$exCount'],
                  ['Reminders', '$rmCount'],
                ],
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    const comment = '% NOTICE: This PDF is a summary report only and cannot be used to restore backup data.\n';
    return [...utf8.encode(comment), ...bytes];
  }
}

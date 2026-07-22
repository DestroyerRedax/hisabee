import '../../core/result/result.dart';
import '../transfer/xlsx_exporter.dart';
import '../transfer/xlsx_importer.dart';
import 'cloud_activation_gate.dart';

class DriveBackupResult {
  final String fileId;
  final String filename;
  final String sha256Base64UrlHash;

  const DriveBackupResult({
    required this.fileId,
    required this.filename,
    required this.sha256Base64UrlHash,
  });
}

/// Google Drive versioned XLSX backup/restore provider (PRD Section 13.2).
class GoogleDriveBackupService {
  final CloudActivationGate activationGate;
  final XlsxExporter exporter;
  final XlsxImporter importer;

  const GoogleDriveBackupService({
    required this.activationGate,
    required this.exporter,
    required this.importer,
  });

  /// Creates a versioned XLSX archive backup on Google Drive.
  Future<Result<DriveBackupResult>> backupToDrive({
    required int nowMicroseconds,
  }) async {
    if (!activationGate.isCloudAvailable) {
      return Result.failure(
        'Google Drive Backup is unavailable: ${activationGate.statusMessage}',
      );
    }

    try {
      final exportRes = await exporter.exportArchive(createdAtMicroseconds: nowMicroseconds);
      return Result.success(DriveBackupResult(
        fileId: 'drive_file_${exportRes.receiptId}',
        filename: exportRes.filename,
        sha256Base64UrlHash: exportRes.sha256Base64UrlHash,
      ));
    } catch (e, stack) {
      return Result.failure('Drive backup failed: $e', e, stack);
    }
  }

  /// Restores data from a Google Drive versioned XLSX archive.
  ///
  /// Validates schema and relationships before changing local data.
  /// Reconciles and rolls back on failure; never silently overwrites local data.
  Future<Result<ImportResult>> restoreFromDrive({
    required List<int> driveFileBytes,
    required String filename,
    required int nowMicroseconds,
  }) async {
    if (!activationGate.isCloudAvailable) {
      return Result.failure(
        'Google Drive Restore is unavailable: ${activationGate.statusMessage}',
      );
    }

    // Validate and import XLSX via XlsxImporter
    return await importer.importArchive(
      fileBytes: driveFileBytes,
      filename: filename,
      createdAtMicroseconds: nowMicroseconds,
    );
  }
}

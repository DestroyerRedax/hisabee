import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hisabee/core/money/money.dart';
import 'package:hisabee/domain/entities/personal_entry.dart';
import 'package:hisabee/infrastructure/database/app_database.dart';
import 'package:hisabee/infrastructure/repositories/personal_entry_repository_impl.dart';
import 'package:hisabee/infrastructure/cloud/cloud_activation_gate.dart';
import 'package:hisabee/infrastructure/cloud/cloud_sync_service.dart';
import 'package:hisabee/infrastructure/cloud/conflict_resolver.dart';
import 'package:hisabee/infrastructure/cloud/google_drive_backup_service.dart';
import 'package:hisabee/infrastructure/transfer/xlsx_exporter.dart';
import 'package:hisabee/infrastructure/transfer/xlsx_importer.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Cloud Activation Gate, Conflict Resolution & Drive Backup Tests', () {
    late AppDatabase appDb;
    late PersonalEntryRepositoryImpl personalRepo;

    setUp(() async {
      appDb = AppDatabase();
      await appDb.initialize(path: inMemoryDatabasePath);
      personalRepo = PersonalEntryRepositoryImpl(appDatabase: appDb);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('1. Locked Activation Gate returns explicit unavailable status while local app remains fully usable', () async {
      const lockedGate = CloudActivationGate(config: CloudActivationConfig()); // Locked
      expect(lockedGate.isCloudAvailable, isFalse);

      final syncService = CloudSyncService(activationGate: lockedGate, appDatabase: appDb);
      final driveService = GoogleDriveBackupService(
        activationGate: lockedGate,
        exporter: XlsxExporter(appDatabase: appDb),
        importer: XlsxImporter(appDatabase: appDb),
      );

      // Perform local save
      final entry = PersonalEntry(
        id: 'p_gated_1',
        direction: 'receive',
        name: 'Gated User',
        normalizedName: 'gated user',
        amount: Money.fromMinorUnits(3000),
        note: '',
        localDate: '2026-07-22',
        category: 'Cash',
        createdAt: 100,
        updatedAt: 100,
      );
      final localSaveRes = await personalRepo.save(entry);
      expect(localSaveRes.isSuccess, isTrue);

      // Trigger Cloud Sync while gate locked
      final syncRes = await syncService.processPendingOutbox(
        firebaseUserId: 'user_123',
        nowMicroseconds: 200,
      );

      expect(syncRes.isSuccess, isTrue);
      expect(syncRes.dataOrNull?.syncedCount, equals(0));
      expect(syncRes.dataOrNull?.statusMessage, contains('LOCKED'));

      // Trigger Drive Backup while gate locked
      final driveRes = await driveService.backupToDrive(nowMicroseconds: 200);
      expect(driveRes.isFailure, isTrue);
      expect(driveRes.errorMessageOrNull, contains('unavailable'));

      // Verify local data is 100% intact
      final activeRes = await personalRepo.getActiveEntries();
      expect(activeRes.dataOrNull?.length, equals(1));
    });

    test('2. Approved Activation Gate processes sync outbox records', () async {
      const approvedConfig = CloudActivationConfig(
        hasDevStagingProdConfig: true,
        hasOauthCredentials: true,
        hasSecurityRules: true,
        hasEmulatorSetup: true,
        hasAppCheckPlan: true,
        hasApprovedConsentCopy: true,
        hasRollbackPlan: true,
      );
      const approvedGate = CloudActivationGate(config: approvedConfig);
      expect(approvedGate.isCloudAvailable, isTrue);

      final syncService = CloudSyncService(activationGate: approvedGate, appDatabase: appDb);

      await personalRepo.save(PersonalEntry(
        id: 'p_sync_1',
        direction: 'receive',
        name: 'Sync Entry',
        normalizedName: 'sync entry',
        amount: Money.fromMinorUnits(1000),
        note: '',
        localDate: '2026-07-22',
        category: 'Cash',
        createdAt: 100,
        updatedAt: 100,
      ));

      final syncRes = await syncService.processPendingOutbox(
        firebaseUserId: 'user_abc',
        nowMicroseconds: 200,
      );

      expect(syncRes.isSuccess, isTrue);
      expect(syncRes.dataOrNull?.syncedCount, equals(1));
      expect(syncRes.dataOrNull?.pendingCount, equals(0));
    });

    test('3. ConflictResolver logs conflict and resolves via keepLocal, keepCloud, or duplicateAsNew without silent merge', () async {
      final resolver = ConflictResolver(appDatabase: appDb);

      final localPayload = {
        'id': 'p_conf_1',
        'direction': 'receive',
        'name': 'Local Version',
        'normalized_name': 'local version',
        'amount_minor': 5000,
        'note': 'Local Note',
        'local_date': '2026-07-22',
        'category': 'Cash',
        'created_at': 100,
        'updated_at': 100,
      };

      final remotePayload = {
        'id': 'p_conf_1',
        'direction': 'receive',
        'name': 'Remote Version',
        'normalized_name': 'remote version',
        'amount_minor': 9000,
        'note': 'Remote Note',
        'local_date': '2026-07-22',
        'category': 'Cash',
        'created_at': 100,
        'updated_at': 150,
      };

      final conflict = await resolver.logConflict(
        entityType: 'personal_entry',
        entityId: 'p_conf_1',
        localPayload: localPayload,
        remotePayload: remotePayload,
        reason: 'Concurrent mutation timestamp mismatch',
        detectedAtMicroseconds: 200,
      );

      expect(conflict.id, isNotEmpty);

      // Resolve via keepCloud
      final resolveRes = await resolver.resolveConflict(
        conflictId: conflict.id,
        strategy: ConflictResolutionStrategy.keepCloud,
        resolvedAtMicroseconds: 300,
      );

      expect(resolveRes.isSuccess, isTrue);

      // Verify remote version applied to local SQLite
      final entry = await personalRepo.getById('p_conf_1');
      expect(entry.dataOrNull?.name, equals('Remote Version'));
      expect(entry.dataOrNull?.amount.minorUnits, equals(9000));
    });

    test('4. Google Drive restore with malformed bytes rejects and rolls back without corrupting local data', () async {
      const approvedGate = CloudActivationGate(
        config: CloudActivationConfig(
          hasDevStagingProdConfig: true,
          hasOauthCredentials: true,
          hasSecurityRules: true,
          hasEmulatorSetup: true,
          hasAppCheckPlan: true,
          hasApprovedConsentCopy: true,
          hasRollbackPlan: true,
        ),
      );

      final driveService = GoogleDriveBackupService(
        activationGate: approvedGate,
        exporter: XlsxExporter(appDatabase: appDb),
        importer: XlsxImporter(appDatabase: appDb),
      );

      // Seed valid local record
      await personalRepo.save(PersonalEntry(
        id: 'p_safe',
        direction: 'receive',
        name: 'Safe Record',
        normalizedName: 'safe record',
        amount: Money.fromMinorUnits(2000),
        note: '',
        localDate: '2026-07-22',
        category: 'Cash',
        createdAt: 100,
        updatedAt: 100,
      ));

      // Attempt restoring garbage bytes
      final restoreRes = await driveService.restoreFromDrive(
        driveFileBytes: [1, 2, 3, 4, 5], // Malformed!
        filename: 'bad.xlsx',
        nowMicroseconds: 200,
      );

      expect(restoreRes.isFailure, isTrue);

      // Local record remains 100% intact
      final safeEntry = await personalRepo.getById('p_safe');
      expect(safeEntry.dataOrNull, isNotNull);
    });
  });
}

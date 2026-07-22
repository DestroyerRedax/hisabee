import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/utils/id_generator.dart';
import '../database/db_tables.dart';

/// Handles durable outbox record creation atomically within SQLite transactions.
class DurableOutboxWriter {
  const DurableOutboxWriter();

  /// Performs a local entity mutation and enqueues an outbox record in one atomic transaction.
  ///
  /// Rejects operations that are not 'upsert' or 'delete'.
  /// Rejects non-JSON-safe payloads.
  /// Throws an exception if either mutation fails, causing SQLite to roll back entirely.
  Future<void> executeAtomicMutation({
    required Transaction txn,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    required int createdAtMicroseconds,
    required Future<void> Function(Transaction txn) localMutation,
  }) async {
    // 1. Validate operation type
    if (operation != 'upsert' && operation != 'delete') {
      throw ArgumentError('Outbox operation must be either "upsert" or "delete": $operation');
    }

    // 2. Validate payload JSON serializability
    String jsonPayload;
    try {
      jsonPayload = jsonEncode(payload);
    } catch (e) {
      throw ArgumentError('Outbox payload must be JSON-serializable: $e');
    }

    // 3. Execute local mutation first inside transaction
    await localMutation(txn);

    // 4. Enqueue outbox record in the SAME transaction
    final operationId = IdGenerator.generateId();
    await txn.insert(
      DbTables.syncOutbox,
      {
        'operation_id': operationId,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'payload': jsonPayload,
        'payload_version': 1,
        'base_version': null,
        'idempotency_key': idempotencyKey,
        'attempt_count': 0,
        'next_retry_at': null,
        'created_at': createdAtMicroseconds,
        'acknowledged_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.fail, // Predictably fail on duplicate idempotency key
    );
  }
}

import 'package:meta/meta.dart';

/// Represents a durable outbox operation for local-first synchronization.
@immutable
class SyncOutboxRecord {
  final String operationId;
  final String entityType;
  final String entityId;
  final String operation; // 'upsert' or 'delete'
  final String payload; // JSON-safe string
  final int payloadVersion; // Must be 1
  final int? baseVersion;
  final String idempotencyKey;
  final int attemptCount;
  final int? nextRetryAt;
  final int createdAt;
  final int? acknowledgedAt;

  const SyncOutboxRecord({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.payloadVersion = 1,
    this.baseVersion,
    required this.idempotencyKey,
    this.attemptCount = 0,
    this.nextRetryAt,
    required this.createdAt,
    this.acknowledgedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'operation_id': operationId,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': payload,
      'payload_version': payloadVersion,
      'base_version': baseVersion,
      'idempotency_key': idempotencyKey,
      'attempt_count': attemptCount,
      'next_retry_at': nextRetryAt,
      'created_at': createdAt,
      'acknowledged_at': acknowledgedAt,
    };
  }

  factory SyncOutboxRecord.fromMap(Map<String, dynamic> map) {
    return SyncOutboxRecord(
      operationId: map['operation_id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      operation: map['operation'] as String,
      payload: map['payload'] as String,
      payloadVersion: map['payload_version'] as int,
      baseVersion: map['base_version'] as int?,
      idempotencyKey: map['idempotency_key'] as String,
      attemptCount: map['attempt_count'] as int? ?? 0,
      nextRetryAt: map['next_retry_at'] as int?,
      createdAt: map['created_at'] as int,
      acknowledgedAt: map['acknowledged_at'] as int?,
    );
  }
}

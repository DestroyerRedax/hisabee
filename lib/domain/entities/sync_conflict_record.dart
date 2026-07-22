import 'package:meta/meta.dart';

/// Synchronization Conflict record domain entity (PRD Section 5.6 & 12).
@immutable
class SyncConflictRecord {
  final String id;
  final String entityType;
  final String entityId;
  final String localPayload; // JSON-safe string
  final String remotePayload; // JSON-safe string
  final String reason;
  final int detectedAt;
  final String? resolution; // keepLocal, keepCloud, duplicateAsNew
  final int? resolvedAt;

  const SyncConflictRecord({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.localPayload,
    required this.remotePayload,
    required this.reason,
    required this.detectedAt,
    this.resolution,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'local_payload': localPayload,
      'remote_payload': remotePayload,
      'reason': reason,
      'detected_at': detectedAt,
      'resolution': resolution,
      'resolved_at': resolvedAt,
    };
  }

  factory SyncConflictRecord.fromMap(Map<String, dynamic> map) {
    return SyncConflictRecord(
      id: map['id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      localPayload: map['local_payload'] as String,
      remotePayload: map['remote_payload'] as String,
      reason: map['reason'] as String,
      detectedAt: map['detected_at'] as int,
      resolution: map['resolution'] as String?,
      resolvedAt: map['resolved_at'] as int?,
    );
  }
}

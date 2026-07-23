import 'package:meta/meta.dart';

/// Profile domain entity (PRD Section 5.4).
@immutable
class Profile {
  final String id;
  final String name;
  final String? colorValue;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const Profile({
    required this.id,
    required this.name,
    this.colorValue,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Validates profile properties per PRD Section 5.4.
  static String? validate({required String name}) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 80) {
      return 'Profile name must be between 1 and 80 characters';
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color_value': colorValue,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    if (val is String) {
      return (double.tryParse(val) ?? int.tryParse(val) ?? 0).toInt();
    }
    return 0;
  }

  static int? _parseNullableInt(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt();
    if (val is String) {
      final s = val.trim();
      if (s.isEmpty || s == 'null' || s == 'NULL') return null;
      return (double.tryParse(s) ?? int.tryParse(s))?.toInt();
    }
    return null;
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      colorValue: map['color_value']?.toString(),
      createdAt: _parseInt(map['created_at']),
      updatedAt: _parseInt(map['updated_at']),
      deletedAt: _parseNullableInt(map['deleted_at']),
    );
  }
}

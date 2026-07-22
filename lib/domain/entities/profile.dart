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

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: map['color_value'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
    );
  }
}

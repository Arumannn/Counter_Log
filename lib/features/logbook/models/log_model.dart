import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'log_model.g.dart';

// ========== Enum & Maps untuk Kategori ==========

@HiveType(typeId: 1)
enum LogCategory {
  @HiveField(0)
  academic,
  @HiveField(1)
  saving,
  @HiveField(2)
  personal,
  @HiveField(3)
  other,
}

final Map<LogCategory, IconData> categoryIcons = {
  LogCategory.academic: Icons.precision_manufacturing,
  LogCategory.saving: Icons.memory,
  LogCategory.personal: Icons.code,
  LogCategory.other: Icons.category,
};

final Map<LogCategory, String> categoryLabels = {
  LogCategory.academic: "Mechanical",
  LogCategory.saving: "Electronic",
  LogCategory.personal: "Software",
  LogCategory.other: "Other",
};

/// Warna utama (foreground / icon) tiap kategori
final Map<LogCategory, Color> categoryColors = {
  LogCategory.academic: const Color(0xFF2E7D32),
  LogCategory.saving: const Color(0xFF1565C0),
  LogCategory.personal: const Color(0xFF6A1B9A),
  LogCategory.other: const Color(0xFF8B7D6B),
};

/// Warna latar belakang chip tiap kategori
final Map<LogCategory, Color> categoryBgColors = {
  LogCategory.academic: const Color(0xFFE8F5E9),
  LogCategory.saving: const Color(0xFFE3F2FD),
  LogCategory.personal: const Color(0xFFF3E5F5),
  LogCategory.other: const Color(0xFFF5EFE8),
};

// ========== Model ==========

@HiveType(typeId: 0)
class LogModel {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String date;

  @HiveField(4)
  final String authorId; // BARU

  @HiveField(5)
  final String teamId; // BARU

  @HiveField(6)
  final LogCategory category; // Simpan sebagai String untuk Hive

  @HiveField(7)
  final bool isSynced; // true jika sudah tersimpan/sinkron ke database

  @HiveField(8)
  final bool isPublic; // default private, true jika dibagikan ke tim

  LogModel({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.authorId,
    required this.teamId,
    this.category = LogCategory.other,
    this.isSynced = true,
    this.isPublic = false,
  });

  LogModel copyWith({
    String? id,
    String? title,
    String? description,
    String? date,
    String? authorId,
    String? teamId,
    LogCategory? category,
    bool? isSynced,
    bool? isPublic,
  }) {
    return LogModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      authorId: authorId ?? this.authorId,
      teamId: teamId ?? this.teamId,
      category: category ?? this.category,
      isSynced: isSynced ?? this.isSynced,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  // Helper: konversi String ke LogCategory enum
  static LogCategory _parseCategory(dynamic value) {
    if (value is LogCategory) return value;
    if (value is String) {
      return LogCategory.values.firstWhere(
        (e) => e.name == value,
        orElse: () => LogCategory.other,
      );
    }
    return LogCategory.other;
  }

  Map<String, dynamic> toMap() => {
        '_id': id != null ? ObjectId.fromHexString(id!) : ObjectId(),
        'title': title,
        'description': description,
        'date': date,
        'authorId': authorId,
        'teamId': teamId,
        'category': category.name,
        'isPublic': isPublic,
      };

  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      id: (map['_id'] as ObjectId?)?.oid,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] ?? '',
      authorId: map['authorId'] ?? 'unknown_user',
      teamId: map['teamId'] ?? 'no_team',
      category: _parseCategory(map['category']),
      // Data dari cloud dianggap sudah sinkron
      isSynced: true,
      isPublic: map['isPublic'] == true,
    );
  }
}

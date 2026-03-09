import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'log_model.g.dart';

// ========== Enum & Maps untuk Kategori ==========

enum LogCategory { academic, saving, personal, other }

final Map<LogCategory, IconData> categoryIcons = {
  LogCategory.academic: Icons.school,
  LogCategory.saving: Icons.savings,
  LogCategory.personal: Icons.person,
  LogCategory.other: Icons.category,
};

final Map<LogCategory, String> categoryLabels = {
  LogCategory.academic: "Academic",
  LogCategory.saving: "Saving",
  LogCategory.personal: "Personal",
  LogCategory.other: "Other",
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

  LogModel({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.authorId,
    required this.teamId,
    this.category = LogCategory.other,
  });

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
    );
  }
}

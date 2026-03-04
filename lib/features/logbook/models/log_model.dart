import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart';

class Logbook {
  final ObjectId? id; // Penanda unik global dari MongoDB
  final String title;
  final String description;
  final DateTime date;

  Logbook({
    this.id,
    required this.title,
    required this.description,
    required this.date,
  });

  // [CONVERT] Memasukkan data ke "Kardus" (BSON/Map) untuk dikirim ke Cloud
  Map<String, dynamic> toMap() {
    return {
      '_id': id ?? ObjectId(), // Buat ID otomatis jika belum ada
      'title': title,
      'description': description,
      'date': date.toIso8601String(), // Simpan tanggal dalam format standar
    };
  }

  // [REVERT] Membongkar "Kardus" (BSON/Map) kembali menjadi objek Flutter
  factory Logbook.fromMap(Map<String, dynamic> map) {
    return Logbook(
      id: map['_id'] as ObjectId?,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
    );
  }
}

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

class LogModel {
  final ObjectId? id;
  final String title;
  final String date;
  final String description;
  final LogCategory category;
  final String owner; // Pemilik catatan (username)

  LogModel({
    this.id,
    required this.title,
    required this.date,
    required this.description,
    this.category = LogCategory.other,
    this.owner = '',
  });

  // Helper: konversi String dari MongoDB ke LogCategory enum
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

  // Untuk Tugas HOTS: Konversi Map (JSON/BSON) ke Object
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      id: map['_id'] as ObjectId?,
      title: map['title'] ?? '',
      date: map['date'] ?? '',
      description: map['description'] ?? '',
      category: _parseCategory(map['category']),
      owner: map['owner'] ?? '',
    );
  }

  // Konversi Object ke Map (JSON) untuk disimpan
  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'title': title,
      'date': date,
      'description': description,
      'category': category.name,
      'owner': owner,
    };
  }
}

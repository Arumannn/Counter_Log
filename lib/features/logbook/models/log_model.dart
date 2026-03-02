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

  LogModel({
    this.id,
    required this.title,
    required this.date,
    required this.description,
    required this.category,
  });

  // Untuk Tugas HOTS: Konversi Map (JSON) ke Object
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      id : map['id'],
      title: map['title'],
      date: map['date'],
      description: map['description'],
      category: map['category'],
    );
  }

  // Konversi Object ke Map (JSON) untuk disimpan
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': date,
      'description': description,
      'category': category,
    };
  }
}

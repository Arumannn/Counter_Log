import 'package:flutter/material.dart';
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
  final String title;
  final String date;
  final String description;
  final LogCategory category;

  LogModel({
    required this.title,
    required this.date,
    required this.description,
    required this.category,
  });

  // Untuk Tugas HOTS: Konversi Map (JSON) ke Object
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      title: map['title'],
      date: map['date'],
      description: map['description'],
      category: map['category']
    );
  }

  // Konversi Object ke Map (JSON) untuk disimpan
  Map<String, dynamic> toMap() {
    return {'title': title, 'date': date, 'description': description, 'category':category};
  }

  
}

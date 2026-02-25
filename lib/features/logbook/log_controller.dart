import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/log_model.dart';

class LogController {
  final ValueNotifier<List<LogModel>> logsNotifier = ValueNotifier([]);
  ValueNotifier<List<LogModel>> filteredLogs = ValueNotifier([]);
  static const String _storageKey = 'user_logs_data';

  LogController() {
    loadFromDisk();
  }

  void searchLog(String query) {
    if (query.isEmpty) {
      filteredLogs.value = List.from(logsNotifier.value);
    } else {
      filteredLogs.value = logsNotifier.value
          .where((log) => log.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  void addLog(String title, String desc) {
    final newLog = LogModel(
      title: title,
      description: desc,
      date: DateTime.now().toString(),
    );
    logsNotifier.value = [...logsNotifier.value, newLog];
    filteredLogs.value = List.from(logsNotifier.value);
    saveToDisk();
  }

  void updateLog(int index, String title, String desc) {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    currentLogs[index] = LogModel(
      title: title,
      description: desc,
      date: DateTime.now().toString(),
    );
    logsNotifier.value = currentLogs;
    filteredLogs.value = List.from(logsNotifier.value);
    saveToDisk();
  }

  void removeLog(int index) {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    currentLogs.removeAt(index);
    logsNotifier.value = currentLogs;
    filteredLogs.value = List.from(logsNotifier.value);

    saveToDisk();
  }

  Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      logsNotifier.value.map((e) => e.toMap()).toList(),
    );
    await prefs.setString(_storageKey, encodedData);
  }

  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data != null) {
      final List decoded = jsonDecode(data);
      logsNotifier.value = decoded.map((e) => LogModel.fromMap(e)).toList();
      filteredLogs.value = List.from(logsNotifier.value);
    }
  }

  Future<void> loadLogs() async {
  final prefs = await SharedPreferences.getInstance();
  String? rawJson = prefs.getString('saved_logs');
  
  if (rawJson != null) {
    // 1. Decode String ke List<Map>
    Iterable decoded = jsonDecode(rawJson);
    
    // 2. Map kembali ke List<LogModel>
    logsNotifier.value = decoded.map((item) => LogModel.fromMap(item)).toList();
  }
}

}

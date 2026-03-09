import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/services/mongo_service.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';
import 'package:logbook_app_001/services/access_policy.dart';

class LogController {
  final ValueNotifier<List<LogModel>> logsNotifier =
      ValueNotifier<List<LogModel>>([]);
  ValueNotifier<List<LogModel>> filteredLogs = ValueNotifier<List<LogModel>>(
    [],
  );

  // Username pemilik data (untuk per-account storage)
  final String username;
  final String teamId;

  // Current user model untuk access control
  late Map<String, dynamic> currentUser;

  // Hive Box untuk penyimpanan lokal yang sangat cepat
  late Box<LogModel> _myBox;

  // Getter untuk mempermudah akses list data saat ini
  List<LogModel> get logs => logsNotifier.value;

  // --- KONSTRUKTOR ---
  // Menerima username dan teamId agar setiap akun/team punya cache sendiri
  LogController({required this.username, required this.teamId}) {
    // Initialize current user
    currentUser = {
      'id': username,
      'role': 'Anggota', // Default role, dapat diubah sesuai kebutuhan
    };
    // Buka Hive Box untuk user dan team ini
    _initHiveBox();
  }

  // Initialize Hive Box
  Future<void> _initHiveBox() async {
    final boxName = 'logs_${username}_$teamId';
    _myBox = await Hive.openBox<LogModel>(boxName);
    // Load data dari Hive ke UI
    logsNotifier.value = _myBox.values.toList();
    filteredLogs.value = List.from(logsNotifier.value);
  }

  // Fitur pencarian berdasarkan judul
  void searchLog(String query) {
    if (query.isEmpty) {
      filteredLogs.value = List.from(logsNotifier.value);
    } else {
      filteredLogs.value = logsNotifier.value
          .where((log) => log.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  /// LOAD DATA (Offline-First Strategy)
  Future<void> fetchLogs() async {
    // Langkah 1: Ambil data dari Hive (Sangat Cepat/Instan)
    logsNotifier.value = _myBox.values.toList();
    filteredLogs.value = List.from(logsNotifier.value);

    // Langkah 2: Sync dari Cloud (Background)
    try {
      final cloudData = await MongoService().getLogs(teamId: teamId);

      // Update Hive dengan data terbaru dari Cloud agar sinkron
      await _myBox.clear();
      await _myBox.addAll(cloudData);

      // Update UI dengan data Cloud
      logsNotifier.value = cloudData;
      filteredLogs.value = List.from(cloudData);

      await LogHelper.writeLog(
        "SYNC: Data berhasil diperbarui dari Atlas",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "OFFLINE: Menggunakan data cache lokal - $e",
        source: "log_controller.dart",
        level: 2,
      );
    }
  }

  /// ADD DATA (Instant Local + Background Cloud)
  Future<void> addLog(String title, String desc, LogCategory category) async {
    final newLog = LogModel(
      id: ObjectId().oid, // Generate ObjectId untuk MongoDB
      title: title,
      description: desc,
      date: DateTime.now().toString(),
      category: category,
      authorId: username,
      teamId: teamId,
    );

    // ACTION 1: Simpan ke Hive (Instan)
    await _myBox.add(newLog);
    logsNotifier.value = [...logsNotifier.value, newLog];
    filteredLogs.value = List.from(logsNotifier.value);

    // ACTION 2: Kirim ke MongoDB Atlas (Background)
    try {
      await MongoService().insertLog(newLog);
      await LogHelper.writeLog(
        "SUCCESS: Data tersinkron ke Cloud",
        source: "log_controller.dart",
      );
    } catch (e) {
      await LogHelper.writeLog(
        "WARNING: Data tersimpan lokal, akan sinkron saat online - $e",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  /// UPDATE DATA (Instant Local + Background Cloud)
  Future<void> updateLog(
    int index,
    String newTitle,
    String newDesc,
    LogCategory category,
  ) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final oldLog = currentLogs[index];

    final updatedLog = LogModel(
      id: oldLog.id, // ID harus tetap sama agar MongoDB mengenali dokumen ini
      title: newTitle,
      description: newDesc,
      date: DateTime.now().toString(),
      category: category,
      authorId: username,
      teamId: teamId,
    );

    // ACTION 1: Update di Hive (Instan)
    await _myBox.putAt(index, updatedLog);
    logsNotifier.value = _myBox.values.toList();
    filteredLogs.value = List.from(logsNotifier.value);

    // ACTION 2: Update di MongoDB Atlas (Background)
    try {
      await MongoService().updateLog(updatedLog);
      await LogHelper.writeLog(
        "SUCCESS: Update '${oldLog.title}' tersinkron ke Cloud",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "WARNING: Update tersimpan lokal, akan sinkron saat online - $e",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  /// DELETE DATA (Instant Local + Background Cloud)
  Future<void> removeLog(
    int index, {
    required String userRole,
    required String userId,
  }) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final targetLog = currentLogs[index];

    // Tambahkan validasi keamanan sebelum melakukan penghapusan
    if (!AccessControlService.canPerform(
      userRole,
      AccessControlService.actionDelete,
      isOwner: targetLog.authorId == userId,
    )) {
      await LogHelper.writeLog(
        "SECURITY BREACH: Unauthorized delete attempt by $userId",
        source: "log_controller.dart",
        level: 1,
      );
      return;
    }

    if (targetLog.id == null) {
      await LogHelper.writeLog(
        "ERROR: ID Log tidak ditemukan",
        source: "log_controller.dart",
        level: 1,
      );
      return;
    }

    // ACTION 1: Hapus dari Hive (Instan)
    await _myBox.deleteAt(index);
    logsNotifier.value = _myBox.values.toList();
    filteredLogs.value = List.from(logsNotifier.value);

    // ACTION 2: Hapus dari MongoDB Atlas (Background)
    try {
      await MongoService().deleteLog(targetLog.id!);
      await LogHelper.writeLog(
        "SUCCESS: Hapus '${targetLog.title}' tersinkron ke Cloud",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "WARNING: Hapus lokal sukses, akan sinkron ke Cloud saat online - $e",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  /// SYNC FROM CLOUD (Offline-First Strategy)
  Future<void> loadFromDisk() async {
    // Langkah 1: Load dari Hive terlebih dahulu (Instant)
    logsNotifier.value = _myBox.values.toList();
    filteredLogs.value = List.from(logsNotifier.value);

    // Langkah 2: Sinkronisasi dari Cloud (Background)
    try {
      final cloudData = await MongoService().getLogs(teamId: teamId);

      // Update Hive dengan data terbaru dari Cloud
      await _myBox.clear();
      await _myBox.addAll(cloudData);

      // Update UI
      logsNotifier.value = cloudData;
      filteredLogs.value = List.from(cloudData);

      await LogHelper.writeLog(
        "SUCCESS: Data dari Cloud berhasil dimuat untuk team '$teamId'",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "OFFLINE: Menggunakan cache lokal - $e",
        source: "log_controller.dart",
        level: 1,
      );
      // Data tetap menampilkan cache lokal jika cloud gagal
    }
  }
}

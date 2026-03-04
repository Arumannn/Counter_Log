import 'dart:convert'; // Wajib ditambahkan untuk jsonEncode & jsonDecode
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/services/mongo_service.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';

class LogController {
  final ValueNotifier<List<LogModel>> logsNotifier =
      ValueNotifier<List<LogModel>>([]);
  ValueNotifier<List<LogModel>> filteredLogs = ValueNotifier<List<LogModel>>(
    [],
  );

  // Username pemilik data (untuk per-account storage)
  final String username;

  // Kunci unik per akun untuk penyimpanan lokal di Shared Preferences
  late final String _storageKey;

  // Getter untuk mempermudah akses list data saat ini
  List<LogModel> get logs => logsNotifier.value;

  // --- KONSTRUKTOR ---
  // Menerima username agar setiap akun punya cookie/cache sendiri
  LogController({required this.username}) {
    _storageKey = 'user_logs_data_$username';
    // Saat Controller dibuat, coba muat data cache lokal dulu (cepat & offline)
    _loadLocalCache();
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

  Future<void> fetchLogs() async {
    var dataFromCloud = await MongoService().getLogs(owner: username);
    logsNotifier.value = dataFromCloud;
    filteredLogs.value = List.from(dataFromCloud);
  }

  // 1. Menambah data ke Cloud
  Future<void> addLog(String title, String desc, LogCategory category) async {
    final newLog = LogModel(
      id: ObjectId(),
      title: title,
      description: desc,
      date: DateTime.now().toString(),
      category: category,
      owner: username, // Tandai pemilik catatan
    );

    try {
      // 2. Kirim ke MongoDB Atlas
      await MongoService().insertLog(newLog);

      // 3. Update UI Lokal (Data sekarang sudah punya ID asli)
      final currentLogs = List<LogModel>.from(logsNotifier.value);
      currentLogs.add(newLog);
      logsNotifier.value = currentLogs;
      filteredLogs.value = List.from(currentLogs);

      // Simpan cache lokal per akun
      await saveToDisk();

      await LogHelper.writeLog(
        "SUCCESS: Tambah data dengan ID lokal",
        source: "log_controller.dart",
      );
    } catch (e) {
      await LogHelper.writeLog("ERROR: Gagal sinkronisasi Add - $e", level: 1);
    }
  }

  // 2. Memperbarui data di Cloud (HOTS: Sinkronisasi Terjamin)
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
      owner: username, // Tetap tandai pemilik
    );

    try {
      // 1. Jalankan update di MongoService (Tunggu konfirmasi Cloud)
      await MongoService().updateLog(updatedLog);

      // 2. Jika sukses, baru perbarui state lokal
      currentLogs[index] = updatedLog;
      logsNotifier.value = currentLogs;
      filteredLogs.value = List.from(currentLogs);

      // Simpan cache lokal per akun
      await saveToDisk();

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Update '${oldLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Gagal sinkronisasi Update - $e",
        source: "log_controller.dart",
        level: 1,
      );
      // Data di UI tidak berubah jika proses di Cloud gagal
    }
  }

  // 3. Menghapus data dari Cloud (HOTS: Sinkronisasi Terjamin)
  Future<void> removeLog(int index) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final targetLog = currentLogs[index];

    try {
      if (targetLog.id == null) {
        throw Exception(
          "ID Log tidak ditemukan, tidak bisa menghapus di Cloud.",
        );
      }

      // 1. Hapus data di MongoDB Atlas (Tunggu konfirmasi Cloud)
      await MongoService().deleteLog(targetLog.id!);

      // 2. Jika sukses, baru hapus dari state lokal
      currentLogs.removeAt(index);
      logsNotifier.value = currentLogs;
      filteredLogs.value = List.from(currentLogs);

      // Simpan cache lokal per akun
      await saveToDisk();

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Hapus '${targetLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Gagal sinkronisasi Hapus - $e",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  // --- FUNGSI PERSISTENCE (PER-AKUN) ---

  // Simpan seluruh List ke penyimpanan lokal (per akun)
  Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    // Mengubah List of Object -> List of Map -> String JSON
    final String encodedData = jsonEncode(
      logsNotifier.value.map((log) => log.toMap()).toList(),
    );
    await prefs.setString(_storageKey, encodedData);
    await LogHelper.writeLog(
      "CACHE: Data disimpan lokal untuk akun '$username'",
      source: "log_controller.dart",
      level: 3,
    );
  }

  // Muat data dari cache lokal (cepat, untuk tampilan awal)
  Future<void> _loadLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data != null) {
      final List decoded = jsonDecode(data);
      logsNotifier.value = decoded.map((e) => LogModel.fromMap(e)).toList();
      filteredLogs.value = List.from(logsNotifier.value);
      await LogHelper.writeLog(
        "CACHE: Data lokal akun '$username' berhasil dimuat",
        source: "log_controller.dart",
        level: 3,
      );
    }
  }

  // Sinkronisasi dari Cloud lalu simpan ke cache lokal
  Future<void> loadFromDisk() async {
    // Mengambil dari Cloud (hanya data milik akun ini)
    final cloudData = await MongoService().getLogs(owner: username);
    logsNotifier.value = cloudData;
    filteredLogs.value = List.from(cloudData);

    // Simpan hasil cloud ke cache lokal per akun
    await saveToDisk();
  }
}

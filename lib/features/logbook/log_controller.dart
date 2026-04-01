import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/services/mongo_service.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';
import 'package:logbook_app_001/services/access_policy.dart';

// MODUL 3 - LogController untuk mengelola data logbook dengan strategi Offline-First.
// MODUL 4 - Save Data to Cloud Service: sinkronisasi data ke MongoDB Atlas.
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

  Future<void> _replaceLogInLocal(LogModel updatedLog) async {
    final idx = _myBox.values.toList().indexWhere((l) => l.id == updatedLog.id);
    if (idx != -1) {
      await _myBox.putAt(idx, updatedLog);
      logsNotifier.value = _myBox.values.toList();
      filteredLogs.value = List.from(logsNotifier.value);
    }
  }

  /// Mencoba mendorong seluruh data lokal yang belum sinkron ke cloud.
  Future<void> syncPendingLocalLogs() async {
    final pending = _myBox.values
        .where((log) => !log.isSynced && log.teamId == teamId)
        .toList();

    if (pending.isEmpty) return;

    for (final log in pending) {
      try {
        // Coba insert dahulu (untuk data baru). Jika sudah ada, fallback update.
        try {
          await MongoService().insertLog(log);
        } catch (_) {
          await MongoService().updateLog(log);
        }

        await _replaceLogInLocal(log.copyWith(isSynced: true));
      } catch (e) {
        await LogHelper.writeLog(
          "WARNING: Sync pending log gagal (${log.id}) - $e",
          source: "log_controller.dart",
          level: 1,
        );
      }
    }
  }

  // --- KONSTRUKTOR ---
  LogController({
    required this.username,
    required this.teamId,
    String role = 'Anggota',
  }) {
    currentUser = {
      'id': username,
      'username': username,
      'role': role,
      'teamId': teamId,
    };
  }

  // HARUS DIPANGGIL DI initState() setelah constructor
  Future<void> initAsync() async {
    final boxName = 'logs_team_$teamId';
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
      final q = query.toLowerCase();
      filteredLogs.value = logsNotifier.value
          .where(
            (log) =>
                log.title.toLowerCase().contains(q) ||
                log.description.toLowerCase().contains(q),
          )
          .toList();
    }
  }

  /// 1. LOAD DATA (Offline-First Strategy)
  Future<void> loadLogs(String teamId) async {
    // Langkah 1: Ambil data dari Hive (Sangat Cepat/Instan)
    logsNotifier.value = _myBox.values.toList();
    filteredLogs.value = List.from(logsNotifier.value);

    // Langkah 2: Sync dari Cloud (Background)
    try {
      // Jika ada data lokal pending, dorong dulu saat internet tersedia.
      await syncPendingLocalLogs();

      final cloudData = await MongoService().getLogs(teamId);

      // Pertahankan draft lokal yang belum sempat sinkron.
      final pendingLocal = _myBox.values
          .where((log) => !log.isSynced && log.teamId == teamId)
          .toList();

      final merged = List<LogModel>.from(cloudData);
      for (final local in pendingLocal) {
        final idx = merged.indexWhere((c) => c.id == local.id);
        if (idx == -1) {
          merged.add(local);
        } else {
          merged[idx] = local;
        }
      }

      // Update Hive dengan data terbaru dari Cloud agar sinkron
      await _myBox.clear();
      await _myBox.addAll(merged);

      // Update UI dengan data Cloud
      logsNotifier.value = merged;
      filteredLogs.value = List.from(merged);

      await LogHelper.writeLog(
        "SYNC: Data berhasil diperbarui dari Atlas",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "OFFLINE: Menggunakan data cache lokal",
        level: 2,
      );
    }
  }

  /// 2. ADD DATA (Instant Local + Background Cloud)
  Future<void> addLog(
    String title,
    String desc,
    String authorId,
    String teamId, {
    LogCategory category = LogCategory.other,
    bool isPublic = false,
  }) async {
    if (!AccessPolicy.isSameTeam(this.teamId, teamId)) {
      await LogHelper.writeLog(
        "SECURITY BREACH: Cross-team create blocked for $username",
        source: "log_controller.dart",
        level: 1,
      );
      return;
    }

    final newLog = LogModel(
      id: ObjectId().oid, // Menggunakan .oid (String) untuk Hive
      title: title,
      description: desc,
      date: DateTime.now().toString(),
      authorId: authorId,
      teamId: teamId,
      category: category,
      isSynced: false,
      isPublic: isPublic,
    );

    // ACTION 1: Simpan ke Hive (Instan)
    await _myBox.add(newLog);
    logsNotifier.value = [...logsNotifier.value, newLog];
    filteredLogs.value = List.from(logsNotifier.value);

    // ACTION 2: Kirim ke MongoDB Atlas (Background)
    try {
      await MongoService().insertLog(newLog);
      await _replaceLogInLocal(newLog.copyWith(isSynced: true));
      await LogHelper.writeLog(
        "SUCCESS: Data tersinkron ke Cloud",
        source: "log_controller.dart",
      );
    } catch (e) {
      await LogHelper.writeLog(
        "WARNING: Data tersimpan lokal, akan sinkron saat online",
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
    bool isPublic,
  ) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final oldLog = currentLogs[index];

    if (!AccessPolicy.canModifyLog(
      currentUserId: (currentUser['id'] ?? '').toString(),
      logAuthorId: oldLog.authorId,
    )) {
      await LogHelper.writeLog(
        "SECURITY BREACH: Owner-only update blocked for $username",
        source: "log_controller.dart",
        level: 1,
      );
      return;
    }

    final updatedLog = LogModel(
      id: oldLog.id, // ID harus tetap sama agar MongoDB mengenali dokumen ini
      title: newTitle,
      description: newDesc,
      date: DateTime.now().toString(),
      category: category,
      authorId: oldLog.authorId,
      teamId: oldLog.teamId,
      isSynced: false,
      isPublic: isPublic,
    );

    // ACTION 1: Update di Hive (Instan)
    await _myBox.putAt(index, updatedLog);
    logsNotifier.value = _myBox.values.toList();
    filteredLogs.value = List.from(logsNotifier.value);

    // ACTION 2: Update di MongoDB Atlas (Background)
    try {
      await MongoService().updateLog(updatedLog);
      await _replaceLogInLocal(updatedLog.copyWith(isSynced: true));
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
  Future<void> removeLog(int index) async {
    final targetLog = logsNotifier.value[index];
    final userId = (currentUser['id'] ?? '').toString();

    if (!AccessPolicy.isSameTeam(teamId, targetLog.teamId)) {
      await LogHelper.writeLog(
        "SECURITY BREACH: Cross-team delete blocked for $userId",
        source: "log_controller.dart",
        level: 1,
      );
      return;
    }

    // Owner-only delete policy
    if (!AccessPolicy.canModifyLog(
      currentUserId: userId,
      logAuthorId: targetLog.authorId,
    )) {
      await LogHelper.writeLog(
        "SECURITY BREACH: Owner-only delete blocked for $userId",
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
}

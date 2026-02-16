import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class HistoryService {
  // Singleton pattern
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  SharedPreferences? _prefs;

  // Initialize SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ==================== COUNTER VALUE ====================

  // Simpan counter terakhir untuk user tertentu
  Future<void> saveCounter(String username, int counter) async {
    await _prefs?.setInt('counter_$username', counter);
  }

  // Ambil counter terakhir untuk user tertentu
  int getCounter(String username) {
    return _prefs?.getInt('counter_$username') ?? 0;
  }

  // ==================== STEP VALUE ====================

  // Simpan step terakhir untuk user tertentu
  Future<void> saveStep(String username, int step) async {
    await _prefs?.setInt('step_$username', step);
  }

  // Ambil step terakhir untuk user tertentu
  int getStep(String username) {
    return _prefs?.getInt('step_$username') ?? 1;
  }

  // ==================== HISTORY LIST ====================

  // Simpan history list untuk user tertentu
  Future<void> saveHistory(String username, List<String> history) async {
    await _prefs?.setStringList('history_$username', history);
  }

  // Ambil history list untuk user tertentu
  List<String> getHistory(String username) {
    return _prefs?.getStringList('history_$username') ?? [];
  }

  // Tambah satu item history
  Future<void> addHistoryItem(String username, String item) async {
    List<String> history = getHistory(username);
    history.add(item);
    await saveHistory(username, history);
  }

  // Clear history untuk user tertentu
  Future<void> clearHistory(String username) async {
    await _prefs?.remove('history_$username');
  }

  // ==================== LAST LOGIN TIME ====================

  // Simpan waktu login terakhir
  Future<void> saveLastLogin(String username) async {
    final now = DateTime.now().toIso8601String();
    await _prefs?.setString('lastLogin_$username', now);
  }

  // Ambil waktu login terakhir
  String? getLastLogin(String username) {
    return _prefs?.getString('lastLogin_$username');
  }

  // ==================== ACTIVITY LOG ====================

  // Simpan activity log (semua aktivitas user)
  Future<void> addActivityLog(String username, String activity) async {
    List<String> logs = getActivityLogs(username);
    final timestamp = DateTime.now().toIso8601String();
    logs.add('[$timestamp] $activity');
    await _prefs?.setStringList('activityLog_$username', logs);
  }

  // Ambil semua activity logs
  List<String> getActivityLogs(String username) {
    return _prefs?.getStringList('activityLog_$username') ?? [];
  }

  // Clear activity logs
  Future<void> clearActivityLogs(String username) async {
    await _prefs?.remove('activityLog_$username');
  }

  // ==================== EXPORT TO FILE (.txt) ====================

  // Export history ke file .txt
  Future<String> exportHistoryToFile(String username) async {
    try {
      // Dapatkan direktori dokumen
      final directory = await getApplicationDocumentsDirectory();
      
      // Buat nama file dengan timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'history_${username}_$timestamp.txt';
      final filePath = '${directory.path}/$fileName';
      
      // Siapkan konten file
      final StringBuffer content = StringBuffer();
      content.writeln('========================================');
      content.writeln('HISTORY LOG - USER: $username');
      content.writeln('Exported: ${DateTime.now()}');
      content.writeln('========================================\n');
      
      // Info counter terakhir
      final lastCounter = getCounter(username);
      final lastStep = getStep(username);
      content.writeln('Counter Terakhir: $lastCounter');
      content.writeln('Step Terakhir: $lastStep\n');
      
      // Login terakhir
      final lastLogin = getLastLogin(username);
      if (lastLogin != null) {
        content.writeln('Login Terakhir: $lastLogin\n');
      }
      
      // History counter
      content.writeln('--- HISTORY COUNTER ---');
      final history = getHistory(username);
      if (history.isEmpty) {
        content.writeln('(Tidak ada history)');
      } else {
        for (var item in history) {
          content.writeln(item);
        }
      }
      
      content.writeln('\n--- ACTIVITY LOG ---');
      final activityLogs = getActivityLogs(username);
      if (activityLogs.isEmpty) {
        content.writeln('(Tidak ada activity log)');
      } else {
        for (var log in activityLogs) {
          content.writeln(log);
        }
      }
      
      content.writeln('\n========================================');
      content.writeln('END OF FILE');
      content.writeln('========================================');
      
      // Tulis ke file
      final file = File(filePath);
      await file.writeAsString(content.toString());
      
      return filePath;
    } catch (e) {
      throw Exception('Gagal export file: $e');
    }
  }

  // ==================== GET ALL USER DATA (Summary) ====================

  // Dapatkan semua data user dalam bentuk Map
  Map<String, dynamic> getUserSummary(String username) {
    return {
      'username': username,
      'counter': getCounter(username),
      'step': getStep(username),
      'lastLogin': getLastLogin(username),
      'historyCount': getHistory(username).length,
      'activityLogCount': getActivityLogs(username).length,
    };
  }

  // ==================== CLEAR ALL USER DATA ====================

  // Hapus semua data user
  Future<void> clearAllUserData(String username) async {
    await _prefs?.remove('counter_$username');
    await _prefs?.remove('step_$username');
    await _prefs?.remove('history_$username');
    await _prefs?.remove('lastLogin_$username');
    await _prefs?.remove('activityLog_$username');
  }
}

import 'dart:developer' as dev;
import 'package:intl/intl.dart'; // Tetap kita gunakan untuk presisi waktu
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LogHelper {
  static Future<void> writeLog(
    String message, {
    String source = "Unknown", // Menandakan file/proses asal
    int level = 2,
  }) async {
    // 1. Filter Konfigurasi (ENV)
    final int configLevel = int.tryParse(dotenv.env['LOG_LEVEL'] ?? '2') ?? 2;
    final String muteList = dotenv.env['LOG_MUTE'] ?? '';

    if (level > configLevel) return;
    if (muteList.split(',').contains(source)) return;

    try {
      // 2. Format Waktu untuk Konsol
      String timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      String label = _getLabel(level);
      String color = _getColor(level);

      // 3. Output ke VS Code Debug Console (Non-blocking)
      dev.log(message, name: source, time: DateTime.now(), level: level * 100);

      // 4. Output ke Terminal (Agar Bapak bisa lihat di PC saat flutter run)
      // Format: [14:30:05] [INFO] [log_view.dart] -> Database Terhubung
      print('$color[$timestamp][$label][$source] -> $message\x1B[0m');
    } catch (e) {
      dev.log("Logging failed: $e", name: "SYSTEM", level: 1000);
    }
  }

  static String _getLabel(int level) {
    switch (level) {
      case 1:
        return "ERROR";
      case 2:
        return "INFO";
      case 3:
        return "VERBOSE";
      default:
        return "LOG";
    }
  }

  static String _getColor(int level) {
    switch (level) {
      case 1:
        return '\x1B[31m'; // Merah
      case 2:
        return '\x1B[32m'; // Hijau
      case 3:
        return '\x1B[34m'; // Biru
      default:
        return '\x1B[0m';
    }
  }

  // === TIMESTAMP FORMATTING (Bahasa Indonesia) ===

  /// Format waktu relatif: "Baru saja", "2 Menit yang lalu", "25 Januari 2026"
  static String formatRelative(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      final DateTime now = DateTime.now();
      final Duration diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} Menit yang lalu';
      if (diff.inHours < 24) return '${diff.inHours} Jam yang lalu';
      if (diff.inDays == 1) return 'Kemarin, ${DateFormat('HH:mm').format(date)}';
      if (diff.inDays < 7) return '${diff.inDays} Hari yang lalu';

      return _formatFullDate(date);
    } catch (e) {
      return dateString.length >= 16 ? dateString.substring(0, 16) : dateString;
    }
  }

  /// Format tanggal lengkap: "25 Januari 2026"
  static String _formatFullDate(DateTime date) {
    const List<String> bulanIndonesia = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final String bulan = bulanIndonesia[date.month - 1];
    return '${date.day} $bulan ${date.year}';
  }

  /// Format tanggal + waktu: "25 Januari 2026, 14:30"
  static String formatFull(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      final String tanggal = _formatFullDate(date);
      final String waktu = DateFormat('HH:mm').format(date);
      return '$tanggal, $waktu';
    } catch (e) {
      return dateString.length >= 16 ? dateString.substring(0, 16) : dateString;
    }
  }
}

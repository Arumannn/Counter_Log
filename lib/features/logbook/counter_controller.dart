import 'history_service.dart';

class CounterController {
  int _counter = 0; // Variabel private (Enkapsulasi)
  int _step = 1; // Langkah increment/decrement (default: 1)
  final List<String> _history = [];

  // Service untuk menyimpan data ke SharedPreferences
  final HistoryService _historyService = HistoryService();
  String? _currentUsername;

  int get value => _counter; // Getter untuk akses data
  int get step => _step; // Getter untuk step
  List<String> get history => _history;
  String? get currentUsername => _currentUsername;

  // Initialize controller dengan data dari SharedPreferences
  Future<void> init(String username) async {
    _currentUsername = username;

    // Load data dari SharedPreferences
    _counter = _historyService.getCounter(username);
    _step = _historyService.getStep(username);

    // Load history
    final savedHistory = _historyService.getHistory(username);
    _history.clear();
    _history.addAll(savedHistory);

    // Simpan waktu login terakhir
    await _historyService.saveLastLogin(username);

    // Log aktivitas login
    await _historyService.addActivityLog(username, 'User login');
  }

  void setStep(int newStep) {
    if (newStep > 0) {
      _step = newStep;
      _saveData();
    }
  }

  String _getTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  // Simpan data ke SharedPreferences
  Future<void> _saveData() async {
    if (_currentUsername == null) return;

    await _historyService.saveCounter(_currentUsername!, _counter);
    await _historyService.saveStep(_currentUsername!, _step);
    await _historyService.saveHistory(_currentUsername!, _history);
  }

  void increment() {
    int oldValue = _counter;
    _counter += _step;
    int no = _history.length + 1;
    final logEntry =
        ' $no. User menambah nilai sebesar  [+$_step] Nilai awal $oldValue →  nilai akhir $_counter  pada jam| ${_getTime()}';
    _history.add(logEntry);

    // Simpan ke SharedPreferences
    _saveData();

    // Log aktivitas
    if (_currentUsername != null) {
      _historyService.addActivityLog(
        _currentUsername!,
        'INCREMENT: +$_step (Total: $_counter)',
      );
    }
  }

  void decrement() {
    if (_counter - _step < 0) {
      return;
    } else {
      int oldValue = _counter;
      _counter -= _step;
      int no = _history.length + 1;
      final logEntry =
          ' $no. User mengurangi nilai sebesar  [-$_step] Nilai awal $oldValue →  nilai akhir $_counter  pada jam| ${_getTime()}';
      _history.add(logEntry);

      // Simpan ke SharedPreferences
      _saveData();

      // Log aktivitas
      if (_currentUsername != null) {
        _historyService.addActivityLog(
          _currentUsername!,
          'DECREMENT: -$_step (Total: $_counter)',
        );
      }
    }
  }

  void reset() {
    int oldValue = _counter;
    _counter = 0;
    int no = _history.length + 1;
    final logEntry =
        '$no. User melakukan [Reset] Nilai yang awalnya bernilai $oldValue →  menjadi 0 | ${_getTime()}';
    _history.add(logEntry);

    // Simpan ke SharedPreferences
    _saveData();

    // Log aktivitas
    if (_currentUsername != null) {
      _historyService.addActivityLog(_currentUsername!, 'RESET: $oldValue → 0');
    }
  }

  void clearHistory() {
    _history.clear();

    // Hapus history di SharedPreferences
    if (_currentUsername != null) {
      _historyService.clearHistory(_currentUsername!);
      _historyService.addActivityLog(_currentUsername!, 'CLEAR HISTORY');
    }
  }

  // Export history ke file .txt
  Future<String> exportToFile() async {
    if (_currentUsername == null) throw Exception('User tidak ditemukan');
    return await _historyService.exportHistoryToFile(_currentUsername!);
  }

  // Dapatkan summary user
  Map<String, dynamic> getUserSummary() {
    if (_currentUsername == null) return {};
    return _historyService.getUserSummary(_currentUsername!);
  }

  // Dapatkan activity logs
  List<String> getActivityLogs() {
    if (_currentUsername == null) return [];
    return _historyService.getActivityLogs(_currentUsername!);
  }
}

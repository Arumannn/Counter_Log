class CounterController {
  int _counter = 0; // Variabel private (Enkapsulasi)
  int _step = 1; // Langkah increment/decrement (default: 1)
  final List<String> _history = [];

  int get value => _counter; // Getter untuk akses data
  int get step => _step; // Getter untuk step
  List<String> get history => _history;

  void setStep(int newStep) {
    if (newStep > 0) _step = newStep;
  }

  String _getTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  void increment() {
    int oldValue = _counter;
    _counter += _step;
    int no = _history.length + 1;
    _history.add(
      ' $no. User menambah nilai sebesar  [+$_step] Nilai awal $oldValue →  nilai akhir $_counter  pada jam| ${_getTime()}',
    );
  }

  void decrement() {
    if (_counter - _step < 0) return;
    int oldValue = _counter;
    _counter -= _step;
    int no = _history.length + 1;
    _history.add(
      ' $no. User menambah nilai sebesar  [-$_step] Nilai awal $oldValue →  nilai akhir $_counter  pada jam| ${_getTime()}',
    );
  }

  

  void reset() {
    int oldValue = _counter;
    _counter = 0;
    int no = _history.length + 1;
    _history.add(
      '$no. User melakukan [Reset] Nilai yang awalnya berniali $oldValue →  menjadi 0 | ${_getTime()}',
    );
  }

  void clearHistory() {
    _history.clear();
  }
}

import 'package:flutter/material.dart';
import 'counter_controller.dart';
import 'package:logbook_app_001/features/onboarding/onboarding_view.dart';

class CounterView extends StatefulWidget {
  // Tambahkan variabel final untuk menampung nama
  final String username;

  // Update Constructor agar mewajibkan (required) kiriman nama
  const CounterView({super.key, required this.username});

  @override
  State<CounterView> createState() => _CounterViewState();
}

class _CounterViewState extends State<CounterView> {
  final CounterController _controller = CounterController();
  final TextEditingController _stepController = TextEditingController(
    text: '1',
  );

  @override
  void dispose() {
    _stepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentHistory = _controller.history.reversed.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Logbook : ${widget.username}"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Kita siapkan tombol logout di sini untuk Fase 3 nanti
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // 1. Munculkan Dialog Konfirmasi
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Konfirmasi Logout"),
                    content: const Text(
                      "Apakah Anda yakin? Data yang belum disimpan mungkin akan hilang.",
                    ),
                    actions: [
                      // Tombol Batal
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context), // Menutup dialog saja
                        child: const Text("Batal"),
                      ),
                      // Tombol Ya, Logout
                      TextButton(
                        onPressed: () {
                          // Menutup dialog
                          Navigator.pop(context);

                          // 2. Navigasi kembali ke Onboarding (Membersihkan Stack)
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OnboardingView(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          "Ya, Keluar",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Bagian atas: Counter dan Step (tidak scroll)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text("Selamat Datang, ${widget.username}!"),
                const Text("Total Hitungan :"),
                Text(
                  '${_controller.value}',
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(height: 20),
                // TextField untuk mengatur step
                TextField(
                  controller: _stepController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Step',
                    border: OutlineInputBorder(),
                    hintText: 'Masukan nilai step',
                  ),
                  onChanged: (value) {
                    final step = int.tryParse(value) ?? 1;
                    _controller.setStep(step);
                  },
                ),
                const SizedBox(height: 10),
                Text('Step saat ini: ${_controller.step}'),
              ],
            ),
          ),

          const Divider(),
          // Label History dan tombol clear
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'History: (${_controller.history.length} total, 5 terbaru))',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _controller.clearHistory()),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Bagian bawah: History (scrollable)
          Expanded(
            child: recentHistory.isEmpty
                ? const Center(child: Text('Belum ada history'))
                : ListView.builder(
                    itemCount: recentHistory.length,
                    itemBuilder: (context, index) {
                      final item = recentHistory[index]; // ← Langsung String

                      // Tentukan warna berdasarkan jenis aksi
                      Color textColor;
                      IconData icon;
                      if (item.contains('[+')) {
                        textColor = Colors.green;
                        icon = Icons.arrow_upward;
                      } else if (item.contains('[-')) {
                        textColor = Colors.red;
                        icon = Icons.arrow_downward;
                      } else {
                        textColor = Colors.orange;
                        icon = Icons.restart_alt;
                      }

                      return ListTile(
                        leading: Icon(icon, color: textColor),
                        title: Text(item, style: TextStyle(color: textColor)),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              backgroundColor: Colors.red,
              heroTag: 'decrement',
              onPressed: () => setState(() => _controller.decrement()),
              child: const Icon(Icons.remove),
            ),
            FloatingActionButton(
              heroTag: 'reset',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Konfirmasi'),
                    content: const Text(
                      'Apakah anda yakin ingin melakukan reset?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _controller.reset());
                          Navigator.pop(context);
                        },
                        child: Text('Ya Reset'),
                      ),
                    ],
                  ),
                );
              },
              backgroundColor: Colors.orange,
              child: const Icon(Icons.restart_alt),
            ),
            FloatingActionButton(
              backgroundColor: Colors.green,
              heroTag: 'increment',
              onPressed: () => setState(() => _controller.increment()),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

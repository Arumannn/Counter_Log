import '../onboarding/onboarding_view.dart';
import 'log_controller.dart';
import 'package:flutter/material.dart';
// import 'history_service.dart';
import 'models/log_model.dart';

class LogView extends StatefulWidget {
  final String username;

  const LogView({super.key, required this.username});


  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  // 1. Tambahkan Controller untuk menangkap input di dalam State
  final LogController _controller = LogController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  // @override
  // void initState() {
  //   super.initState();
  //   _init
  // }

  void _showAddLogDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tambah Catatan Baru"),
        content: Column(
          mainAxisSize: MainAxisSize.min, // Agar dialog tidak memenuhi layar
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: "Judul Catatan"),
            ),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(hintText: "Isi Deskripsi"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Tutup tanpa simpan
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              // Jalankan fungsi tambah di Controller
              _controller.addLog(
                _titleController.text,
                _contentController.text,
              );

              // Trigger UI Refresh
              setState(() {});

              // Bersihkan input dan tutup dialog
              _titleController.clear();
              _contentController.clear();
              Navigator.pop(context);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  void _showEditLogDialog(int index, LogModel log) {
    _titleController.text = log.title;
    _contentController.text = log.description;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Catatan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleController),
            TextField(controller: _contentController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              _controller.updateLog(
                index,
                _titleController.text,
                _contentController.text,
              );
              _titleController.clear();
              _contentController.clear();
              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  // Future<void> _initializeData() async {
  //   await _controller.init
  // }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Logbook - ${widget.username}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          // Tombol Export
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Export History',
            onPressed: _controller.loadFromDisk,
          ),
          // // Tombol Activity Log
          // IconButton(
          //   icon: const Icon(Icons.history),
          //   tooltip: 'Activity Log',
          //   onPressed: _showActivityLogs,
          // ),
          // // Tombol User Summary
          // IconButton(
          //   icon: const Icon(Icons.info_outline),
          //   tooltip: 'User Summary',
          //   onPressed: _showUserSummary,
          // ),
          // Tombol Logout
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
                      "Apakah Anda yakin? Data Anda akan tersimpan otomatis.",
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
                        onPressed: () async {
                          // Log aktivitas logout
                          // await _historyService.addActivityLog(
                          //   widget.username,
                          //   'User logout',
                          // );

                          // Menutup dialog
                          if (context.mounted) Navigator.pop(context);

                          // 2. Navigasi kembali ke Onboarding (Membersihkan Stack)
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const OnboardingView(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        child: const Text(
                          "Ya, Keluar",
                          style: TextStyle(color: Color(0xFF9E5A5A)),
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
      body: ValueListenableBuilder<List<LogModel>>(
        valueListenable: _controller.filteredLogs,
        builder: (context, currentLogs, child) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsetsGeometry.all(8.0),
                child: TextField(
                  onChanged: (value) => _controller.searchLog(value),
                  decoration: const InputDecoration(
                    labelText: "Cari Catatan...",
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: currentLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.no_sim_outlined,
                              size: 80,
                              color: Colors.brown,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Belum ada catatan",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.brown,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: currentLogs.length,
                        itemBuilder: (context, index) {
                          final log = currentLogs[index];
                          return Dismissible(
                            key: Key(
                              log.date,
                            ), // Gunakan identitas unik (timestamp)
                            direction: DismissDirection
                                .endToStart, // Swipe dari kanan ke kiri
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (direction) {
                              _controller.removeLog(index);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Catatan dihapus"),
                                ),
                              );
                            },
                            child: Card(
                              child: ListTile(
                                leading: const Icon(Icons.note),
                                title: Text(log.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(log.description),
                                    const SizedBox(height: 4),
                                    Text(
                                      log.date.substring(0, 16),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Wrap(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _showEditLogDialog(
                                        index,
                                        log,
                                      ), // Fungsi edit
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => _controller.removeLog(index),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton(
              backgroundColor: const Color(0xFF9E5A5A),
              foregroundColor: const Color(0xFFF3EBDD),
              heroTag: 'Add',
              elevation: 3,
              onPressed: _showAddLogDialog,
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

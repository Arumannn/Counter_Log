import 'package:flutter/material.dart';

class LoginController {
  /// Data akun: username → {password, role, teamId}
  /// teamId menggunakan format sederhana: 1, 2, 3.
  final Map<String, Map<String, String>> _accounts = {
    'admin': {
      'password': 'admin123',
      'role': 'Ketua',
      'teamId': '1',
    },
    'aruman': {
      'password': 'aruman123',
      'role': 'Reviewer',
      'teamId': '1',
    },
    'reviewer1': {
      'password': 'reviewer123',
      'role': 'Reviewer',
      'teamId': '1',
    },
    'user1': {
      'password': 'password1',
      'role': 'Anggota',
      'teamId': '1',
    },
    'user2': {
      'password': 'password2',
      'role': 'Anggota',
      'teamId': '2',
    },
  };

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Map<String, dynamic>? _currentUser;

  /// Kembalikan data user yang sedang login, atau null jika belum login.
  Map<String, dynamic>? get currentUser => _currentUser;

  /// Login.
  /// Mengembalikan Map {id, username, role, teamId} jika berhasil.
  Map<String, dynamic>? login(String username, String password) {
    final account = _accounts[username];
    if (account != null && account['password'] == password) {
      _currentUser = {
        'id': username,
        'username': username,
        'role': account['role'] ?? 'Anggota',
        'teamId': account['teamId'] ?? '1',
      };
      return _currentUser;
    }
    return null;
  }

  void logout() {
    _currentUser = null;
    usernameController.clear();
    passwordController.clear();
  }

  /// Daftarkan akun baru dengan peran default 'Anggota'.
  bool register(String username, String password) {
    if (_accounts.containsKey(username)) return false;
    _accounts[username] = {
      'password': password,
      'role': 'Anggota',
      'teamId': '1',
    };
    return true;
  }

  List<String> getAllUsernames() => _accounts.keys.toList();

  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
  }
}

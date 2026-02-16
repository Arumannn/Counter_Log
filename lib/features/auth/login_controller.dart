import 'package:flutter/material.dart';

class LoginController {
  // Map untuk menyimpan multiple account (username: password)
  final Map<String, String> _accounts = {
    'admin': 'admin123',
    'user1': 'password1',
    'user2': 'password2',
    'aruman': 'aruman123',
  };

  // Controller untuk input field
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Variabel untuk menyimpan user yang sedang login
  String? _currentUser;

  // Getter untuk current user
  String? get currentUser => _currentUser;

  // Method untuk login
  bool login(String username, String password) {
    // Cek apakah username ada di map
    if (_accounts.containsKey(username)) {
      // Cek apakah password cocok
      if (_accounts[username] == password) {
        _currentUser = username;
        return true; // Login berhasil
      }
    }
    return false; // Login gagal
  }

  // Method untuk logout
  void logout() {
    _currentUser = null;
    usernameController.clear();
    passwordController.clear();
  }

  // Method untuk register akun baru
  bool register(String username, String password) {
    // Cek apakah username sudah ada
    if (_accounts.containsKey(username)) {
      return false; // Username sudah dipakai
    }
    // Tambah akun baru
    _accounts[username] = password;
    return true; // Register berhasil
  }

  // Method untuk mendapatkan semua username (untuk debugging)
  List<String> getAllUsernames() {
    return _accounts.keys.toList();
  }

  // Method untuk dispose controller
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
  }
}
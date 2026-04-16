import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class VisionController extends ChangeNotifier with WidgetsBindingObserver {
  CameraController? controller;
  bool isInitialized = false;
  String? errorMessage;

  final Random _random = Random();
  Timer? _mockDetectionTimer;
  bool _isInitializing = false;
  bool _isDisposed = false;

  // Koordinat normalized (0..1) agar box mudah dipetakan ke ukuran layar apapun.
  Offset _mockDetectionCenter = const Offset(0.5, 0.5);
  double _mockDetectionWidthRatio = 0.3;

  Offset get mockDetectionCenter => _mockDetectionCenter;
  double get mockDetectionWidthRatio => _mockDetectionWidthRatio;

  VisionController() {
    // Mendaftarkan observer agar bisa memantau status aplikasi (Lifecycle)
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  Future<void> initCamera() async {
    if (_isDisposed || _isInitializing) {
      return;
    }

    _isInitializing = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        errorMessage = "No camera detected on device.";
        notifyListeners();
        _isInitializing = false;
        return;
      }

      await releaseCamera();

      // Memilih Kamera Belakang (Index 0)
      controller = CameraController(
        cameras[0],
        ResolutionPreset.high, // Keseimbangan antara akurasi AI & performa
        enableAudio: false, // Kita hanya butuh visual untuk deteksi jalan
      );

      await controller!.initialize();
      isInitialized = true;
      errorMessage = null;
      _startMockDetection();
    } catch (e) {
      errorMessage = "Failed to initialize camera: $e";
    } finally {
      _isInitializing = false;
    }

    if (_isDisposed) {
      return;
    }

    notifyListeners();
  }

  void _startMockDetection() {
    _mockDetectionTimer?.cancel();
    _updateMockDetection();
    _mockDetectionTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _updateMockDetection();
    });
  }

  void _updateMockDetection() {
    // Simulasi output YOLO: lokasi box berpindah acak secara berkala.
    final widthRatio = 0.2 + (_random.nextDouble() * 0.18); // 20% - 38%
    final half = widthRatio / 2;

    final x = half + (_random.nextDouble() * (1 - (half * 2)));
    final y = half + (_random.nextDouble() * (1 - (half * 2)));

    _mockDetectionCenter = Offset(x, y);
    _mockDetectionWidthRatio = widthRatio;
    notifyListeners();
  }

  Future<void> releaseCamera() async {
    _mockDetectionTimer?.cancel();
    _mockDetectionTimer = null;

    final currentController = controller;
    controller = null;
    isInitialized = false;

    if (currentController != null) {
      await currentController.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      // Menginisialisasi ulang saat pengguna kembali ke aplikasi
      if (!isInitialized && !_isInitializing) {
        initCamera();
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Melepaskan resource kamera saat aplikasi masuk background.
      releaseCamera().then((_) {
        if (!_isDisposed) {
          notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Menghapus observer agar tidak terjadi memory leak
    WidgetsBinding.instance.removeObserver(this);

    _mockDetectionTimer?.cancel();
    _mockDetectionTimer = null;

    controller?.dispose();
    controller = null;
    isInitialized = false;

    super.dispose();
  }
}

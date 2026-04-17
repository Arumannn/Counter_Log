import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'vision_image_processor.dart';

enum VisionInteractiveFilterId {
  natural,
  contrastBoost,
  brightPop,
  histogramFocus,
  blurSoft,
  sharpenPlus,
  edgeDetect,
}

class VisionInteractiveFilter {
  const VisionInteractiveFilter({
    required this.id,
    required this.label,
    required this.filterType,
    required this.filterIntensity,
    required this.applyContrast,
    required this.customContrast,
    required this.customBrightness,
    required this.customSaturation,
    required this.showHistogram,
  });

  final VisionInteractiveFilterId id;
  final String label;
  final VisionFilterType filterType;
  final double filterIntensity;
  final bool applyContrast;
  final double customContrast;
  final double customBrightness;
  final double customSaturation;
  final bool showHistogram;
}

const List<VisionInteractiveFilter> visionInteractiveFilters = [
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.natural,
    label: 'Natural',
    filterType: VisionFilterType.none,
    filterIntensity: 0.0,
    applyContrast: false,
    customContrast: 1.0,
    customBrightness: 0.0,
    customSaturation: 1.0,
    showHistogram: false,
  ),
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.contrastBoost,
    label: 'Contrast+',
    filterType: VisionFilterType.none,
    filterIntensity: 0.55,
    applyContrast: true,
    customContrast: 1.2,
    customBrightness: 0.0,
    customSaturation: 1.05,
    showHistogram: false,
  ),
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.brightPop,
    label: 'Bright Pop',
    filterType: VisionFilterType.none,
    filterIntensity: 0.7,
    applyContrast: true,
    customContrast: 1.08,
    customBrightness: 0.08,
    customSaturation: 1.08,
    showHistogram: false,
  ),
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.histogramFocus,
    label: 'Histogram',
    filterType: VisionFilterType.none,
    filterIntensity: 0.68,
    applyContrast: true,
    customContrast: 1.16,
    customBrightness: 0.0,
    customSaturation: 0.95,
    showHistogram: true,
  ),
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.blurSoft,
    label: 'Blur',
    filterType: VisionFilterType.blur,
    filterIntensity: 0.72,
    applyContrast: false,
    customContrast: 1.0,
    customBrightness: 0.0,
    customSaturation: 1.0,
    showHistogram: false,
  ),
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.sharpenPlus,
    label: 'Sharpen',
    filterType: VisionFilterType.sharpen,
    filterIntensity: 0.88,
    applyContrast: true,
    customContrast: 1.12,
    customBrightness: -0.01,
    customSaturation: 1.03,
    showHistogram: false,
  ),
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.edgeDetect,
    label: 'Edge',
    filterType: VisionFilterType.edgeDetection,
    filterIntensity: 0.8,
    applyContrast: true,
    customContrast: 1.26,
    customBrightness: -0.02,
    customSaturation: 0.88,
    showHistogram: true,
  ),
];

class VisionController extends ChangeNotifier with WidgetsBindingObserver {
  CameraController? controller;
  bool isInitialized = false;
  String? errorMessage;
  bool isTorchEnabled = false;
  bool isOverlayEnabled = true;
  bool isLoading = false;
  String loadingMessage = 'Menghubungkan ke Sensor Visual...';
  bool isCapturing = false;
  bool isProcessing = false;
  String? processMessage;
  VisionFilterType selectedFilter = VisionFilterType.none;
  VisionPresetStyle selectedPreset = VisionPresetStyle.original;
  bool applyContrast = true;
  bool showHistogram = true;
  double filterIntensity = 0.8;
  double customContrast = 1.0;
  double customBrightness = 0.0;
  double customSaturation = 1.0;
  VisionInteractiveFilterId selectedInteractiveFilter =
      VisionInteractiveFilterId.natural;
  Map<VisionInteractiveFilterId, Uint8List> filterPreviewBytes =
      const <VisionInteractiveFilterId, Uint8List>{};
  bool isGeneratingFilterPreviews = false;

  Uint8List? capturedImageBytes;
  Uint8List? processedImageBytes;
  List<int>? histogramBins;

  final Random _random = Random();
  Timer? _mockDetectionTimer;
  Timer? _processDebounceTimer;
  bool _isInitializing = false;
  bool _isDisposed = false;
  int _previewGenerationToken = 0;

  // Koordinat normalized (0..1) agar box mudah dipetakan ke ukuran layar apapun.
  Offset _mockDetectionCenter = const Offset(0.5, 0.5);
  double _mockDetectionWidthRatio = 0.3;
  String _mockDetectionCode = 'RD-004';
  String _mockDetectionName = 'Pothole';
  String _mockSeverityCode = 'D40';
  String _mockSeverityLabel = 'Severe';

  Offset get mockDetectionCenter => _mockDetectionCenter;
  double get mockDetectionWidthRatio => _mockDetectionWidthRatio;
  String get mockDetectionCode => _mockDetectionCode;
  String get mockDetectionName => _mockDetectionName;
  String get mockSeverityCode => _mockSeverityCode;
  String get mockSeverityLabel => _mockSeverityLabel;

  bool get hasCapturedImage => capturedImageBytes != null;
  List<VisionInteractiveFilter> get availableInteractiveFilters =>
      visionInteractiveFilters;

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
    isLoading = true;
    loadingMessage = 'Menghubungkan ke Sensor Visual...';
    errorMessage = null;
    if (!_isDisposed) {
      notifyListeners();
    }

    try {
      final permissionStatus = await Permission.camera.request();
      if (permissionStatus.isDenied ||
          permissionStatus.isPermanentlyDenied ||
          permissionStatus.isRestricted) {
        errorMessage = 'No Camera Access';
        isInitialized = false;
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        errorMessage = "No camera detected on device.";
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
      if (isTorchEnabled) {
        await _setTorchMode(true);
      }
      _startMockDetection();
    } catch (e) {
      errorMessage = "Failed to initialize camera: $e";
    } finally {
      isLoading = false;
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

    const detections = <({
      String code,
      String name,
      String severityCode,
      String severityLabel
    })>[
      (
        code: 'RD-001',
        name: 'Longitudinal Crack',
        severityCode: 'D00',
        severityLabel: 'Light'
      ),
      (
        code: 'RD-002',
        name: 'Transverse Crack',
        severityCode: 'D10',
        severityLabel: 'Minor'
      ),
      (
        code: 'RD-003',
        name: 'Alligator Crack',
        severityCode: 'D20',
        severityLabel: 'Moderate'
      ),
      (
        code: 'RD-004',
        name: 'Pothole',
        severityCode: 'D40',
        severityLabel: 'Severe'
      ),
      (
        code: 'RD-005',
        name: 'Rutting',
        severityCode: 'D20',
        severityLabel: 'Moderate'
      ),
      (
        code: 'RD-006',
        name: 'Depression',
        severityCode: 'D20',
        severityLabel: 'Moderate'
      ),
      (
        code: 'RD-007',
        name: 'Shoving',
        severityCode: 'D10',
        severityLabel: 'Minor'
      ),
      (
        code: 'RD-008',
        name: 'Edge Break',
        severityCode: 'D20',
        severityLabel: 'Moderate'
      ),
      (
        code: 'RD-009',
        name: 'Patch Failure',
        severityCode: 'D40',
        severityLabel: 'Severe'
      ),
      (
        code: 'RD-010',
        name: 'Bleeding',
        severityCode: 'D00',
        severityLabel: 'Light'
      ),
    ];

    final selected = detections[_random.nextInt(detections.length)];

    final x = half + (_random.nextDouble() * (1 - (half * 2)));
    final y = half + (_random.nextDouble() * (1 - (half * 2)));

    _mockDetectionCenter = Offset(x, y);
    _mockDetectionWidthRatio = widthRatio;
    _mockDetectionCode = selected.code;
    _mockDetectionName = selected.name;
    _mockSeverityCode = selected.severityCode;
    _mockSeverityLabel = selected.severityLabel;
    notifyListeners();
  }

  Future<void> releaseCamera() async {
    _mockDetectionTimer?.cancel();
    _mockDetectionTimer = null;

    isTorchEnabled = false;
    isLoading = false;

    final currentController = controller;
    controller = null;
    isInitialized = false;

    if (currentController != null) {
      await currentController.dispose();
    }
  }

  Future<void> toggleTorch() async {
    if (!isInitialized || controller == null) {
      return;
    }

    final nextValue = !isTorchEnabled;
    await _setTorchMode(nextValue);
    isTorchEnabled = nextValue;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> _setTorchMode(bool enabled) async {
    final cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    try {
      await cameraController.setFlashMode(
        enabled ? FlashMode.torch : FlashMode.off,
      );
    } catch (_) {
      // Jika device tidak mendukung torch, state tidak diubah.
    }
  }

  void toggleOverlay() {
    isOverlayEnabled = !isOverlayEnabled;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void setFilter(VisionFilterType filter) {
    selectedFilter = filter;
    selectedPreset = VisionPresetStyle.original;
    selectedInteractiveFilter = VisionInteractiveFilterId.natural;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void applyPreset(VisionPresetStyle preset) {
    selectedPreset = preset;
    final config = visionPresetConfig(preset);
    applyContrast = config.applyContrast;
    selectedFilter = config.filterType;
    filterIntensity = config.filterIntensity;
    customContrast = 1.0;
    customBrightness = 0.0;
    customSaturation = 1.0;
    selectedInteractiveFilter = VisionInteractiveFilterId.natural;
    if (!_isDisposed) {
      notifyListeners();
    }
    requestReprocessCapturedFrame();
  }

  void selectInteractiveFilter(VisionInteractiveFilterId id) {
    final selected = visionInteractiveFilters.firstWhere(
      (item) => item.id == id,
      orElse: () => visionInteractiveFilters.first,
    );

    selectedInteractiveFilter = selected.id;
    selectedPreset = VisionPresetStyle.original;
    applyContrast = selected.applyContrast;
    selectedFilter = selected.filterType;
    filterIntensity = selected.filterIntensity;
    customContrast = selected.customContrast;
    customBrightness = selected.customBrightness;
    customSaturation = selected.customSaturation;
    showHistogram = selected.showHistogram;

    if (!_isDisposed) {
      notifyListeners();
    }

    requestReprocessCapturedFrame();
  }

  void setFilterIntensity(double value) {
    filterIntensity = value.clamp(0.0, 1.0);
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void toggleContrast(bool value) {
    applyContrast = value;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void toggleHistogram(bool value) {
    showHistogram = value;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void requestReprocessCapturedFrame() {
    if (capturedImageBytes == null || isProcessing) {
      return;
    }

    _processDebounceTimer?.cancel();
    _processDebounceTimer = Timer(const Duration(milliseconds: 180), () {
      if (!_isDisposed) {
        processCapturedFrame();
      }
    });
  }

  Future<void> captureFrame() async {
    final cameraController = controller;
    if (!isInitialized ||
        cameraController == null ||
        isCapturing ||
        isProcessing) {
      return;
    }

    isCapturing = true;
    processMessage = 'Menangkap gambar...';
    if (!_isDisposed) {
      notifyListeners();
    }

    try {
      final captured = await cameraController.takePicture();
      capturedImageBytes = await captured.readAsBytes();
      processedImageBytes = capturedImageBytes;
      histogramBins = null;
      selectedInteractiveFilter = VisionInteractiveFilterId.natural;
      applyContrast = false;
      selectedFilter = VisionFilterType.none;
      filterIntensity = 0.0;
      customContrast = 1.0;
      customBrightness = 0.0;
      customSaturation = 1.0;
      selectedPreset = VisionPresetStyle.original;
      showHistogram = true;
      debugPrint(
        '[HistogramDebug][captureFrame] Captured bytes=${capturedImageBytes?.length ?? 0}. '
        'State reset -> showHistogram=$showHistogram, filter=$selectedFilter, intensity=$filterIntensity',
      );
      unawaited(generateInteractiveFilterPreviews());
      requestReprocessCapturedFrame();
      processMessage = 'Gambar berhasil ditangkap. Siap diproses.';
    } catch (e) {
      processMessage = 'Gagal menangkap gambar: $e';
    } finally {
      isCapturing = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> processCapturedFrame() async {
    final sourceBytes = capturedImageBytes;
    if (sourceBytes == null || isProcessing) {
      return;
    }

    isProcessing = true;
    processMessage = 'Memproses citra digital...';
    if (!_isDisposed) {
      notifyListeners();
    }

    try {
      debugPrint(
        '[HistogramDebug][process:start] includeHistogram=$showHistogram, '
        'sourceBytes=${sourceBytes.length}, filter=$selectedFilter, preset=$selectedPreset',
      );

      final result = await VisionImageProcessor.process(
        sourceBytes: sourceBytes,
        applyContrast: applyContrast,
        filterType: selectedFilter,
        filterIntensity: filterIntensity,
        presetStyle: selectedPreset,
        customContrast: customContrast,
        customBrightness: customBrightness,
        customSaturation: customSaturation,
        includeHistogram: showHistogram,
      );

      processedImageBytes = result.imageBytes;
      histogramBins = result.histogramBins;
      final binsCount = histogramBins?.length ?? 0;
      final totalBinSamples = histogramBins?.fold<int>(0, (a, b) => a + b) ?? 0;
      debugPrint(
        '[HistogramDebug][process:done] binsCount=$binsCount, totalBinSamples=$totalBinSamples, '
        'showHistogram=$showHistogram',
      );
      if (!showHistogram) {
        debugPrint(
          '[HistogramDebug][process:hint] Histogram tidak akan ditampilkan di preview karena showHistogram=false.',
        );
      } else if (binsCount == 0) {
        debugPrint(
          '[HistogramDebug][process:warn] showHistogram=true tetapi bins kosong.',
        );
      }
      processMessage = 'Pemrosesan selesai.';
    } catch (e) {
      processMessage = 'Gagal memproses citra: $e';
    } finally {
      isProcessing = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> generateInteractiveFilterPreviews() async {
    final sourceBytes = capturedImageBytes;
    if (sourceBytes == null) {
      return;
    }

    final generationId = ++_previewGenerationToken;
    filterPreviewBytes = const <VisionInteractiveFilterId, Uint8List>{};
    isGeneratingFilterPreviews = true;
    if (!_isDisposed) {
      notifyListeners();
    }

    final nextPreviews = <VisionInteractiveFilterId, Uint8List>{};
    for (final item in visionInteractiveFilters) {
      try {
        final result = await VisionImageProcessor.process(
          sourceBytes: sourceBytes,
          applyContrast: item.applyContrast,
          filterType: item.filterType,
          filterIntensity: item.filterIntensity,
          presetStyle: VisionPresetStyle.original,
          customContrast: item.customContrast,
          customBrightness: item.customBrightness,
          customSaturation: item.customSaturation,
          maxDimension: 220,
          includeHistogram: false,
        );

        if (_isDisposed || generationId != _previewGenerationToken) {
          return;
        }

        nextPreviews[item.id] = result.imageBytes;
        filterPreviewBytes = Map<VisionInteractiveFilterId, Uint8List>.from(
          nextPreviews,
        );
        if (!_isDisposed) {
          notifyListeners();
        }
      } catch (_) {
        if (_isDisposed || generationId != _previewGenerationToken) {
          return;
        }
      }
    }

    if (_isDisposed || generationId != _previewGenerationToken) {
      return;
    }

    isGeneratingFilterPreviews = false;
    if (!_isDisposed) {
      notifyListeners();
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
      } else if (isInitialized && isTorchEnabled) {
        _setTorchMode(true);
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

    _processDebounceTimer?.cancel();
    _processDebounceTimer = null;

    controller?.dispose();
    controller = null;
    isInitialized = false;

    super.dispose();
  }
}

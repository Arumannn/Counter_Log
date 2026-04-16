import 'vision_controller.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'damage_painter.dart';
import 'histogram_painter.dart';
import 'vision_image_processor.dart';

enum VisionWorkspaceMode { camera, capture, process }

class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> {
  // Inisialisasi controller secara lokal untuk halaman ini
  late VisionController _visionController;
  VisionWorkspaceMode _workspaceMode = VisionWorkspaceMode.camera;

  @override
  void initState() {
    super.initState();
    _visionController = VisionController();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Guard resource saat user menekan tombol back.
        await _visionController.releaseCamera();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("Smart-Patrol Vision")),
        body: ListenableBuilder(
          listenable: _visionController,
          builder: (context, child) {
            if (_visionController.isLoading) {
              return _buildLoadingState();
            }

            if (_visionController.errorMessage != null) {
              return _buildErrorState(context);
            }

            if (!_visionController.isInitialized) {
              return _buildLoadingState();
            }

            return Column(
              children: [
                Expanded(child: _buildVisionStage()),
                _buildModeSwitcher(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVisionStage() {
    final cameraController = _visionController.controller!;
    final previewSize = cameraController.value.previewSize;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildStageContent(cameraController, previewSize),
        if (_workspaceMode == VisionWorkspaceMode.camera &&
            _visionController.isOverlayEnabled)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: DamagePainter(
                  detectionCenter: _visionController.mockDetectionCenter,
                  detectionWidthRatio: _visionController.mockDetectionWidthRatio,
                  detectionCode: _visionController.mockDetectionCode,
                  detectionName: _visionController.mockDetectionName,
                  severityCode: _visionController.mockSeverityCode,
                  severityLabel: _visionController.mockSeverityLabel,
                ),
              ),
            ),
          ),
        Positioned(
          top: 16,
          right: 16,
          child: SafeArea(
            child: _buildControlPanel(context),
          ),
        ),
        Positioned(
          bottom: 18,
          left: 0,
          right: 0,
          child: SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCaptureBar(),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSwitcher() {
    final label = switch (_workspaceMode) {
      VisionWorkspaceMode.camera => 'Mode: Camera Live',
      VisionWorkspaceMode.capture => 'Mode: Capture Preview',
      VisionWorkspaceMode.process => 'Mode: Image Processing',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard_customize, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (_visionController.processMessage != null)
            Flexible(
              child: Text(
                _visionController.processMessage!,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStageContent(
    CameraController cameraController,
    Size? previewSize,
  ) {
    switch (_workspaceMode) {
      case VisionWorkspaceMode.camera:
        return _buildLiveCameraPreview(cameraController, previewSize);
      case VisionWorkspaceMode.capture:
        return _buildCapturedPreview();
      case VisionWorkspaceMode.process:
        return _buildProcessedPreview();
    }
  }

  Widget _buildLiveCameraPreview(
    CameraController cameraController,
    Size? previewSize,
  ) {
    if (previewSize != null) {
      return Positioned.fill(
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenRatio = constraints.maxWidth / constraints.maxHeight;
              final cameraRatio = cameraController.value.aspectRatio;

              final fit =
                  cameraRatio > screenRatio ? BoxFit.fitHeight : BoxFit.fitWidth;

              return FittedBox(
                fit: fit,
                child: SizedBox(
                  width: previewSize.height,
                  height: previewSize.width,
                  child: CameraPreview(cameraController),
                ),
              );
            },
          ),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: cameraController.value.aspectRatio,
        child: CameraPreview(cameraController),
      ),
    );
  }

  Widget _buildCapturedPreview() {
    final bytes = _visionController.capturedImageBytes;
    if (bytes == null) {
      return _buildEmptyPreviewState(
        title: 'Belum ada gambar',
        subtitle: 'Tekan tombol Capture untuk mengambil frame jalan.',
      );
    }

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );
  }

  Widget _buildProcessedPreview() {
    final bytes = _visionController.processedImageBytes ??
        _visionController.capturedImageBytes;
    if (bytes == null) {
      return _buildEmptyPreviewState(
        title: 'Belum ada citra untuk diproses',
        subtitle: 'Ambil gambar terlebih dahulu, lalu jalankan processing.',
      );
    }

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Preset Looks',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      _visionController.selectedPreset.name.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _presetChip('Original', VisionPresetStyle.original),
                    _presetChip('Warm', VisionPresetStyle.warm),
                    _presetChip('Cool', VisionPresetStyle.cool),
                    _presetChip('Vintage', VisionPresetStyle.vintage),
                    _presetChip('Punch', VisionPresetStyle.punch),
                    _presetChip('Sharp', VisionPresetStyle.sharp),
                    _presetChip('Drama', VisionPresetStyle.drama),
                    _presetChip('Mono', VisionPresetStyle.monochrome),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Filter Intensity',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${(_visionController.filterIntensity * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
                Slider(
                  value: _visionController.filterIntensity,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  activeColor: Colors.lightGreenAccent,
                  onChanged: (value) {
                    _visionController.setFilterIntensity(value);
                    _visionController.requestReprocessCapturedFrame();
                  },
                ),
                Text(
                  'Geser ke kiri untuk efek ringan, geser ke kanan untuk efek filter/konvolusi yang lebih kuat.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
          if (_visionController.showHistogram &&
              (_visionController.histogramBins?.isNotEmpty ?? false))
            Container(
              height: 140,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Histogram Visual',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: CustomPaint(
                      painter: HistogramPainter(
                        bins: _visionController.histogramBins!,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyPreviewState({
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_search, color: Colors.white54, size: 54),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                strokeWidth: 5,
                color: Colors.lightGreenAccent,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _visionController.loadingMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mohon tunggu, sistem sedang menyiapkan kamera dan mode pemindaian.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final errorMessage = _visionController.errorMessage;
    final isCameraAccessIssue = errorMessage == 'No Camera Access';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 6,
          color: Colors.black.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCameraAccessIssue ? Icons.videocam_off : Icons.error_outline,
                  color: Colors.orangeAccent,
                  size: 54,
                ),
                const SizedBox(height: 16),
                Text(
                  isCameraAccessIssue ? 'No Camera Access' : 'Vision Error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  isCameraAccessIssue
                      ? 'Izin kamera belum aktif. Aktifkan izin agar proses inspeksi visual dapat berjalan dengan normal.'
                      : (errorMessage ?? 'Terjadi gangguan saat memuat kamera.'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (isCameraAccessIssue)
                      FilledButton.icon(
                        onPressed: () async {
                          await openAppSettings();
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('Open Settings'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        _visionController.initCamera();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presetChip(String label, VisionPresetStyle style) {
    final isSelected = _visionController.selectedPreset == style;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        _visionController.applyPreset(style);
        setState(() {
          _workspaceMode = VisionWorkspaceMode.process;
        });
      },
      selectedColor: Colors.lightGreenAccent,
      backgroundColor: Colors.white12,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _visionController.isTorchEnabled
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _visionController.toggleTorch(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _visionController.isTorchEnabled ? 'Torch ON' : 'Torch OFF',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.contrast, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: _visionController.applyContrast,
                onChanged: (value) {
                  _visionController.toggleContrast(value);
                  _visionController.requestReprocessCapturedFrame();
                },
                activeColor: Colors.lightGreenAccent,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_alt, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              DropdownButton<VisionFilterType>(
                value: _visionController.selectedFilter,
                dropdownColor: Colors.black87,
                iconEnabledColor: Colors.white,
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                items: const [
                  DropdownMenuItem(
                    value: VisionFilterType.none,
                    child: Text('None'),
                  ),
                  DropdownMenuItem(
                    value: VisionFilterType.blur,
                    child: Text('Blur'),
                  ),
                  DropdownMenuItem(
                    value: VisionFilterType.sharpen,
                    child: Text('Sharpen'),
                  ),
                  DropdownMenuItem(
                    value: VisionFilterType.edgeDetection,
                    child: Text('Edge'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _visionController.setFilter(value);
                    _visionController.requestReprocessCapturedFrame();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.layers, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: _visionController.isOverlayEnabled,
                onChanged: (_) => _visionController.toggleOverlay(),
                activeColor: Colors.lightGreenAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureBar() {
    final isProcessing = _visionController.isProcessing;
    final isCapturing = _visionController.isCapturing;

    return Row(
      children: [
        Expanded(
          child: SegmentedButton<VisionWorkspaceMode>(
            segments: const [
              ButtonSegment(
                value: VisionWorkspaceMode.camera,
                label: Text('Camera'),
                icon: Icon(Icons.videocam),
              ),
              ButtonSegment(
                value: VisionWorkspaceMode.capture,
                label: Text('Capture'),
                icon: Icon(Icons.photo_camera),
              ),
              ButtonSegment(
                value: VisionWorkspaceMode.process,
                label: Text('Process'),
                icon: Icon(Icons.auto_fix_high),
              ),
            ],
            selected: {_workspaceMode},
            onSelectionChanged: (values) {
              setState(() {
                _workspaceMode = values.first;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: (!isCapturing && !isProcessing)
              ? () async {
                  await _visionController.captureFrame();
                  if (mounted) {
                    setState(() {
                      _workspaceMode = VisionWorkspaceMode.capture;
                    });
                  }
                }
              : null,
          icon: isCapturing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.camera_alt),
          label: Text(isCapturing ? 'Capturing' : 'Capture'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: (_visionController.hasCapturedImage && !isProcessing)
              ? () async {
                  await _visionController.processCapturedFrame();
                  if (mounted) {
                    setState(() {
                      _workspaceMode = VisionWorkspaceMode.process;
                    });
                  }
                }
              : null,
          child: Text(isProcessing ? 'Processing...' : 'Analyze'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // WAJIB: Memutus akses kamera saat pindah halaman
    _visionController.dispose();
    super.dispose();
  }
}

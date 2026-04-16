// ============================================================
// vision_view.dart — Smart-Patrol Vision  (Redesigned UI)
// Gaya: Immersive camera · Glassmorphism · Instagram-filter UX
// ============================================================

import 'vision_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'damage_painter.dart';
import 'histogram_painter.dart';
import 'histogram_analysis_page.dart';
import 'vision_image_processor.dart';

enum VisionWorkspaceMode { camera, capture, process }

// ─── Design Tokens ───────────────────────────────────────────
class _Tokens {
  static const accent = Color(0xFF00E5CC);
  static const accentDim = Color(0x3300E5CC);
  static const surface = Color(0xFF080C10);
  static const glass = Color(0x99080C10);
  static const glassLight = Color(0x33FFFFFF);
  static const glassStroke = Color(0x26FFFFFF);
  static const warn = Color(0xFFFF6B35);
  static const modeCamera = Color(0xFF4DD17A);
  static const modeCapture = Color(0xFF5B9CF6);
  static const modeProcess = Color(0xFF00E5CC);

  static const double radiusPill = 999;
  static const double radiusCard = 20;
  static const double radiusFilter = 16;

  static BoxDecoration glassCard({Color? color, double radius = radiusCard}) =>
      BoxDecoration(
        color: color ?? glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glassStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════
class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> with TickerProviderStateMixin {
  late VisionController _visionController;
  VisionWorkspaceMode _workspaceMode = VisionWorkspaceMode.camera;

  // Animation controllers
  late AnimationController _captureRingCtrl;
  late AnimationController _captureScaleCtrl;
  late AnimationController _hudFadeCtrl;
  bool _hudVisible = true;

  @override
  void initState() {
    super.initState();
    _visionController = VisionController();

    _captureRingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _captureScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _hudFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1.0,
    );

    // Go full-screen immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _visionController.dispose();
    _captureRingCtrl.dispose();
    _captureScaleCtrl.dispose();
    _hudFadeCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleHud() {
    setState(() => _hudVisible = !_hudVisible);
    if (_hudVisible) {
      _hudFadeCtrl.forward();
    } else {
      _hudFadeCtrl.reverse();
    }
  }

  // ─── Root ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _visionController.releaseCamera();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        return true;
      },
      child: Scaffold(
        backgroundColor: _Tokens.surface,
        body: ListenableBuilder(
          listenable: _visionController,
          builder: (context, _) {
            if (_visionController.isLoading ||
                !_visionController.isInitialized) {
              return _buildLoadingState();
            }
            if (_visionController.errorMessage != null) {
              return _buildErrorState(context);
            }
            return _buildMainStage();
          },
        ),
      ),
    );
  }

  // ─── Main Stage ──────────────────────────────────────────────
  Widget _buildMainStage() {
    return GestureDetector(
      onTap: _toggleHud,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera / preview content
          _buildVisionStage(),
          // 2. Top HUD (fade with tap)
          FadeTransition(
            opacity: _hudFadeCtrl,
            child: _buildTopHUD(),
          ),
          // 3. Bottom controls always visible
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomSheet(),
          ),
        ],
      ),
    );
  }

  // ─── Vision Stage (overlays live here) ───────────────────────
  Widget _buildVisionStage() {
    final cam = _visionController.controller!;
    final previewSize = cam.value.previewSize;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Content (camera / image)
        _buildStageContent(cam, previewSize),

        // ① Cinematic vignette gradient overlay
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.80),
                  ],
                  stops: const [0.0, 0.22, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),

        // ② Scan-grid overlay (camera mode only)
        if (_workspaceMode == VisionWorkspaceMode.camera)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ScanGridPainter()),
            ),
          ),

        // ③ Damage-detection overlay (camera + overlay enabled)
        if (_workspaceMode == VisionWorkspaceMode.camera &&
            _visionController.isOverlayEnabled)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: DamagePainter(
                  detectionCenter: _visionController.mockDetectionCenter,
                  detectionWidthRatio:
                      _visionController.mockDetectionWidthRatio,
                  detectionCode: _visionController.mockDetectionCode,
                  detectionName: _visionController.mockDetectionName,
                  severityCode: _visionController.mockSeverityCode,
                  severityLabel: _visionController.mockSeverityLabel,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Top HUD Overlay ─────────────────────────────────────────
  Widget _buildTopHUD() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back
            _GlassButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () async {
                await _visionController.releaseCamera();
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                if (mounted) Navigator.of(context).pop();
              },
            ),
            const SizedBox(width: 10),
            // Title badge
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: _buildStatusBadge(),
              ),
            ),
            const SizedBox(width: 10),
            // Right actions
            _GlassButton(
              icon: _visionController.isTorchEnabled
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
              isActive: _visionController.isTorchEnabled,
              accentColor: const Color(0xFFFFD166),
              onTap: () => _visionController.toggleTorch(),
            ),
            const SizedBox(width: 8),
            _GlassButton(
              icon: Icons.layers_rounded,
              isActive: _visionController.isOverlayEnabled,
              onTap: () => _visionController.toggleOverlay(),
            ),
            const SizedBox(width: 8),
            _GlassButton(
              icon: Icons.contrast_rounded,
              isActive: _visionController.applyContrast,
              onTap: () {
                _visionController
                    .toggleContrast(!_visionController.applyContrast);
                _visionController.requestReprocessCapturedFrame();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final (label, color) = switch (_workspaceMode) {
      VisionWorkspaceMode.camera => ('LIVE', _Tokens.modeCamera),
      VisionWorkspaceMode.capture => ('CAPTURE', _Tokens.modeCapture),
      VisionWorkspaceMode.process => ('PROCESS', _Tokens.modeProcess),
    };

    // Wrap in ConstrainedBox so the badge never exceeds its Expanded slot,
    // preventing the "RIGHT OVERFLOWED BY N px" debug banner.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _Tokens.glass,
          borderRadius: BorderRadius.circular(_Tokens.radiusPill),
          border: Border.all(color: _Tokens.glassStroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulse dot
            _PulseDot(color: color),
            const SizedBox(width: 6),
            // Use Flexible so the title shrinks instead of overflowing
            Flexible(
              child: Text(
                'Smart-Patrol',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Sheet ─────────────────────────────────────────────
  Widget _buildBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.96),
            Colors.black.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      padding: const EdgeInsets.only(bottom: 0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filter strip (only in non-camera modes)
            if (_workspaceMode != VisionWorkspaceMode.camera)
              _buildFilterStrip(),

            // Preset looks (only in process mode)
            if (_workspaceMode == VisionWorkspaceMode.process)
              _buildPresetBar(),

            // Intensity slider (only in capture/process)
            if (_workspaceMode != VisionWorkspaceMode.camera)
              _buildIntensityRow(),

            const SizedBox(height: 10),

            // Mode selector tabs
            Center(child: _buildModeTabs()),

            const SizedBox(height: 16),

            // Main action row
            _buildActionRow(),

            const SizedBox(height: 12),

            // Process message
            if (_visionController.processMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _visionController.processMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Instagram-style Filter Strip ────────────────────────────
  Widget _buildFilterStrip() {
    final filters = _visionController.availableInteractiveFilters;
    final isLoading = _visionController.isGeneratingFilterPreviews;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
          child: Row(
            children: [
              const Text(
                'FILTER',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              if (isLoading) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white38,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: filters.length,
            itemBuilder: (context, index) {
              final filter = filters[index];
              final isSelected =
                  _visionController.selectedInteractiveFilter == filter.id;
              final previewBytes =
                  _visionController.filterPreviewBytes[filter.id] ??
                      _visionController.capturedImageBytes;

              return GestureDetector(
                onTap: () =>
                    _visionController.selectInteractiveFilter(filter.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Thumbnail
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(_Tokens.radiusFilter),
                          border: Border.all(
                            color: isSelected
                                ? _Tokens.accent
                                : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color:
                                        _Tokens.accent.withValues(alpha: 0.45),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13.5),
                          child: (isLoading || previewBytes == null)
                              ? Container(
                                  color: Colors.white,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ),
                                )
                              : Image.memory(
                                  previewBytes,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: isSelected ? _Tokens.accent : Colors.white54,
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                          letterSpacing: 0.4,
                        ),
                        child: Text(
                          filter.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Preset Bar ───────────────────────────────────────────────
  Widget _buildPresetBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'LOOKS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _presetPill('Original', VisionPresetStyle.original,
                    const Color(0xFF888888)),
                _presetPill(
                    'Warm', VisionPresetStyle.warm, const Color(0xFFFF9A3C)),
                _presetPill(
                    'Cool', VisionPresetStyle.cool, const Color(0xFF5B9CF6)),
                _presetPill('Vintage', VisionPresetStyle.vintage,
                    const Color(0xFFD4A96A)),
                _presetPill(
                    'Punch', VisionPresetStyle.punch, const Color(0xFFFF6B35)),
                _presetPill(
                    'Sharp', VisionPresetStyle.sharp, const Color(0xFF00E5CC)),
                _presetPill(
                    'Drama', VisionPresetStyle.drama, const Color(0xFF9B5CF6)),
                _presetPill('Mono', VisionPresetStyle.monochrome,
                    const Color(0xFFCCCCCC)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetPill(
    String label,
    VisionPresetStyle style,
    Color color,
  ) {
    final isSelected = _visionController.selectedPreset == style;

    return GestureDetector(
      onTap: () {
        _visionController.applyPreset(style);
        setState(() => _workspaceMode = VisionWorkspaceMode.process);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(_Tokens.radiusPill),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white60,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Intensity Row ────────────────────────────────────────────
  Widget _buildIntensityRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, color: Colors.white38, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: _Tokens.accent,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                thumbColor: Colors.white,
                overlayColor: _Tokens.accentDim,
              ),
              child: Slider(
                value: _visionController.filterIntensity,
                min: 0,
                max: 1,
                divisions: 20,
                onChanged: (v) {
                  _visionController.setFilterIntensity(v);
                  _visionController.requestReprocessCapturedFrame();
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              '${(_visionController.filterIntensity * 100).round()}%',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mode Tabs ────────────────────────────────────────────────
  Widget _buildModeTabs() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(_Tokens.radiusPill),
        border: Border.all(color: _Tokens.glassStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeTab('Camera', Icons.videocam_rounded, VisionWorkspaceMode.camera,
              _Tokens.modeCamera),
          _modeTab('Capture', Icons.photo_camera_rounded,
              VisionWorkspaceMode.capture, _Tokens.modeCapture),
          _modeTab('Process', Icons.auto_fix_high_rounded,
              VisionWorkspaceMode.process, _Tokens.modeProcess),
        ],
      ),
    );
  }

  Widget _modeTab(
    String label,
    IconData icon,
    VisionWorkspaceMode mode,
    Color color,
  ) {
    final isSelected = _workspaceMode == mode;

    return GestureDetector(
      onTap: () => setState(() => _workspaceMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(_Tokens.radiusPill),
          border: isSelected
              ? Border.all(color: color.withValues(alpha: 0.45))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? color : Colors.white38,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white38,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Action Row ───────────────────────────────────────────────
  Widget _buildActionRow() {
    final isProcessing = _visionController.isProcessing;
    final isCapturing = _visionController.isCapturing;
    final hasImage = _visionController.hasCapturedImage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Histogram
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildHistogramButton(hasImage),
            ),
          ),

          // Center: Capture
          _buildCaptureButton(isCapturing, isProcessing),

          // Right: Filter dropdown or spacer
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _workspaceMode == VisionWorkspaceMode.camera
                  ? _buildFilterDropdown()
                  : const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton(bool isCapturing, bool isProcessing) {
    final disabled = isCapturing || isProcessing;

    return GestureDetector(
      onTapDown: disabled
          ? null
          : (_) => _captureScaleCtrl.animateTo(1.0, curve: Curves.easeOut),
      onTapUp: disabled
          ? null
          : (_) {
              _captureScaleCtrl.animateTo(0.0,
                  curve: Curves.elasticOut,
                  duration: const Duration(milliseconds: 400));
              _captureAndOpenHistogram();
            },
      onTapCancel: () => _captureScaleCtrl.animateTo(0.0),
      child: AnimatedBuilder(
        animation: _captureScaleCtrl,
        builder: (_, __) {
          final scale = 1.0 - (_captureScaleCtrl.value * 0.09);
          return Transform.scale(
            scale: scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing ring when capturing
                if (isCapturing)
                  AnimatedBuilder(
                    animation: _captureRingCtrl,
                    builder: (_, __) {
                      final t = _captureRingCtrl.value;
                      return Container(
                        width: 82 + (t * 16),
                        height: 82 + (t * 16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                _Tokens.accent.withValues(alpha: (1 - t) * 0.6),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  ),
                // Outer ring
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: disabled
                          ? Colors.white24
                          : Colors.white.withValues(alpha: 0.85),
                      width: 3,
                    ),
                  ),
                ),
                // Inner button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: disabled ? Colors.white24 : Colors.white,
                    boxShadow: disabled
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.3),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                  ),
                  child: isCapturing
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black54,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.black,
                          size: 28,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistogramButton(bool hasImage) {
    return GestureDetector(
      onTap: () {
        _logHistogramDebugState(source: 'histogram_button_tap');
        if (hasImage) {
          _openHistogramAnalysisPage();
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Histogram belum tersedia. ${_histogramDebugSummary()}',
            ),
          ),
        );
      },
      child: AnimatedOpacity(
        opacity: hasImage ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: _Tokens.glassStroke),
          ),
          child: const Icon(
            Icons.query_stats_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Tokens.glassStroke),
      ),
      child: DropdownButton<VisionFilterType>(
        value: _visionController.selectedFilter,
        dropdownColor: const Color(0xFF151820),
        iconEnabledColor: Colors.white54,
        underline: const SizedBox.shrink(),
        isDense: true,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        items: const [
          DropdownMenuItem(value: VisionFilterType.none, child: Text('None')),
          DropdownMenuItem(value: VisionFilterType.blur, child: Text('Blur')),
          DropdownMenuItem(
              value: VisionFilterType.sharpen, child: Text('Sharpen')),
          DropdownMenuItem(
              value: VisionFilterType.edgeDetection, child: Text('Edge')),
        ],
        onChanged: (v) {
          if (v != null) {
            _visionController.setFilter(v);
            _visionController.requestReprocessCapturedFrame();
          }
        },
      ),
    );
  }

  // ─── Stage Content Router ─────────────────────────────────────
  Widget _buildStageContent(
      CameraController cameraController, Size? previewSize) {
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
      CameraController cameraController, Size? previewSize) {
    if (previewSize != null) {
      return Positioned.fill(
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenRatio = constraints.maxWidth / constraints.maxHeight;
              final cameraRatio = cameraController.value.aspectRatio;
              final fit = cameraRatio > screenRatio
                  ? BoxFit.fitHeight
                  : BoxFit.fitWidth;
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: _Tokens.surface,
          child: Center(
            child: Image.memory(
              _visionController.processedImageBytes ?? bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
        _buildHistogramMiniPanel(),
      ],
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

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: _Tokens.surface,
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
        _buildHistogramMiniPanel(),
      ],
    );
  }

  Widget _buildHistogramMiniPanel() {
    if (!_visionController.showHistogram ||
        !(_visionController.histogramBins?.isNotEmpty ?? false)) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 12,
      top: 80,
      child: Container(
        width: 140,
        height: 90,
        decoration: _Tokens.glassCard(radius: 14),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HISTOGRAM',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
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
    );
  }

  // ─── Empty State ──────────────────────────────────────────────
  Widget _buildEmptyPreviewState({
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: _Tokens.glassStroke),
              ),
              child: const Icon(
                Icons.image_search_rounded,
                color: Colors.white38,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Loading State ────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Container(
      color: _Tokens.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: _Tokens.accent,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _visionController.loadingMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mohon tunggu, sistem sedang\nmenyiapkan kamera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error State ──────────────────────────────────────────────
  Widget _buildErrorState(BuildContext context) {
    final errorMessage = _visionController.errorMessage;
    final isCameraAccessIssue = errorMessage == 'No Camera Access';

    return Container(
      color: _Tokens.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: _Tokens.glassCard(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _Tokens.warn.withValues(alpha: 0.12),
                    border:
                        Border.all(color: _Tokens.warn.withValues(alpha: 0.35)),
                  ),
                  child: Icon(
                    isCameraAccessIssue
                        ? Icons.videocam_off_rounded
                        : Icons.error_outline_rounded,
                    color: _Tokens.warn,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isCameraAccessIssue ? 'Camera Access Denied' : 'Vision Error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isCameraAccessIssue
                      ? 'Izin kamera belum aktif. Aktifkan izin agar proses inspeksi visual dapat berjalan.'
                      : (errorMessage ??
                          'Terjadi gangguan saat memuat kamera.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (isCameraAccessIssue)
                      _errorButton(
                        label: 'Buka Pengaturan',
                        icon: Icons.settings_rounded,
                        primary: true,
                        onTap: () async => openAppSettings(),
                      ),
                    _errorButton(
                      label: 'Coba Lagi',
                      icon: Icons.refresh_rounded,
                      primary: false,
                      onTap: () => _visionController.initCamera(),
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

  Widget _errorButton({
    required String label,
    required IconData icon,
    required bool primary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: primary
              ? _Tokens.accent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(_Tokens.radiusPill),
          border: Border.all(
            color: primary
                ? _Tokens.accent.withValues(alpha: 0.5)
                : _Tokens.glassStroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: primary ? _Tokens.accent : Colors.white70),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: primary ? _Tokens.accent : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────
  Future<void> _captureAndOpenHistogram() async {
    await _visionController.captureFrame();
    if (!mounted) return;
    setState(() => _workspaceMode = VisionWorkspaceMode.capture);
    _logHistogramDebugState(source: 'after_capture');
    if (_visionController.hasCapturedImage) _openHistogramAnalysisPage();
  }

  void _openHistogramAnalysisPage() {
    _logHistogramDebugState(source: 'open_histogram_page');
    final imageBytes = _visionController.capturedImageBytes ??
        _visionController.processedImageBytes;
    if (imageBytes == null || imageBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data gambar belum tersedia untuk analisis histogram.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistogramAnalysisPage(
          imageBytes: imageBytes,
          title: 'Analisis Histogram',
        ),
      ),
    );
  }

  String _histogramDebugSummary() {
    final hasCaptured =
        _visionController.capturedImageBytes?.isNotEmpty ?? false;
    final hasProcessed =
        _visionController.processedImageBytes?.isNotEmpty ?? false;
    final binsCount = _visionController.histogramBins?.length ?? 0;
    return 'mode=$_workspaceMode, captured=$hasCaptured, processed=$hasProcessed, '
        'showHistogram=${_visionController.showHistogram}, bins=$binsCount';
  }

  void _logHistogramDebugState({required String source}) {
    debugPrint('[HistogramDebug][$source] ${_histogramDebugSummary()}');
  }
}

// ═══════════════════════════════════════════════════════════════
// Reusable: Glass Icon Button
// ═══════════════════════════════════════════════════════════════
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.accentColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? _Tokens.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? color.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.52),
          border: Border.all(
            color:
                isActive ? color.withValues(alpha: 0.60) : _Tokens.glassStroke,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? color : Colors.white70,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Reusable: Animated Pulse Dot
// ═══════════════════════════════════════════════════════════════
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _anim.value * 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Scan Grid Painter (camera mode overlay)
// ═══════════════════════════════════════════════════════════════
class _ScanGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.7;

    // 3×3 grid
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Corner brackets
    final bPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const m = 28.0; // margin
    const s = 22.0; // bracket arm length

    // Top-left
    canvas
      ..drawLine(const Offset(m, m + s), const Offset(m, m), bPaint)
      ..drawLine(const Offset(m, m), Offset(m + s, m), bPaint);
    // Top-right
    canvas
      ..drawLine(
          Offset(size.width - m - s, m), Offset(size.width - m, m), bPaint)
      ..drawLine(
          Offset(size.width - m, m), Offset(size.width - m, m + s), bPaint);
    // Bottom-left
    canvas
      ..drawLine(
          Offset(m, size.height - m - s), Offset(m, size.height - m), bPaint)
      ..drawLine(
          Offset(m, size.height - m), Offset(m + s, size.height - m), bPaint);
    // Bottom-right
    canvas
      ..drawLine(Offset(size.width - m - s, size.height - m),
          Offset(size.width - m, size.height - m), bPaint)
      ..drawLine(Offset(size.width - m, size.height - m),
          Offset(size.width - m, size.height - m - s), bPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

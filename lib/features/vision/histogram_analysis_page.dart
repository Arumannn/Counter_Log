import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'vision_image_processor.dart';

class HistogramAnalysisPage extends StatefulWidget {
  const HistogramAnalysisPage({
    super.key,
    required this.imageBytes,
    this.title = 'Histogram Analysis',
  });

  final Uint8List imageBytes;
  final String title;

  @override
  State<HistogramAnalysisPage> createState() => _HistogramAnalysisPageState();
}

class _HistogramAnalysisPageState extends State<HistogramAnalysisPage> {
  HistogramFilterSettings _settings = const HistogramFilterSettings();
  Uint8List? _previewBytes;
  HistogramAnalysisResult? _analysis;

  bool _isAnalyzing = false;
  String? _error;

  Timer? _debounceTimer;
  int _analysisToken = 0;

  @override
  void initState() {
    super.initState();
    _previewBytes = widget.imageBytes;
    _runAnalysis();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF101113),
              Colors.black.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPreviewPanel(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _buildInlineErrorBanner(),
              ],
              const SizedBox(height: 12),
              if (_analysis != null) ...[
                _buildStatsGrid(context, _analysis!),
                // Dark-image warning: shown when every pixel is at luminance 0
                if (_analysis!.minIntensity == 0 &&
                    _analysis!.maxIntensity == 0) ...[
                  const SizedBox(height: 8),
                  _buildDarkImageWarning(),
                ],
              ] else
                _buildStatsSkeletonPlaceholder(),
              const SizedBox(height: 12),
              _HistogramPanel(
                title: 'Histogram Grayscale',
                subtitle:
                    'Distribusi luminance piksel (0-255) pada citra hasil filter.',
                trailing: _isAnalyzing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                child: SizedBox(
                  height: 170,
                  child: _analysis != null
                      ? CustomPaint(
                          painter: _SingleHistogramPainter(
                            bins: _analysis!.grayBins,
                            color: const Color(0xFFA9FF50),
                          ),
                          child: const SizedBox.expand(),
                        )
                      : _buildAnalyzingOverlay(),
                ),
              ),
              const SizedBox(height: 12),
              _HistogramPanel(
                title: 'Histogram RGB',
                subtitle:
                    'Kurva channel merah, hijau, dan biru untuk analisis distribusi warna.',
                child: SizedBox(
                  height: 190,
                  child: _analysis != null
                      ? CustomPaint(
                          painter: _RgbHistogramPainter(
                            redBins: _analysis!.redBins,
                            greenBins: _analysis!.greenBins,
                            blueBins: _analysis!.blueBins,
                          ),
                          child: const SizedBox.expand(),
                        )
                      : _buildAnalyzingOverlay(),
                ),
              ),
              const SizedBox(height: 12),
              _buildFilterSettingsPanel(),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali ke Kamera'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: _runAnalysis,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Shown inside a histogram panel while compute() is still running.
  Widget _buildAnalyzingOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFA9FF50),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Menganalisis citra…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                ),
          ),
        ],
      ),
    );
  }

  /// Skeleton placeholder for the stats grid while analysis is running.
  Widget _buildStatsSkeletonPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribusi & Kontras',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Menganalisis citra…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Shown when the analysis result indicates the captured image is all-black.
  Widget _buildDarkImageWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.brightness_low_rounded,
              color: Colors.orangeAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Citra terlihat sangat gelap (semua piksel mendekati luminance 0). '
              'Pastikan pencahayaan mencukupi saat mengambil frame.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel() {
    final bytes = _previewBytes ?? widget.imageBytes;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pratinjau Citra',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
              const Spacer(),
              if (_isAnalyzing)
                Text(
                  'Memproses...',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
      BuildContext context, HistogramAnalysisResult analysis) {
    final info = <({String label, String value})>[
      (label: 'Total Pixel Sampel', value: analysis.sampledPixels.toString()),
      (label: 'Min Intensitas', value: analysis.minIntensity.toString()),
      (label: 'Max Intensitas', value: analysis.maxIntensity.toString()),
      (label: 'Mean Gray', value: analysis.meanGray.toStringAsFixed(1)),
      (label: 'Std Dev Gray', value: analysis.stdDevGray.toStringAsFixed(1)),
      (label: 'Kontras', value: analysis.contrastLevel),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribusi & Kontras',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: info.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.25,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final item = info[index];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSettingsPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Styles Settings',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Setiap perubahan langsung memperbarui pratinjau dan histogram secara real-time.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 12),
          _SettingSlider(
            title: 'Brightness',
            value: _settings.brightness,
            min: -0.35,
            max: 0.35,
            divisions: 70,
            valueLabel: _settings.brightness.toStringAsFixed(2),
            onChanged: (value) {
              _updateSettings(_settings.copyWith(brightness: value));
            },
          ),
          _SettingSlider(
            title: 'Contrast',
            value: _settings.contrast,
            min: 0.55,
            max: 1.85,
            divisions: 65,
            valueLabel: _settings.contrast.toStringAsFixed(2),
            onChanged: (value) {
              _updateSettings(_settings.copyWith(contrast: value));
            },
          ),
          _SettingSlider(
            title: 'Convolution Intensity',
            value: _settings.convolutionIntensity,
            min: 0,
            max: 1,
            divisions: 20,
            valueLabel:
                (_settings.convolutionIntensity * 100).round().toString(),
            onChanged: (value) {
              _updateSettings(_settings.copyWith(convolutionIntensity: value));
            },
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _convolutionChip('None', VisionFilterType.none),
              _convolutionChip('Blur', VisionFilterType.blur),
              _convolutionChip('Sharpen', VisionFilterType.sharpen),
              _convolutionChip('Edge', VisionFilterType.edgeDetection),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  _updateSettings(const HistogramFilterSettings(),
                      immediate: true);
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
              ),
              const SizedBox(width: 8),
              if (_isAnalyzing)
                Text(
                  'Updating...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _convolutionChip(String label, VisionFilterType type) {
    final isSelected = _settings.convolutionType == type;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        _updateSettings(_settings.copyWith(convolutionType: type));
      },
      selectedColor: Colors.lightGreenAccent,
      backgroundColor: Colors.white12,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _updateSettings(HistogramFilterSettings next, {bool immediate = false}) {
    setState(() {
      _settings = next;
    });

    _debounceTimer?.cancel();
    if (immediate) {
      _runAnalysis();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 140), _runAnalysis);
  }

  Future<void> _runAnalysis() async {
    final token = ++_analysisToken;

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final result = await compute(
        _processAndAnalyzeInIsolate,
        <String, Object>{
          'bytes': widget.imageBytes,
          'brightness': _settings.brightness,
          'contrast': _settings.contrast,
          'convolutionType': _settings.convolutionType.name,
          'convolutionIntensity': _settings.convolutionIntensity,
        },
      );

      if (!mounted || token != _analysisToken) {
        return;
      }

      setState(() {
        _previewBytes = result['previewBytes'] as Uint8List;
        _analysis = _analysisFromMap(result);
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted || token != _analysisToken) {
        return;
      }

      try {
        final fallback = await compute(
          _analyzeRawHistogramInIsolate,
          <String, Object>{'bytes': widget.imageBytes},
        );

        if (!mounted || token != _analysisToken) {
          return;
        }

        setState(() {
          _previewBytes = widget.imageBytes;
          _analysis = _analysisFromMap(fallback);
          _isAnalyzing = false;
          _error =
              'Analisis filter gagal, menampilkan histogram asli. Detail: $e';
        });
      } catch (fallbackError) {
        if (!mounted || token != _analysisToken) {
          return;
        }

        setState(() {
          _isAnalyzing = false;
          _error =
              'Gagal menganalisis histogram: $e | fallback: $fallbackError';
        });
      }
    }
  }

  HistogramAnalysisResult _analysisFromMap(Map<String, Object> result) {
    return HistogramAnalysisResult(
      grayBins: List<int>.from(result['grayBins'] as List),
      redBins: List<int>.from(result['redBins'] as List),
      greenBins: List<int>.from(result['greenBins'] as List),
      blueBins: List<int>.from(result['blueBins'] as List),
      minIntensity: result['minIntensity'] as int,
      maxIntensity: result['maxIntensity'] as int,
      meanGray: (result['meanGray'] as num).toDouble(),
      stdDevGray: (result['stdDevGray'] as num).toDouble(),
      sampledPixels: result['sampledPixels'] as int,
      contrastLevel: result['contrastLevel'] as String,
    );
  }
}

class _HistogramPanel extends StatelessWidget {
  const _HistogramPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: Colors.lightGreenAccent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class HistogramFilterSettings {
  const HistogramFilterSettings({
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.convolutionType = VisionFilterType.none,
    this.convolutionIntensity = 0.85,
  });

  final double brightness;
  final double contrast;
  final VisionFilterType convolutionType;
  final double convolutionIntensity;

  HistogramFilterSettings copyWith({
    double? brightness,
    double? contrast,
    VisionFilterType? convolutionType,
    double? convolutionIntensity,
  }) {
    return HistogramFilterSettings(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      convolutionType: convolutionType ?? this.convolutionType,
      convolutionIntensity: convolutionIntensity ?? this.convolutionIntensity,
    );
  }
}

class HistogramAnalysisResult {
  const HistogramAnalysisResult({
    required this.grayBins,
    required this.redBins,
    required this.greenBins,
    required this.blueBins,
    required this.minIntensity,
    required this.maxIntensity,
    required this.meanGray,
    required this.stdDevGray,
    required this.sampledPixels,
    required this.contrastLevel,
  });

  final List<int> grayBins;
  final List<int> redBins;
  final List<int> greenBins;
  final List<int> blueBins;
  final int minIntensity;
  final int maxIntensity;
  final double meanGray;
  final double stdDevGray;
  final int sampledPixels;
  final String contrastLevel;
}

Map<String, Object> _processAndAnalyzeInIsolate(Map<String, Object> payload) {
  final sourceBytes = payload['bytes'] as Uint8List;
  final brightness =
      ((payload['brightness'] as num?)?.toDouble() ?? 0.0).clamp(-0.45, 0.45);
  final brightnessMultiplier = (1.0 + brightness).clamp(0.0, 2.0);
  final contrast =
      ((payload['contrast'] as num?)?.toDouble() ?? 1.0).clamp(0.4, 2.2);
  final convolutionIntensity =
      ((payload['convolutionIntensity'] as num?)?.toDouble() ?? 0.85)
          .clamp(0.0, 1.0);
  final convolutionName = payload['convolutionType'] as String? ?? 'none';
  final convolutionType = VisionFilterType.values.firstWhere(
    (value) => value.name == convolutionName,
    orElse: () => VisionFilterType.none,
  );

  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    throw StateError('Tidak dapat membaca citra untuk histogram.');
  }

  final original = decoded.clone();
  var working = decoded.clone();

  working = img.adjustColor(
    working,
    // image.adjustColor expects brightness multiplier (1.0 = unchanged).
    brightness: brightnessMultiplier,
    contrast: contrast,
    saturation: 1.0,
  );

  switch (convolutionType) {
    case VisionFilterType.blur:
      working = img.gaussianBlur(working, radius: 4);
      break;
    case VisionFilterType.sharpen:
      working = img.convolution(
        working,
        filter: <double>[
          0,
          -1,
          0,
          -1,
          5,
          -1,
          0,
          -1,
          0,
        ],
      );
      break;
    case VisionFilterType.edgeDetection:
      working = img.convolution(
        working,
        filter: <double>[
          -1,
          -1,
          -1,
          -1,
          8,
          -1,
          -1,
          -1,
          -1,
        ],
      );
      break;
    case VisionFilterType.none:
      break;
  }

  if (convolutionType != VisionFilterType.none && convolutionIntensity < 1.0) {
    working = _blendWithOriginal(
      original: original,
      filtered: working,
      amount: convolutionIntensity,
    );
  }

  final analysis = _analyzeImageHistogram(working);
  final previewBytes = Uint8List.fromList(img.encodeJpg(working, quality: 90));

  return <String, Object>{
    'previewBytes': previewBytes,
    'grayBins': analysis.grayBins,
    'redBins': analysis.redBins,
    'greenBins': analysis.greenBins,
    'blueBins': analysis.blueBins,
    'minIntensity': analysis.minIntensity,
    'maxIntensity': analysis.maxIntensity,
    'meanGray': analysis.meanGray,
    'stdDevGray': analysis.stdDevGray,
    'sampledPixels': analysis.sampledPixels,
    'contrastLevel': analysis.contrastLevel,
  };
}

Map<String, Object> _analyzeRawHistogramInIsolate(Map<String, Object> payload) {
  final sourceBytes = payload['bytes'] as Uint8List;
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    throw StateError('Tidak dapat membaca citra untuk fallback histogram.');
  }

  final analysis = _analyzeImageHistogram(decoded);
  return <String, Object>{
    'grayBins': analysis.grayBins,
    'redBins': analysis.redBins,
    'greenBins': analysis.greenBins,
    'blueBins': analysis.blueBins,
    'minIntensity': analysis.minIntensity,
    'maxIntensity': analysis.maxIntensity,
    'meanGray': analysis.meanGray,
    'stdDevGray': analysis.stdDevGray,
    'sampledPixels': analysis.sampledPixels,
    'contrastLevel': analysis.contrastLevel,
  };
}

HistogramAnalysisResult _analyzeImageHistogram(img.Image image) {
  final totalPixels = image.width * image.height;
  final targetSamples = 360000;
  final stride = max(1, sqrt(totalPixels / targetSamples).floor());

  final grayBins = List<int>.filled(256, 0);
  final redBins = List<int>.filled(256, 0);
  final greenBins = List<int>.filled(256, 0);
  final blueBins = List<int>.filled(256, 0);

  var sampledPixels = 0;
  var minIntensity = 255;
  var maxIntensity = 0;
  var sumGray = 0.0;
  var sumSquareGray = 0.0;

  for (var y = 0; y < image.height; y += stride) {
    for (var x = 0; x < image.width; x += stride) {
      final px = image.getPixel(x, y);
      final r = _channelToByte(px.r);
      final g = _channelToByte(px.g);
      final b = _channelToByte(px.b);
      final gray =
          (((r * 299) + (g * 587) + (b * 114)) / 1000).round().clamp(0, 255);

      redBins[r]++;
      greenBins[g]++;
      blueBins[b]++;
      grayBins[gray]++;

      if (gray < minIntensity) {
        minIntensity = gray;
      }
      if (gray > maxIntensity) {
        maxIntensity = gray;
      }

      sampledPixels++;
      sumGray += gray;
      sumSquareGray += gray * gray;
    }
  }

  final meanGray = sampledPixels > 0 ? (sumGray / sampledPixels) : 0.0;
  final variance = sampledPixels > 0
      ? max(0.0, (sumSquareGray / sampledPixels) - (meanGray * meanGray))
      : 0.0;
  final stdDevGray = sqrt(variance);
  final contrastLevel =
      _classifyContrast(stdDevGray, maxIntensity - minIntensity);

  return HistogramAnalysisResult(
    grayBins: grayBins,
    redBins: redBins,
    greenBins: greenBins,
    blueBins: blueBins,
    minIntensity: minIntensity,
    maxIntensity: maxIntensity,
    meanGray: meanGray,
    stdDevGray: stdDevGray,
    sampledPixels: sampledPixels,
    contrastLevel: contrastLevel,
  );
}

img.Image _blendWithOriginal({
  required img.Image original,
  required img.Image filtered,
  required double amount,
}) {
  final blended = original.clone();
  final inverse = 1.0 - amount;

  for (var y = 0; y < original.height; y++) {
    for (var x = 0; x < original.width; x++) {
      final base = original.getPixel(x, y);
      final fx = filtered.getPixel(x, y);
      final out = blended.getPixel(x, y);

      out
        ..r = (base.r * inverse + fx.r * amount)
        ..g = (base.g * inverse + fx.g * amount)
        ..b = (base.b * inverse + fx.b * amount)
        ..a = (base.a * inverse + fx.a * amount);
    }
  }

  return blended;
}

String _classifyContrast(double stdDev, int dynamicRange) {
  if (stdDev >= 62 && dynamicRange >= 210) {
    return 'Tinggi';
  }
  if (stdDev >= 42 && dynamicRange >= 150) {
    return 'Sedang';
  }
  return 'Rendah';
}

int _channelToByte(num channel) {
  final value = channel.toDouble();
  final normalized = value <= 1.0 ? value * 255.0 : value;
  return normalized.round().clamp(0, 255);
}

class _SingleHistogramPainter extends CustomPainter {
  _SingleHistogramPainter({required this.bins, required this.color});

  final List<int> bins;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (bins.isEmpty) {
      return;
    }

    final maxBin = bins.reduce(max);
    if (maxBin <= 0) {
      return;
    }

    // Background rounded rect
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );

    // Subtle baseline
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1,
    );

    final totalBins = bins.length;
    // Use at least 2px per bar so a single-bin spike is always visible.
    final rawBarWidth = size.width / totalBins;
    final barWidth = rawBarWidth.clamp(2.0, 5.0);
    final paint = Paint()..color = color.withValues(alpha: 0.92);

    for (var i = 0; i < totalBins; i++) {
      final ratio = bins[i] / maxBin;
      final h = ratio * size.height;
      if (h < 0.5) continue; // skip invisible bars
      final rect = Rect.fromLTWH(
        i * rawBarWidth,
        size.height - h,
        barWidth,
        h,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SingleHistogramPainter oldDelegate) {
    return oldDelegate.bins != bins || oldDelegate.color != color;
  }
}

class _RgbHistogramPainter extends CustomPainter {
  _RgbHistogramPainter({
    required this.redBins,
    required this.greenBins,
    required this.blueBins,
  });

  final List<int> redBins;
  final List<int> greenBins;
  final List<int> blueBins;

  @override
  void paint(Canvas canvas, Size size) {
    if (redBins.isEmpty || greenBins.isEmpty || blueBins.isEmpty) {
      return;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );

    final maxBin = [
      redBins.reduce(max),
      greenBins.reduce(max),
      blueBins.reduce(max),
    ].reduce(max);
    if (maxBin <= 0) {
      return;
    }

    _drawCurve(
      canvas: canvas,
      size: size,
      bins: redBins,
      maxBin: maxBin,
      color: Colors.redAccent,
    );
    _drawCurve(
      canvas: canvas,
      size: size,
      bins: greenBins,
      maxBin: maxBin,
      color: Colors.lightGreenAccent,
    );
    _drawCurve(
      canvas: canvas,
      size: size,
      bins: blueBins,
      maxBin: maxBin,
      color: Colors.blueAccent,
    );
  }

  void _drawCurve({
    required Canvas canvas,
    required Size size,
    required List<int> bins,
    required int maxBin,
    required Color color,
  }) {
    final stepX = size.width / (bins.length - 1);
    final path = Path();

    for (var i = 0; i < bins.length; i++) {
      final x = i * stepX;
      final y = size.height - ((bins[i] / maxBin) * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = color.withValues(alpha: 0.95);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RgbHistogramPainter oldDelegate) {
    return oldDelegate.redBins != redBins ||
        oldDelegate.greenBins != greenBins ||
        oldDelegate.blueBins != blueBins;
  }
}

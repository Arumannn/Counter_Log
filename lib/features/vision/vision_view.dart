import 'vision_controller.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'damage_painter.dart';

class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> {
  // Inisialisasi controller secara lokal untuk halaman ini
  late VisionController _visionController;

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
            // Tampilkan loading jika kamera sedang inisialisasi
            if (!_visionController.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }

            // Lanjut ke struktur Stack di sub-langkah berikutnya
            return _buildVisionStack();
          },
        ),
      ),
    );
  }

  Widget _buildVisionStack() {
    final cameraController = _visionController.controller!;
    final previewSize = cameraController.value.previewSize;

    return Stack(
      fit: StackFit.expand,
      children: [
        // LAYER 1: Hardware Preview
        // Gunakan cover + crop agar preview stabil di berbagai rasio layar.
        if (previewSize != null)
          Positioned.fill(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenRatio =
                      constraints.maxWidth / constraints.maxHeight;
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
          )
        else
          Center(
            child: AspectRatio(
              aspectRatio: cameraController.value.aspectRatio,
              child: CameraPreview(cameraController),
            ),
          ),

        // LAYER 2: Digital Overlay (Canvas)
        // Layer ini transparan dan berada tepat di atas kamera
        Positioned.fill(
          child: CustomPaint(
            painter: DamagePainter(
              detectionCenter: _visionController.mockDetectionCenter,
              detectionWidthRatio: _visionController.mockDetectionWidthRatio,
            ),
          ),
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

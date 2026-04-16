import 'dart:math' as math;

import 'package:flutter/material.dart';

class DamagePainter extends CustomPainter {
  DamagePainter({
    required this.detectionCenter,
    required this.detectionWidthRatio,
  });

  final Offset detectionCenter;
  final double detectionWidthRatio;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! DamagePainter) {
      return true;
    }

    return oldDelegate.detectionCenter != detectionCenter ||
        oldDelegate.detectionWidthRatio != detectionWidthRatio;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final base = size.shortestSide;

    // Crosshair tetap statis di tengah layar.
    final screenCenter = size.center(Offset.zero);

    // Kotak YOLO bergerak mengikuti deteksi mock.
    final normalizedWidth = detectionWidthRatio.clamp(0.15, 0.5);
    final frameWidth = size.width * normalizedWidth;
    final frameHeight = frameWidth * 0.68;

    final rawCenter = Offset(
      detectionCenter.dx * size.width,
      detectionCenter.dy * size.height,
    );

    final halfW = frameWidth / 2;
    final halfH = frameHeight / 2;

    final center = Offset(
      rawCenter.dx.clamp(halfW, size.width - halfW),
      rawCenter.dy.clamp(halfH, size.height - halfH),
    );

    final frameRect = Rect.fromCenter(
      center: center,
      width: frameWidth,
      height: frameHeight,
    );

    final framePaint = Paint()
      ..color = Colors.lightGreenAccent
      ..strokeWidth = (base * 0.007).clamp(2.0, 4.0)
      ..style = PaintingStyle.stroke;

    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.25);

    // Area luar dibuat sedikit redup agar anchor di tengah lebih fokus.
    final overlayPath = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(frameRect, Radius.circular(base * 0.04)),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlayPath, dimPaint);

    // Gambar kotak YOLO yang bergerak.
    final detectionPaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = (base * 0.006).clamp(2.0, 4.0)
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, Radius.circular(base * 0.018)),
      detectionPaint,
    );

    // Crosshair tetap di tengah layar.
    final crosshairRadius = base * 0.06;
    final crosshairGap = base * 0.015;
    final centerDotRadius = (base * 0.009).clamp(2.0, 4.0);

    canvas.drawLine(
      Offset(screenCenter.dx - crosshairRadius, screenCenter.dy),
      Offset(screenCenter.dx - crosshairGap, screenCenter.dy),
      framePaint,
    );
    canvas.drawLine(
      Offset(screenCenter.dx + crosshairGap, screenCenter.dy),
      Offset(screenCenter.dx + crosshairRadius, screenCenter.dy),
      framePaint,
    );
    canvas.drawLine(
      Offset(screenCenter.dx, screenCenter.dy - crosshairRadius),
      Offset(screenCenter.dx, screenCenter.dy - crosshairGap),
      framePaint,
    );
    canvas.drawLine(
      Offset(screenCenter.dx, screenCenter.dy + crosshairGap),
      Offset(screenCenter.dx, screenCenter.dy + crosshairRadius),
      framePaint,
    );
    canvas.drawCircle(
      screenCenter,
      centerDotRadius,
      Paint()..color = Colors.lightGreenAccent,
    );

    // Label informasi tetap terpasang pada crosshair pusat.
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'Searching for Road Damage...',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: frameWidth);

    final labelPadding = EdgeInsets.symmetric(
      horizontal: base * 0.025,
      vertical: base * 0.012,
    );

    final labelWidth = labelPainter.width + (labelPadding.horizontal);
    final labelHeight = labelPainter.height + (labelPadding.vertical);
    final labelLeft = (screenCenter.dx - (labelWidth / 2)).clamp(
      8.0,
      size.width - labelWidth - 8.0,
    );
    final labelTop = math.min(
      size.height - labelHeight - 8.0,
      screenCenter.dy + base * 0.09,
    );

    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelLeft, labelTop, labelWidth, labelHeight),
      Radius.circular(base * 0.02),
    );

    canvas.drawRRect(
      labelRect,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    labelPainter.paint(
      canvas,
      Offset(
        labelLeft + labelPadding.left,
        labelTop + labelPadding.top,
      ),
    );
  }
}

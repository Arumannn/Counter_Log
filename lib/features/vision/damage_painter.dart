import 'dart:math' as math;

import 'package:flutter/material.dart';

class DamagePainter extends CustomPainter {
  DamagePainter({
    required this.detectionCenter,
    required this.detectionWidthRatio,
    required this.detectionCode,
    required this.detectionName,
    required this.severityCode,
    required this.severityLabel,
  });

  final Offset detectionCenter;
  final double detectionWidthRatio;
  final String detectionCode;
  final String detectionName;
  final String severityCode;
  final String severityLabel;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! DamagePainter) {
      return true;
    }

    return oldDelegate.detectionCenter != detectionCenter ||
        oldDelegate.detectionWidthRatio != detectionWidthRatio ||
        oldDelegate.detectionCode != detectionCode ||
        oldDelegate.detectionName != detectionName ||
        oldDelegate.severityCode != severityCode ||
        oldDelegate.severityLabel != severityLabel;
  }

  Color _brandSeedColor(String code) {
    switch (code) {
      case 'RD-001':
        return const Color(0xFF42A5F5); // blue
      case 'RD-002':
        return const Color(0xFF26C6DA); // cyan
      case 'RD-003':
        return const Color(0xFF26A69A); // teal
      case 'RD-004':
        return const Color(0xFF66BB6A); // green
      case 'RD-005':
        return const Color(0xFFAB47BC); // purple
      case 'RD-006':
        return const Color(0xFF5C6BC0); // indigo
      case 'RD-007':
        return const Color(0xFFFFA726); // orange
      case 'RD-008':
        return const Color(0xFF8D6E63); // brown
      case 'RD-009':
        return const Color(0xFF78909C); // blueGrey
      case 'RD-010':
        return const Color(0xFFFF7043); // deep orange
      default:
        return Colors.lightBlueAccent;
    }
  }

  Color _severityAnchorColor(String code) {
    switch (code) {
      case 'D40':
        return Colors.redAccent;
      case 'D20':
        return Colors.orangeAccent;
      case 'D10':
        return Colors.amberAccent;
      case 'D00':
      default:
        return Colors.yellowAccent;
    }
  }

  Color _derivedDamageColor() {
    final seed = _brandSeedColor(detectionCode);
    final anchor = _severityAnchorColor(severityCode);

    final severityMix = switch (severityCode) {
      'D40' => 0.88,
      'D20' => 0.66,
      'D10' => 0.48,
      'D00' => 0.28,
      _ => 0.4,
    };

    return Color.lerp(seed, anchor, severityMix) ?? anchor;
  }

  String _severityHint(String code) {
    switch (code) {
      case 'D40':
        return 'Heavy';
      case 'D20':
        return 'Moderate';
      case 'D10':
        return 'Minor';
      case 'D00':
      default:
        return 'Light';
    }
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

    final severityColor = _derivedDamageColor();
    final severityText = severityLabel;

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
      ..color = severityColor
      ..strokeWidth = (base * 0.006).clamp(2.0, 4.0)
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, Radius.circular(base * 0.018)),
      detectionPaint,
    );

    final glowPaint = Paint()
      ..color = severityColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (base * 0.018).clamp(4.0, 8.0)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, Radius.circular(base * 0.018)),
      glowPaint,
    );

    final borderShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (base * 0.014).clamp(3.0, 6.0);

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, Radius.circular(base * 0.018)),
      borderShadowPaint,
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

    // Label informasi berbasis klasifikasi kerusakan.
    final labelPainter = TextPainter(
      text: TextSpan(
        text: '$detectionCode • $detectionName',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
          shadows: const [
            Shadow(
              color: Colors.black87,
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
            Shadow(
              color: Colors.black54,
              offset: Offset(0, 0),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: frameWidth);

    final severityPainter = TextPainter(
      text: TextSpan(
        text: '$severityCode • $severityText',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(
              color: Colors.black87,
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: frameWidth);

    final labelPadding = EdgeInsets.symmetric(
      horizontal: base * 0.028,
      vertical: base * 0.014,
    );

    final labelWidth = labelPainter.width + (labelPadding.horizontal);
    final severityHeight = severityPainter.height + (base * 0.008);
    final labelHeight = labelPainter.height + severityHeight + (labelPadding.vertical * 1.2);
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
      Paint()
        ..color = Colors.black.withValues(alpha: 0.62)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      labelRect,
      Paint()
        ..color = severityColor.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    final labelTextOffset = Offset(
      labelLeft + labelPadding.left,
      labelTop + labelPadding.top,
    );

    labelPainter.paint(
      canvas,
      labelTextOffset,
    );

    severityPainter.paint(
      canvas,
      Offset(
        labelTextOffset.dx,
        labelTextOffset.dy + labelPainter.height + (base * 0.006),
      ),
    );

    final badgePainter = TextPainter(
      text: TextSpan(
        text: _severityHint(severityCode),
        style: TextStyle(
          color: severityColor.computeLuminance() > 0.55
              ? Colors.black
              : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgePadding = EdgeInsets.symmetric(
      horizontal: base * 0.012,
      vertical: base * 0.006,
    );
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelRect.right - badgePainter.width - badgePadding.horizontal - 8,
        labelRect.top - (base * 0.01),
        badgePainter.width + badgePadding.horizontal,
        badgePainter.height + badgePadding.vertical,
      ),
      Radius.circular(base * 0.012),
    );

    canvas.drawRRect(
      badgeRect,
      Paint()..color = severityColor,
    );
    badgePainter.paint(
      canvas,
      Offset(
        badgeRect.left + badgePadding.left,
        badgeRect.top + badgePadding.top,
      ),
    );
  }
}

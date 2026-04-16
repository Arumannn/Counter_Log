import 'package:flutter/material.dart';

class HistogramPainter extends CustomPainter {
  HistogramPainter({required this.bins});

  final List<int> bins;

  @override
  void paint(Canvas canvas, Size size) {
    if (bins.isEmpty) {
      return;
    }

    final maxBin = bins.reduce((a, b) => a > b ? a : b);
    if (maxBin <= 0) {
      return;
    }

    final barWidth = size.width / bins.length;
    final fillPaint = Paint()
      ..color = Colors.lightGreenAccent.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    for (var i = 0; i < bins.length; i++) {
      final value = bins[i] / maxBin;
      final barHeight = size.height * value;
      final left = i * barWidth;
      final rect = Rect.fromLTWH(
        left + 1,
        size.height - barHeight,
        (barWidth - 2).clamp(1.0, double.infinity),
        barHeight,
      );
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HistogramPainter oldDelegate) {
    return oldDelegate.bins != bins;
  }
}

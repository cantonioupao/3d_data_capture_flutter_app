import 'package:flutter/material.dart';

class DetectionBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>>? recognitions;
  final int imageHeight;
  final int imageWidth;

  DetectionBoxPainter({
    required this.recognitions,
    required this.imageHeight,
    required this.imageWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (recognitions == null) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.red;

    for (final detection in recognitions!) {
      final rect = _normalizedRectToScreen(
        detection['bounds'] as List<double>,
        size,
        imageHeight,
        imageWidth,
      );

      canvas.drawRect(rect, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${detection['class']}: ${(detection['score'] * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            backgroundColor: Colors.black54,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, rect.topLeft);
    }
  }

  Rect _normalizedRectToScreen(
    List<double> normalizedRect,
    Size size,
    int imageHeight,
    int imageWidth,
  ) {
    return Rect.fromLTRB(
      normalizedRect[0] * size.width,
      normalizedRect[1] * size.height,
      normalizedRect[2] * size.width,
      normalizedRect[3] * size.height,
    );
  }

  @override
  bool shouldRepaint(DetectionBoxPainter oldDelegate) {
    return recognitions != oldDelegate.recognitions;
  }
}
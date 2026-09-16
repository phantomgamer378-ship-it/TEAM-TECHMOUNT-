import 'dart:math';
import 'package:flutter/material.dart';

import '../../../core/theme/vr_colors.dart';

/// Animated waveform visualization using CustomPainter.
///
/// Draws a flowing sine wave that responds visually during analysis.
class WaveformPainter extends CustomPainter {
  final double phase;
  final Color color;
  final double amplitude;

  WaveformPainter({
    required this.phase,
    this.color = VrColors.primary,
    this.amplitude = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintFaded = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final mid = size.height / 2;
    final path1 = Path();
    final path2 = Path();

    for (double x = 0; x <= size.width; x += 2) {
      final norm = x / size.width;
      final envelope = sin(norm * pi); // fade edges
      final y1 = mid + sin(norm * 2 * pi * 3 + phase) * amplitude * envelope;
      final y2 = mid + sin(norm * 2 * pi * 2 + phase * 0.7) * amplitude * 0.6 * envelope;

      if (x == 0) {
        path1.moveTo(x, y1);
        path2.moveTo(x, y2);
      } else {
        path1.lineTo(x, y1);
        path2.lineTo(x, y2);
      }
    }

    canvas.drawPath(path2, paintFaded);
    canvas.drawPath(path1, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.amplitude != amplitude;
}

/// Animated waveform widget — continuously moves while active.
class AnimatedWaveform extends StatefulWidget {
  const AnimatedWaveform({
    super.key,
    this.isActive = true,
    this.height = 80,
    this.color = VrColors.primary,
  });

  final bool isActive;
  final double height;
  final Color color;

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: WaveformPainter(
          phase: _controller.value * 2 * pi,
          color: widget.color,
          amplitude: widget.isActive ? 20 : 5,
        ),
      ),
    );
  }
}

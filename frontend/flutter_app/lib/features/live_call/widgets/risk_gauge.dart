import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/vr_colors.dart';
import '../../../core/theme/vr_typography.dart';
import '../../../core/utils/risk_utils.dart';

/// Semi-circular risk gauge with smooth animated transitions.
///
/// Animates the score smoothly when it changes. Colors shift by risk level.
class RiskGauge extends StatefulWidget {
  const RiskGauge({super.key, required this.score, this.size = 200});

  final int score;
  final double size;

  @override
  State<RiskGauge> createState() => _RiskGaugeState();
}

class _RiskGaugeState extends State<RiskGauge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scoreAnimation;
  int _displayScore = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scoreAnimation = Tween<double>(begin: 0, end: widget.score.toDouble())
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic))
      ..addListener(() {
        setState(() => _displayScore = _scoreAnimation.value.round());
      });
    _controller.forward();
  }

  @override
  void didUpdateWidget(RiskGauge old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _scoreAnimation = Tween<double>(
        begin: _displayScore.toDouble(),
        end: widget.score.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = RiskUtils.color(_displayScore);
    final level = RiskUtils.level(_displayScore);

    return SizedBox(
      width: widget.size,
      height: widget.size * 0.65,
      child: CustomPaint(
        painter: _GaugePainter(
          score: _displayScore,
          color: color,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: widget.size * 0.05),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_displayScore',
                  style: VrTypography.riskScore.copyWith(color: color),
                ),
                Text(
                  '/ 100',
                  style: VrTypography.caption.copyWith(
                    color: color.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  level,
                  style: VrTypography.overline.copyWith(
                    color: color,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width / 2 - 16;

    // Background arc
    final bgPaint = Paint()
      ..color = VrColors.surfaceLight
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );

    // Score arc
    final scorePaint = Paint()
      ..color = color
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweep = (score / 100) * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      sweep,
      false,
      scorePaint,
    );

    // Glow arc
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      sweep,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.score != score || old.color != color;
}

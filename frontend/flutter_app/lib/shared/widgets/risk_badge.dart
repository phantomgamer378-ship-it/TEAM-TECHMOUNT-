import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../core/utils/risk_utils.dart';

/// Large colored risk badge — "93 / 100 — CRITICAL".
///
/// Uses dramatic typography (56px score). Color comes from risk state only.
class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.score, this.level});

  final int score;
  final String? level;

  @override
  Widget build(BuildContext context) {
    final lvl = level ?? RiskUtils.level(score);
    final color = RiskUtils.levelColor(lvl);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: VrTypography.riskScore.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          Text(
            '/ 100',
            style: VrTypography.bodySmall.copyWith(color: color.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$lvl RISK',
              style: VrTypography.label.copyWith(
                color: color,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Smaller inline risk badge for list items.
class RiskBadgeSmall extends StatelessWidget {
  const RiskBadgeSmall({super.key, required this.score, this.level});

  final int score;
  final String? level;

  @override
  Widget build(BuildContext context) {
    final lvl = level ?? RiskUtils.level(score);
    final color = RiskUtils.levelColor(lvl);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: VrTypography.riskScoreSmall.copyWith(color: color),
          ),
          Text(
            lvl,
            style: VrTypography.caption.copyWith(
              color: color,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

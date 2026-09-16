import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../core/utils/risk_utils.dart';

/// Threat indicator chip — animates into view when a signal is detected.
class ThreatIndicator extends StatelessWidget {
  const ThreatIndicator({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? VrColors.highRisk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: c),
          const SizedBox(width: 6),
          Text(label, style: VrTypography.caption.copyWith(color: c)),
        ],
      ),
    );
  }
}

/// Scam indicator chips — "✓ OTP request", "✓ Urgent money request".
class IndicatorChips extends StatelessWidget {
  const IndicatorChips({super.key, required this.indicators});

  final List<String> indicators;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final i in indicators)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: VrColors.safe.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: VrColors.safe.withValues(alpha: 0.3)),
              ),
              child: Text('✓ $i',
                  style: VrTypography.caption.copyWith(color: VrColors.safe)),
            ),
        ],
      );
}

/// Attack type tags — "Bank Fraud", "Family Impersonation".
class AttackTags extends StatelessWidget {
  const AttackTags({super.key, required this.types});

  final List<String> types;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in types)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: VrColors.highRisk.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: VrColors.highRisk.withValues(alpha: 0.3)),
              ),
              child: Text(t,
                  style: VrTypography.caption.copyWith(color: VrColors.highRisk)),
            ),
        ],
      );
}

/// Language badge — "Hindi", "Marathi + English".
class LanguageBadge extends StatelessWidget {
  const LanguageBadge({super.key, required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: VrColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VrColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        language,
        style: VrTypography.caption.copyWith(color: VrColors.primary),
      ),
    );
  }
}

/// Simple key/value row used across screens.
class InfoRow extends StatelessWidget {
  const InfoRow(this.k, this.v, {super.key, this.color});

  final String k;
  final String v;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(k,
                  style: VrTypography.bodySmall.copyWith(color: VrColors.textMuted))),
          Expanded(
              child: Text(v,
                  style: VrTypography.bodySmall.copyWith(
                      color: color ?? VrColors.textPrimary))),
        ]),
      );
}

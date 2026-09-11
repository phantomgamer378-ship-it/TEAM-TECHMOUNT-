import 'package:flutter/material.dart';
import 'vcs_theme.dart';

/// Panel — the standard card container (dark cybersecurity aesthetic).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VcsTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VcsTheme.cardAlt),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              ?trailing,
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

/// Big colored risk badge: "78 / 100 — HIGH RISK".
class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.score, required this.level});

  final int score;
  final String level;

  @override
  Widget build(BuildContext context) {
    final color = VcsTheme.levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(
        '$score / 100 — $level RISK',
        style: TextStyle(
            color: color, fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Chip row for scam indicators (e.g. "✓ OTP request").
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: VcsTheme.good.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: VcsTheme.good.withValues(alpha: 0.5)),
              ),
              child: Text('✓ $i',
                  style: const TextStyle(color: VcsTheme.good, fontSize: 12)),
            ),
        ],
      );
}

/// Tags for attack types (e.g. "Bank Fraud").
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: VcsTheme.high.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: VcsTheme.high.withValues(alpha: 0.5)),
              ),
              child: Text(t,
                  style:
                      const TextStyle(color: VcsTheme.high, fontSize: 12)),
            ),
        ],
      );
}

/// One explanation line with its colored source tag: [voice] / [scam_rule] / …
class ExplanationTile extends StatelessWidget {
  const ExplanationTile({super.key, required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final m = RegExp(r'^\[(\w+)\]\s*(.*)$').firstMatch(line);
    final tag = m != null ? m.group(1)! : 'info';
    final text = m != null ? m.group(2)! : line;
    final color = VcsTheme.sourceTagColor(tag);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Text(tag,
              style: TextStyle(color: color, fontSize: 10)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(color: VcsTheme.textDim, fontSize: 13))),
      ]),
    );
  }
}

/// "Prototype Analysis" banner shown whenever fallback/demo data is in play
/// (hard rule: never present mock output as real inference).
class PrototypeBanner extends StatelessWidget {
  const PrototypeBanner({super.key, this.note});

  final String? note;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: VcsTheme.warn.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VcsTheme.warn),
        ),
        child: Text(
          note ?? 'Prototype Analysis — some signals used demo-mode fallback',
          style: const TextStyle(color: VcsTheme.warn, fontSize: 12),
        ),
      );
}

/// Simple key/value row used across screens.
class InfoRow extends StatelessWidget {
  const InfoRow(this.k, this.v, {super.key, this.color});

  final String k;
  final String v;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 130,
              child: Text(k,
                  style: const TextStyle(color: VcsTheme.textDim, fontSize: 13))),
          Expanded(
              child: Text(v,
                  style:
                      TextStyle(color: color ?? Colors.white, fontSize: 13))),
        ]),
      );
}

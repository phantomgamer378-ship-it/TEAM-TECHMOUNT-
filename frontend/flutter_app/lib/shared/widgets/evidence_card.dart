import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../core/utils/risk_utils.dart';

/// Expandable "Why?" evidence card for progressive disclosure.
///
/// Shows a title + summary. Tapping expands to show the full evidence list.
/// Technical detail is hidden by default — users see human-readable labels first.
class EvidenceCard extends StatefulWidget {
  const EvidenceCard({
    super.key,
    required this.title,
    required this.evidenceLines,
    this.initiallyExpanded = false,
  });

  final String title;
  final List<String> evidenceLines;
  final bool initiallyExpanded;

  @override
  State<EvidenceCard> createState() => _EvidenceCardState();
}

class _EvidenceCardState extends State<EvidenceCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: VrColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VrColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, color: VrColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: VrColors.borderSubtle),
                  const SizedBox(height: 8),
                  for (final line in widget.evidenceLines)
                    _EvidenceLine(line: line),
                ],
              ),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

/// A single evidence line with optional source tag: [voice] text → parsed into colored tag + text.
class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^\[(\w+)\]\s*(.*)$').firstMatch(line);
    final tag = match != null ? match.group(1)! : 'info';
    final text = match != null ? match.group(2)! : line;
    final color = RiskUtils.sourceTagColor(tag);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(tag, style: VrTypography.caption.copyWith(color: color, fontSize: 10)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: VrTypography.bodySmall.copyWith(color: VrColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

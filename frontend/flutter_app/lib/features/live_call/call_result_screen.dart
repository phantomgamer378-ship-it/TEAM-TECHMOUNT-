import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../core/utils/risk_utils.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/risk_badge.dart';
import '../../shared/widgets/evidence_card.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Post-call incident summary — premium result screen.
class CallResultScreen extends StatelessWidget {
  const CallResultScreen({super.key, required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final risk = (result['risk'] as Map?)?.cast<String, dynamic>() ?? {};
    final score = risk['score'] as int? ?? 0;
    final level = risk['level']?.toString() ?? RiskUtils.level(score);
    final color = RiskUtils.levelColor(level);
    final scam = (result['scam_analysis'] as Map?)?.cast<String, dynamic>();
    final asr = (result['asr'] as Map?)?.cast<String, dynamic>();
    final attackTypes = (result['attack_types'] as List?)?.cast<String>() ?? [];
    final indicators = (scam?['indicators'] as List?)?.cast<String>() ?? [];
    final explanations = (result['explanation'] as List?)?.cast<String>() ?? [];
    final recommendation = result['recommendation']?.toString();
    final fallbackUsed = result['fallback_used'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Report'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Demo mode banner
          if (fallbackUsed) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VrColors.caution.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VrColors.caution.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: VrColors.caution, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo mode — simulated analysis',
                      style: VrTypography.caption.copyWith(color: VrColors.caution),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Risk score
          RiskBadge(score: score, level: level),
          const SizedBox(height: 20),

          // Human-readable verdict
          Center(
            child: Text(
              RiskUtils.humanLabel(score),
              style: VrTypography.sectionTitle.copyWith(color: color),
            ),
          ),
          const SizedBox(height: 24),

          // Attack type + language
          if (attackTypes.isNotEmpty) ...[
            Text('Attack type', style: VrTypography.label.copyWith(color: VrColors.textMuted)),
            const SizedBox(height: 8),
            AttackTags(types: attackTypes),
            const SizedBox(height: 16),
          ],

          if (asr != null) ...[
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Transcript', style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary)),
                      const Spacer(),
                      LanguageBadge(language: (asr['language'] ?? '?').toString().toUpperCase()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    asr['transcript']?.toString() ?? 'No transcript available',
                    style: VrTypography.body.copyWith(color: VrColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Detected indicators
          if (indicators.isNotEmpty) ...[
            Text('Detected indicators', style: VrTypography.label.copyWith(color: VrColors.textMuted)),
            const SizedBox(height: 8),
            IndicatorChips(indicators: indicators),
            const SizedBox(height: 16),
          ],

          // Why was this flagged?
          if (explanations.isNotEmpty)
            EvidenceCard(
              title: 'Why was this flagged?',
              evidenceLines: explanations,
            ),
          const SizedBox(height: 16),

          // Recommendation
          if (recommendation != null)
            PremiumCard(
              color: VrColors.critical.withValues(alpha: 0.05),
              borderColor: VrColors.critical.withValues(alpha: 0.2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: VrColors.critical, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(recommendation,
                        style: VrTypography.body.copyWith(color: VrColors.critical)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // CTAs
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VrColors.critical),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted (prototype)')),
              );
            },
            child: const Text('Report This Call'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
}

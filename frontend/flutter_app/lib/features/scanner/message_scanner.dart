import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../core/utils/risk_utils.dart';
import '../../services/api_client.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/risk_badge.dart';
import '../../shared/widgets/evidence_card.dart';
import '../../shared/widgets/shared_widgets.dart';

/// "Check a message." — message scanning experience.
class MessageScannerScreen extends StatefulWidget {
  const MessageScannerScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<MessageScannerScreen> createState() => _MessageScannerScreenState();
}

class _MessageScannerScreenState extends State<MessageScannerScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await widget.api.post('/api/analyze/message', {'text': text});
      if (mounted) setState(() => _result = r as Map<String, dynamic>);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message Scanner')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text('Check a message.',
              style: VrTypography.hero.copyWith(color: VrColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Paste a suspicious SMS or message to scan for threats.',
              style: VrTypography.body.copyWith(color: VrColors.textSecondary)),
          const SizedBox(height: 24),
          PremiumCard(
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  maxLines: 5,
                  style: const TextStyle(color: VrColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'पाठ संदेश यहाँ लिखें / paste the SMS here…',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _scan,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.bolt),
                  label: Text(_busy ? 'Scanning…' : 'Scan Message'),
                ),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _MessageResult(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _MessageResult extends StatelessWidget {
  const _MessageResult({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final risk = (result['risk'] as Map?)?.cast<String, dynamic>();
    if (risk == null) {
      return PremiumCard(
        child: Text('Analysis unavailable', style: VrTypography.body.copyWith(color: VrColors.textMuted)),
      );
    }
    final score = risk['score'] as int;
    final scam = (result['scam_analysis'] as Map?)?.cast<String, dynamic>();
    final indicators = (scam?['indicators'] as List?)?.cast<String>() ?? [];
    final attackTypes = (result['attack_types'] as List?)?.cast<String>() ?? [];
    final explanations = (result['explanation'] as List?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RiskBadge(score: score, level: risk['level']?.toString()),
        const SizedBox(height: 16),
        if (indicators.isNotEmpty) ...[
          IndicatorChips(indicators: indicators),
          const SizedBox(height: 12),
        ],
        if (attackTypes.isNotEmpty) ...[
          AttackTags(types: attackTypes),
          const SizedBox(height: 12),
        ],
        if (explanations.isNotEmpty)
          EvidenceCard(title: 'Why?', evidenceLines: explanations),
        if (result['recommendation'] != null) ...[
          const SizedBox(height: 12),
          PremiumCard(
            color: VrColors.caution.withValues(alpha: 0.05),
            borderColor: VrColors.caution.withValues(alpha: 0.2),
            child: Text('⚠ ${result['recommendation']}',
                style: VrTypography.body.copyWith(color: VrColors.caution)),
          ),
        ],
      ],
    );
  }
}

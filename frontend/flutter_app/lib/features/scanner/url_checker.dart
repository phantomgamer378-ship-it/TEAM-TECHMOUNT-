import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../services/api_client.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/risk_badge.dart';
import '../../shared/widgets/evidence_card.dart';
import '../../shared/widgets/shared_widgets.dart';

/// "Check before you tap." — URL checking experience.
class UrlCheckerScreen extends StatefulWidget {
  const UrlCheckerScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<UrlCheckerScreen> createState() => _UrlCheckerScreenState();
}

class _UrlCheckerScreenState extends State<UrlCheckerScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await widget.api.post('/api/analyze/url', {'url': url});
      if (mounted) setState(() => _result = r as Map<String, dynamic>);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('URL Checker')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text('Check before\nyou tap.',
              style: VrTypography.hero.copyWith(color: VrColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Paste a suspicious URL to check for threats.',
              style: VrTypography.body.copyWith(color: VrColors.textSecondary)),
          const SizedBox(height: 24),
          PremiumCard(
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  style: const TextStyle(color: VrColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'https://example.com/verify…',
                    prefixIcon: Icon(Icons.link, color: VrColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _check,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: Text(_busy ? 'Checking…' : 'Check Link'),
                ),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _UrlResult(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _UrlResult extends StatelessWidget {
  const _UrlResult({required this.result});
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
    final urlAnalysis = (result['url_analysis'] as Map?)?.cast<String, dynamic>();
    final reasons = (urlAnalysis?['reasons'] as List?)?.cast<String>() ?? [];
    final explanations = (result['explanation'] as List?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RiskBadge(score: score, level: risk['level']?.toString()),
        const SizedBox(height: 16),
        if (urlAnalysis != null) ...[
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoRow('Domain', urlAnalysis['domain']?.toString() ?? '?'),
                InfoRow('Status', urlAnalysis['status']?.toString() ?? '?'),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (reasons.isNotEmpty)
          EvidenceCard(title: 'Threat details', evidenceLines: reasons),
        if (explanations.isNotEmpty) ...[
          const SizedBox(height: 12),
          EvidenceCard(title: 'Why?', evidenceLines: explanations),
        ],
        const SizedBox(height: 16),
        if (score >= 70) ...[
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VrColors.critical),
            onPressed: () => Navigator.pop(context),
            child: const Text("Don't Open"),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

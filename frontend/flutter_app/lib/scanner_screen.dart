import 'package:flutter/material.dart';

import 'api_client.dart';
import 'vcs_theme.dart';
import 'widgets.dart';

/// Message Scanner + URL Checker (§10) — simple form + result, reusing the
/// shared AnalysisResultView renderer.
class ScannerView extends StatefulWidget {
  const ScannerView({super.key, required this.api});

  final ApiClient api;

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  final _controller = TextEditingController();
  bool _urlMode = false;
  bool _busy = false;
  Map<String, dynamic>? _messageResult;
  Map<String, dynamic>? _urlResult;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      if (_urlMode) {
        _urlResult = await widget.api.post('/api/analyze/url', {'url': text});
      } else {
        _messageResult =
            await widget.api.post('/api/analyze/message', {'text': text});
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic>? get _result => _urlMode ? _urlResult : _messageResult;

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Message'), icon: Icon(Icons.sms)),
            ButtonSegment(value: true, label: Text('URL'), icon: Icon(Icons.link)),
          ],
          selected: {_urlMode},
          onSelectionChanged: (s) => setState(() {
            _urlMode = s.first;
            _controller.clear();
          }),
        ),
        const SizedBox(height: 14),
        Panel(
          title: _urlMode ? 'Check a URL' : 'Scan a message',
          child: Column(children: [
            TextField(
              controller: _controller,
              maxLines: _urlMode ? 1 : 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                  hintText: _urlMode
                      ? 'http://192.168.4.22/sbi/kyc/verify'
                      : 'पाठ संदेश यहाँ लिखें / paste the SMS here…'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bolt),
                label: Text(_urlMode ? 'Check URL' : 'Scan message'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (r != null)
          Panel(title: 'Result', child: _ScannerResult(result: r)),
      ],
    );
  }
}

/// Renders the message/URL response shapes (slightly different field names
/// from the audio response — handled explicitly, never guessed).
class _ScannerResult extends StatelessWidget {
  const _ScannerResult({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    if (result['risk'] == null) {
      return PrototypeBanner(
          note: 'Analysis unavailable: ${result['error'] ?? 'unknown'}');
    }
    final risk = (result['risk'] as Map).cast<String, dynamic>();
    final scam = (result['scam_analysis'] as Map?)?.cast<String, dynamic>();
    final urlAnalysis =
        (result['url_analysis'] as Map?)?.cast<String, dynamic>();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RiskBadge(score: risk['score'] as int, level: risk['level'] as String),
      const SizedBox(height: 10),
      if (scam != null) ...[
        InfoRow('Category', scam['category']?.toString() ?? '?'),
        InfoRow(
            'Scam risk', (scam['risk'] ?? 0).toStringAsFixed(2)),
        if ((scam['indicators'] as List?)?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          IndicatorChips(
              indicators: (scam['indicators'] as List).cast<String>()),
        ],
      ],
      if (urlAnalysis != null)
        for (final reason in (urlAnalysis['reasons'] as List? ??
            []).cast<String>())
          ExplanationTile(line: reason),
      if ((result['attack_types'] as List?)?.isNotEmpty == true) ...[
        const SizedBox(height: 8),
        AttackTags(types: (result['attack_types'] as List).cast<String>()),
      ],
      const SizedBox(height: 10),
      InfoRow('Policy action', result['policy_action']?.toString() ?? '?'),
      for (final e in (result['explanation'] as List? ?? [])
          .cast<String>())
        ExplanationTile(line: e),
      if (result['recommendation'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('⚠ ${result['recommendation']}',
              style: const TextStyle(color: VcsTheme.warn, fontSize: 13)),
        ),
    ]);
  }
}

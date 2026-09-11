import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'vcs_theme.dart';
import 'widgets.dart';

/// Risk(t) line chart — the dynamic-risk demo moment (§DYNAMIC RISK SCORE).
/// One point per streamed second; tier bands drawn as reference lines.
class RiskTimelineChart extends StatelessWidget {
  const RiskTimelineChart({super.key, required this.scores, this.height = 180});

  final List<int> scores;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
            child: Text('waiting for risk updates…',
                style: TextStyle(color: VcsTheme.textDim))),
      );
    }
    final spots = <FlSpot>[
      for (var i = 0; i < scores.length; i++) FlSpot(i.toDouble(), scores[i].toDouble()),
    ];
    final last = scores.last;
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: VcsTheme.cardAlt, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  interval: 20,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style:
                          const TextStyle(color: VcsTheme.textDim, fontSize: 10))),
            ),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  interval: scores.length > 10 ? 5 : 1,
                  reservedSize: 20,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}s',
                      style:
                          const TextStyle(color: VcsTheme.textDim, fontSize: 10))),
            ),
          ),
          // Prototype policy bands (§POLICY): 40 MEDIUM, 70 HIGH, 85 CRITICAL.
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(
                y: 40,
                color: VcsTheme.warn.withValues(alpha: 0.35),
                strokeWidth: 1,
                dashArray: [4, 4]),
            HorizontalLine(
                y: 70,
                color: VcsTheme.high.withValues(alpha: 0.35),
                strokeWidth: 1,
                dashArray: [4, 4]),
            HorizontalLine(
                y: 85,
                color: VcsTheme.danger.withValues(alpha: 0.35),
                strokeWidth: 1,
                dashArray: [4, 4]),
          ]),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              barWidth: 2.5,
              color: VcsTheme.levelColor(_band(last)),
              dotData: FlDotData(show: scores.length <= 20),
              belowBarData: BarAreaData(
                show: true,
                color: VcsTheme.accent.withValues(alpha: 0.08),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem('${s.y.round()}/100',
                      const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _band(int score) {
    if (score < 40) return 'LOW';
    if (score < 70) return 'MEDIUM';
    if (score < 85) return 'HIGH';
    return 'CRITICAL';
  }
}

/// The big result card shared by audio/message/url analysis screens.
class AnalysisResultView extends StatelessWidget {
  const AnalysisResultView({super.key, this.result});

  final Map<String, dynamic>? result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const SizedBox.shrink();

    // Hard rule: a bare fallback shape renders as a soft banner, never a
    // crash or a raw error screen.
    if (r['risk'] == null) {
      return Column(children: [
        PrototypeBanner(
            note: 'Analysis unavailable: ${r['error'] ?? 'unknown error'}'),
      ]);
    }

    final risk = (r['risk'] as Map).cast<String, dynamic>();
    final fallbackUsed = r['fallback_used'] == true;
    final voice = (r['voice_trust'] as Map?)?.cast<String, dynamic>();
    final asr = (r['asr'] as Map?)?.cast<String, dynamic>();
    final scam = (r['scam_analysis'] as Map?)?.cast<String, dynamic>();
    final liveness = (r['liveness'] as Map?)?.cast<String, dynamic>();
    final timeline = (r['risk_timeline'] as List?)
            ?.map((e) => ((e as Map)['risk_score'] ?? 0) as int)
            .toList() ??
        const <int>[];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (fallbackUsed)
        PrototypeBanner(note: r['error']?.toString()),
      const SizedBox(height: 8),
      RiskBadge(
          score: risk['score'] as int, level: risk['level'] as String),
      const SizedBox(height: 12),
      RiskTimelineChart(scores: timeline),
      const SizedBox(height: 12),
      if (voice != null)
        InfoRow('Voice trust',
            'spoof ${(voice['spoof_risk'] ?? 0).toStringAsFixed(2)} — ${voice['status'] ?? '?'}',
            color: VcsTheme.levelColor(voice['status'] == 'SUSPICIOUS' ? 'HIGH' : 'LOW')),
      if (asr != null) ...[
        InfoRow('Language', ((asr['language'] ?? '?') as String).toUpperCase()),
        InfoRow('Transcript', asr['transcript']?.toString() ?? ''),
      ],
      if (scam != null)
        InfoRow('Scam intent',
            'risk ${(scam['risk'] ?? 0).toStringAsFixed(2)} — ${scam['category'] ?? '?'}'),
      if ((r['attack_types'] as List?)?.isNotEmpty == true) ...[
        const SizedBox(height: 8),
        AttackTags(types: (r['attack_types'] as List).cast<String>()),
      ],
      if ((scam?['indicators'] as List?)?.isNotEmpty == true) ...[
        const SizedBox(height: 8),
        IndicatorChips(
            indicators: (scam!['indicators'] as List).cast<String>()),
      ],
      if (liveness?['required'] == true) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VcsTheme.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VcsTheme.danger),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🔐 LIVENESS VERIFICATION REQUIRED',
                style: TextStyle(
                    color: VcsTheme.danger, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Ask the caller to say: "${liveness!['challenge']}"',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 4),
            const Text(
                'Prototype check — text match only; does not defeat cloning (§9).',
                style: TextStyle(color: VcsTheme.textDim, fontSize: 11)),
          ]),
        ),
      ],
      if ((r['explanation'] as List?)?.isNotEmpty == true) ...[
        const SizedBox(height: 12),
        const Text('Why this verdict (explainable evidence)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        for (final e in (r['explanation'] as List).cast<String>())
          ExplanationTile(line: e),
      ],
      if (r['recommendation'] != null) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VcsTheme.warn.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('⚠ ${r['recommendation']}',
              style: const TextStyle(color: VcsTheme.warn, fontSize: 13)),
        ),
      ],
    ]);
  }
}

/// Helper used by History rows: pretty-print a stored result summary.
String historyLine(Map<String, dynamic> row) {
  final level = row['risk_level'] ?? '?';
  final score = row['risk_score'] ?? '?';
  final lang = row['language'] ?? '?';
  return '$score/100 $level · $lang';
}

/// base64 helpers (kept local to avoid extra deps).
String b64Encode(List<int> bytes) => base64Encode(bytes);

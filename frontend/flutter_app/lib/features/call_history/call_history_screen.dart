import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../core/utils/risk_utils.dart';
import '../../services/api_client.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/risk_badge.dart';
import '../live_call/live_call_screen.dart';

/// Timeline-style call history with large risk indicators and filters.
class VrCallHistoryScreen extends StatefulWidget {
  const VrCallHistoryScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<VrCallHistoryScreen> createState() => _VrCallHistoryScreenState();
}

class _VrCallHistoryScreenState extends State<VrCallHistoryScreen> {
  late Future<Map<String, dynamic>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    try {
      final r = await widget.api.get('/api/history', {'limit': '50'});
      return (r as Map).cast<String, dynamic>();
    } catch (_) {
      throw Exception('unreachable');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: VrColors.primary,
      onRefresh: () async => setState(() => _future = _load()),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: VrColors.primary));
          }
          if (snap.hasError) {
            return _emptyState(
                'Backend unreachable',
                'Is the server running on ${widget.api.baseUrl}?');
          }
          final items = (snap.data?['history'] as List?) ?? [];
          if (items.isEmpty) {
            return _emptyState(
                'No analyses yet',
                'Run a Call Analysis or Scan to see activity here.');
          }

          // Apply filter
          final filtered = items.cast<Map<String, dynamic>>().where((row) {
            if (_filter == 'all') return true;
            final level = row['risk_level']?.toString() ?? '';
            if (_filter == 'high') return level == 'HIGH' || level == 'CRITICAL';
            if (_filter == 'safe') return level == 'LOW';
            return true;
          }).toList();

          return Scaffold(
            backgroundColor: Colors.transparent, // Let parent handle bg, or use VrColors.bg
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), // extra padding for FAB
              children: [
                Text('Threat History',
                    style: VrTypography.sectionTitle.copyWith(color: VrColors.textPrimary)),
                const SizedBox(height: 16),
                // Filters
                Row(
                  children: [
                    _FilterChip(label: 'All', active: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all')),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'High Risk', active: _filter == 'high',
                        onTap: () => setState(() => _filter = 'high')),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Safe', active: _filter == 'safe',
                        onTap: () => setState(() => _filter = 'safe')),
                  ],
                ),
                const SizedBox(height: 16),
                // History items
                for (var i = 0; i < filtered.length; i++) ...[
                  _HistoryCard(row: filtered[i]),
                  if (i < filtered.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 24),
                Center(
                  child: Text('🔒 Audio is never stored — metadata + results only',
                      style: VrTypography.caption.copyWith(color: VrColors.textMuted)),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LiveCallScreen(api: widget.api)),
                );
              },
              backgroundColor: VrColors.primary,
              foregroundColor: VrColors.bg,
              icon: const Icon(Icons.shield),
              label: const Text('Simulate Call', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.history, size: 64, color: VrColors.textMuted.withValues(alpha: 0.3)),
        const SizedBox(height: 24),
        Text(title, textAlign: TextAlign.center,
            style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary)),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center,
            style: VrTypography.body.copyWith(color: VrColors.textMuted)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? VrColors.primary.withValues(alpha: 0.12) : VrColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? VrColors.primary : VrColors.borderSubtle),
        ),
        child: Text(label,
            style: VrTypography.label.copyWith(
                color: active ? VrColors.primary : VrColors.textMuted)),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final level = row['risk_level']?.toString() ?? '?';
    final score = row['risk_score'] ?? 0;
    final color = RiskUtils.levelColor(level);
    final attacks = (row['attack_types'] as List?)?.join(', ') ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VrColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          RiskBadgeSmall(score: score as int, level: level),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$level · ${row['language'] ?? '?'}',
                    style: VrTypography.label.copyWith(color: VrColors.textPrimary)),
                if (attacks.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(attacks,
                      style: VrTypography.caption.copyWith(color: VrColors.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Text('${row['created_at'] ?? ''}',
                    style: VrTypography.caption.copyWith(color: VrColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

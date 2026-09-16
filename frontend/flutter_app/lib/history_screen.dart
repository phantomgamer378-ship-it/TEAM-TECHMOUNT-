import 'package:flutter/material.dart';

import 'api_client.dart';

import 'vcs_theme.dart';

/// Threat History (§16) — persisted analysis results from GET /api/history.
/// Privacy note shown inline: raw audio is never stored (§PRIVACY-FIRST).
class HistoryView extends StatefulWidget {
  const HistoryView({super.key, required this.api});

  final ApiClient api;

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final r = await widget.api.get('/api/history', {'limit': '50'});
    // A bare fallback shape (e.g. DB unavailable) also lands here.
    return (r as Map).cast<String, dynamic>();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _future = _load()),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: VcsTheme.accent));
          }
          if (snap.hasError) {
            return _center('backend unreachable — is the server running on ${widget.api.baseUrl}?');
          }
          final data = snap.data ?? {};
          final items = (data['history'] as List?) ?? [];
          if (items.isEmpty) {
            return _center('no analyses yet — run the Call Analysis screen first');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final row = (items[i] as Map).cast<String, dynamic>();
              final level = row['risk_level']?.toString() ?? '?';
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VcsTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: VcsTheme.levelColor(level).withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: VcsTheme.levelColor(level).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${row['risk_score'] ?? '?'}',
                        style: TextStyle(
                            color: VcsTheme.levelColor(level),
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$level · ${row['language'] ?? '?'}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                              (row['attack_types'] as List?)
                                      ?.join(', ') ??
                                  '',
                              style: const TextStyle(
                                  color: VcsTheme.textDim, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                              '${row['created_at'] ?? ''} · session ${row['session_id'] ?? ''}',
                              style: const TextStyle(
                                  color: VcsTheme.textDim, fontSize: 10)),
                        ]),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _center(String msg) => ListView(children: [
        const SizedBox(height: 120),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VcsTheme.textDim)),
        ),
        const SizedBox(height: 24),
        const Center(
            child: Text('🔒 audio is never stored — metadata + results only',
                style: TextStyle(color: VcsTheme.textDim, fontSize: 11))),
      ]);
}


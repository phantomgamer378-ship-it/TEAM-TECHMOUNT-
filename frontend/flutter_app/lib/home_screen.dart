import 'package:flutter/material.dart';

import 'api_client.dart';
import 'vcs_theme.dart';
import 'widgets.dart';

/// Dashboard — system health at a glance.
class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.api});

  final ApiClient api;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late Future<Map<String, dynamic>> _health;
  late Future<Map<String, dynamic>> _profiles;

  @override
  void initState() {
    super.initState();
    _health = _checkHealth();
    _profiles = _loadProfiles();
  }

  Future<Map<String, dynamic>> _checkHealth() async {
    try {
      final r = await widget.api.get('/api/health');
      return (r as Map).cast<String, dynamic>();
    } catch (e) {
      throw Exception('unreachable');
    }
  }

  Future<Map<String, dynamic>> _loadProfiles() async {
    try {
      final r = await widget.api.get('/api/voice-profiles');
      return (r as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---------------------------------------------------- health card
        FutureBuilder<Map<String, dynamic>>(
          future: _health,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Panel(
                title: 'System status',
                child: Text('checking backend…',
                    style: TextStyle(color: VcsTheme.textDim)),
              );
            }
            if (snap.hasError) {
              return Panel(
                title: 'System status',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠ Backend unreachable',
                          style: TextStyle(
                              color: VcsTheme.danger,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(widget.api.baseUrl,
                          style: const TextStyle(color: VcsTheme.textDim)),
                      const SizedBox(height: 6),
                      const Text(
                          'Start it: cd backend && uvicorn app.main:app --host 0.0.0.0 --port 8000\n'
                          'Android emulator → use 10.0.2.2:8000 · phone → your Mac LAN IP (⚙).',
                          style:
                              TextStyle(color: VcsTheme.textDim, fontSize: 11)),
                    ]),
              );
            }
            final d = snap.data!;
            final services = (d['services'] as Map).cast<String, dynamic>();
            Widget dot(Object v) {
              final s = v.toString();
              final color = s == 'loaded'
                  ? VcsTheme.good
                  : s == 'demo_mode'
                      ? VcsTheme.warn
                      : VcsTheme.accent;
              return Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]
                    )),
                const SizedBox(width: 6),
                Text(s,
                    style: TextStyle(color: color, fontSize: 12)),
              ]);
            }

            return Panel(
              title: 'System status',
              trailing: IconButton(
                icon: const Icon(Icons.refresh, color: VcsTheme.accent),
                onPressed: () =>
                    setState(() => _health = _checkHealth()),
              ),
              child: Column(children: [
                InfoRow('API', 'online · v${d['version'] ?? '?'}'),
                InfoRow('Database', d['database']?.toString() ?? '?'),
                InfoRow('Privacy mode',
                    d['privacy_mode'] == true ? 'on (audio never stored)' : 'off',
                    color: VcsTheme.good),
                const Divider(color: VcsTheme.cardAlt),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    for (final e in services.entries)
                      ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 110),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.key,
                                    style: const TextStyle(
                                        color: VcsTheme.textDim,
                                        fontSize: 10)),
                                dot(e.value),
                              ])),
                  ],
                ),
              ]),
            );
          },
        ),
        const SizedBox(height: 16),
        
        // ---------------------------------------------------- trusted contacts stub
        FutureBuilder<Map<String, dynamic>>(
          future: _profiles,
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final profiles = (snap.data!['profiles'] as List?) ?? [];
            return Panel(
              title: '👥 Trusted Contacts (Stub)',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Voice profile enrollment — coming in v2.\n'
                      'The real flow is on the research roadmap; identity alone never proves identity.',
                      style: TextStyle(color: VcsTheme.warn, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    if (profiles.isEmpty)
                      const Text('none yet', style: TextStyle(color: VcsTheme.textDim))
                    else
                      for (final p in profiles.cast<Map<String, dynamic>>())
                        InfoRow(
                            p['label']?.toString() ?? '?',
                            'embedding: ${p['embedding_status'] ?? '—'} · '
                            '${p['created_at'] ?? ''}'),
                  ]),
            );
          },
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'PROTOTYPE — recorded/uploaded audio · no telephony interception\n'
            'deepfake model: pretrained baseline, not yet evaluated on Indian-language speech',
            textAlign: TextAlign.center,
            style: TextStyle(color: VcsTheme.textDim, fontSize: 10),
          ),
        ),
      ],
    );
  }
}


import 'package:flutter/material.dart';

import 'api_client.dart';
import 'call_analysis_screen.dart';
import 'history_screen.dart';
import 'scanner_screen.dart';
import 'vcs_theme.dart';
import 'widgets.dart';

/// Home/Dashboard — system health at a glance + navigation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> _health;
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.api.baseUrl;
    _health = _check();
  }

  Future<Map<String, dynamic>> _check() async {
    try {
      final r = await widget.api.get('/api/health');
      return (r as Map).cast<String, dynamic>();
    } catch (e) {
      throw Exception('unreachable');
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ Voice Clone Shield'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: ListView(
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
                          color: color, shape: BoxShape.circle)),
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
                      setState(() => _health = _check()),
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

          // ---------------------------------------------------- quick actions
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _ActionCard(
                  icon: Icons.call,
                  title: 'Call Analysis',
                  subtitle: 'live risk timeline',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CallAnalysisScreen(api: widget.api)))),
              _ActionCard(
                  icon: Icons.search,
                  title: 'Scanners',
                  subtitle: 'message + URL',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ScannerScreen(api: widget.api)))),
              _ActionCard(
                  icon: Icons.history,
                  title: 'Threat History',
                  subtitle: 'past analyses',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              HistoryScreen(api: widget.api)))),
              _ActionCard(
                  icon: Icons.contacts,
                  title: 'Trusted Contacts',
                  subtitle: 'stub — v2',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              TrustedContactsScreen(api: widget.api)))),
            ],
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'PROTOTYPE — recorded/uploaded audio · no telephony interception\n'
              'deepfake model: pretrained baseline, not yet evaluated on Indian-language speech',
              textAlign: TextAlign.center,
              style: TextStyle(color: VcsTheme.textDim, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettings(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VcsTheme.card,
        title: const Text('Backend URL',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: _urlController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'http://192.168.43.73:8000'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ApiClient.saveBaseUrl(_urlController.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              widget.api.baseUrl = _urlController.text.trim();
              setState(() => _health = _check());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: VcsTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VcsTheme.cardAlt),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: VcsTheme.accent, size: 28),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(
                      color: VcsTheme.textDim, fontSize: 11)),
            ],
          ),
        ),
      );
}

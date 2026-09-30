import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../services/api_client.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/protection_status.dart';
import '../live_call/live_call_screen.dart';
import '../scanner/message_scanner.dart';
import '../scanner/url_checker.dart';

/// Home screen — editorial layout with protection status and quick actions.
class VrHomeScreen extends StatefulWidget {
  const VrHomeScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<VrHomeScreen> createState() => _VrHomeScreenState();
}

class _VrHomeScreenState extends State<VrHomeScreen> {
  bool _backendOnline = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    try {
      await widget.api.get('/v1/health');
      if (mounted) setState(() { _backendOnline = true; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _backendOnline = false; _loading = false; });
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning.';
    if (h < 17) return 'Good afternoon.';
    return 'Good evening.';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // ── Greeting ──
        Text(
          _greeting(),
          style: VrTypography.hero.copyWith(color: VrColors.textPrimary),
        ),
        const SizedBox(height: 24),

        // ── Protection status hero ──
        ProtectionStatus(
          isActive: _backendOnline,
          message: _loading
              ? 'Connecting to protection services…'
              : _backendOnline
                  ? null
                  : 'Backend unreachable. Tap ⚙ to set the server URL.',
        ),
        const SizedBox(height: 24),

        // ── Call Protection card ──
        PremiumCard(
          color: VrColors.primary.withValues(alpha: 0.06),
          borderColor: VrColors.primary.withValues(alpha: 0.2),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => LiveCallScreen(api: widget.api))),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VrColors.primary.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.phone_in_talk, color: VrColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Call Protection',
                        style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Analyze a call or start a simulated demo',
                        style: VrTypography.bodySmall.copyWith(color: VrColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: VrColors.textMuted, size: 16),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Quick actions row ──
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.chat_bubble_outline,
                label: 'Scan Message',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => MessageScannerScreen(api: widget.api))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickAction(
                icon: Icons.link,
                label: 'Check Link',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => UrlCheckerScreen(api: widget.api))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // ── Recent activity ──
        Text(
          'Recent activity',
          style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          child: Column(
            children: [
              _ActivityItem(
                icon: Icons.phone_missed,
                title: 'No recent analyses',
                subtitle: 'Start a call analysis or scan to see activity here.',
                color: VrColors.textMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ── Privacy note ──
        Center(
          child: Text(
            '🔒 Audio is processed but never stored.',
            style: VrTypography.caption.copyWith(color: VrColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: VrColors.primary, size: 28),
          const SizedBox(height: 10),
          Text(label,
              style: VrTypography.label.copyWith(color: VrColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: VrTypography.label.copyWith(color: VrColors.textPrimary)),
              Text(subtitle, style: VrTypography.caption.copyWith(color: VrColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

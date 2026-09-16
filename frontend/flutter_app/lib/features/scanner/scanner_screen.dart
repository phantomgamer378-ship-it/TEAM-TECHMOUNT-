import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../services/api_client.dart';
import 'message_scanner.dart';
import 'url_checker.dart';

/// Scanner tab — entry point for Message Scanner and URL Checker.
class VrScannerScreen extends StatelessWidget {
  const VrScannerScreen({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text('Scan for threats.',
            style: VrTypography.sectionTitle.copyWith(color: VrColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Check suspicious messages or links before interacting.',
            style: VrTypography.body.copyWith(color: VrColors.textSecondary)),
        const SizedBox(height: 24),

        _ScanOption(
          icon: Icons.chat_bubble_outline,
          title: 'Message Scanner',
          subtitle: 'Paste an SMS or message to check for scam patterns.',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => MessageScannerScreen(api: api))),
        ),
        const SizedBox(height: 12),
        _ScanOption(
          icon: Icons.link,
          title: 'URL Checker',
          subtitle: 'Paste a link to check for phishing or malicious domains.',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => UrlCheckerScreen(api: api))),
        ),
      ],
    );
  }
}

class _ScanOption extends StatelessWidget {
  const _ScanOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: VrColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VrColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VrColors.primary.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: VrColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: VrTypography.bodySmall.copyWith(color: VrColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: VrColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}

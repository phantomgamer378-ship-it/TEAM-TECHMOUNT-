import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../services/api_client.dart';
import '../../shared/widgets/premium_card.dart';

/// Profile & Settings screen.
class VrProfileScreen extends StatefulWidget {
  const VrProfileScreen({super.key, required this.api, required this.onUrlChanged});

  final ApiClient api;
  final VoidCallback onUrlChanged;

  @override
  State<VrProfileScreen> createState() => _VrProfileScreenState();
}

class _VrProfileScreenState extends State<VrProfileScreen> {
  Future<void> _showSettings(BuildContext context) async {
    final controller = TextEditingController(text: widget.api.baseUrl);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VrColors.surface,
        title: Text('Backend URL', style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: VrColors.textPrimary),
          decoration: const InputDecoration(hintText: 'http://192.168.1.100:8000'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ApiClient.saveBaseUrl(controller.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              widget.api.baseUrl = controller.text.trim();
              widget.onUrlChanged();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VrColors.primary.withValues(alpha: 0.1),
                border: Border.all(color: VrColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.person, color: VrColors.primary, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Protection',
                      style: VrTypography.sectionTitle.copyWith(color: VrColors.textPrimary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: VrColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('ACTIVE',
                        style: VrTypography.caption.copyWith(color: VrColors.primary, letterSpacing: 1.2)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Settings Groups
        _SettingsGroup(
          title: 'Protection',
          items: [
            _SettingsItem(
              icon: Icons.wifi,
              title: 'Backend Connection',
              subtitle: widget.api.baseUrl,
              onTap: () => _showSettings(context),
            ),
            _SettingsItem(
              icon: Icons.notifications_active,
              title: 'Alerts & Notifications',
              subtitle: 'Push notifications active',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsGroup(
          title: 'Privacy',
          items: [
            _SettingsItem(
              icon: Icons.lock_outline,
              title: 'Privacy Mode',
              subtitle: 'ON — Audio is never stored',
              onTap: () {},
              trailing: Switch(
                value: true,
                onChanged: (v) {},
                activeColor: VrColors.primary,
              ),
            ),
            _SettingsItem(
              icon: Icons.data_usage,
              title: 'Data Retention',
              subtitle: 'Minimal',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsGroup(
          title: 'Support',
          items: [
            _SettingsItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.info_outline,
              title: 'About VANIRAKSHAK',
              subtitle: 'Version 1.0.0',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.items});
  final String title;
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(title, style: VrTypography.label.copyWith(color: VrColors.textMuted)),
        ),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  const Divider(color: VrColors.borderSubtle, height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: VrColors.textMuted, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: VrTypography.body.copyWith(color: VrColors.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: VrTypography.caption.copyWith(color: VrColors.textMuted)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              const Icon(Icons.arrow_forward_ios, color: VrColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../shared/widgets/premium_card.dart';

/// Reports screen — personal security center.
class VrReportsScreen extends StatelessWidget {
  const VrReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text('Your security report',
            style: VrTypography.sectionTitle.copyWith(color: VrColors.textPrimary)),
        const SizedBox(height: 24),

        // Stats row
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '14',
                label: 'Calls analyzed',
                color: VrColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                value: '3',
                label: 'Threats detected',
                color: VrColors.highRisk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PremiumCard(
          color: VrColors.primary.withValues(alpha: 0.05),
          borderColor: VrColors.primary.withValues(alpha: 0.2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('92%', style: VrTypography.hero.copyWith(color: VrColors.primary)),
                  const SizedBox(height: 4),
                  Text('Threat avoidance rate',
                      style: VrTypography.label.copyWith(color: VrColors.textMuted)),
                ],
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VrColors.primary.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.security, color: VrColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        Text('Threat activity',
            style: VrTypography.cardTitle.copyWith(color: VrColors.textPrimary)),
        const SizedBox(height: 12),
        PremiumCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Bar(height: 40, label: 'Mon'),
                  _Bar(height: 20, label: 'Tue'),
                  _Bar(height: 60, label: 'Wed', isHigh: true),
                  _Bar(height: 10, label: 'Thu'),
                  _Bar(height: 30, label: 'Fri'),
                  _Bar(height: 80, label: 'Sat', isHigh: true),
                  _Bar(height: 20, label: 'Sun'),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: VrColors.borderSubtle),
              const SizedBox(height: 12),
              Text('Most threats occur on weekends. Stay alert.',
                  style: VrTypography.caption.copyWith(color: VrColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Text(value, style: VrTypography.hero.copyWith(color: color)),
          const SizedBox(height: 8),
          Text(label, style: VrTypography.label.copyWith(color: VrColors.textMuted)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.label, this.isHigh = false});
  final double height;
  final String label;
  final bool isHigh;

  @override
  Widget build(BuildContext context) {
    final color = isHigh ? VrColors.highRisk : VrColors.primary;
    return Column(
      children: [
        Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: VrTypography.caption.copyWith(color: VrColors.textMuted)),
      ],
    );
  }
}

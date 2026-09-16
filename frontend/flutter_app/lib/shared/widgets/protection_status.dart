import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';

/// Hero "Protection Active" status widget with shield icon and breathing glow.
class ProtectionStatus extends StatefulWidget {
  const ProtectionStatus({super.key, this.isActive = true, this.message});

  final bool isActive;
  final String? message;

  @override
  State<ProtectionStatus> createState() => _ProtectionStatusState();
}

class _ProtectionStatusState extends State<ProtectionStatus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VrColors.surfaceAlt,
            VrColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VrColors.borderSubtle),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VrColors.primary.withValues(alpha: 0.1 * _pulseAnimation.value),
                border: Border.all(
                  color: VrColors.primary.withValues(alpha: 0.3 * _pulseAnimation.value),
                  width: 2,
                ),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: VrColors.primary.withValues(alpha: 0.15 * _pulseAnimation.value),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                widget.isActive ? Icons.shield : Icons.shield_outlined,
                color: widget.isActive ? VrColors.primary : VrColors.textMuted,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.isActive ? 'PROTECTION ACTIVE' : 'PROTECTION INACTIVE',
            style: VrTypography.overline.copyWith(
              color: widget.isActive ? VrColors.primary : VrColors.textMuted,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.message ??
                (widget.isActive
                    ? 'VANIRAKSHAK is watching for suspicious\ncalls, messages and links.'
                    : 'Connect to the backend to start protection.'),
            textAlign: TextAlign.center,
            style: VrTypography.bodySmall.copyWith(color: VrColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

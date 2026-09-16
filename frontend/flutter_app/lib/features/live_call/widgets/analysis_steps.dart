import 'package:flutter/material.dart';
import '../../../core/theme/vr_colors.dart';
import '../../../core/theme/vr_typography.dart';

/// Analysis pipeline steps — shows the human-readable stages of the pipeline.
///
/// Listening ✓ → Understanding ✓ → Checking voice ✓ → Checking intent → Calculating risk…
class AnalysisSteps extends StatelessWidget {
  const AnalysisSteps({super.key, required this.currentStage});

  /// One of: 'idle', 'listening', 'understanding', 'checking_voice', 'checking_intent', 'calculating', 'done'
  final String currentStage;

  static const _stages = [
    ('listening', 'Listening', Icons.hearing),
    ('understanding', 'Understanding', Icons.psychology),
    ('checking_voice', 'Checking voice', Icons.record_voice_over),
    ('checking_intent', 'Checking intent', Icons.search),
    ('calculating', 'Calculating risk', Icons.analytics),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _stages.indexWhere((s) => s.$1 == currentStage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _stages.length; i++)
          _StepRow(
            label: _stages[i].$2,
            icon: _stages[i].$3,
            state: i < currentIdx
                ? _StepState.done
                : i == currentIdx
                    ? _StepState.active
                    : _StepState.pending,
            isLast: i == _stages.length - 1,
          ),
      ],
    );
  }
}

enum _StepState { pending, active, done }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.icon,
    required this.state,
    required this.isLast,
  });

  final String label;
  final IconData icon;
  final _StepState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => VrColors.primary,
      _StepState.active => VrColors.primarySoft,
      _StepState.pending => VrColors.textMuted,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state == _StepState.done
                  ? VrColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(
              state == _StepState.done ? Icons.check : icon,
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          // Label
          Expanded(
            child: Text(
              label,
              style: VrTypography.body.copyWith(
                color: color,
                fontWeight: state == _StepState.active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          // Active spinner
          if (state == _StepState.active)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(VrColors.primary),
              ),
            ),
          if (state == _StepState.done)
            Text('✓', style: TextStyle(color: VrColors.primary, fontSize: 14)),
        ],
      ),
    );
  }
}

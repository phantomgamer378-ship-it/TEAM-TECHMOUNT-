import 'package:flutter/material.dart';
import '../theme/vr_colors.dart';

/// Risk utility functions — maps scores to human-readable levels and colors.
class RiskUtils {
  RiskUtils._();

  /// Score → risk level string.
  static String level(int score) {
    if (score < 30) return 'LOW';
    if (score < 50) return 'GUARDED';
    if (score < 70) return 'SUSPICIOUS';
    if (score < 85) return 'HIGH';
    return 'CRITICAL';
  }

  /// Score → human-readable label (no jargon).
  static String humanLabel(int score) {
    if (score < 30) return 'Looks safe';
    if (score < 50) return 'Some caution needed';
    if (score < 70) return 'Suspicious activity';
    if (score < 85) return 'High risk detected';
    return 'Critical threat';
  }

  /// Score → risk color.
  static Color color(int score) {
    if (score < 30) return VrColors.safe;
    if (score < 50) return VrColors.caution;
    if (score < 70) return VrColors.highRisk;
    if (score < 85) return VrColors.critical;
    return VrColors.critical;
  }

  /// Level string → color.
  static Color levelColor(String? lvl) {
    switch (lvl) {
      case 'LOW':
        return VrColors.safe;
      case 'GUARDED':
      case 'MEDIUM':
        return VrColors.caution;
      case 'SUSPICIOUS':
      case 'HIGH':
        return VrColors.highRisk;
      case 'CRITICAL':
        return VrColors.critical;
      default:
        return VrColors.textMuted;
    }
  }

  /// Voice spoof risk → human-friendly text.
  static String voiceLabel(double spoofRisk) {
    if (spoofRisk < 0.3) return 'Voice seems genuine';
    if (spoofRisk < 0.6) return 'Voice needs checking';
    if (spoofRisk < 0.8) return 'Voice looks suspicious';
    return 'Likely AI-generated voice';
  }

  /// Source tag → display color for explanation tiles.
  static Color sourceTagColor(String tag) {
    switch (tag) {
      case 'voice':
        return VrColors.primary;
      case 'scam_rule':
        return VrColors.safe;
      case 'fused':
        return const Color(0xFFA78BFA);
      case 'policy':
        return VrColors.highRisk;
      case 'liveness':
        return const Color(0xFFF472B6);
      case 'identity':
        return const Color(0xFF60A5FA);
      case 'url_rule':
        return VrColors.safe;
      default:
        return VrColors.textMuted;
    }
  }
}

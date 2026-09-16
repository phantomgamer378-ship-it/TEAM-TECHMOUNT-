import 'package:flutter/material.dart';

/// VANIRAKSHAK dark forest color palette.
///
/// Primary direction: dark forest / near-black green foundation.
/// Risk states use distinct colors — never used for decoration.
class VrColors {
  VrColors._();

  // ── Backgrounds ──
  static const bg = Color(0xFF06150F);
  static const bgAlt = Color(0xFF081C14);

  // ── Surfaces ──
  static const surface = Color(0xFF0D261C);
  static const surfaceAlt = Color(0xFF123126);
  static const surfaceLight = Color(0xFF1A3D30);

  // ── Primary accent ──
  static const primary = Color(0xFF42D66F);
  static const primarySoft = Color(0xFF8DEFA5);
  static const primaryMuted = Color(0xFF2A8B4A);

  // ── Light background (for light cards if needed) ──
  static const lightBg = Color(0xFFF4F8F3);

  // ── Text ──
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFDCE8DF);
  static const textMuted = Color(0xFF7A9B87);
  static const textDark = Color(0xFF0A120E);

  // ── Risk states (used ONLY for security communication) ──
  static const safe = Color(0xFF42D66F);
  static const caution = Color(0xFFF59E0B);
  static const highRisk = Color(0xFFF97316);
  static const critical = Color(0xFFEF4444);

  // ── Borders ──
  static const border = Color(0xFF1A3D30);
  static const borderSubtle = Color(0xFF0F2E22);
}

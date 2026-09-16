import 'package:flutter/material.dart';

/// VANIRAKSHAK dramatic typography scale.
///
/// Uses the system sans-serif for zero-dependency builds.
/// Typography hierarchy is intentionally dramatic — hero text is 36px+,
/// risk numbers are 56px+. Avoid making everything 12-14px.
class VrTypography {
  VrTypography._();

  // ── Hero / splash ──
  static const hero = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
  );

  static const heroLarge = TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.8,
  );

  // ── Section titles ──
  static const sectionTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
  );

  // ── Card titles ──
  static const cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // ── Body ──
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ── Secondary / captions ──
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.3,
  );

  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 1.2,
  );

  // ── Risk numbers (large) ──
  static const riskScore = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -1.0,
  );

  static const riskScoreSmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -0.5,
  );

  // ── Buttons ──
  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );

  static const buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  // ── Labels / tags ──
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
}

import 'package:flutter/material.dart';

/// Primary brand colour (buttons, progress indicators, glow).
const brandBlue = Color(0xFF3B7BFF);

/// App background gradient, top to bottom.
const backgroundTop = Color(0xFF060D1F);
const backgroundMiddle = Color(0xFF0B1A3E);
const backgroundBottom = Color(0xFF112258);
const backgroundGradientColors = [
  backgroundTop,
  backgroundMiddle,
  backgroundBottom,
];

const sheetBackground = backgroundMiddle;

const accentBlue = Color(0xFF60A5FA);
const accentAmber = Color(0xFFF59E0B);
const accentGreen = Color(0xFF22C55E);
const accentViolet = Color(0xFFA78BFA);
const accentRed = Color(0xFFEF4444);

/// Maps a training's verdict ("Go"/"Maybe"/"No", case-insensitive) to the
/// accent color used consistently across the score badge, card and sheet.
Color verdictColor(String verdict) => switch (verdict.toLowerCase()) {
  'go' => accentGreen,
  'maybe' => accentAmber,
  _ => accentRed,
};

Color precipRiskColor(int prob) => prob >= 70
    ? accentRed
    : prob >= 40
    ? accentAmber
    : accentBlue;

BoxDecoration glassDecoration({Color? borderColor}) => BoxDecoration(
  color: Colors.white.withValues(alpha: 0.05),
  borderRadius: BorderRadius.circular(14),
  border: Border.all(
    color: borderColor ?? Colors.white.withValues(alpha: 0.10),
  ),
);

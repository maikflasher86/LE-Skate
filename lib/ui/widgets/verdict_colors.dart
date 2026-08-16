import 'package:flutter/material.dart';

/// Maps a training's verdict ("Go"/"Maybe"/"No", case-insensitive) to the
/// accent color used consistently across the score badge and detail sheet.
Color verdictColor(String verdict) => switch (verdict.toLowerCase()) {
  'go' => const Color(0xFF22C55E),
  'maybe' => const Color(0xFFF59E0B),
  _ => const Color(0xFFEF4444),
};

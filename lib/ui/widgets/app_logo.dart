import 'package:flutter/material.dart';
import 'package:inliner2/ui/app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.size,
    required this.asset,
    required this.glowBlur,
    required this.glowOffsetY,
  });

  final double size;
  final String asset;
  final double glowBlur;
  final double glowOffsetY;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: brandBlue.withValues(alpha: 0.4),
            blurRadius: glowBlur,
            offset: Offset(0, glowOffsetY),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(asset, width: size, height: size, fit: BoxFit.cover),
      ),
    );
  }
}

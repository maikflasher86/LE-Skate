import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:inliner2/ui/app_colors.dart';

/// Compact pill badge showing the training type.
class TrainingPill extends StatelessWidget {
  const TrainingPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wide precipitation bubble (source, amount and risk) for the card.
class CardPrecipBubble extends StatelessWidget {
  const CardPrecipBubble({
    super.key,
    required this.source,
    required this.icon,
    required this.value,
    required this.probability,
  });

  final String source;
  final IconData icon;
  final String value;
  final int probability;

  @override
  Widget build(BuildContext context) {
    final color = precipRiskColor(probability);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withValues(alpha: 0.85)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  source,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.65),
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$probability %',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Details & Diagramme ›" hint at the bottom right of the card.
class CardDetailsHint extends StatelessWidget {
  const CardDetailsHint({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: 0.45);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Details & Diagramme',
          style: TextStyle(fontSize: 11, color: color, letterSpacing: 0.3),
        ),
        const SizedBox(width: 2),
        Icon(Icons.chevron_right_rounded, size: 14, color: color),
      ],
    );
  }
}

/// Blurred glass card with a coloured accent bar on the left.
class TrainingCardShell extends StatelessWidget {
  const TrainingCardShell({
    super.key,
    required this.accent,
    required this.child,
    this.onTap,
  });

  final Color accent;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.45)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
    return Material(
      color: Colors.transparent,
      child: onTap == null
          ? card
          : InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: card,
            ),
    );
  }
}

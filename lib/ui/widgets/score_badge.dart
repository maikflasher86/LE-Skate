import 'package:flutter/material.dart';
import 'package:inliner2/ui/widgets/verdict_colors.dart';

class ScoreBadge extends StatelessWidget {
  const ScoreBadge({super.key, required this.score, required this.verdict});

  final int? score;
  final String verdict;

  @override
  Widget build(BuildContext context) {
    // AI Score
    const icon = Icons.auto_awesome_rounded;
    final color = verdictColor(verdict);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.50), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            score != null ? '$score' : '–',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

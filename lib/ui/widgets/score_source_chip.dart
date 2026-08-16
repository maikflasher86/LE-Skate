import 'package:flutter/material.dart';

class ScoreSourceChip extends StatelessWidget {
  const ScoreSourceChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: hasValue ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.white.withValues(alpha: hasValue ? 0.60 : 0.30),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: ${value?.toString() ?? '–'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: hasValue ? 0.75 : 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

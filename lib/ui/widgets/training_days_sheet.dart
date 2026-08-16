import 'package:flutter/material.dart';
import 'package:inliner2/services/training_settings_service.dart';
import 'package:inliner2/utils/session_utils.dart';

/// Bottom sheet for selecting active training days.
class TrainingDaysSheet extends StatefulWidget {
  const TrainingDaysSheet({super.key});

  @override
  State<TrainingDaysSheet> createState() => _TrainingDaysSheetState();
}

class _TrainingDaysSheetState extends State<TrainingDaysSheet> {
  Set<int> _activeDays = {};
  bool _loading = true;
  bool _showAlternatives = TrainingSettingsService.defaultShowAlternatives;

  // Day list is derived from the central schedule map – no duplication needed.

  @override
  void initState() {
    super.initState();
    Future.wait([
      TrainingSettingsService.loadActiveDays(),
      TrainingSettingsService.loadShowAlternatives(),
    ]).then((results) {
      if (!mounted) return;
      setState(() {
        _activeDays = results[0] as Set<int>;
        _showAlternatives = results[1] as bool;
        _loading = false;
      });
    });
  }

  Future<void> _toggle(int day, bool active) async {
    final next = Set<int>.from(_activeDays);
    if (active) {
      next.add(day);
    } else {
      next.remove(day);
    }
    setState(() => _activeDays = next);
    await TrainingSettingsService.saveActiveDays(next);
  }

  Future<void> _toggleAlternatives(bool value) async {
    setState(() => _showAlternatives = value);
    await TrainingSettingsService.saveShowAlternatives(value);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + bottomPadding + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Trainingstage',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B7BFF)),
            )
          else
            for (final info in scheduleDayInfoList())
              _DayRow(
                day: info.weekday,
                name: info.weekdayName,
                time: info.trainingTime,
                badgeLabel: info.badgeLabel,
                badgeColor: _badgeColor(info.category, info.regularParity),
                active: _activeDays.contains(info.weekday),
                onChanged: (v) => _toggle(info.weekday, v),
              ),
          if (!_loading) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _showAlternatives,
              onChanged: _toggleAlternatives,
              activeThumbColor: const Color(0xFF3B7BFF),
              title: const Text(
                'Alternative Trainings anzeigen',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              subtitle: const Text(
                'Freitag/Sonntag ausserhalb der regulären KW-Regel',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B7BFF),
              ),
              child: const Text('Übernehmen & neu laden'),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Badge color based on category and calendar-week parity.
Color _badgeColor(TrainingCategory category, WeekParity parity) {
  if (category == TrainingCategory.special) {
    return Colors.purple; // Cossi
  }
  if (parity != WeekParity.any) {
    return Colors.amber; // KW rule
  }
  return Colors.deepPurple; // Technik
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.name,
    required this.time,
    required this.active,
    required this.onChanged,
    this.badgeLabel,
    this.badgeColor,
  });

  final int day;
  final String name;
  final String time;
  final bool active;
  final ValueChanged<bool> onChanged;
  final String? badgeLabel;
  final Color? badgeColor;

  bool get _isWeekend => day >= 6;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!active),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: active,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: const Color(0xFF3B7BFF),
                side: const BorderSide(color: Colors.white38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  color: active ? Colors.white : Colors.white54,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            // ── Right-side badges ──────────────────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badgeLabel != null && badgeColor != null) ...[
                  _ColorBox(
                    label: badgeLabel!,
                    color: badgeColor!,
                    active: active,
                  ),
                  const SizedBox(width: 6),
                ],
                _ColorBox(
                  label: time,
                  color: _isWeekend
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF3B7BFF),
                  active: active,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable colored label box (same style for time and badge).
class _ColorBox extends StatelessWidget {
  const _ColorBox({
    required this.label,
    required this.color,
    required this.active,
  });

  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: active ? color : Colors.white24,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

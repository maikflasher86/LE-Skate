import 'package:flutter/material.dart';
import 'package:inliner2/services/training_settings_service.dart';
import 'package:inliner2/ui/app_colors.dart';
import 'package:inliner2/ui/widgets/sheet_scaffold.dart';
import 'package:inliner2/utils/date_utils.dart';
import 'package:inliner2/utils/session_utils.dart';
import 'package:inliner2/utils/training_schedule.dart';

class TrainingDaysSheet extends StatefulWidget {
  const TrainingDaysSheet({super.key});

  @override
  State<TrainingDaysSheet> createState() => _TrainingDaysSheetState();
}

class _TrainingDaysSheetState extends State<TrainingDaysSheet> {
  Set<int> _activeDays = {};
  bool _loading = true;
  bool _showAlternatives = TrainingSettingsService.defaultShowAlternatives;

  /// Saves still in flight; awaited before the sheet is closed so the
  /// reload triggered by closing sees the latest settings.
  final List<Future<void>> _pendingSaves = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    var activeDays = TrainingSettingsService.defaultDaysFor(DateTime.now());
    var showAlternatives = TrainingSettingsService.defaultShowAlternatives;
    try {
      activeDays = await TrainingSettingsService.loadActiveDays();
      showAlternatives = await TrainingSettingsService.loadShowAlternatives();
    } catch (_) {
      // Fall back to the defaults so the sheet stays usable.
    }
    if (!mounted) return;
    setState(() {
      _activeDays = activeDays;
      _showAlternatives = showAlternatives;
      _loading = false;
    });
  }

  Future<void> _track(Future<void> save) {
    _pendingSaves.add(save);
    return save.whenComplete(() => _pendingSaves.remove(save));
  }

  Future<void> _toggle(int day, bool active) async {
    final next = Set<int>.from(_activeDays);
    if (active) {
      next.add(day);
    } else {
      next.remove(day);
    }
    setState(() => _activeDays = next);
    await _track(TrainingSettingsService.saveActiveDays(next));
  }

  Future<void> _toggleAlternatives(bool value) async {
    setState(() => _showAlternatives = value);
    await _track(TrainingSettingsService.saveShowAlternatives(value));
  }

  Future<void> _applyAndClose() async {
    try {
      await Future.wait(List.of(_pendingSaves));
    } catch (_) {
      // A failed save must not keep the sheet open; the reload uses
      // whatever was stored.
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
          const SheetDragHandle(),
          const SizedBox(height: 16),
          const SheetTitle('Trainingstage'),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: brandBlue))
          else
            for (final info in scheduleDayInfoList())
              _DayRow(
                info: info,
                active: _activeDays.contains(info.weekday),
                onChanged: (v) => _toggle(info.weekday, v),
              ),
          if (!_loading && !isWinterSeason(DateTime.now())) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _showAlternatives,
              onChanged: _toggleAlternatives,
              activeThumbColor: brandBlue,
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
              onPressed: _applyAndClose,
              style: FilledButton.styleFrom(backgroundColor: brandBlue),
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
    required this.info,
    required this.active,
    required this.onChanged,
  });

  final ScheduleDayInfo info;
  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = info.badgeLabel;
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
                activeColor: brandBlue,
                side: const BorderSide(color: Colors.white38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                weekdayLabel(info.weekday),
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
                if (badgeLabel != null) ...[
                  _ColorBox(
                    label: badgeLabel,
                    color: _badgeColor(info.category, info.regularParity),
                    active: active,
                  ),
                  const SizedBox(width: 6),
                ],
                _ColorBox(
                  label: info.trainingTime,
                  color: info.weekday >= 6 ? accentGreen : brandBlue,
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

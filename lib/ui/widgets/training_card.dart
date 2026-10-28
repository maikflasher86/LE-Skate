import 'package:flutter/material.dart';
import 'package:inliner2/models/training_forecast.dart';
import 'package:inliner2/ui/app_colors.dart';
import 'package:inliner2/ui/widgets/metric_chip.dart';
import 'package:inliner2/ui/widgets/score_badge.dart';
import 'package:inliner2/ui/widgets/training_card_parts.dart';
import 'package:inliner2/ui/widgets/training_detail_sheet.dart';
import 'package:inliner2/utils/date_utils.dart';
import 'package:inliner2/utils/precip_series.dart';
import 'package:inliner2/utils/season_utils.dart';
import 'package:inliner2/utils/training_schedule.dart';

class TrainingCard extends StatelessWidget {
  const TrainingCard({
    super.key,
    required this.training,
    required this.rawApiJson,
  });

  final TrainingForecast training;
  final String rawApiJson;

  @override
  Widget build(BuildContext context) {
    // Indoor trainings: weather is irrelevant, so only day/time are shown
    // (no score, reason or forecast).
    if (training.isIndoor) {
      return TrainingCardShell(
        accent: accentBlue,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 13, 13),
          child: _CardTitle(training: training),
        ),
      );
    }

    final accent = verdictColor(training.verdict);
    final weather = training.weather;

    return TrainingCardShell(
      accent: accent,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            TrainingDetailSheet(training: training, rawApiJson: rawApiJson),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Date + Score
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 13, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _CardTitle(training: training)),
                const SizedBox(width: 10),
                ScoreBadge(score: training.llmScore, verdict: training.verdict),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 0),
            child: _buildReason(accent),
          ),
          if (weather != null)
            ..._buildWeather()
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  /// Reasoning plus the optional recommendation box.
  Widget _buildReason(Color accent) {
    final recommendation = training.recommendation?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          training.reason,
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.white.withValues(alpha: 0.80),
            height: 1.45,
          ),
        ),
        if (recommendation != null && recommendation.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates_rounded, size: 14, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendation,
                    style: TextStyle(
                      fontSize: 13,
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Weather chips, precipitation bubbles and the details hint.
  List<Widget> _buildWeather() {
    final weather = training.weather!;
    final dwd = summarizeDwdWindow(
      training.dwdPoints,
      training.start,
      training.end,
    );
    return [
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            MetricChip(
              icon: Icons.thermostat_rounded,
              label: '${weather.temperatureC.toStringAsFixed(0)} °C',
            ),
            MetricChip(
              icon: Icons.air_rounded,
              label: '${weather.windKmh.toStringAsFixed(0)} km/h',
            ),
            MetricChip(
              icon: Icons.cloud_rounded,
              label: '${weather.cloudCoverPercent.toStringAsFixed(0)} % Wolken',
            ),
          ],
        ),
      ),
      // Precipitation bubbles: own line, side by side
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(
              child: CardPrecipBubble(
                source: 'Open-Meteo',
                icon: Icons.water_drop_rounded,
                value: '${weather.precipitationMm.toStringAsFixed(2)} mm/h',
                probability: weather.precipitationProbabilityPercent.toInt(),
              ),
            ),
            if (dwd != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: CardPrecipBubble(
                  source: 'DWD',
                  icon: Icons.water_drop_outlined,
                  value: '${dwd.totalMm.toStringAsFixed(2)} mm/h',
                  probability: dwd.maxProbability,
                ),
              ),
            ],
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(14, 10, 14, 13),
        child: CardDetailsHint(),
      ),
    ];
  }
}

/// Label, icon and colour of the training-type pill.
({String label, IconData icon, Color color}) _pillFor(
  TrainingForecast training,
) {
  if (training.isIndoor) {
    return (
      label: training.trainingName,
      icon: Icons.home_work_rounded,
      color: accentBlue,
    );
  }
  if (training.trainingName.trim().toLowerCase() == 'technik') {
    return (
      label: training.trainingName,
      icon: Icons.precision_manufacturing_rounded,
      color: const Color(0xFFA855F7),
    );
  }
  // One-off special event (e.g. Porsche Event), independent of the
  // weekday/alternative schedule.
  if (isOneTimeEventId(training.id)) {
    return (
      label: training.trainingName,
      icon: Icons.event_rounded,
      color: const Color(0xFF3B82F6),
    );
  }
  // Alternative training: Friday/Sunday outside the calendar-week rule.
  if (isAlternativeTrainingDate(training.start)) {
    return (
      label: 'Alternativ',
      icon: Icons.swap_horiz_rounded,
      color: accentAmber,
    );
  }
  return (
    label: training.trainingName,
    icon: Icons.check_circle_outline_rounded,
    color: accentGreen,
  );
}

/// Weekday title with type pill, and the date/time line below.
class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.training});

  final TrainingForecast training;

  @override
  Widget build(BuildContext context) {
    final pill = _pillFor(training);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              training.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            TrainingPill(label: pill.label, icon: pill.icon, color: pill.color),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          formatTrainingRange(training.start, training.end),
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.48),
          ),
        ),
      ],
    );
  }
}

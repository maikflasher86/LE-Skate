import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:inliner2/models/training_forecast.dart';
import 'package:inliner2/ui/app_colors.dart';
import 'package:inliner2/ui/widgets/metric_chip.dart';
import 'package:inliner2/ui/widgets/score_badge.dart';
import 'package:inliner2/ui/widgets/training_detail_sheet.dart';
import 'package:inliner2/utils/date_utils.dart';
import 'package:inliner2/utils/precip_series.dart';
import 'package:inliner2/utils/session_utils.dart';
import 'package:inliner2/utils/training_schedule.dart';

class TrainingCard extends StatelessWidget {
  const TrainingCard({
    super.key,
    required this.training,
    required this.rawApiJson,
  });

  final TrainingForecast training;
  final String rawApiJson;

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          TrainingDetailSheet(training: training, rawApiJson: rawApiJson),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Indoor trainings have no weather evaluation or forecast.
    if (training.isIndoor) {
      return _TrainingCardShell(
        accent: accentBlue,
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 13, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(training: training),
              const SizedBox(height: 8),
              Text(
                'Kursdetails',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final accent = verdictColor(training.verdict);
    final weather = training.weather;

    return _TrainingCardShell(
      accent: accent,
      onTap: () => _showDetails(context),
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
    final hint = Colors.white.withValues(alpha: 0.45);
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
              child: _CardPrecipBubble(
                source: 'Open-Meteo',
                icon: Icons.water_drop_rounded,
                value: '${weather.precipitationMm.toStringAsFixed(2)} mm/h',
                probability: weather.precipitationProbabilityPercent.toInt(),
              ),
            ),
            if (dwd != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _CardPrecipBubble(
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
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Details & Diagramme',
              style: TextStyle(fontSize: 11, color: hint, letterSpacing: 0.3),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 14, color: hint),
          ],
        ),
      ),
    ];
  }
}

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
            _TrainingPill(training),
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

class _TrainingPill extends StatelessWidget {
  const _TrainingPill(this.training);

  final TrainingForecast training;

  @override
  Widget build(BuildContext context) {
    final (:label, :icon, :color) = _pillFor(training);
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

class _CardPrecipBubble extends StatelessWidget {
  const _CardPrecipBubble({
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

/// Blurred glass card with a coloured accent bar on the left.
class _TrainingCardShell extends StatelessWidget {
  const _TrainingCardShell({
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

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:inliner2/models/training_forecast.dart';
import 'package:inliner2/ui/widgets/metric_chip.dart';
import 'package:inliner2/ui/widgets/score_badge.dart';
import 'package:inliner2/ui/widgets/training_detail_sheet.dart';
import 'package:inliner2/utils/session_utils.dart';
import 'package:intl/intl.dart';

class TrainingCard extends StatelessWidget {
  const TrainingCard({
    super.key,
    required this.training,
    required this.rawApiJson,
  });

  final TrainingForecast training;
  final String rawApiJson;

  Color get _verdictColor => switch (training.verdict.toLowerCase()) {
    'go' => Colors.green.shade400,
    'maybe' => Colors.amber.shade600,
    _ => Colors.red.shade400,
  };

  bool get _isTechnik =>
      training.trainingName.trim().toLowerCase() == 'technik';

  /// Alternative training: Friday/Sunday outside calendar week rule only.
  bool get _isAlternativByKwRule => isAlternativeTrainingDate(training.start);

  /// Calculates DWD data for the training window (null if no data).
  ({double totalMm, int maxProb})? _dwdDuring() {
    if (training.dwdPoints.isEmpty) return null;
    final during = training.dwdPoints
        .where(
          (p) =>
              !p.time.isBefore(training.start) && !p.time.isAfter(training.end),
        )
        .toList();
    if (during.isEmpty) return null;
    return (
      totalMm: during.fold(0.0, (s, p) => s + p.precipitationMm),
      maxProb: during
          .map((p) => p.precipitationProbability ?? 0)
          .reduce(math.max),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weather = training.weather;
    final recommendation = training.recommendation?.trim();
    final hasRecommendation =
        recommendation != null && recommendation.isNotEmpty;
    final accent = _verdictColor;
    final dwd = _dwdDuring();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              TrainingDetailSheet(training: training, rawApiJson: rawApiJson),
        ),
        child: ClipRRect(
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
                    // ── Colored left accent bar ──────────────────
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
                    // ── Content ─────────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Title + Date + Score
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 13, 13, 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Weekday + Type pill
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
                                          if (_isTechnik)
                                            _Pill(
                                              label: training.trainingName,
                                              icon: Icons
                                                  .precision_manufacturing_rounded,
                                              color: const Color(0xFFA855F7),
                                            )
                                          else
                                            _Pill(
                                              label: _isAlternativByKwRule
                                                  ? 'Alternativ'
                                                  : training.trainingName,
                                              icon: _isAlternativByKwRule
                                                  ? Icons.swap_horiz_rounded
                                                  : Icons
                                                        .check_circle_outline_rounded,
                                              color: _isAlternativByKwRule
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFF22C55E),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      // Date + Time
                                      Text(
                                        '${DateFormat('dd.MM.yyyy HH:mm').format(training.start)} – '
                                        '${DateFormat('HH:mm').format(training.end)} Uhr',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withValues(
                                            alpha: 0.48,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ScoreBadge(
                                  score: training.llmScore,
                                  verdict: training.verdict,
                                ),
                              ],
                            ),
                          ),

                          // Divider line
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),

                          // Reasoning + Recommendation
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 11, 14, 0),
                            child: Column(
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
                                if (hasRecommendation) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.tips_and_updates_rounded,
                                          size: 14,
                                          color: accent,
                                        ),
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
                            ),
                          ),

                          // Weather chips
                          if (weather != null) ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  MetricChip(
                                    icon: Icons.thermostat_rounded,
                                    label:
                                        '${weather.temperatureC.toStringAsFixed(0)} °C',
                                  ),
                                  MetricChip(
                                    icon: Icons.air_rounded,
                                    label:
                                        '${weather.windKmh.toStringAsFixed(0)} km/h',
                                  ),
                                  MetricChip(
                                    icon: Icons.cloud_rounded,
                                    label:
                                        '${weather.cloudCoverPercent.toStringAsFixed(0)} % Wolken',
                                  ),
                                ],
                              ),
                            ),
                            // ── Precipitation bubbles: own line, side by side ──
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _PrecipBubble(
                                      source: 'Open-Meteo',
                                      icon: Icons.water_drop_rounded,
                                      value:
                                          '${weather.precipitationMm.toStringAsFixed(2)} mm/h',
                                      probability: weather
                                          .precipitationProbabilityPercent
                                          .toInt(),
                                    ),
                                  ),
                                  if (dwd != null) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _PrecipBubble(
                                        source: 'DWD',
                                        icon: Icons.water_drop_outlined,
                                        value:
                                            '${dwd.totalMm.toStringAsFixed(2)} mm/h',
                                        probability: dwd.maxProb,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Details hint
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                10,
                                14,
                                13,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Details & Diagramme',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(
                                        alpha: 0.45,
                                      ),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.45),
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact pill badge.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.color});
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

/// Precipitation bubble – wide variant for own row.
class _PrecipBubble extends StatelessWidget {
  const _PrecipBubble({
    required this.source,
    required this.icon,
    required this.value,
    required this.probability,
  });

  final String source;
  final IconData icon;
  final String value;
  final int probability;

  Color get _color => probability >= 70
      ? const Color(0xFFEF4444)
      : probability >= 40
      ? const Color(0xFFF59E0B)
      : const Color(0xFF60A5FA);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _color.withValues(alpha: 0.85)),
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
                    color: _color.withValues(alpha: 0.65),
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
              color: _color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$probability %',
              style: TextStyle(
                fontSize: 11,
                color: _color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

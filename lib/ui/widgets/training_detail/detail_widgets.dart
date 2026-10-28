import 'package:flutter/material.dart';
import 'package:inliner2/models/weather_metrics.dart';
import 'package:inliner2/ui/app_colors.dart';

/// Upper-case, muted section heading.
class DetailSectionTitle extends StatelessWidget {
  const DetailSectionTitle({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Colors.white.withValues(alpha: 0.40),
      ),
    );
  }
}

/// Labelled 0–100 progress bar.
class DetailScoreBar extends StatelessWidget {
  const DetailScoreBar({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.color,
  });

  final String label;
  final IconData icon;
  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (value ?? 0).clamp(0, 100) / 100.0;
    final displayValue = value?.toString() ?? '–';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.70),
              ),
            ),
            const Spacer(),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: value != null ? color : Colors.white38,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two-column grid of the aggregated weather values.
class WeatherGrid extends StatelessWidget {
  const WeatherGrid({super.key, required this.weather});

  final WeatherMetrics weather;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.thermostat_rounded,
        '${weather.temperatureC.toStringAsFixed(1)} °C',
        'Temperatur',
      ),
      (Icons.air_rounded, '${weather.windKmh.toStringAsFixed(0)} km/h', 'Wind'),
      (
        Icons.water_drop_rounded,
        '${weather.precipitationMm.toStringAsFixed(1)} mm/h',
        'Niederschlag',
      ),
      (
        Icons.grain_rounded,
        '${weather.precipitationProbabilityPercent.toStringAsFixed(0)} %',
        'Regenrisiko',
      ),
      (
        Icons.cloud_rounded,
        '${weather.cloudCoverPercent.toStringAsFixed(0)} %',
        'Wolken',
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final (icon, value, label) = item;
        return Container(
          width: (MediaQuery.of(context).size.width - 56) / 2 - 4,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: glassDecoration(),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.50)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Shows Open-Meteo and DWD precipitation values as two tiles side by side.
class CombinedPrecipBubble extends StatelessWidget {
  const CombinedPrecipBubble({
    super.key,
    required this.omPrecipMm,
    required this.omProbPercent,
    required this.dwdTotalMm,
    required this.dwdMaxProbPercent,
  });

  final double omPrecipMm;
  final int omProbPercent;
  final double dwdTotalMm;
  final int dwdMaxProbPercent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PrecipBubbleTile(
            source: 'Open-Meteo',
            color: precipRiskColor(omProbPercent),
            precipMm: omPrecipMm,
            probability: omProbPercent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PrecipBubbleTile(
            source: 'DWD',
            color: precipRiskColor(dwdMaxProbPercent),
            precipMm: dwdTotalMm,
            probability: dwdMaxProbPercent,
          ),
        ),
      ],
    );
  }
}

/// Precipitation amount and risk of one source.
class PrecipBubbleTile extends StatelessWidget {
  const PrecipBubbleTile({
    super.key,
    required this.source,
    required this.color,
    required this.precipMm,
    required this.probability,
  });

  final String source;
  final Color color;
  final double precipMm;
  final int probability;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_rounded, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                source,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${precipMm.toStringAsFixed(2)} mm/h',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$probability % Risiko',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

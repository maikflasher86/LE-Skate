import 'package:flutter/material.dart';
import 'package:inliner2/models/hourly_point.dart';
import 'package:inliner2/models/training_forecast.dart';
import 'package:inliner2/models/weather_metrics.dart';
import 'package:inliner2/ui/app_colors.dart';
import 'package:inliner2/ui/widgets/line_chart.dart';
import 'package:inliner2/ui/widgets/line_chart_painter.dart';
import 'package:inliner2/ui/widgets/score_badge.dart';
import 'package:inliner2/ui/widgets/sheet_scaffold.dart';
import 'package:inliner2/utils/api_utils.dart';
import 'package:inliner2/utils/date_utils.dart';
import 'package:inliner2/utils/precip_series.dart';

class TrainingDetailSheet extends StatefulWidget {
  const TrainingDetailSheet({
    super.key,
    required this.training,
    required this.rawApiJson,
  });

  final TrainingForecast training;
  final String rawApiJson;

  @override
  State<TrainingDetailSheet> createState() => _TrainingDetailSheetState();
}

class _TrainingDetailSheetState extends State<TrainingDetailSheet> {
  // Two controllers that are kept mutually synchronized via listeners.
  // A single shared ScrollController is NOT sufficient: it would only
  // apply programmatic scrolls (jumpTo/animateTo) to both positions,
  // but not user-driven drag gestures – so the previous
  // "shared controller" approach didn't work under Android (and generally).
  final _precipScrollController = ScrollController();
  final _probScrollController = ScrollController();
  bool _isSyncingScroll = false;

  /// Hourly Open-Meteo points of the training day, decoded once.
  late final List<HourlyPoint> _points;

  TrainingForecast get training => widget.training;

  @override
  void initState() {
    super.initState();
    _points = hourlyPointsOfDay(widget.rawApiJson, training.start);
    _precipScrollController.addListener(
      () => _syncScroll(_precipScrollController, _probScrollController),
    );
    _probScrollController.addListener(
      () => _syncScroll(_probScrollController, _precipScrollController),
    );
  }

  void _syncScroll(ScrollController source, ScrollController target) {
    if (_isSyncingScroll || !target.hasClients) return;
    final offset = source.offset.clamp(0.0, target.position.maxScrollExtent);
    if (offset == target.offset) return;
    _isSyncingScroll = true;
    target.jumpTo(offset);
    _isSyncingScroll = false;
  }

  @override
  void dispose() {
    _precipScrollController.dispose();
    _probScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B1630),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 4),
                child: SheetDragHandle(),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _buildHeader(),
                    ..._buildCourseDetails(),
                    if (!training.isIndoor) ...[
                      const SizedBox(height: 20),
                      // Score bar
                      const _DetailSectionTitle(title: 'Bewertung'),
                      const SizedBox(height: 10),
                      _DetailScoreBar(value: training.llmScore),
                      const SizedBox(height: 16),
                      ..._buildReasonSection(),
                      ..._buildWeatherSection(),
                      ..._buildCharts(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildCourseDetails() {
    final locationLabel = training.locationLabel;
    if (training.courses.isEmpty && locationLabel == null) {
      return const [];
    }

    return [
      const SizedBox(height: 20),
      const _DetailSectionTitle(title: 'Kursdetails'),
      const SizedBox(height: 10),
      if (locationLabel != null)
        _CourseDetailRow(label: 'Ort', value: locationLabel),
      for (final course in training.courses) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: glassDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.category,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              _CourseDetailRow(
                label: 'Übungsleiter',
                value: course.instructors.join(', '),
              ),
              _CourseDetailRow(label: 'Inhalt', value: course.content),
              _CourseDetailRow(label: 'Ausrüstung', value: course.equipment),
              if (course.notes.isNotEmpty)
                _CourseDetailRow(
                  label: 'Hinweis',
                  value: course.notes.join('\n'),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                training.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                // Start is shown in local time (as before), end as given.
                formatTrainingRange(
                  training.start.toLocal(),
                  training.end,
                  separator: '  –  ',
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.50),
                ),
              ),
            ],
          ),
        ),
        if (!training.isIndoor)
          ScoreBadge(score: training.llmScore, verdict: training.verdict),
      ],
    );
  }

  List<Widget> _buildReasonSection() {
    final recommendation = training.recommendation?.trim();
    final accentColor = verdictColor(training.verdict);
    return [
      const _DetailSectionTitle(title: 'Begründung'),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: glassDecoration(),
        child: Text(
          training.reason,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.80),
            height: 1.5,
          ),
        ),
      ),
      if (recommendation != null && recommendation.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accentColor.withValues(alpha: 0.30)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.tips_and_updates_rounded,
                size: 16,
                color: accentColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  recommendation,
                  style: TextStyle(
                    fontSize: 14,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  /// Aggregated weather grid plus the Open-Meteo/DWD precipitation tiles.
  List<Widget> _buildWeatherSection() {
    final weather = training.weather;
    if (weather == null) return const [];
    final dwd = summarizeDwdWindow(
      training.dwdPoints,
      training.start,
      training.end,
    );
    return [
      const SizedBox(height: 20),
      const _DetailSectionTitle(title: 'Wetter im Trainingszeitraum'),
      const SizedBox(height: 10),
      _WeatherGrid(weather: weather),
      if (dwd != null) ...[
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _PrecipBubbleTile(
                source: 'Open-Meteo',
                precipMm: weather.precipitationMm,
                probability: weather.precipitationProbabilityPercent.toInt(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PrecipBubbleTile(
                source: 'DWD',
                precipMm: dwd.totalMm,
                probability: dwd.maxProbability,
              ),
            ),
          ],
        ),
      ],
    ];
  }

  /// Hourly charts, or a hint if no hourly data is available yet.
  List<Widget> _buildCharts() {
    final points = _points;
    if (points.length < 2) {
      if (points.isEmpty && training.weather != null) {
        return [
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Stundendaten für diesen Termin noch nicht verfügbar.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ];
      }
      return const [];
    }

    final precip = buildPrecipSeries(
      precip15m: training.precipitation15mPoints,
      hourly: points,
      dwd: training.dwdPoints,
    );
    final has15m = precip.has15m;
    final hourlyTimes = points.map((p) => p.time).toList();

    LineChart hourlyChart(
      String title,
      String unit,
      Color color,
      double Function(HourlyPoint p) selector,
    ) => LineChart(
      title: title,
      unit: unit,
      times: hourlyTimes,
      series: [
        ChartSeries(values: points.map(selector).toList(), color: color),
      ],
    );

    return [
      const SizedBox(height: 20),
      const _DetailSectionTitle(title: 'Stündlicher Verlauf'),
      const SizedBox(height: 10),
      hourlyChart(
        'Temperatur',
        '°C',
        const Color(0xFF22D3EE),
        (p) => p.temperatureC,
      ),
      const SizedBox(height: 12),
      // Precipitation – both sources combined
      LineChart(
        title: has15m ? 'Niederschlag (15 Min)' : 'Niederschlag',
        unit: 'mm/h',
        times: precip.times,
        showLegend: true,
        scrollController: _precipScrollController,
        series: [
          ChartSeries(
            values: precip.openMeteoMm,
            label: has15m ? 'Open-Meteo 15m' : 'Open-Meteo',
            color: accentBlue,
          ),
          ChartSeries(
            values: precip.dwdMm,
            label: 'DWD',
            color: const Color(0xFF34D399),
          ),
        ],
      ),
      const SizedBox(height: 12),
      // Precipitation probability – both sources combined
      LineChart(
        title: has15m ? 'Regenrisiko (15 Min)' : 'Regenrisiko',
        unit: '%',
        times: precip.times,
        showLegend: true,
        scrollController: _probScrollController,
        series: [
          ChartSeries(
            values: precip.openMeteoProbability,
            label: has15m ? 'Open-Meteo (15m)' : 'Open-Meteo',
            color: const Color(0xFF38BDF8),
          ),
          ChartSeries(
            values: precip.dwdProbability,
            label: 'DWD (1h)',
            color: const Color(0xFF6EE7B7),
          ),
        ],
      ),
      const SizedBox(height: 12),
      hourlyChart('Wind', 'km/h', accentAmber, (p) => p.windKmh),
      const SizedBox(height: 12),
      hourlyChart(
        'Wolkenbedeckung',
        '%',
        accentViolet,
        (p) => p.cloudCoverPercent,
      ),
    ];
  }
}

class _CourseDetailRow extends StatelessWidget {
  const _CourseDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.48),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DetailSectionTitle extends StatelessWidget {
  const _DetailSectionTitle({required this.title});
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

/// Labelled 0–100 progress bar of the AI score.
class _DetailScoreBar extends StatelessWidget {
  const _DetailScoreBar({required this.value});

  final int? value;

  @override
  Widget build(BuildContext context) {
    const color = accentViolet;
    final pct = (value ?? 0).clamp(0, 100) / 100.0;
    final displayValue = value?.toString() ?? '–';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              'KI-Bewertung',
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
class _WeatherGrid extends StatelessWidget {
  const _WeatherGrid({required this.weather});

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

class _PrecipBubbleTile extends StatelessWidget {
  const _PrecipBubbleTile({
    required this.source,
    required this.precipMm,
    required this.probability,
  });

  final String source;
  final double precipMm;
  final int probability;

  @override
  Widget build(BuildContext context) {
    final color = precipRiskColor(probability);
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

import 'package:flutter/material.dart';
import 'package:inliner2/models/dwd_hourly_point.dart';
import 'package:inliner2/models/hourly_point.dart';
import 'package:inliner2/models/training_forecast.dart';
import 'package:inliner2/ui/widgets/dual_mini_line_chart.dart';
import 'package:inliner2/ui/widgets/mini_line_chart.dart';
import 'package:inliner2/ui/widgets/score_badge.dart';
import 'package:inliner2/ui/widgets/verdict_colors.dart';
import 'package:inliner2/utils/api_utils.dart';
import 'package:inliner2/utils/format_utils.dart';
import 'package:intl/intl.dart';

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

  TrainingForecast get training => widget.training;
  String get rawApiJson => widget.rawApiJson;

  @override
  void initState() {
    super.initState();
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

  List<HourlyPoint> _loadPoints() {
    final periodData = extractHourlyPointsByTraining(rawApiJson, [training]);
    if (periodData.isEmpty) return const [];
    return periodData.first.points;
  }

  /// Aligns DWD values temporally to arbitrary target times (±30 min).
  List<double> _alignDwdToTimes(
    List<DateTime> targetTimes,
    List<DwdHourlyPoint> dwdPoints,
    double Function(DwdHourlyPoint) selector,
  ) {
    return targetTimes.map((target) {
      final match = dwdPoints
          .where((d) => d.time.difference(target).inMinutes.abs() <= 30)
          .firstOrNull;
      return match != null ? selector(match) : 0.0;
    }).toList();
  }

  /// Aligns Open-Meteo hourly values to target times (nearest hour ±30 min).
  List<double> _alignHourlyToTimes(
    List<DateTime> targetTimes,
    List<HourlyPoint> hourlyPoints,
    double Function(HourlyPoint) selector,
  ) {
    return targetTimes.map((target) {
      final match = hourlyPoints
          .where((p) => p.time.difference(target).inMinutes.abs() <= 30)
          .firstOrNull;
      return match != null ? selector(match) : 0.0;
    }).toList();
  }

  /// DWD points exactly within the training time window.
  List<DwdHourlyPoint> get _dwdDuring => training.dwdPoints
      .where(
        (p) =>
            !p.time.isBefore(training.start) && !p.time.isAfter(training.end),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final weather = training.weather;
    final recommendation = training.recommendation?.trim();
    final hasRecommendation =
        recommendation != null && recommendation.isNotEmpty;
    final accentColor = verdictColor(training.verdict);
    final points = _loadPoints();
    final dwdDuring = _dwdDuring;

    final precip15m = [...training.precipitation15mPoints]
      ..sort((a, b) => a.time.compareTo(b.time));
    final has15m = precip15m.length >= 2;
    final precipTimes = has15m
        ? precip15m.map((p) => p.time).toList()
        : points.map((p) => p.time).toList();
    final precipOpenMeteoSeries = has15m
        ? precip15m.map((p) => p.precipitationMm).toList()
        : points.map((p) => p.precipitationMm).toList();
    final precipOpenMeteoProbSeries = has15m
        ? _alignHourlyToTimes(
            precipTimes,
            points,
            (p) => p.precipitationProbabilityPercent,
          )
        : points.map((p) => p.precipitationProbabilityPercent).toList();
    final precipDwdMmSeries = _alignDwdToTimes(
      precipTimes,
      training.dwdPoints,
      (d) => d.precipitationMm,
    );
    final precipDwdProbSeries = _alignDwdToTimes(
      precipTimes,
      training.dwdPoints,
      (d) => (d.precipitationProbability ?? 0).toDouble(),
    );

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
              // Drag-Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    // Header
                    Row(
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
                                '${formatDateTime(training.start)}  –  ${DateFormat('HH:mm').format(training.end)} Uhr',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.50),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ScoreBadge(
                          score: training.llmScore,
                          verdict: training.verdict,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Score bar
                    _SectionTitle(title: 'Bewertung'),
                    const SizedBox(height: 10),
                    _ScoreBar(
                      label: 'KI-Bewertung',
                      icon: Icons.auto_awesome_rounded,
                      value: training.llmScore,
                      color: const Color(0xFFA78BFA),
                    ),

                    const SizedBox(height: 16),

                    // Reasoning
                    _SectionTitle(title: 'Begründung'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Text(
                        training.reason,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.80),
                          height: 1.5,
                        ),
                      ),
                    ),

                    // Recommendation
                    if (hasRecommendation) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.30),
                          ),
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

                    // Weather aggregate
                    if (weather != null) ...[
                      const SizedBox(height: 20),
                      _SectionTitle(title: 'Wetter im Trainingszeitraum'),
                      const SizedBox(height: 10),
                      _WeatherGrid(weather: weather),
                    ],

                    // Combined precipitation bubble (Open-Meteo + DWD)
                    if (weather != null && dwdDuring.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _CombinedPrecipBubble(
                        omPrecipMm: weather.precipitationMm,
                        omProbPercent: weather.precipitationProbabilityPercent
                            .toInt(),
                        dwdPoints: dwdDuring,
                      ),
                    ],

                    // Hourly charts
                    if (points.length >= 2) ...[
                      const SizedBox(height: 20),
                      _SectionTitle(title: 'Stündlicher Verlauf'),
                      const SizedBox(height: 10),
                      MiniLineChart(
                        title: 'Temperatur',
                        color: const Color(0xFF22D3EE),
                        unit: '°C',
                        points: points,
                        selector: (p) => p.temperatureC,
                      ),
                      const SizedBox(height: 12),
                      // Precipitation – both sources combined
                      DualMiniLineChart(
                        title: has15m
                            ? 'Niederschlag (15 Min)'
                            : 'Niederschlag',
                        unit: 'mm/h',
                        times: precipTimes,
                        series1: precipOpenMeteoSeries,
                        series1Label: has15m ? 'Open-Meteo 15m' : 'Open-Meteo',
                        series1Color: const Color(0xFF60A5FA),
                        series2: precipDwdMmSeries,
                        series2Label: 'DWD',
                        series2Color: const Color(0xFF34D399),
                        scrollController: _precipScrollController,
                      ),
                      const SizedBox(height: 12),
                      // Precipitation probability – both sources combined
                      DualMiniLineChart(
                        title: has15m
                            ? 'Regenrisiko (15 Min)'
                            : 'Regenrisiko',
                        unit: '%',
                        times: precipTimes,
                        series1: precipOpenMeteoProbSeries,
                        series1Label: has15m
                            ? 'Open-Meteo (15m)'
                            : 'Open-Meteo',
                        series1Color: const Color(0xFF38BDF8),
                        series2: precipDwdProbSeries,
                        series2Label: 'DWD (1h)',
                        series2Color: const Color(0xFF6EE7B7),
                        scrollController: _probScrollController,
                      ),
                      const SizedBox(height: 12),
                      MiniLineChart(
                        title: 'Wind',
                        color: const Color(0xFFF59E0B),
                        unit: 'km/h',
                        points: points,
                        selector: (p) => p.windKmh,
                      ),
                      const SizedBox(height: 12),
                      MiniLineChart(
                        title: 'Wolkenbedeckung',
                        color: const Color(0xFFA78BFA),
                        unit: '%',
                        points: points,
                        selector: (p) => p.cloudCoverPercent,
                      ),
                    ] else if (points.isEmpty && weather != null) ...[
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
}

// ── Hilfs-Widgets ─────────────────────────────────────────────────────────────

/// Shows Open-Meteo and DWD precipitation values as two bubbles side by side.
class _CombinedPrecipBubble extends StatelessWidget {
  const _CombinedPrecipBubble({
    required this.omPrecipMm,
    required this.omProbPercent,
    required this.dwdPoints,
  });

  final double omPrecipMm;
  final int omProbPercent;
  final List<DwdHourlyPoint> dwdPoints;

  Color _color(int prob) => prob >= 70
      ? const Color(0xFFEF4444)
      : prob >= 40
      ? const Color(0xFFF59E0B)
      : const Color(0xFF60A5FA);

  @override
  Widget build(BuildContext context) {
    final dwdTotalMm = dwdPoints.fold(0.0, (s, p) => s + p.precipitationMm);
    final dwdMaxProb = dwdPoints.isEmpty
        ? 0
        : dwdPoints
              .map((p) => p.precipitationProbability ?? 0)
              .reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        Expanded(
          child: _PrecipBubbleTile(
            source: 'Open-Meteo',
            color: _color(omProbPercent),
            precipMm: omPrecipMm,
            probability: omProbPercent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PrecipBubbleTile(
            source: 'DWD',
            color: _color(dwdMaxProb),
            precipMm: dwdTotalMm,
            probability: dwdMaxProb,
          ),
        ),
      ],
    );
  }
}

class _PrecipBubbleTile extends StatelessWidget {
  const _PrecipBubbleTile({
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
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

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
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

class _WeatherGrid extends StatelessWidget {
  const _WeatherGrid({required this.weather});

  final dynamic weather;

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
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
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

class _DwdDebugTable extends StatelessWidget {
  const _DwdDebugTable({required this.points});

  final List<DwdHourlyPoint> points;

  @override
  Widget build(BuildContext context) {
    final sorted = [...points]..sort((a, b) => a.time.compareTo(b.time));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
          dataTextStyle: const TextStyle(fontSize: 12, color: Colors.white),
          columns: const [
            DataColumn(label: Text('Zeit')),
            DataColumn(label: Text('Menge (mm/h)')),
            DataColumn(label: Text('Wahrsch. (%)')),
          ],
          rows: sorted
              .map(
                (p) => DataRow(
                  cells: [
                    DataCell(Text(DateFormat('dd.MM. HH:mm').format(p.time))),
                    DataCell(Text(p.precipitationMm.toStringAsFixed(2))),
                    DataCell(
                      Text((p.precipitationProbability ?? 0).toString()),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

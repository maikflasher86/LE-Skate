import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:inliner2/models/forecast_response.dart';
import 'package:inliner2/ui/pages/about_page.dart';
import 'package:inliner2/ui/widgets/rain_radar_sheet.dart';
import 'package:inliner2/ui/widgets/training_days_sheet.dart';
import 'package:inliner2/utils/format_utils.dart';
import 'package:intl/intl.dart';

class HeaderCard extends StatelessWidget {
  const HeaderCard({super.key, required this.response, required this.onReload});

  final ForecastResponse response;
  final VoidCallback onReload;

  void _showRainRadar(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: RainRadarSheet(location: response.location),
      ),
    );
  }

  void _showTrainingDays(BuildContext context) async {
    final reload = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1A3E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const TrainingDaysSheet(),
    );
    if (reload == true) onReload();
  }

  void _showImpressum(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1A3E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: isLandscape ? screenHeight * 0.92 : screenHeight * 0.6,
        maxWidth: isLandscape ? 520 : double.infinity,
      ),
      builder: (_) => const AboutSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left side: Logo, title, rain info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF3B7BFF,
                              ).withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LE Skate',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              formatDateTime(response.fetchedAt),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _LastRainInfo(
                    lastEvent: response.lastRainEvent,
                    nextEvent: response.nextRainEvent,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // ── Right side: Buttons vertically centered + info above ──
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => _showImpressum(context),
                  child: const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.white30,
                  ),
                ),
                SizedBox(
                  width: 105,
                  child: Column(
                    children: [
                      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                        _CompactActionButton(
                          icon: Icons.satellite_alt_rounded,
                          label: 'Regenradar',
                          onTap: () => _showRainRadar(context),
                        ),
                        const SizedBox(height: 4),
                      _CompactActionButton(
                        icon: Icons.calendar_month_rounded,
                        label: 'Wochentage',
                        onTap: () => _showTrainingDays(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 0), // Spacer bottom for symmetry
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LastRainInfo extends StatelessWidget {
  const _LastRainInfo({required this.lastEvent, required this.nextEvent});

  final LastRainEvent? lastEvent;
  final LastRainEvent? nextEvent;

  String _formatRainTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final eventDay = DateTime(time.year, time.month, time.day);
    final timeStr = DateFormat('HH:mm').format(time);
    if (eventDay == today) return 'heute $timeStr Uhr';
    if (eventDay == yesterday) return 'gestern $timeStr Uhr';
    if (eventDay == tomorrow) return 'morgen $timeStr Uhr';
    return '${DateFormat('dd.MM.').format(time)} $timeStr Uhr';
  }

  String _intensity(double rainMm) => rainMm < 0.5
      ? 'leichter Regen'
      : rainMm < 2.0
      ? 'mäßiger Regen'
      : 'starker Regen';

  @override
  Widget build(BuildContext context) {
    final nowUtc = DateTime.now().toUtc();
    // At render time re-check – UTC comparison avoids timezone bugs
    final validLast =
        lastEvent != null &&
            lastEvent!.time.toUtc().isBefore(nowUtc) &&
            nowUtc.difference(lastEvent!.time.toUtc()).inHours <= 24
        ? lastEvent
        : null;
    final validNext =
        nextEvent != null && nextEvent!.time.toUtc().isAfter(nowUtc)
        ? nextEvent
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source badge
        Row(
          children: [
            const Icon(Icons.cloud_outlined, size: 11, color: Colors.white38),
            const SizedBox(width: 4),
            const Text(
              'Niederschlag: DWD via BrightSky',
              style: TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Last rain
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.history, size: 14, color: Colors.white54),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: validLast == null
                  ? const Text(
                      'Kein Regen in den letzten 24h',
                      style: TextStyle(fontSize: 13, color: Colors.white38),
                    )
                  : Text(
                      'Zuletzt: ${_formatRainTime(validLast.time)}\n'
                      '${_intensity(validLast.rainMm)} (${validLast.rainMm.toStringAsFixed(1)} mm/h)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Next rain
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.water_drop,
                size: 14,
                color: Colors.lightBlueAccent,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: validNext == null
                  ? const Text(
                      'Kein Regen in der Vorhersage',
                      style: TextStyle(fontSize: 13, color: Colors.white38),
                    )
                  : Text(
                      'Nächster Regen: ${_formatRainTime(validNext.time)}\n'
                      '${_intensity(validNext.rainMm)} (${validNext.rainMm.toStringAsFixed(1)} mm/h)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF3B7BFF).withValues(alpha: 0.20),
              const Color(0xFF1A3A8F).withValues(alpha: 0.18),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF3B7BFF).withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF93C5FD)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

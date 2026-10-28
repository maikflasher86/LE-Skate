import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:inliner2/models/forecast_response.dart';
import 'package:inliner2/ui/app_colors.dart';
import 'package:inliner2/ui/widgets/about_sheet.dart';
import 'package:inliner2/ui/widgets/app_logo.dart';
import 'package:inliner2/ui/widgets/rain_radar_sheet.dart';
import 'package:inliner2/ui/widgets/sheet_scaffold.dart';
import 'package:inliner2/ui/widgets/training_days_sheet.dart';
import 'package:inliner2/utils/date_utils.dart';
import 'package:inliner2/utils/rain_info_utils.dart';

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
    final reload = await showAppSheet<bool>(
      context,
      (_) => const TrainingDaysSheet(),
    );
    if (reload == true) onReload();
  }

  void _showImpressum(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    showAppSheet<void>(
      context,
      (_) => const AboutSheet(),
      constraints: BoxConstraints(
        maxHeight: isLandscape ? screenHeight * 0.92 : screenHeight * 0.6,
        maxWidth: isLandscape ? 520 : double.infinity,
      ),
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
                  _Brand(fetchedAt: response.fetchedAt),
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
            _ActionColumn(
              onInfo: () => _showImpressum(context),
              onRainRadar: () => _showRainRadar(context),
              onTrainingDays: () => _showTrainingDays(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo, app name and fetch time.
class _Brand extends StatelessWidget {
  const _Brand({required this.fetchedAt});

  final DateTime fetchedAt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppLogo(
          size: 52,
          asset: 'assets/images/app_icon.png',
          glowBlur: 12,
          glowOffsetY: 4,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LE Skate',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                formatDateTime(fetchedAt),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Info icon at the top, action buttons vertically centered.
class _ActionColumn extends StatelessWidget {
  const _ActionColumn({
    required this.onInfo,
    required this.onRainRadar,
    required this.onTrainingDays,
  });

  final VoidCallback onInfo;
  final VoidCallback onRainRadar;
  final VoidCallback onTrainingDays;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: onInfo,
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
              if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) ...[
                _CompactActionButton(
                  icon: Icons.satellite_alt_rounded,
                  label: 'Regenradar',
                  onTap: onRainRadar,
                ),
                const SizedBox(height: 4),
              ],
              _CompactActionButton(
                icon: Icons.calendar_month_rounded,
                label: 'Wochentage',
                onTap: onTrainingDays,
              ),
            ],
          ),
        ),
        const SizedBox(height: 0), // Spacer bottom for symmetry
      ],
    );
  }
}

class _LastRainInfo extends StatelessWidget {
  const _LastRainInfo({required this.lastEvent, required this.nextEvent});

  final LastRainEvent? lastEvent;
  final LastRainEvent? nextEvent;

  @override
  Widget build(BuildContext context) {
    // Re-checked at render time.
    final now = DateTime.now();
    final validLast = validLastRainEvent(lastEvent, now: now);
    final validNext = validNextRainEvent(nextEvent, now: now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source badge
        const Row(
          children: [
            Icon(Icons.cloud_outlined, size: 11, color: Colors.white38),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'DWD via BrightSky & Open-Meteo',
                style: TextStyle(fontSize: 10, color: Colors.white38),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _RainRow(
          icon: Icons.history,
          color: Colors.white54,
          text: validLast == null
              ? null
              : 'Zuletzt: ${formatRainTime(validLast.time, now: now)}\n'
                    '${rainEventDetails(validLast)}',
          emptyText: 'Kein Regen in den letzten 24h',
        ),
        const SizedBox(height: 4),
        _RainRow(
          icon: Icons.water_drop,
          color: Colors.lightBlueAccent,
          text: validNext == null
              ? null
              : 'Nächster Regen: ${formatRainTime(validNext.time, now: now)}\n'
                    '${rainEventDetails(validNext)}',
          emptyText: 'Kein Regen in der Vorhersage',
        ),
      ],
    );
  }
}

/// Icon plus rain text; shows the muted [emptyText] if [text] is null.
class _RainRow extends StatelessWidget {
  const _RainRow({
    required this.icon,
    required this.color,
    required this.text,
    required this.emptyText,
  });

  final IconData icon;
  final Color color;
  final String? text;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text ?? emptyText,
            style: TextStyle(
              fontSize: 13,
              color: text == null ? Colors.white38 : color,
            ),
          ),
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
              brandBlue.withValues(alpha: 0.20),
              const Color(0xFF1A3A8F).withValues(alpha: 0.18),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: brandBlue.withValues(alpha: 0.45)),
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

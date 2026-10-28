import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inliner2/models/forecast_response.dart';
import 'package:inliner2/services/forecast_service.dart';
import 'package:inliner2/services/training_settings_service.dart';
//import 'package:inliner2/ui/widgets/ad_banner_widget.dart';
import 'package:inliner2/ui/app_colors.dart';
import 'package:inliner2/ui/widgets/app_logo.dart';
import 'package:inliner2/ui/widgets/error_view.dart';
import 'package:inliner2/ui/widgets/header_card.dart';
import 'package:inliner2/ui/widgets/training_card.dart';
import 'package:inliner2/utils/session_utils.dart';

class ForecastPage extends StatefulWidget {
  const ForecastPage({super.key, required this.service});

  final ForecastRepository service;

  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage> {
  late Future<ForecastResponse> _forecastFuture;
  bool _showAlternatives = TrainingSettingsService.defaultShowAlternatives;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _forecastFuture = widget.service.loadForecast();
    _loadShowAlternatives();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadShowAlternatives() async {
    final value = await TrainingSettingsService.loadShowAlternatives();
    if (!mounted) return;
    setState(() => _showAlternatives = value);
  }

  Future<void> _reload() async {
    await _loadShowAlternatives();
    if (!mounted) return;
    setState(() {
      _forecastFuture = widget.service.loadForecast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Show the ad banner at the bottom
      // bottomNavigationBar: const SafeArea(child: AdBannerWidget()),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: backgroundGradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<ForecastResponse>(
            future: _forecastFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingView();
              }
              if (snapshot.hasError) {
                return ErrorView(
                  message: snapshot.error.toString(),
                  onRetry: _reload,
                );
              }
              final data = snapshot.data;
              if (data == null) {
                return ErrorView(
                  message: 'Keine Daten verfügbar.',
                  onRetry: _reload,
                );
              }

              return RefreshIndicator(
                color: brandBlue,
                backgroundColor: sheetBackground,
                onRefresh: _reload,
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: kIsWeb || Platform.isWindows,
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      HeaderCard(response: data, onReload: _reload),
                      const SizedBox(height: 14),
                      for (final training in visibleTrainings(
                        data.trainings,
                        showAlternatives: _showAlternatives,
                      )) ...[
                        TrainingCard(
                          training: training,
                          rawApiJson: data.rawApiJson,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Logo, app name and spinner while the forecast loads.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(
            size: 80,
            asset: 'assets/images/inliner_icon.png',
            glowBlur: 20,
            glowOffsetY: 6,
          ),
          const SizedBox(height: 16),
          const Text(
            'LE Skate',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: brandBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Daten werden geladen…',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

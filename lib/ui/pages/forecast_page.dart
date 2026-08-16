import 'package:flutter/material.dart';
import 'package:inliner2/models/forecast_response.dart';
import 'package:inliner2/services/forecast_service.dart';
import 'package:inliner2/services/training_settings_service.dart';
import 'package:inliner2/ui/widgets/ad_banner_widget.dart';
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

  @override
  void initState() {
    super.initState();
    _forecastFuture = widget.service.loadForecast();
    _loadShowAlternatives();
  }

  Future<void> _loadShowAlternatives() async {
    final value = await TrainingSettingsService.loadShowAlternatives();
    if (!mounted) return;
    setState(() => _showAlternatives = value);
  }

  Future<void> _reload() async {
    await _loadShowAlternatives();
    setState(() {
      _forecastFuture = widget.service.loadForecast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Show the ad banner at the bottom
      bottomNavigationBar: const SafeArea(child: AdBannerWidget()),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF060D1F), Color(0xFF0B1A3E), Color(0xFF112258)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<ForecastResponse>(
            future: _forecastFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // LE Skate Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF3B7BFF,
                              ).withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/inliner_icon.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
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
                          color: Color(0xFF3B7BFF),
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
                color: const Color(0xFF3B7BFF),
                backgroundColor: const Color(0xFF0B1A3E),
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  children: [
                    HeaderCard(response: data, onReload: _reload),
                    const SizedBox(height: 14),
                    for (final training in data.trainings.where(
                      (t) =>
                          _showAlternatives ||
                          !isAlternativeTrainingDate(t.start),
                    )) ...[
                      TrainingCard(
                        training: training,
                        rawApiJson: data.rawApiJson,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

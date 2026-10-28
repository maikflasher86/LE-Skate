import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inliner2/models/dwd_hourly_point.dart';
import 'package:inliner2/models/forecast_response.dart';
import 'package:inliner2/models/location.dart';
import 'package:inliner2/services/brightsky_service.dart';
import 'package:inliner2/services/llm_service.dart';
import 'package:inliner2/services/training_settings_service.dart';
import 'package:inliner2/utils/dwd_merge_utils.dart';
import 'package:inliner2/utils/forecast_constants.dart';
import 'package:inliner2/utils/forecast_payload_utils.dart';
import 'package:inliner2/utils/session_utils.dart';

abstract class ForecastRepository {
  Future<ForecastResponse> loadForecast();
}

class ForecastService implements ForecastRepository {
  const ForecastService();

  static const String _timezone = 'Europe/Berlin';

  @override
  Future<ForecastResponse> loadForecast() async {
    // Load active days first to know which locations are needed. Fall back
    // to the current season's own regular training days if the stored
    // selection doesn't exist in this season's schedule at all (e.g. summer
    // defaults don't match any winter training day), so we never end up
    // with zero locations to fetch.
    final storedActiveDays = await TrainingSettingsService.loadActiveDays();
    final activeDays = effectiveActiveDays(storedActiveDays);
    final locationMap = locationsForActiveDays(activeDays);
    final forecastDaysMap = await forecastDaysPerLocation(activeDays);

    final targets = [
      for (final e in locationMap.entries)
        (
          label: e.key,
          location: e.value,
          days: forecastDaysMap[e.key] ?? maxForecastDays,
        ),
    ];
    debugPrint('[Weather] Active days: $activeDays');
    debugPrint(
      '[Weather] Locations to fetch: ${targets.map((t) => '${t.label} (${t.location.lat}, ${t.location.lon}) forecastDays=${t.days}').join(', ')}',
    );

    // Fetch Open-Meteo and BrightSky for every required location in parallel.
    final openMeteoResponses = await Future.wait(
      targets.map((t) => _fetchOpenMeteo(t.location, t.days)),
    );
    final dwdResponses = await Future.wait(
      targets.map((t) {
        return const BrightSkyService()
            .fetchPrecipitation(location: t.location, forecastDays: t.days)
            .catchError((dynamic err) {
              debugPrint('[Weather] BrightSky failed for ${t.label}: $err');
              return <DwdHourlyPoint>[];
            });
      }),
    );

    // Validate and collect weather bodies.
    final weatherBodies = <String, String>{};
    for (var i = 0; i < targets.length; i++) {
      if (openMeteoResponses[i].statusCode != 200) {
        throw Exception(
          'Wetterdienst Fehler (${openMeteoResponses[i].statusCode}).',
        );
      }
      weatherBodies[targets[i].label] = openMeteoResponses[i].body;
      debugPrint(
        '[Weather] Open-Meteo OK for "${targets[i].label}" → ${openMeteoResponses[i].body.length} chars',
      );
    }

    // Collect DWD points per location.
    final dwdByLocation = <String, List<DwdHourlyPoint>>{
      for (var i = 0; i < targets.length; i++)
        targets[i].label: dwdResponses[i],
    };
    for (final e in dwdByLocation.entries) {
      debugPrint(
        '[Weather] BrightSky/DWD "${e.key}" → ${e.value.length} points',
      );
    }

    var payload = await compute(buildForecastPayload, {
      'bodies': weatherBodies,
      'active_days': activeDays.toList(),
    });
    payload = addDwdToPayload(payload, dwdByLocation);

    // Merge the first available location's DWD data into the global rain events.
    final primaryDwd = dwdByLocation.values.firstOrNull ?? [];
    payload = mergeRainEventsFromDwd(payload, primaryDwd, now: DateTime.now());

    final evaluatedPayload = await const LlmService().applyEvaluation(payload);

    // ForecastResponse.location = location of the first upcoming session.
    final firstTraining =
        (evaluatedPayload['trainings'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .firstOrNull;
    final location =
        (firstTraining?['location'] as Map<String, dynamic>?) ??
        locationMap.values.firstOrNull?.toJson() ??
        const Location(lat: 0, lon: 0, label: 'Unbekannt').toJson();
    evaluatedPayload['location'] = location;
    return ForecastResponse.fromJson(evaluatedPayload);
  }

  /// Fetches the Open-Meteo forecast for [location] with a horizon of [days].
  Future<http.Response> _fetchOpenMeteo(Location location, int days) {
    final url = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${location.lat}',
      'longitude': '${location.lon}',
      'hourly':
          'temperature_2m,'
          'precipitation,'
          'rain,'
          'precipitation_probability,'
          'wind_speed_10m,'
          'cloud_cover',
      // Higher resolution for precipitation including probability
      'minutely_15': 'precipitation,precipitation_probability',
      'past_days': '1',
      'forecast_days': '$days',
      'timezone': _timezone,
    });

    debugPrint('[Weather] Open-Meteo URL for "${location.label}": $url');
    return http.get(url, headers: {'Accept': 'application/json'});
  }
}

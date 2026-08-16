import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inliner2/models/dwd_hourly_point.dart';
import 'package:inliner2/models/forecast_response.dart';
import 'package:inliner2/models/location.dart';
import 'package:inliner2/services/brightsky_service.dart';
import 'package:inliner2/services/secure_config_service.dart';
import 'package:inliner2/services/training_settings_service.dart';
import 'package:inliner2/utils/forecast_payload_utils.dart';
import 'package:inliner2/utils/llm_utils.dart';
import 'package:inliner2/utils/session_utils.dart';

abstract class ForecastRepository {
  Future<ForecastResponse> loadForecast();
}

class ForecastService implements ForecastRepository {
  const ForecastService();

  static const String _timezone = 'Europe/Berlin';
  static const String _llmApiBase = String.fromEnvironment(
    'LLM_API_BASE',
    defaultValue: '',
  );
  static const String _llmModel = String.fromEnvironment(
    'LLM_MODEL',
    defaultValue: '',
  );
  static const bool _llmDebugLogs = bool.fromEnvironment(
    'LLM_DEBUG_LOGS',
    defaultValue: true,
  );

  @override
  Future<ForecastResponse> loadForecast() async {
    // Load active days first to know which locations are needed.
    final activeDays = await TrainingSettingsService.loadActiveDays();
    final locationMap = locationsForActiveDays(activeDays);
    final forecastDaysMap = forecastDaysPerLocation(activeDays);

    // Build Open-Meteo URI for a specific location with its own forecast horizon.
    Uri openMeteoUri(Location loc) {
      final days = forecastDaysMap[loc.label] ?? 8;
      return Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${loc.lat}',
        'longitude': '${loc.lon}',
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
    }

    final locationList = locationMap.entries.toList();
    debugPrint('[Weather] Active days: $activeDays');
    debugPrint(
      '[Weather] Locations to fetch: ${locationList.map((e) => '${e.key} (${e.value.lat}, ${e.value.lon}) forecastDays=${forecastDaysMap[e.key]}').join(', ')}',
    );

    // Fetch Open-Meteo and BrightSky for every required location in parallel.
    final openMeteoResponses = await Future.wait(
      locationList.map(
        (e) => http.get(
          openMeteoUri(e.value),
          headers: {'Accept': 'application/json'},
        ),
      ),
    );
    final dwdResponses = await Future.wait(
      locationList.map((e) {
        final days = forecastDaysMap[e.key] ?? 8;
        return const BrightSkyService()
            .fetchPrecipitation(location: e.value, forecastDays: days)
            .catchError((dynamic err) {
              debugPrint('[Weather] BrightSky failed for ${e.key}: $err');
              return <DwdHourlyPoint>[];
            });
      }),
    );

    // Validate and collect weather bodies.
    final weatherBodies = <String, String>{};
    for (var i = 0; i < locationList.length; i++) {
      if (openMeteoResponses[i].statusCode != 200) {
        throw Exception(
          'Wetterdienst Fehler (${openMeteoResponses[i].statusCode}).',
        );
      }
      weatherBodies[locationList[i].key] = openMeteoResponses[i].body;
      debugPrint(
        '[Weather] Open-Meteo OK for "${locationList[i].key}" → ${openMeteoResponses[i].body.length} chars',
      );
    }

    // Collect DWD points per location.
    final dwdByLocation = <String, List<DwdHourlyPoint>>{
      for (var i = 0; i < locationList.length; i++)
        locationList[i].key: dwdResponses[i],
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
    payload = _addDwdToPayload(payload, dwdByLocation);

    // Use the first available location's DWD data for global rain-event overrides.
    final primaryDwd = dwdByLocation.values.firstOrNull ?? [];
    payload = _overrideRainEventsFromDwd(payload, primaryDwd);

    final evaluatedPayload = await _applyLlmEvaluation(payload);

    // ForecastResponse.location = location of the first upcoming session.
    final firstTraining =
        (evaluatedPayload['trainings'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .firstOrNull;
    final location =
        (firstTraining?['location'] as Map<String, dynamic>?) ??
        locationMap.values.first.toJson();
    evaluatedPayload['location'] = location;
    return ForecastResponse.fromJson(evaluatedPayload);
  }

  /// Assigns per-location DWD precipitation points to each training.
  Map<String, dynamic> _addDwdToPayload(
    Map<String, dynamic> payload,
    Map<String, List<DwdHourlyPoint>> dwdByLocation,
  ) {
    if (dwdByLocation.isEmpty) {
      debugPrint(
        '[DWD] dwdByLocation is empty – skipping dwd_points assignment',
      );
      return payload;
    }
    final trainings = (payload['trainings'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    for (final training in trainings) {
      final locationLabel =
          (training['location'] as Map<String, dynamic>?)?['label']
              as String? ??
          dwdByLocation.keys.first;
      final dwdPoints =
          dwdByLocation[locationLabel] ?? dwdByLocation.values.first;
      debugPrint(
        '[DWD] Training "${training['title']} ${training['start']}" '
        '→ location "$locationLabel" '
        '→ ${dwdPoints.length} DWD points available',
      );
      if (dwdPoints.isEmpty) {
        debugPrint('[DWD]   └─ no points, skipping');
        continue;
      }
      final start = DateTime.parse(training['start'] as String).toLocal();
      final end = DateTime.parse(training['end'] as String).toLocal();
      final windowStart = start.subtract(const Duration(hours: 4));
      final filtered = dwdPoints
          .where((p) => !p.time.isBefore(windowStart) && !p.time.isAfter(end))
          .toList();
      debugPrint(
        '[DWD]   └─ window ${windowStart.toIso8601String()} … ${end.toIso8601String()} → ${filtered.length} matching points',
      );
      training['dwd_points'] = filtered.map((p) => p.toJson()).toList();
    }
    return payload;
  }

  /// Replaces last_rain_event and next_rain_event in the payload with DWD values.
  Map<String, dynamic> _overrideRainEventsFromDwd(
    Map<String, dynamic> payload,
    List<DwdHourlyPoint> dwdPoints,
  ) {
    if (dwdPoints.isEmpty) return payload;
    final nowUtc = DateTime.now()..toUtc();
    final history24hStart = nowUtc.subtract(const Duration(hours: 24));

    // Last rain from DWD (last 24 hours)
    // BrightSky timestamps are already in local time – no offset needed.
    Map<String, dynamic>? lastRain;
    for (var i = dwdPoints.length - 1; i >= 0; i--) {
      final p = dwdPoints[i];
      final tUtc = p.time.toUtc();
      if (!tUtc.isBefore(history24hStart) &&
          !tUtc.isAfter(nowUtc) &&
          p.precipitationMm > 0.1) {
        lastRain = {
          'time': p.time.toIso8601String(),
          'rain_mm': p.precipitationMm,
        };
        break;
      }
    }

    // Next rain event from DWD (future)
    Map<String, dynamic>? nextRain;
    for (final p in dwdPoints) {
      if (p.time.toUtc().isAfter(nowUtc) && p.precipitationMm > 0.1) {
        nextRain = {
          'time': p.time.toIso8601String(),
          'rain_mm': p.precipitationMm,
        };
        break;
      }
    }

    payload['last_rain_event'] = lastRain;
    payload['next_rain_event'] = nextRain;
    return payload;
  }

  Future<Map<String, dynamic>> _applyLlmEvaluation(
    Map<String, dynamic> payload,
  ) async {
    final llmApiKey = await SecureConfigService.getLlmApiKey();
    if (llmApiKey.isEmpty) return payload;

    try {
      final trainings = (payload['trainings'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (trainings.isEmpty) return payload;

      final userPrompt = {
        'rain_history_24h': payload['rain_history_24h'] ?? [],
        'trainings': trainings.map((entry) {
          final start = DateTime.parse(entry['start'] as String).toLocal();
          final end = DateTime.parse(entry['end'] as String).toLocal();
          String fmt(DateTime t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
          return {
            'id': entry['id'],
            'title': entry['title'],
            'start': entry['start'],
            'end': entry['end'],
            'geplant': '${fmt(start)}–${fmt(end)} Uhr',
            'weather': entry['weather'],
            'precipitation_15m': entry['precipitation_15m'] ?? [],
            'fallback_score': entry['score'],
            'fallback_verdict': entry['verdict'],
            'fallback_reason': entry['reason'],
          };
        }).toList(),
      };

      const systemPrompt = """
        Du bist ein Wetter-Coach für Inline-Skating. Antworte AUSSCHLIESSLICH mit validem JSON in genau diesem Schema, ohne weiteren Text:
        {"evaluations":[{"id":"...","score":0-100,"verdict":"go|maybe|no","reason":"Begründung auf Deutsch","recommendation":"Training HH:MM–HH:MM Uhr ODER leerer String"}]}

        ## Grundregel
        Inline-Skaten ist NUR auf trockenem Asphalt möglich. Bewerte jedes Training mit einem Score (0-100) und einem verdict (go/maybe/no).

        ## Regenbewertung
        Nutze ausschließlich precipitation_15m (15-Minuten-Auflösung, Felder: time/precipitation_mm/precipitation_probability) im Fenster 4h vor Trainingsstart bis 2h nach Ende – das ist die einzige verbindliche Regenquelle. rain_history_24h liefert zusätzlichen Kontext zum Tagesverlauf.
        precipitation_probability: >= 70 = hohe Regenwahrscheinlichkeit, >= 40 = möglich, < 40 = gering.

        ## Asphalt-Trocknungszeiten nach Regen
        Bestimme die notwendige Wartezeit nach dem letzten Regen anhand der Schauer-Art und Umweltbedingungen:

        --- Kurzer Schauer (Oberfläche nur benetzt, keine tiefen Pfützen) ---
        - 14°C: mit Sonne 45-90 Min. | ohne Sonne (bewölkt/Schatten) 90-180 Min.
        - 16°C: mit Sonne 35-60 Min. | ohne Sonne + Wind (>=10 km/h) 75-100 Min. | ohne Sonne + Windstille 90-150 Min.
        - 24°C: mit Sonne 20-35 Min. | ohne Sonne 45-75 Min.
        - 30°C: mit Sonne 10-15 Min. | ohne Sonne 30-45 Min.

        --- Langer Schauer / Dauerregen (Asphalt tiefenvernässt, Pfützenbildung) ---
        - 14°C: mit Sonne 2-3,5 Std. | ohne Sonne 4-6 Std. (Trocknung oft unvollständig).
        - 16°C: mit Sonne 1,5-2,5 Std. | ohne Sonne + Wind (>=10 km/h) 2,5-3,5 Std. | ohne Sonne + Windstille 3,5-5 Std.
        - 24°C: mit Sonne 45-75 Min. | ohne Sonne 1,5-2,5 Std.
        - 30°C: mit Sonne 25-40 Min. | ohne Sonne 60-90 Min.

        Zusatzfaktoren: Wind (>=10 km/h) verkürzt die Wartezeit bei Bewölkung um ca. 20-30%. Waldwege, Schattenzonen oder hohe Luftfeuchtigkeit verdoppeln die Wartezeit bei 14-16°C; bei langem Schauer trocknen Waldwege unter 16°C oft gar nicht mehr am selben Tag ab.

        ## Verschiebungslogik, wenn es am Trainingstag geregnet hat oder Regen droht
        Wähle strikt eine der folgenden Optionen, bevorzugt Option A:
        - Option A (Priorität – Vorziehen): Start VOR den Regen vorziehen. Frühester Start am Wochenende 09:00 Uhr, Mo-Fr 18:00 Uhr. Dauer beibehalten oder bei Bedarf kürzen.
        - Option B (Nach hinten verschieben): Nur empfehlen, wenn nach dem Regen laut obiger Trocknungszeit-Tabelle eine verlässliche, durchgehende Trockenphase bis zum neuen Start erwartet wird.

        ## Empfehlungsformat (Feld "recommendation")
        - Immer als konkretes Zeitfenster: "Training HH:MM–HH:MM Uhr". Niemals pauschale Aussagen wie "1h kürzen" oder "verschieben" ohne Uhrzeiten.
        - Setze recommendation="" wenn: (1) verdict=go und keine sinnvolle Anpassung existiert, (2) das Zeitfenster identisch mit dem geplanten start/end ist, oder (3) keine echte Verbesserung durch eine Zeitverschiebung erreichbar ist.

        ## Begründung (Feld "reason")
        - Begründe ausfürlich. Erwähne, falls und wann es kurz vor dem Training geregnet hat.
        
        ## Weitere Faktoren
        Berücksichtige Wind und Temperatur zusätzlich zu Regen in Score und Begründung.
        """;

      // Gemini's generateContent endpoint: model + API key are part of the
      // request itself, not an OpenAI-style chat/completions call.
      final uri = Uri.parse('$_llmApiBase/models/$_llmModel:generateContent');

      debugPrint("LLM Modell: $_llmModel | URI: $_llmApiBase");
      final llmResponse = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-goog-api-key': llmApiKey,
            },
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': systemPrompt},
                ],
              },
              'contents': [
                {
                  'parts': [
                    {'text': jsonEncode(userPrompt)},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.2,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('[LLM] HTTP ${llmResponse.statusCode}');

      if (kDebugMode) {
        if (_llmDebugLogs) {
          _debugPrintInChunks('[LLM] Body: ${llmResponse.body}');
        }
      }

      if (llmResponse.statusCode < 200 || llmResponse.statusCode >= 300) {
        throw Exception('LLM API Fehler (${llmResponse.statusCode}).');
      }

      return compute(mergeLlmEvaluationsInPayload, {
        'payload': payload,
        'llmBody': llmResponse.body,
      });
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('LLM API Fehler: $e');
    }
  }
}

void _debugPrintInChunks(String message, {int chunkSize = 900}) {
  if (message.length <= chunkSize) {
    debugPrint(message);
    return;
  }
  final totalChunks = (message.length / chunkSize).ceil();
  var currentChunk = 0;
  for (var i = 0; i < message.length; i += chunkSize) {
    currentChunk++;
    final end = (i + chunkSize < message.length)
        ? i + chunkSize
        : message.length;
    debugPrint(
      '[LLM] Body ($currentChunk/$totalChunks): ${message.substring(i, end)}',
    );
  }
}

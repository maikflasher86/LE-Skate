import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inliner2/services/secure_config_service.dart';
import 'package:inliner2/utils/date_utils.dart';
import 'package:inliner2/utils/llm_utils.dart';

/// Evaluates the outdoor trainings of a forecast payload with the LLM
/// (Gemini `generateContent`).
class LlmService {
  const LlmService();

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

  /// Returns [payload] with the LLM evaluations merged in. Returns [payload]
  /// unchanged when no API key is configured or there are no outdoor
  /// trainings. Throws on any LLM failure.
  Future<Map<String, dynamic>> applyEvaluation(
    Map<String, dynamic> payload,
  ) async {
    final llmApiKey = await SecureConfigService.getLlmApiKey();
    if (llmApiKey.isEmpty) return payload;

    try {
      final trainings = (payload['trainings'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      // Indoor trainings have no weather data and are never evaluated.
      final outdoorTrainings = trainings
          .where((entry) => entry['is_indoor'] != true)
          .toList();
      if (outdoorTrainings.isEmpty) return payload;

      final userPrompt = {
        'rain_history_24h': payload['rain_history_24h'] ?? [],
        'trainings': outdoorTrainings.map((entry) {
          final start = DateTime.parse(entry['start'] as String).toLocal();
          final end = DateTime.parse(entry['end'] as String).toLocal();
          return {
            'id': entry['id'],
            'title': entry['title'],
            'start': entry['start'],
            'end': entry['end'],
            'geplant':
                '${formatHourMinute(start.hour, start.minute)}–'
                '${formatHourMinute(end.hour, end.minute)} Uhr',
            'weather': entry['weather'],
            'precipitation_15m': entry['precipitation_15m'] ?? [],
            'fallback_score': entry['score'],
            'fallback_verdict': entry['verdict'],
            'fallback_reason': entry['reason'],
          };
        }).toList(),
      };

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
                  {'text': _systemPrompt},
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
                'temperature': 0.0,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('[LLM] HTTP ${llmResponse.statusCode}');

      if (kDebugMode && _llmDebugLogs) {
        _debugPrintInChunks('[LLM] Body: ${llmResponse.body}');
      }

      if (llmResponse.statusCode < 200 || llmResponse.statusCode >= 300) {
        throw Exception('LLM API Fehler (${llmResponse.statusCode}).');
      }

      return await compute(mergeLlmEvaluationsInPayload, {
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

// The exact whitespace of this prompt is sent to the LLM; keep it unchanged.
const String _systemPrompt = """
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
        - Immer als konkretes Zeitfenster: "Training HH:MM–HH:MM Uhr". Keine pauschalen Aussagen wie "1h kürzen" oder "verschieben" ohne Uhrzeiten.
        - PFLICHT: Bei verdict=maybe oder verdict=no MUSST du ein Zeitfenster angeben, sobald laut precipitation_15m im Bereich
          [frühester erlaubter Start … geplantes Ende + 2h] eine zusammenhängende trockene Phase von mindestens 45 Minuten existiert
          (trocken = precipitation_mm <= 0.1 UND precipitation_probability < 40). Kürze die Dauer notfalls auf diese Trockenphase.
        - Das Zeitfenster MUSS sich vom Feld "geplant" unterscheiden. Empfiehl nie die geplante Zeit erneut.
        - Setze recommendation="" nur, wenn:
          (1) verdict=go und keine sinnvolle Anpassung existiert,
          (2) das Zeitfenster mit dem geplanten start/end identisch wäre, oder
          (3) im gesamten Suchbereich keine trockene Phase von mindestens 45 Minuten existiert.
        - Bei einer recommendation ergänze "reason" um eine Begründung, warum dieses Zeitfenster besser ist.

        ## Begründung (Feld "reason")
        - Begründe ausfürlich. Erwähne, falls und wann es kurz vor dem Training geregnet hat.
        
        ## Weitere Faktoren
        Berücksichtige Wind und Temperatur zusätzlich zu Regen in Score und Begründung.

        ## Zahlenformat
        Runde alle Werte wie Temperaturen, Windgeschwindigkeiten und ähnliche Messwerte in deiner Ausgabe (z.B. im Feld "reason") stets auf ganze Zahlen (keine Nachkommastellen).
        """;

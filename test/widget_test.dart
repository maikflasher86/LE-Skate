import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inliner2/main.dart';
import 'package:inliner2/models/forecast_response.dart';
import 'package:inliner2/models/location.dart';
import 'package:inliner2/models/training_course.dart';
import 'package:inliner2/models/training_forecast.dart';
import 'package:inliner2/models/weather_metrics.dart';
import 'package:inliner2/services/forecast_service.dart';
import 'package:inliner2/ui/widgets/score_badge.dart';
import 'package:inliner2/ui/widgets/training_card.dart';
import 'package:inliner2/ui/widgets/training_detail_sheet.dart';

void main() {
  testWidgets('displays forecast header and training card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      InlinerWeatherApp(service: _FakeForecastRepository()),
    );

    await tester.pumpAndSettle();

    expect(find.text('LE Skate'), findsOneWidget);
    expect(find.text('Sonntag Session'), findsOneWidget);
    // ScoreBadge shows llmScore
    expect(find.text('82'), findsOneWidget);
    expect(find.text('Sehr gute Bedingungen.'), findsOneWidget);
    // No recommendation → box is not displayed
    expect(find.textContaining('Empfehlung:'), findsNothing);
  });

  testWidgets('displays recommendation when LLM suggests adjustment', (
    WidgetTester tester,
  ) async {
    // The fake session is on a Friday, which the schedule classifies as an
    // "alternative" training day. Those are hidden unless the user opted in,
    // so enable the toggle here to ensure the card (and its recommendation)
    // is rendered.
    SharedPreferences.setMockInitialValues({
      'show_alternative_trainings': true,
    });

    await tester.pumpWidget(
      InlinerWeatherApp(service: _FakeWithRecommendationRepository()),
    );

    await tester.pumpAndSettle();

    // Recommendation is displayed directly without prefix
    expect(find.textContaining('Start auf 17:00 verschieben'), findsOneWidget);
  });

  testWidgets('displays "not recommended" and wet road reason', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      InlinerWeatherApp(service: _FakeRoadWetRepository()),
    );

    await tester.pumpAndSettle();

    // llmScore is null → badge shows '–', reason is displayed in text
    expect(find.text('–'), findsOneWidget);
    expect(find.textContaining('Fahrbahn nass'), findsOneWidget);
  });

  testWidgets('renders an indoor training card without score', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingCard(
            training: TrainingForecast(
              id: 'day6_2026-11-21',
              title: 'Samstag',
              trainingName: 'EVS',
              start: DateTime(2026, 11, 21, 14, 0),
              end: DateTime(2026, 11, 21, 16, 0),
              llmScore: null,
              verdict: 'Indoor',
              reason: '',
              weather: null,
              isIndoor: true,
              locationLabel: 'Evangelisches Schulzentrum (EvaSchulze)',
              courses: const [
                TrainingCourse(
                  category: 'Fitness',
                  instructors: [
                    'Annett Marien',
                    'Michael Marien',
                    'Annett Voigt',
                  ],
                  content: 'Skate',
                  equipment: 'Skates / Technik & Spaß',
                  notes: ['Sporthalle'],
                ),
                TrainingCourse(
                  category: 'Kurs',
                  instructors: ['Sven Knauer-Goldschmidt'],
                  content: 'Skate',
                  equipment: 'Skates / Technik & Spaß',
                  notes: ['Sporthalle', 'Nur nach Voranmeldung'],
                ),
              ],
            ),
            rawApiJson: '',
          ),
        ),
      ),
    );

    expect(find.text('Samstag'), findsOneWidget);
    expect(find.text('EVS'), findsOneWidget);
    expect(find.text('21.11.2026 14:00 – 16:00 Uhr'), findsOneWidget);
    expect(find.byType(ScoreBadge), findsNothing);
    expect(find.text('Details & Diagramme'), findsNothing);

    await tester.tap(find.text('EVS'));
    await tester.pumpAndSettle();

    expect(find.byType(TrainingDetailSheet), findsOneWidget);
    expect(find.text('KURSDETAILS'), findsOneWidget);
    expect(
      find.text('Evangelisches Schulzentrum (EvaSchulze)'),
      findsOneWidget,
    );
    expect(find.text('Sven Knauer-Goldschmidt'), findsOneWidget);
    expect(find.text('Übungsleiter'), findsNWidgets(2));
    expect(find.textContaining('Nur nach Voranmeldung'), findsOneWidget);
  });

  testWidgets('tapping a training card opens the detail sheet', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      InlinerWeatherApp(service: _FakeForecastRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TrainingDetailSheet), findsNothing);

    await tester.tap(find.text('Sonntag Session'));
    await tester.pumpAndSettle();

    expect(find.byType(TrainingDetailSheet), findsOneWidget);
    expect(find.text('BEWERTUNG'), findsOneWidget);
    expect(find.text('KI-Bewertung'), findsOneWidget);
    expect(find.text('BEGRÜNDUNG'), findsOneWidget);
    expect(find.text('WETTER IM TRAININGSZEITRAUM'), findsOneWidget);
    // The fake has no raw Open-Meteo JSON, so no hourly charts are available.
    final hint = find.text(
      'Stundendaten für diesen Termin noch nicht verfügbar.',
    );
    await tester.scrollUntilVisible(
      hint,
      200,
      scrollable: find
          .descendant(
            of: find.byType(TrainingDetailSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(hint, findsOneWidget);
  });
}

// --- Fake Repositories ---

class _FakeForecastRepository implements ForecastRepository {
  @override
  Future<ForecastResponse> loadForecast() async {
    return ForecastResponse(
      location: Location(
        lat: 51.3720365653869,
        lon: 12.343817084568474,
        label: 'Leipzig Inline Spot',
      ),
      fetchedAt: DateTime(2026, 7, 5, 9, 30),
      trainings: [
        TrainingForecast(
          id: 'sunday-1',
          title: 'Sonntag Session',
          trainingName: "Foo",
          start: DateTime(2026, 7, 5, 10, 0),
          end: DateTime(2026, 7, 5, 12, 0),
          llmScore: 82,
          verdict: 'Go',
          reason: 'Sehr gute Bedingungen.',
          recommendation: null,
          weather: WeatherMetrics(
            temperatureC: 21.4,
            windKmh: 11.2,
            precipitationMm: 0,
            rainMm: 0,
            precipitationProbabilityPercent: 15,
            cloudCoverPercent: 42,
          ),
        ),
      ],
    );
  }
}

class _FakeWithRecommendationRepository implements ForecastRepository {
  @override
  Future<ForecastResponse> loadForecast() async {
    return ForecastResponse(
      location: Location(
        lat: 51.3720365653869,
        lon: 12.343817084568474,
        label: 'Leipzig Inline Spot',
      ),
      fetchedAt: DateTime(2026, 7, 10, 18, 0),
      trainings: [
        TrainingForecast(
          id: 'friday-1',
          title: 'Freitag Session',
          trainingName: "Foo",
          start: DateTime(2026, 7, 10, 19, 0),
          end: DateTime(2026, 7, 10, 21, 0),
          llmScore: 55,
          verdict: 'Maybe',
          reason: 'Leichter Regen möglich, Bedingungen grenzwertig.',
          recommendation: 'Start auf 17:00 verschieben',
          weather: WeatherMetrics(
            temperatureC: 17.0,
            windKmh: 14.5,
            precipitationMm: 0.3,
            rainMm: 0.3,
            precipitationProbabilityPercent: 55,
            cloudCoverPercent: 78,
          ),
        ),
      ],
    );
  }
}

class _FakeRoadWetRepository implements ForecastRepository {
  @override
  Future<ForecastResponse> loadForecast() async {
    return ForecastResponse(
      location: Location(
        lat: 51.3720365653869,
        lon: 12.343817084568474,
        label: 'Leipzig Inline Spot',
      ),
      fetchedAt: DateTime(2026, 7, 5, 9, 30),
      trainings: [
        TrainingForecast(
          id: 'sunday-1',
          title: 'Sonntag Session',
          trainingName: "Foo",
          start: DateTime(2026, 7, 5, 10, 0),
          end: DateTime(2026, 7, 5, 12, 0),
          llmScore: null,
          verdict: 'No',
          reason: 'Regen kurz vor dem Training – Fahrbahn nass, Training nicht möglich.',
          recommendation: null,
          weather: WeatherMetrics(
            temperatureC: 18.0,
            windKmh: 8.0,
            precipitationMm: 0.5,
            rainMm: 0.5,
            precipitationProbabilityPercent: 90,
            cloudCoverPercent: 80,
          ),
        ),
      ],
    );
  }
}

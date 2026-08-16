import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inliner2/main.dart';
import 'package:inliner2/models/forecast_response.dart';
import 'package:inliner2/models/location.dart';
import 'package:inliner2/models/training_forecast.dart';
import 'package:inliner2/models/weather_metrics.dart';
import 'package:inliner2/services/forecast_service.dart';

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
          reason:
              'Regen kurz vor dem Training – Fahrbahn nass, Training nicht möglich.',
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

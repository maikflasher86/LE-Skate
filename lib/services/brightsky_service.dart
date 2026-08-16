import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:inliner2/models/dwd_hourly_point.dart';
import 'package:inliner2/models/location.dart';

/// Fetches hourly DWD precipitation data from BrightSky API.
/// BrightSky is free, requires no API key, based on DWD data.
class BrightSkyService {
  const BrightSkyService();

  /// Fetches precipitation for the given [location].
  /// [forecastDays] limits how far ahead data is requested (default: 10 days).
  Future<List<DwdHourlyPoint>> fetchPrecipitation({
    required Location location,
    int forecastDays = 10,
  }) async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(hours: 24));
    final to = now.add(Duration(days: forecastDays));

    final uri = Uri.https('api.brightsky.dev', '/weather', {
      'lat': '${location.lat}',
      'lon': '${location.lon}',
      'date': from.toUtc().toIso8601String(),
      'last_date': to.toUtc().toIso8601String(),
    });

    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('BrightSky/DWD Fehler (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final weather = (json['weather'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return weather.map(DwdHourlyPoint.fromBrightSky).toList();
  }
}

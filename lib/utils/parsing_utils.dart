List<double> toDoubleList(List<dynamic> values) {
  return values.map(toDoubleOrZero).toList();
}

List<double> toDoubleListOrDefault(
  dynamic values, {
  required int fallbackLength,
}) {
  if (values is List<dynamic>) {
    return values.map(toDoubleOrZero).toList();
  }
  return List<double>.filled(fallbackLength, 0);
}

double toDoubleOrZero(dynamic value) {
  return (value as num?)?.toDouble() ?? 0;
}

/// Extracts the `rain` array from an Open-Meteo `hourly` JSON map, falling
/// back to [precipitationFallback] when `rain` is absent or empty (some
/// older/partial API responses omit it).
List<double> extractRainOrFallback(
  Map<String, dynamic> hourly,
  List<double> precipitationFallback,
) {
  final rainRaw = hourly['rain'] as List<dynamic>?;
  return (rainRaw != null && rainRaw.isNotEmpty)
      ? toDoubleList(rainRaw)
      : precipitationFallback;
}

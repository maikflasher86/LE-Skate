class Location {
  const Location({required this.lat, required this.lon, required this.label});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      label: json['label'] as String,
    );
  }

  final double lat;
  final double lon;
  final String label;

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon, 'label': label};
}

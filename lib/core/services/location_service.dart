import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationSuggestion {
  final String displayName;
  final double lat;
  final double lon;

  LocationSuggestion({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      displayName: json['display_name'] ?? '',
      lat: double.tryParse(json['lat'] ?? '0.0') ?? 0.0,
      lon: double.tryParse(json['lon'] ?? '0.0') ?? 0.0,
    );
  }
}

class LocationService {
  static Future<List<LocationSuggestion>> getSuggestions(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'JalDharan/1.0 (com.example.jaldharan)'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) => LocationSuggestion.fromJson(item)).toList();
      } else {
        return [];
      }
    } catch (e) {
      // In production, log this error
      return [];
    }
  }
}

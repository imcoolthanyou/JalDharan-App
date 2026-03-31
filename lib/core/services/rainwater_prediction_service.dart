import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/structure_prediction.dart';
import '../config/api_config.dart';

class RainwaterPredictionService {
  static Future<StructurePrediction> predictStructure({
    required double lat,
    required double lon,
    required double roofAreaSqm,
    required double openSpaceSqm,
    required int numberOfDwellers,
    required String existingStructure,
  }) async {
    try {
      final url = Uri.parse(ApiConfig.predictStructureEndpoint);

      final body = {
        'lat': lat,
        'lon': lon,
        'roof_area_sqm': roofAreaSqm,
        'open_space_sqm': openSpaceSqm,
        'number_of_dwellers': numberOfDwellers,
        'existing_structure': existingStructure,
      };

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(
            ApiConfig.requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return StructurePrediction.fromJson(jsonData);
      } else {
        throw Exception(
          'Failed to get prediction: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}

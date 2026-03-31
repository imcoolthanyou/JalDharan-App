import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException, TimeoutException;
import 'package:http/http.dart' as http;
import '../models/groundwater_data.dart';
import '../config/api_config.dart';

class DashboardApiService {
  // Singleton pattern
  static final DashboardApiService _instance = DashboardApiService._internal();

  factory DashboardApiService() {
    return _instance;
  }

  DashboardApiService._internal();

  /// Fetch dashboard data from the mobile endpoint
  ///
  /// Returns: GroundwaterData with current sensor readings
  /// Throws: Exception if the request fails
  Future<GroundwaterData> fetchDashboardData({
    String userId = 'test_user',
  }) async {
    try {
      final url = Uri.parse(
        '${ApiConfig.dashboardEndpoint}?user_id=$userId',
      );

      final response = await http.get(url).timeout(
        ApiConfig.requestTimeout,
        onTimeout: () {
          throw Exception('Request timeout: Could not reach server');
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return GroundwaterData.fromJson(json);
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint not found (404): $url');
      } else if (response.statusCode == 500) {
        throw Exception('Server error (500): ${response.body}');
      } else {
        throw Exception(
          'Failed to load dashboard data: ${response.statusCode}\n'
          '${response.body}',
        );
      }
    } on SocketException catch (e) {
      throw Exception('Network error: Unable to connect to server\n$e');
    } on TimeoutException catch (e) {
      throw Exception('Request timed out: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Check if the API is reachable (health check)
  Future<bool> isServerReachable() async {
    try {
      final url = Uri.parse('${ApiConfig.dashboardEndpoint}?user_id=test_user');
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Send prompt to local Ollama instance to generate a summary report
  Future<String> generateAiReport(GroundwaterData data) async {
    try {
      final String prompt = '''
You are Jal Dharan AI, a water monitoring expert. Generate a very brief summary and future prediction based on these current readings:
TDS: ${data.tdsLevel} ppm
pH: ${data.phLevel}
Depth: ${data.sensorDistanceCm} cm
Water Quality: ${data.qualityStatus}

Write 2 short paragraphs:
1. Current State Summary
2. Future Predictions & Advice

Do not use formatting like markdown bold (*). Just plain text.
''';

      // Address for physical device to reach host's localhost where Ollama runs
      final ollamaUrl = Uri.parse('http://10.90.72.219:11434/api/generate'); 
      final response = await http.post(
        ollamaUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'models': 'gemma3:4b',
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.7,
            'num_predict': 250,
          }
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['response']?.toString().trim() ?? 'No summary generated.';
      } else {
        return 'AI Summary could not be generated at this time (Error ${response.statusCode}).';
      }
    } catch (e) {
      return 'AI Summary failed: Ensure local Ollama is running and models gemma3:4b is pulled.';
    }
  }
}

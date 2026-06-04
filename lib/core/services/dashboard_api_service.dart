import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import '../models/groundwater_data.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class DashboardApiService {
  static final DashboardApiService _instance = DashboardApiService._internal();
  factory DashboardApiService() => _instance;
  DashboardApiService._internal();

  final AuthService _authService = AuthService();

  /// Fetch dashboard data from the authenticated /dashboard endpoint.
  /// Returns GroundwaterData from the first claimed device.
  /// Throws [NoDeviceException] if the user has no claimed devices.
  Future<GroundwaterData> fetchDashboardData({
    String userId = 'test_user',
  }) async {
    try {
      final headers = await _authService.authHeaders();
      final url = Uri.parse(ApiConfig.dashboardEndpoint);

      final response = await http
          .get(url, headers: headers)
          .timeout(
            ApiConfig.requestTimeout,
            onTimeout: () =>
                throw Exception('Request timeout: Could not reach server'),
          );

      // Debug log the raw response body for troubleshooting
      // ignore: avoid_print
      print('Dashboard response: \\n${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        // New response shape: { "devices": [...] }
        if (json is Map && json.containsKey('devices')) {
          final devices = json['devices'] as List;
          if (devices.isEmpty) throw NoDeviceException();
          // Use first device's data
          return GroundwaterData.fromDeviceJson(
            devices[0] as Map<String, dynamic>,
          );
        }

        // Fallback: old flat shape (for backward compat during transition)
        return GroundwaterData.fromJson(json as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please sign in again');
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint not found (404)');
      } else if (response.statusCode == 500) {
        throw Exception('Server error (500): ${response.body}');
      } else {
        throw Exception(
          'Failed to load dashboard data: ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      throw Exception('Network error: Unable to connect to server\n$e');
    } on NoDeviceException {
      rethrow;
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      rethrow;
    }
  }

  /// Check if the API is reachable (health check)
  Future<bool> isServerReachable() async {
    try {
      final headers = await _authService.authHeaders();
      final response = await http
          .get(Uri.parse(ApiConfig.dashboardEndpoint), headers: headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Send prompt to local Ollama instance to generate a summary report
  Future<String> generateAiReport(GroundwaterData data) async {
    try {
      final String prompt =
          '''
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

      final ollamaUrl = Uri.parse('http://10.90.72.219:11434/api/generate');
      final response = await http
          .post(
            ollamaUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'models': 'gemma3:4b',
              'prompt': prompt,
              'stream': false,
              'options': {'temperature': 0.7, 'num_predict': 250},
            }),
          )
          .timeout(const Duration(seconds: 30));

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

/// Thrown when the user has no claimed devices
class NoDeviceException implements Exception {
  final String message;
  NoDeviceException([this.message = 'No device claimed yet']);
  @override
  String toString() => message;
}

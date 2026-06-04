import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class RAGResponse {
  final String reply;
  final String timestamp;

  RAGResponse({required this.reply, required this.timestamp});

  factory RAGResponse.fromJson(Map<String, dynamic> json) {
    return RAGResponse(
      reply:
          json['reply'] ?? 'Unable to process your question. Please try again.',
      timestamp: json['timestamp'] ?? DateTime.now().toString(),
    );
  }
}

class RAGService {
  static Future<RAGResponse> sendMessage(String message) async {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(ApiConfig.aiRagEndpoint))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'message': message});

      // Send and stream response — no socket-level timeout, only our Future timeout
      final streamedResponse = await client
          .send(request)
          .timeout(
            ApiConfig.aiRequestTimeout,
            onTimeout: () => throw TimeoutException(
              'AI model is taking too long. Please try again.',
              ApiConfig.aiRequestTimeout,
            ),
          );

      final response = await http.Response.fromStream(streamedResponse).timeout(
        ApiConfig.aiRequestTimeout,
        onTimeout: () => throw TimeoutException(
          'AI model response timed out while streaming.',
          ApiConfig.aiRequestTimeout,
        ),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return RAGResponse.fromJson(json);
      } else if (response.statusCode == 400) {
        throw Exception('Invalid request: ${response.body}');
      } else if (response.statusCode == 500) {
        throw Exception('Server error: Unable to process your question');
      } else {
        throw Exception('Failed with status: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      throw Exception('⏱ ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception(
        'Cannot connect to AI service\n'
        'Endpoint: ${ApiConfig.aiRagEndpoint}\n'
        'Error: $e',
      );
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<RAGResponse> sendMessageWithContext({
    required String message,
    required Map<String, dynamic> groundwaterData,
  }) async {
    final client = http.Client();
    try {
      final context = {
        'current_depth': groundwaterData['currentDepth'],
        'water_quality': groundwaterData['qualityStatus'],
        'ph': groundwaterData['phLevel'],
        'tds': groundwaterData['tdsLevel'],
        'flow_rate': groundwaterData['flowRate'],
        'motor_status': groundwaterData['motorStatus'],
        'weather_condition': groundwaterData['weatherCondition'],
        'rain_alert': groundwaterData['rainAlert'],
      };

      final request = http.Request('POST', Uri.parse(ApiConfig.aiRagEndpoint))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'message': message, 'context': context});

      final streamedResponse = await client
          .send(request)
          .timeout(
            ApiConfig.aiRequestTimeout,
            onTimeout: () => throw TimeoutException(
              'AI model timed out.',
              ApiConfig.aiRequestTimeout,
            ),
          );

      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(ApiConfig.aiRequestTimeout);

      if (response.statusCode == 200) {
        return RAGResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed with status: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      throw Exception('⏱ ${e.message}');
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
  }
}

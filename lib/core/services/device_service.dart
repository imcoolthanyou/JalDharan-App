import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final AuthService _authService = AuthService();

  /// Claim a device by MAC address
  /// Throws on 409 (already claimed by another user) or other errors
  Future<Map<String, dynamic>> claimDevice(
    String deviceMac,
    String deviceName,
  ) async {
    final headers = await _authService.authHeaders();
    final response = await http
        .post(
          Uri.parse(ApiConfig.devicesClaimEndpoint),
          headers: headers,
          body: jsonEncode({
            'device_mac': deviceMac,
            'device_name': deviceName,
          }),
        )
        .timeout(ApiConfig.requestTimeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 409) {
      throw Exception('Device already claimed by another user.');
    } else {
      throw Exception('Failed to claim device: ${response.statusCode}');
    }
  }

  /// Poll /dashboard to check if any device has appeared for this user
  /// Returns the devices list (may be empty)
  Future<List<dynamic>> getUserDevices() async {
    final headers = await _authService.authHeaders();
    final response = await http
        .get(Uri.parse(ApiConfig.dashboardEndpoint), headers: headers)
        .timeout(ApiConfig.requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Backend returns devices list or wraps it
      if (data is List) return data;
      if (data is Map && data.containsKey('devices'))
        return data['devices'] as List;
      return [];
    } else {
      throw Exception('Failed to fetch devices: ${response.statusCode}');
    }
  }
}

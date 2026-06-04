class ApiConfig {
  static const String baseUrl = 'https://jal-dharan-backend-827267712942.asia-south1.run.app';

  // Dashboard endpoints
  static const String dashboardEndpoint = '$baseUrl/dashboard';
  static const String mobileDashboardEndpoint =
      '$baseUrl/mobile/dashboard'; // legacy
  static const String weatherForecastEndpoint = '$baseUrl/weather/forecast';

  // Pump control endpoints
  static const String pumpControlEndpoint = '$baseUrl/control/pump';

  // Rainwater harvesting endpoints
  static const String predictStructureEndpoint =
      '$baseUrl/api/recommend-structure';

  // AI endpoints
  static const String aiVerificationEndpoint = '$baseUrl/ai_verification';
  static const String aiRagEndpoint = '$baseUrl/ai_rag';

  // Auth & Device endpoints (backend JWT)
  static const String authGoogleEndpoint = '$baseUrl/auth/google';
  static const String devicesClaimEndpoint = '$baseUrl/devices/claim';
  static const String profileEndpoint = '$baseUrl/profile';

  // ESP32 provisioning — captive portal is ALWAYS at 192.168.4.1 (ESP32 default AP IP)
  // This is fixed by ESP32 firmware and must NOT use baseUrl
  static const String espSsid = 'JalDharan_Setup';
  static const String espBaseUrl = 'http://192.168.4.1';
  static const String espInfoEndpoint = '$espBaseUrl/info';
  static const String espSaveEndpoint = '$espBaseUrl/save';

  // Request timeouts
  static const Duration requestTimeout = Duration(seconds: 10);
  static const Duration aiRequestTimeout = Duration(
    seconds: 120,
  ); // AI models can be slow

  // Socket.IO Configuration
  // ========================
  // The SocketService automatically connects to:
  // WebSocket: ws://{baseUrl}
  //
  // Backend Socket.IO Server emits 'sensor_update' event with RAW SENSOR DATA ONLY:
  // {
  //   "water_depth_m": double,
  //   "flow_rate_L_min": double,
  //   "tds_value": double,
  //   "pump_current_amps": double,
  //   "voltage": double,
  //   "ph": double,
  //   "timestamp": string (ISO format)
  // }
  //
  // This is the LIVE/REAL-TIME sensor data stream.
  // Calculated data (water_quality, motor_load, groundwater_trend, weather_data)
  // comes from the REST endpoint /mobile/dashboard which should be called
  // periodically (every 5-10 seconds) to get the full calculated data.
  //
  // See SOCKET_IO_INTEGRATION.txt for complete documentation
}

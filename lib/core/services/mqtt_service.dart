import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/api_config.dart';
import 'dart:developer' as developer;

/// Real-time MQTT service for live sensor data updates
/// Handles connection, disconnection, and automatic reconnection
class MqttService with ChangeNotifier {
  late MqttServerClient client;
  bool isConnected = false;
  bool isConnecting = false;

  // Latest data from sensors — keyed by device_mac
  // e.g. { "1C:69:20:A3:4E:98": { ...data }, "28:05:A5:6E:71:B8": { ...data } }
  final Map<String, Map<String, dynamic>> deviceDataMap = {};

  // Legacy single-device field (kept for backward compatibility)
  Map<String, dynamic>? latestSensorData;
  String? lastError;

  // Callbacks for listening to data changes
  final List<Function(Map<String, dynamic>)> _sensorUpdateListeners = [];
  final List<Function(bool)> _connectionStatusListeners = [];

  // Singleton pattern
  static final MqttService _instance = MqttService._internal();

  factory MqttService() {
    return _instance;
  }

  MqttService._internal() {
    final clientId = 'fl_${DateTime.now().millisecondsSinceEpoch % 10000}';
    client = MqttServerClient(ApiConfig.mqttBrokerUrl, clientId);
    client.port = ApiConfig.mqttPort;
    client.logging(on: true);
    client.setProtocolV311();
    client.keepAlivePeriod = 60;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onAutoReconnect = onAutoReconnect;
    client.onAutoReconnected = onAutoReconnected;
    client.autoReconnect = true;
  }

  /// Returns latest data for a specific device MAC, or null if not yet received
  Map<String, dynamic>? getDeviceData(String mac) => deviceDataMap[mac];

  /// Initialize MQTT connection
  Future<void> initConnection() async {
    if (isConnecting || isConnected) {
      developer.log('MQTT already connecting or connected, skipping init');
      return;
    }

    isConnecting = true;
    notifyListeners();

    developer.log(
        '🔌 Initializing MQTT connection to ${ApiConfig.mqttBrokerUrl}:${ApiConfig.mqttPort}');

    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      developer.log('MQTT Client exception: $e');
      client.disconnect();
      lastError = e.toString();
      isConnecting = false;
      notifyListeners();
    } catch (e) {
      developer.log('MQTT Error: $e');
      client.disconnect();
      lastError = e.toString();
      isConnecting = false;
      notifyListeners();
    }
  }

  void onConnected() {
    developer.log('✅ MQTT Connected to backend');
    isConnected = true;
    isConnecting = false;
    lastError = null;
    notifyListeners();

    for (var listener in _connectionStatusListeners) {
      listener(true);
    }

    // Subscribe to wildcard — catches ALL devices under jaldharan/sensors/
    const wildcardTopic = 'jaldharan/sensors/#';
    developer.log('📡 Subscribing to topic: $wildcardTopic');
    client.subscribe(wildcardTopic, MqttQos.atMostOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message);

      developer.log(
          '📡 New Sensor Data on topic <${c[0].topic}>: $pt');

      try {
        final data = json.decode(pt) as Map<String, dynamic>;
        // Ignore pump control / actuator feedback if needed
        final type = data['type']?.toString();
        final topic = c[0].topic;

// Optional: ignore pump-status messages
        if (type == 'pump_status' || type == 'actuator') {
          developer.log("⛔ Ignored actuator message from MQTT");
          return;
        }

        // Identify device by MAC in payload, fallback to topic suffix
        final String mac = (data['device_mac'] as String?) ??
            c[0].topic.split('/').last;

        // Store per-device
        deviceDataMap[mac] = data;

        // Keep legacy field updated (last received device)
        latestSensorData = data;
        lastError = null;
        notifyListeners();

        for (var listener in _sensorUpdateListeners) {
          listener(data);
        }
      } catch (e) {
        developer.log('❌ Error parsing MQTT message: $e');
      }
    });
  }

  void onDisconnected() {
    developer.log('❌ MQTT Disconnected from backend');
    isConnected = false;
    isConnecting = false;
    notifyListeners();

    for (var listener in _connectionStatusListeners) {
      listener(false);
    }
  }

  void onAutoReconnect() {
    developer.log('🔌 MQTT Auto Reconnecting...');
    isConnecting = true;
    notifyListeners();
  }

  void onAutoReconnected() {
    developer.log('✅ MQTT Auto Reconnected');
    isConnected = true;
    isConnecting = false;
    notifyListeners();
    for (var listener in _connectionStatusListeners) {
      listener(true);
    }
  }

  /// Disconnect from MQTT
  void disconnect() {
    if (isConnected || isConnecting) {
      developer.log('🔌 Disconnecting MQTT...');
      client.disconnect();
    }
  }

  /// Reconnect to MQTT
  void reconnect() {
    if (!isConnected && !isConnecting) {
      developer.log('🔌 Reconnecting MQTT...');
      initConnection();
    }
  }

  void addSensorUpdateListener(Function(Map<String, dynamic>) listener) {
    _sensorUpdateListeners.add(listener);
  }

  void removeSensorUpdateListener(Function(Map<String, dynamic>) listener) {
    _sensorUpdateListeners.remove(listener);
  }

  void addConnectionStatusListener(Function(bool) listener) {
    _connectionStatusListeners.add(listener);
  }

  void removeConnectionStatusListener(Function(bool) listener) {
    _connectionStatusListeners.remove(listener);
  }

  String getConnectionStatus() {
    if (isConnected) return 'Connected';
    if (isConnecting) return 'Connecting...';
    return 'Disconnected';
  }

  @override
  void dispose() {
    disconnect();
    _sensorUpdateListeners.clear();
    _connectionStatusListeners.clear();
    super.dispose();
  }
}
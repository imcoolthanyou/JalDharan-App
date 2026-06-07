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

  // Latest data from sensors
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
    // Initialize the client with a shorter ID
    final clientId = 'fl_${DateTime.now().millisecondsSinceEpoch % 10000}';
    client = MqttServerClient(ApiConfig.mqttBrokerUrl, clientId);
    client.port = ApiConfig.mqttPort;
    client.logging(on: true); // Enable logging to see the error
    client.setProtocolV311(); // Strongly recommended for mosquitto
    client.keepAlivePeriod = 60;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onAutoReconnect = onAutoReconnect;
    client.onAutoReconnected = onAutoReconnected;
    client.autoReconnect = true;
  }

  /// Initialize MQTT connection
  Future<void> initConnection() async {
    if (isConnecting || isConnected) {
      developer.log('MQTT already connecting or connected, skipping init');
      return;
    }

    isConnecting = true;
    notifyListeners();

    developer.log('🔌 Initializing MQTT connection to ${ApiConfig.mqttBrokerUrl}:${ApiConfig.mqttPort}');

    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      developer.log('❌ MQTT Client exception: $e');
      client.disconnect();
      lastError = e.toString();
      isConnecting = false;
      notifyListeners();
    } catch (e) {
      developer.log('❌ MQTT Error: $e');
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

    // Notify all listeners
    for (var listener in _connectionStatusListeners) {
      listener(true);
    }

    // Subscribe to the topic
    developer.log('📡 Subscribing to topic: ${ApiConfig.mqttTopic}');
    client.subscribe(ApiConfig.mqttTopic, MqttQos.atMostOnce);

    // Listen to updates
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      developer.log('📡 New Sensor Data Received on topic <${c[0].topic}>: $pt');

      try {
        final data = json.decode(pt) as Map<String, dynamic>;
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

  /// Add listener for sensor data updates
  void addSensorUpdateListener(Function(Map<String, dynamic>) listener) {
    _sensorUpdateListeners.add(listener);
  }

  /// Remove listener for sensor data updates
  void removeSensorUpdateListener(Function(Map<String, dynamic>) listener) {
    _sensorUpdateListeners.remove(listener);
  }

  /// Add listener for connection status changes
  void addConnectionStatusListener(Function(bool) listener) {
    _connectionStatusListeners.add(listener);
  }

  /// Remove listener for connection status changes
  void removeConnectionStatusListener(Function(bool) listener) {
    _connectionStatusListeners.remove(listener);
  }

  /// Get connection status as string
  String getConnectionStatus() {
    if (isConnected) return 'Connected';
    if (isConnecting) return 'Connecting...';
    return 'Disconnected';
  }

  /// Dispose resources
  @override
  void dispose() {
    disconnect();
    _sensorUpdateListeners.clear();
    _connectionStatusListeners.clear();
    super.dispose();
  }
}

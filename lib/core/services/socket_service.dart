import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'dart:developer' as developer;

/// Real-time Socket.IO service for live sensor data updates
/// Handles connection, disconnection, and automatic reconnection
class SocketService with ChangeNotifier {
  late IO.Socket socket;
  bool isConnected = false;
  bool isConnecting = false;

  // Latest data from sensors
  Map<String, dynamic>? latestSensorData;
  String? lastError;

  // Callbacks for listening to data changes
  final List<Function(Map<String, dynamic>)> _sensorUpdateListeners = [];
  final List<Function(bool)> _connectionStatusListeners = [];

  // Singleton pattern
  static final SocketService _instance = SocketService._internal();

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  /// Initialize Socket.IO connection
  void initSocket() {
    if (isConnecting || isConnected) {
      developer.log('Socket already connecting or connected, skipping init');
      return;
    }

    isConnecting = true;
    notifyListeners();

    developer.log(
      '🔌 Initializing Socket.IO connection to ${ApiConfig.baseUrl}',
    );

    // Updated options map - more reliable across Android/iOS than OptionBuilder
    socket = IO.io(ApiConfig.baseUrl, <String, dynamic>{
      'transports': ['websocket'], // Use WebSocket transport
      'autoConnect': true, // Auto reconnect on disconnect
      'reconnectionAttempts': double.infinity, // Retry forever
      'reconnectionDelay': 1000, // Delay between reconnection attempts
      'reconnectionDelayMax': 5000, // Max delay
    });

    // ===== Connection Events =====
    socket.onConnect((_) {
      developer.log('✅ Socket Connected to backend');
      isConnected = true;
      isConnecting = false;
      lastError = null;
      notifyListeners();

      // Notify all listeners
      for (var listener in _connectionStatusListeners) {
        listener(true);
      }
    });

    socket.onDisconnect((_) {
      developer.log('❌ Socket Disconnected from backend');
      isConnected = false;
      isConnecting = false;
      notifyListeners();

      // Notify all listeners
      for (var listener in _connectionStatusListeners) {
        listener(false);
      }
    });

    // ===== Sensor Data Event =====
    /// Listen for 'sensor_update' event from backend
    /// Backend emits this whenever /sensor/update is hit by ESP32
    socket.on('sensor_update', (data) {
      developer.log('📡 New Sensor Data Received: $data');
      latestSensorData = data;
      lastError = null;
      notifyListeners();

      // Notify all listeners
      for (var listener in _sensorUpdateListeners) {
        listener(data);
      }
    });

    // ===== Error Handling =====
    socket.onError((error) {
      developer.log('❌ Socket Error: $error');
      lastError = error.toString();
      notifyListeners();
    });

    socket.onConnectError((error) {
      developer.log('❌ Socket Connection Error: $error');
      lastError = error.toString();
      notifyListeners();
    });
  }

  /// Disconnect from Socket.IO
  void disconnect() {
    if (socket.connected) {
      developer.log('🔌 Disconnecting Socket...');
      socket.disconnect();
    }
  }

  /// Reconnect to Socket.IO
  void reconnect() {
    if (!isConnected && !isConnecting) {
      developer.log('🔌 Reconnecting Socket...');
      socket.connect();
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

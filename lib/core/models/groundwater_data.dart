import 'package:flutter/material.dart';

class GroundwaterData {
  final double currentDepth;
  final double totalDepth;
  final double flowRate;
  final String remainingPercentage;
  final double qualityScore;
  final String qualityStatus;
  final double currentSession;
  final double estimatedExtraction;
  final double tdsLevel;
  final String tdsStatus;
  final double phLevel;
  final String phStatus;
  final double voltage;
  final double current;
  final String motorStatus;
  final double soilMoisture;
  final String soilMoistureStatus;
  final double extractionRate;
  final String extractionStatus;
  final String lastUpdated;
  final double sensorDistanceCm; // New field for sensor distance in cm
  final double flowRateThisSession; // New field for current session flow rate
  final double
  totalExtractionPerSession; // New field for total extraction since pump start
  final double
  totalLifetimeExtractionL; // New field for total accumulated extraction

  // Prediction fields
  final double predictedDepth7Days;
  final double predictedDepth14Days;
  final double predictedDepth30Days;
  final String trend30Days;
  final String waterStressLevel;

  // Weather data fields
  final double? weatherTemp;
  final String? weatherCondition;
  final String? weatherDescription;
  final String? weatherIcon;
  final String? rainAlert;

  // Water Health AI fields
  final WaterHealthAI? waterHealthAI;

  GroundwaterData({
    required this.currentDepth,
    required this.totalDepth,
    required this.flowRate,
    required this.remainingPercentage,
    required this.qualityScore,
    required this.qualityStatus,
    required this.currentSession,
    required this.estimatedExtraction,
    required this.tdsLevel,
    required this.tdsStatus,
    required this.phLevel,
    required this.phStatus,
    required this.voltage,
    required this.current,
    required this.motorStatus,
    required this.soilMoisture,
    required this.soilMoistureStatus,
    required this.extractionRate,
    required this.extractionStatus,
    required this.lastUpdated,
    required this.predictedDepth7Days,
    required this.predictedDepth14Days,
    required this.predictedDepth30Days,
    required this.trend30Days,
    required this.waterStressLevel,
    required this.sensorDistanceCm, // New parameter
    required this.flowRateThisSession,
    required this.totalExtractionPerSession,
    required this.totalLifetimeExtractionL,
    this.weatherTemp,
    this.weatherCondition,
    this.weatherDescription,
    this.weatherIcon,
    this.rainAlert,
    this.waterHealthAI,
  });

  // Helper to calculate Power in kW
  double get powerKw => (voltage * current) / 1000;

  // Helper to determine soil moisture status
  String getSoilMoistureStatus() {
    if (soilMoisture < 20) return 'Dry';
    if (soilMoisture < 40) return 'Adequate';
    if (soilMoisture < 60) return 'Good';
    if (soilMoisture < 80) return 'Wet';
    return 'Saturated';
  }

  // Helper to format lastUpdated as HH:MM format
  String get formattedTime {
    try {
      final dateTime = DateTime.parse(lastUpdated);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return lastUpdated; // Fallback to original if parsing fails
    }
  }

  // Helper for Quality Score
  double getQualityScore() {
    switch (qualityStatus.toLowerCase()) {
      case 'excellent':
        return 95.0;
      case 'good':
        return 80.0;
      case 'poor':
        return 45.0;
      default:
        return 20.0;
    }
  }

  /// Parse the new /dashboard response shape:
  /// { device_mac, device_name, is_online, last_seen, data: { sensor: {...}, predictions: {...} } }
  factory GroundwaterData.fromDeviceJson(Map<String, dynamic> device) {
    final data = device['data'] as Map<String, dynamic>? ?? {};
    final sensor = data['sensor'] as Map<String, dynamic>? ?? {};
    final predictions = data['predictions'] as Map<String, dynamic>? ?? {};
    final quality = predictions['water_quality'] as Map<String, dynamic>? ?? {};
    final motor = predictions['motor_load'] as Map<String, dynamic>? ?? {};
    final trend =
        predictions['groundwater_trend'] as Map<String, dynamic>? ?? {};
    final weather = predictions['weather_data'] as Map<String, dynamic>? ?? {};

    // Debug: Log predictions and trend maps
    // ignore: avoid_print
    debugPrint('Predictions map: ' + predictions.toString());
    // ignore: avoid_print
    debugPrint('Groundwater trend map: ' + trend.toString());

    // sensor.distance is the distance from sensor to water surface in cm
    // This is the raw ultrasonic sensor reading — use it directly as the
    // displayed depth value (e.g., 20 cm → 0.2 m).
    final sensorDistanceCm =
        (sensor['distance'] ?? sensor['sensor_distance_cm'] ?? 0.0).toDouble();
    final totalDepth = 50.0;
    final currentDepth = sensorDistanceCm / 100;

    return GroundwaterData(
      currentDepth: currentDepth,
      totalDepth: totalDepth,
      flowRate: (sensor['flow_rate'] ?? sensor['flow_rate_L_min'] ?? 0.0)
          .toDouble(),
      remainingPercentage:
          '${((1 - (currentDepth / totalDepth)) * 100).toStringAsFixed(1)}%',
      qualityScore: (quality['score'] ?? 80.0).toDouble(),
      qualityStatus: quality['quality_class'] ?? quality['status'] ?? 'Good',
      currentSession: (sensor['current_session_m3'] ?? 0.0).toDouble(),
      estimatedExtraction: (sensor['extracted_amount_m3'] ?? 0.0).toDouble(),
      tdsLevel: (sensor['tds'] ?? sensor['tds_value'] ?? 0.0).toDouble(),
      tdsStatus: 'Safe',
      phLevel: (sensor['ph'] ?? 7.0).toDouble(),
      phStatus: 'Balanced',
      voltage: (sensor['voltage'] ?? 0.0).toDouble(),
      current: (sensor['current'] ?? sensor['pump_current_amps'] ?? 0.0)
          .toDouble(),
      motorStatus:
          motor['motor_status'] ??
          (device['is_online'] == true ? 'Normal' : 'Off'),
      soilMoisture: (sensor['soil_moisture'] ?? 0.0).toDouble(),
      soilMoistureStatus: 'Loading...',
      extractionRate: (sensor['flow_rate'] ?? sensor['flow_rate_L_min'] ?? 0.0)
          .toDouble(),
      extractionStatus: 'Active',
      lastUpdated:
          device['last_seen'] ??
          sensor['timestamp'] ??
          DateTime.now().toString(),
      sensorDistanceCm: sensorDistanceCm,
      flowRateThisSession: (sensor['flow_rate'] ?? 0.0).toDouble(),
      totalExtractionPerSession: (sensor['total_extraction_per_session'] ?? 0.0)
          .toDouble(),
      totalLifetimeExtractionL: (sensor['total_lifetime_extraction_L'] ?? 0.0)
          .toDouble(),
      predictedDepth7Days: (trend['predicted_depth_7days'] ?? 0.0).toDouble(),
      predictedDepth14Days: (trend['predicted_depth_14days'] ?? 0.0).toDouble(),
      predictedDepth30Days: (trend['predicted_depth_30days'] ?? 0.0).toDouble(),
      trend30Days: trend['trend_30days'] ?? 'stable',
      waterStressLevel: trend['water_stress_level'] ?? 'low',
      weatherTemp: (weather['temp'] ?? 0.0).toDouble(),
      weatherCondition: weather['condition'] ?? 'Clear',
      weatherDescription: weather['description'] ?? 'clear',
      weatherIcon: weather['icon'] ?? '01d',
      rainAlert: weather['rain_alert'] ?? '',
      waterHealthAI: predictions['water_health_ai'] != null
          ? WaterHealthAI.fromJson(predictions['water_health_ai'])
          : null,
    );
  }

  // Factory constructor from JSON (for API integration)
  factory GroundwaterData.fromJson(Map<String, dynamic> json) {
    final sensor = json['sensor_data'] ?? {};
    final quality = json['water_quality'] ?? {};
    final motor = json['motor_load'] ?? {};
    final trend = json['groundwater_trend'] ?? {}; // Safely handle null
    final weather = json['weather_data'] ?? {}; // Safely handle null

    final sensorDistanceCm =
        (sensor['distance'] ?? sensor['sensor_distance_cm'] ?? 0.0).toDouble();
    final totalDepth = 50.0;
    final currentDepth = sensorDistanceCm / 100;

    // Parse new session data
    final flowRateThisSession =
        (json['water_extraction']?['flow_rate_this_session'] ?? 0.0).toDouble();
    final totalExtractionPerSession =
        (json['water_extraction']?['total_extraction_per_session'] ?? 0.0)
            .toDouble();

    // Verify where total_lifetime_extraction_L comes from. User example shows root.
    final totalLifetimeExtractionL =
        (json['total_lifetime_extraction_L'] ?? 0.0).toDouble();

    return GroundwaterData(
      currentDepth: currentDepth,
      totalDepth: totalDepth,
      flowRate: (sensor['flow_rate_L_min'] ?? 0.0).toDouble(),
      remainingPercentage:
          '${((1 - (currentDepth / totalDepth)) * 100).toStringAsFixed(1)}%',
      qualityScore: 80.0,
      qualityStatus: quality['quality_class'] ?? 'Good',
      currentSession: (json['water_extraction']?['current_session_m3'] ?? 0.0)
          .toDouble(),
      estimatedExtraction:
          (json['water_extraction']?['extracted_amount_m3'] ?? 0.0).toDouble(),
      tdsLevel: (sensor['tds_value'] ?? 0.0).toDouble(),
      tdsStatus: 'Safe',
      phLevel: (sensor['ph'] ?? 7.0).toDouble(),
      phStatus: 'Balanced',
      voltage: (sensor['voltage'] ?? 0.0).toDouble(),
      current: (sensor['pump_current_amps'] ?? 0.0).toDouble(),
      motorStatus: motor['motor_status'] ?? 'Off',
      soilMoisture: (sensor['soil_moisture'] ?? 0.0).toDouble(),
      soilMoistureStatus:
          'Loading...', // Will be updated from REST API or calculated
      extractionRate: (sensor['flow_rate_L_min'] ?? 0.0).toDouble(),
      extractionStatus: 'Active',
      lastUpdated: json['timestamp'] ?? DateTime.now().toString(),
      sensorDistanceCm: sensorDistanceCm, // New field
      flowRateThisSession: flowRateThisSession,
      totalExtractionPerSession: totalExtractionPerSession,
      totalLifetimeExtractionL: totalLifetimeExtractionL,
      // Prediction data
      predictedDepth7Days: (trend['predicted_depth_7days'] ?? 0.0).toDouble(),
      predictedDepth14Days: (trend['predicted_depth_14days'] ?? 0.0).toDouble(),
      predictedDepth30Days: (trend['predicted_depth_30days'] ?? 0.0).toDouble(),
      trend30Days: trend['trend_30days'] ?? 'stable',
      waterStressLevel: trend['water_stress_level'] ?? 'low',
      // Weather data
      weatherTemp: (weather['temp'] ?? 0.0).toDouble(),
      weatherCondition: weather['condition'] ?? 'Clear',
      weatherDescription: weather['description'] ?? 'clear',
      weatherIcon: weather['icon'] ?? '01d',
      rainAlert: weather['rain_alert'] ?? '',
      // Water Health AI
      waterHealthAI: json['water_health_ai'] != null
          ? WaterHealthAI.fromJson(json['water_health_ai'])
          : null,
    );
  }

  /// Factory to parse RAW SENSOR DATA from Socket.IO sensor_update event
  /// This ONLY contains raw sensor values, not calculated data
  /// For complete data, use fromJson() with /mobile/dashboard response
  factory GroundwaterData.fromSensorUpdate(Map<String, dynamic> json) {
    final sensorDistanceCm =
        (json['distance'] ?? json['sensor_distance_cm'] ?? 0.0).toDouble();
    final totalDepth = 50.0;
    final currentDepth = sensorDistanceCm / 100;

    return GroundwaterData(
      currentDepth: currentDepth,
      totalDepth: totalDepth,
      flowRate: (json['flow_rate_L_min'] ?? 0.0).toDouble(),
      remainingPercentage:
          '${((1 - (currentDepth / totalDepth)) * 100).toStringAsFixed(1)}%',
      qualityScore: 0.0, // Will be updated from REST API
      qualityStatus: 'Loading...', // Will be updated from REST API
      currentSession: 0.0, // Will be updated from REST API
      estimatedExtraction: 0.0, // Will be updated from REST API
      tdsLevel: (json['tds_value'] ?? 0.0).toDouble(),
      tdsStatus: 'Safe',
      phLevel: (json['ph'] ?? 7.0).toDouble(),
      phStatus: 'Balanced',
      voltage: (json['voltage'] ?? 0.0).toDouble(),
      current: (json['pump_current_amps'] ?? 0.0).toDouble(),
      motorStatus: 'Unknown', // Will be updated from REST API
      soilMoisture: (json['soil_moisture'] ?? 0.0).toDouble(),
      soilMoistureStatus:
          'Unknown', // Will be updated from REST API or calculated
      extractionRate: (json['flow_rate_L_min'] ?? 0.0).toDouble(),
      extractionStatus: 'Active',
      lastUpdated: json['timestamp'] ?? DateTime.now().toString(),
      sensorDistanceCm: sensorDistanceCm, // New field
      flowRateThisSession: (json['flow_rate_L_min'] ?? 0.0).toDouble(),
      totalExtractionPerSession: 0.0,
      totalLifetimeExtractionL:
          0.0, // Sensor update doesn't have this, explicit 0 or persist? Usually explicit 0 if we can't persist here.
      // These will be updated from REST API
      predictedDepth7Days: 0.0,
      predictedDepth14Days: 0.0,
      predictedDepth30Days: 0.0,
      trend30Days: 'stable',
      waterStressLevel: 'low',
    );
  }

  /// Merge raw sensor data from Socket.IO with calculated data from REST API
  /// This keeps sensor values fresh from Socket while preserving calculated data
  GroundwaterData mergeWithSensorUpdate(Map<String, dynamic> sensorData) {
    final sensorDistanceCm =
        (sensorData['distance'] ?? sensorData['sensor_distance_cm'] ?? this.sensorDistanceCm)
            .toDouble();
    final totalDepth = this.totalDepth;
    final currentDepth = sensorDistanceCm / 100;

    return GroundwaterData(
      currentDepth: currentDepth,
      totalDepth: totalDepth,
      flowRate: (sensorData['flow_rate_L_min'] ?? this.flowRate).toDouble(),
      remainingPercentage:
          '${((1 - (currentDepth / totalDepth)) * 100).toStringAsFixed(1)}%',
      qualityScore: this.qualityScore,
      qualityStatus: this.qualityStatus,
      currentSession: this.currentSession,
      estimatedExtraction: this.estimatedExtraction,
      tdsLevel: (sensorData['tds_value'] ?? this.tdsLevel).toDouble(),
      tdsStatus: this.tdsStatus,
      phLevel: (sensorData['ph'] ?? this.phLevel).toDouble(),
      phStatus: this.phStatus,
      voltage: (sensorData['voltage'] ?? this.voltage).toDouble(),
      current: (sensorData['pump_current_amps'] ?? this.current).toDouble(),
      motorStatus: this.motorStatus,
      soilMoisture: (sensorData['soil_moisture'] ?? this.soilMoisture)
          .toDouble(),
      soilMoistureStatus: this.soilMoistureStatus,
      extractionRate: (sensorData['flow_rate_L_min'] ?? this.extractionRate)
          .toDouble(),
      extractionStatus: this.extractionStatus,
      lastUpdated: sensorData['timestamp'] ?? this.lastUpdated,
      sensorDistanceCm: sensorDistanceCm, // New field
      flowRateThisSession:
          (sensorData['flow_rate_L_min'] ?? this.flowRateThisSession)
              .toDouble(),
      totalExtractionPerSession: this.totalExtractionPerSession,
      // Note: totalExtractionPerSession is complex to calculate on socket, relying on polling for now.
      totalLifetimeExtractionL:
          (sensorData['total_lifetime_extraction_L'] ??
                  this.totalLifetimeExtractionL)
              .toDouble(),
      // Updated from socket payload if available
      predictedDepth7Days: this.predictedDepth7Days,
      predictedDepth14Days: this.predictedDepth14Days,
      predictedDepth30Days: this.predictedDepth30Days,
      trend30Days: this.trend30Days,
      waterStressLevel: this.waterStressLevel,
      weatherTemp: this.weatherTemp,
      weatherCondition: this.weatherCondition,
      weatherDescription: this.weatherDescription,
      weatherIcon: this.weatherIcon,
      rainAlert: this.rainAlert,
      waterHealthAI: this.waterHealthAI,
    );
  }

  // Mock data for Current Data tab
  static GroundwaterData mockCurrentData() {
    return GroundwaterData(
      currentDepth: 35,
      totalDepth: 50,
      flowRate: 2.5,
      remainingPercentage: '30%',
      qualityScore: 85,
      qualityStatus: 'Excellent',
      currentSession: 450,
      estimatedExtraction: 2800,
      tdsLevel: 250,
      tdsStatus: 'Safe',
      phLevel: 7.2,
      phStatus: 'Balanced',
      voltage: 230,
      current: 5.2,
      motorStatus: 'Normal',
      soilMoisture: 28.0,
      soilMoistureStatus: 'Adequate', // 20-40% = Adequate
      extractionRate: 2.5,
      extractionStatus: 'Optimal',
      lastUpdated: '10 mins ago',
      sensorDistanceCm: 20.0, // New field with mock value
      flowRateThisSession: 45.2,
      totalExtractionPerSession: 1250.5,
      totalLifetimeExtractionL: 15000.0,
      predictedDepth7Days: 34.8,
      predictedDepth14Days: 34.5,
      predictedDepth30Days: 34.0,
      trend30Days: 'falling',
      waterStressLevel: 'moderate',
      // Weather data
      weatherTemp: 28.5,
      weatherCondition: 'Partly Cloudy',
      weatherDescription: 'partly cloudy',
      weatherIcon: '02d',
      rainAlert: 'No rain expected',
    );
  }

  // Mock data for Average Data tab
  static GroundwaterData mockAverageData() {
    return GroundwaterData(
      currentDepth: 38,
      totalDepth: 50,
      flowRate: 2.0,
      remainingPercentage: '24%',
      qualityScore: 82,
      qualityStatus: 'Good',
      currentSession: 425,
      estimatedExtraction: 2600,
      tdsLevel: 260,
      tdsStatus: 'Safe',
      phLevel: 7.1,
      phStatus: 'Balanced',
      voltage: 230,
      current: 4.8,
      motorStatus: 'Normal',
      soilMoisture: 32.0,
      soilMoistureStatus: 'Adequate', // 20-40% = Adequate
      extractionRate: 2.4,
      extractionStatus: 'Optimal',
      lastUpdated: '7 days average',
      sensorDistanceCm: 22.0, // New field with mock value
      flowRateThisSession: 40.0,
      totalExtractionPerSession: 1100.0,
      totalLifetimeExtractionL: 14000.0,
      predictedDepth7Days: 37.8,
      predictedDepth14Days: 37.5,
      predictedDepth30Days: 37.0,
      trend30Days: 'stable',
      waterStressLevel: 'low',
      // Weather data
      weatherTemp: 26.3,
      weatherCondition: 'Clear',
      weatherDescription: 'clear sky',
      weatherIcon: '01d',
      rainAlert: 'No rain expected',
    );
  }
}

/// AI-generated water health analysis from the backend /mobile/dashboard endpoint
class WaterHealthAI {
  final double contaminationScore;
  final String contaminationLevel;
  final String diseaseRisk;
  final List<String> healthRiskTags;
  final String recommendedAction;
  final String colorIndicator;
  final Map<String, String> sensorInsights;
  final String model;

  WaterHealthAI({
    required this.contaminationScore,
    required this.contaminationLevel,
    required this.diseaseRisk,
    required this.healthRiskTags,
    required this.recommendedAction,
    required this.colorIndicator,
    required this.sensorInsights,
    required this.model,
  });

  factory WaterHealthAI.fromJson(Map<String, dynamic> json) {
    final rawInsights = json['sensor_insights'] ?? {};
    final insights = <String, String>{};
    rawInsights.forEach((k, v) => insights[k.toString()] = v.toString());

    return WaterHealthAI(
      contaminationScore: (json['contamination_score'] ?? 0.0).toDouble(),
      contaminationLevel: json['contamination_level'] ?? 'Unknown',
      diseaseRisk: json['disease_risk'] ?? 'Unknown',
      healthRiskTags: List<String>.from(json['health_risk_tags'] ?? []),
      recommendedAction: json['recommended_action'] ?? '',
      colorIndicator: json['color_indicator'] ?? '#22c55e',
      sensorInsights: insights,
      model: json['models'] ?? '',
    );
  }

  /// Parse hex color string like '#f97316' to Flutter Color
  Color get indicatorColor {
    try {
      final hex = colorIndicator.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF22c55e);
    }
  }
}

class AverageDataMetrics {
  final String metric;
  final double value;
  final String unit;
  final double trend;
  final String trendStatus; // 'up', 'down', 'stable'
  final List<double> chartData;

  AverageDataMetrics({
    required this.metric,
    required this.value,
    required this.unit,
    required this.trend,
    required this.trendStatus,
    required this.chartData,
  });

  static List<AverageDataMetrics> mockMetrics() {
    return [
      AverageDataMetrics(
        metric: 'Avg. Depth',
        value: 58,
        unit: 'Feet',
        trend: 2,
        trendStatus: 'up',
        chartData: [50, 52, 54, 56, 57, 58, 58],
      ),
      AverageDataMetrics(
        metric: 'Avg. pH',
        value: 7.1,
        unit: 'pH',
        trend: 0,
        trendStatus: 'stable',
        chartData: [7.0, 7.1, 7.1, 7.2, 7.1, 7.1, 7.1],
      ),
      AverageDataMetrics(
        metric: 'Avg. TDS',
        value: 260,
        unit: 'ppm',
        trend: -3,
        trendStatus: 'down',
        chartData: [270, 268, 265, 262, 260, 260, 260],
      ),
      AverageDataMetrics(
        metric: 'Avg. Quality',
        value: 82,
        unit: '/100',
        trend: 1,
        trendStatus: 'up',
        chartData: [80, 80, 81, 82, 82, 82, 82],
      ),
    ];
  }
}

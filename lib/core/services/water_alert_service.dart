import 'package:flutter/material.dart';
import 'dart:developer' as developer;

/// Thresholds for safe water parameters
class WaterThresholds {
  static const double phMin = 6.5;
  static const double phMax = 8.5;
  static const double tdsMax = 500.0; // ppm
}

class WaterAlertService {
  static bool _initialized = false;

  // Track the last alert state to prevent duplicate notifications
  static String? _lastAlertBody;
  static DateTime? _lastAlertTime;

  /// Initialize the alert service
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    developer.log('✅ WaterAlertService initialized');
  }

  /// Checks pH, TDS and logs alerts if contaminated
  /// Prevents duplicate alerts within 5 minutes
  static Future<void> checkAndNotify({
    required double ph,
    required double tds,
  }) async {
    developer.log('🔍 WaterAlertService.checkAndNotify called: pH=$ph, TDS=$tds');

    final List<String> issues = [];

    // Check pH levels
    if (ph < WaterThresholds.phMin) {
      issues.add('Low pH (${ph.toStringAsFixed(1)})');
      developer.log('⚠️ Low pH detected: $ph (threshold: ${WaterThresholds.phMin})');
    } else if (ph > WaterThresholds.phMax) {
      issues.add('High pH (${ph.toStringAsFixed(1)})');
      developer.log('⚠️ High pH detected: $ph (threshold: ${WaterThresholds.phMax})');
    }

    // Check TDS levels
    if (tds > WaterThresholds.tdsMax) {
      issues.add('High TDS (${tds.toStringAsFixed(0)} ppm)');
      developer.log('⚠️ High TDS detected: $tds (threshold: ${WaterThresholds.tdsMax})');
    }

    if (issues.isNotEmpty) {
      final body = issues.join(' | ');
      developer.log('📢 Alert issues detected: $body');

      // Check if this is a duplicate (same alert within 5 minutes)
      final now = DateTime.now();
      final isDuplicate = _lastAlertBody == body &&
          _lastAlertTime != null &&
          now.difference(_lastAlertTime!).inMinutes < 5;

      if (isDuplicate) {
        developer.log('⏭️ Skipping duplicate notification (same alert within 5 minutes)');
        return;
      }

      // Update last alert state
      _lastAlertBody = body;
      _lastAlertTime = now;

      developer.log('✅ Water Quality Alert: $body');
    } else {
      developer.log('✅ Water parameters are within safe thresholds');
      if (_lastAlertBody != null) {
        developer.log('🟢 Alert status cleared (was: $_lastAlertBody)');
        _lastAlertBody = null;
      }
    }
  }
}

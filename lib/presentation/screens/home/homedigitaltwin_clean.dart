import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import '../../../core/models/groundwater_data.dart';
import '../../../core/localization/app_localizations.dart';

class HomeDigitalTwin extends StatefulWidget {
  final GroundwaterData initialData;

  const HomeDigitalTwin({super.key, required this.initialData});

  @override
  State<HomeDigitalTwin> createState() => _HomeDigitalTwinState();
}

class _HomeDigitalTwinState extends State<HomeDigitalTwin> {
  late GroundwaterData _currentData;
  late Flutter3DController _controller;

  @override
  void initState() {
    super.initState();
    _currentData = widget.initialData;
    _controller = Flutter3DController();

    // Listen to model loading state and start rotation only when loaded
    _controller.onModelLoaded.addListener(_onModelLoaded);
  }

  void _onModelLoaded() {
    if (_controller.onModelLoaded.value) {
      debugPrint('3D Model loaded successfully');
      // Model is fixed in position - no auto-rotation
    }
  }

  @override
  void didUpdateWidget(HomeDigitalTwin oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update data when parent passes new data
    if (widget.initialData != oldWidget.initialData) {
      setState(() {
        _currentData = widget.initialData;
      });
    }
  }

  @override
  void dispose() {
    _controller.onModelLoaded.removeListener(_onModelLoaded);
    super.dispose();
  }

  /// Derive quality label from actual sensor values (pH + TDS)
  /// so it always reflects real data regardless of backend field
  String _formatWaterQuality(String status) {
    final ph = _currentData.phLevel;
    final tds = _currentData.tdsLevel;

    // If we have real sensor data, compute quality from it
    if (ph > 0 && tds > 0) {
      final bool phOk = ph >= 6.5 && ph <= 8.5;
      final bool tdsOk = tds <= 500;

      if (phOk && tdsOk && tds <= 300) return '✅ Excellent';
      if (phOk && tdsOk) return '✅ Good';
      if (!phOk && !tdsOk) return '❌ Very Poor';
      return '⚠️ Fair';
    }

    // Fallback to status string from backend
    switch (status.toLowerCase()) {
      case 'excellent':
        return '✅ Excellent';
      case 'good':
        return '✅ Good';
      case 'fair':
        return '⚠️ Fair';
      case 'poor':
        return '⚠️ Poor';
      case 'very_poor':
        return '❌ Very Poor';
      default:
        return '⚠️ Fair';
    }
  }

  String _formatPumpStatus(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
        return '✅ Normal';
      case 'overload':
        return '⚠️ Overload';
      case 'off':
        return '⏸️ Off';
      default:
        return '❓ Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Stack(
        children: [
          // 3D Model Viewer
          Flutter3DViewer(
            src: 'assets/models/house_model.glb',
            controller: _controller,
          ),

          // Sensor Data Overlay - Bottom Left
          Positioned(
            bottom: 20,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Water Quality
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.85),
                    border: Border.all(
                      color: const Color(0xFF008888).withOpacity(0.8),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💧 ${AppLocalizations.of(context)!.get('quality_indicator')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatWaterQuality(_currentData.qualityStatus),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Water Depth
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.85),
                    border: Border.all(
                      color: const Color(0xFF008888).withOpacity(0.8),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⏬ ${AppLocalizations.of(context)!.get('depth_indicator')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_currentData.currentDepth.toStringAsFixed(1)}m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Pump Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.85),
                    border: Border.all(
                      color: const Color(0xFF008888).withOpacity(0.8),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚡ ${AppLocalizations.of(context)!.get('pump_indicator')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatPumpStatus(_currentData.motorStatus),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

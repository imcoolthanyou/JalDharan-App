import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import '../../../core/models/groundwater_data.dart';

class HomeDigitalTwin extends StatefulWidget {
  final GroundwaterData initialData;

  const HomeDigitalTwin({
    super.key,
    required this.initialData,
  });

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
      debugPrint('3D Model loaded successfully - starting rotation');
      try {
        _controller.startRotation(rotationSpeed: 15);
      } catch (e) {
        debugPrint('Error starting rotation: $e');
      }
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
    try {
      _controller.stopRotation();
    } catch (e) {
      debugPrint('Error stopping rotation: $e');
    }
    super.dispose();
  }

  String _formatWaterQuality(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return '✅ Excellent';
      case 'good':
        return '✅ Good';
      case 'poor':
        return '⚠️ Poor';
      case 'very_poor':
        return '❌ Very Poor';
      default:
        return '❓ Unknown';
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      const Text(
                        '💧 Quality',
                        style: TextStyle(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      const Text(
                        '⏬ Depth',
                        style: TextStyle(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      const Text(
                        '⚡ Pump',
                        style: TextStyle(
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


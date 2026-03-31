import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mp;
import '../../../core/theme/app_colors.dart';

class AreaCalculatorMap extends StatefulWidget {
  final Function(double, LatLng) onAreaCalculated;
  final LatLng initialPosition;
  final String title;

  const AreaCalculatorMap({
    Key? key,
    required this.onAreaCalculated,
    required this.initialPosition,
    required this.title,
  }) : super(key: key);

  @override
  State<AreaCalculatorMap> createState() => _AreaCalculatorMapState();
}

class _AreaCalculatorMapState extends State<AreaCalculatorMap> {
  GoogleMapController? mapController;
  final List<List<LatLng>> _completedPolygons = [];
  final List<LatLng> _currentPolyPoints = [];

  final Set<Marker> _markers = HashSet<Marker>();
  final Set<Polygon> _polygons = HashSet<Polygon>();

  double _totalArea = 0.0;

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  void _calculateTotalArea() {
    double total = 0.0;
    for (var polyPoints in _completedPolygons) {
      total += _computeSinglePolygonArea(polyPoints);
    }
    if (_currentPolyPoints.length >= 3) {
      total += _computeSinglePolygonArea(_currentPolyPoints);
    }
    setState(() => _totalArea = total);
  }

  double _computeSinglePolygonArea(List<LatLng> points) {
    List<mp.LatLng> mpPoints = points
        .map((p) => mp.LatLng(p.latitude, p.longitude))
        .toList();
    double areaSqm = mp.SphericalUtil.computeArea(mpPoints).toDouble();
    return areaSqm * 10.7639; // Convert to sqft
  }

  void _onMapTap(LatLng point) {
    // Allow tapping always
    if (mapController != null) {
      setState(() {
        _currentPolyPoints.add(point);
        _updateMapVisuals();
        _calculateTotalArea();
      });
    }
  }

  void _updateMapVisuals() {
    _markers.clear();
    _polygons.clear();

    for (int i = 0; i < _completedPolygons.length; i++) {
      _polygons.add(
        Polygon(
          polygonId: PolygonId('completed_$i'),
          points: _completedPolygons[i],
          fillColor: AppColors.fieldGreen.withOpacity(0.3),
          strokeColor: AppColors.fieldGreen,
          strokeWidth: 2,
        ),
      );
    }

    if (_currentPolyPoints.isNotEmpty) {
      for (var p in _currentPolyPoints) {
        _markers.add(
          Marker(
            markerId: MarkerId(p.toString()),
            position: p,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );
      }
      _polygons.add(
        Polygon(
          polygonId: const PolygonId('current'),
          points: _currentPolyPoints,
          fillColor: AppColors.deepAquiferBlue.withOpacity(0.3),
          strokeColor: AppColors.deepAquiferBlue,
          strokeWidth: 2,
        ),
      );
    }
  }

  void _undo() {
    if (_currentPolyPoints.isEmpty) return;
    setState(() {
      _currentPolyPoints.removeLast();
      _updateMapVisuals();
      _calculateTotalArea();
    });
  }

  void _finishCurrentPolygon() {
    if (_currentPolyPoints.length < 3) return;
    setState(() {
      _completedPolygons.add(List.from(_currentPolyPoints));
      _currentPolyPoints.clear();
      _updateMapVisuals();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Roof section saved! Tap to start next section."),
        backgroundColor: AppColors.fieldGreen,
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _completedPolygons.clear();
      _currentPolyPoints.clear();
      _totalArea = 0.0;
      _updateMapVisuals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Measure Area"),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.textTheme.titleLarge?.color,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: theme.iconTheme.color),
            onPressed: _clearAll,
            tooltip: "Reset All",
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: 18,
            ),
            mapType: MapType.hybrid,
            onMapCreated: (controller) {
              mapController = controller;
            },
            markers: _markers,
            polygons: _polygons,
            onTap: _onMapTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total Area",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.mediumGrey,
                            ),
                          ),
                          Text(
                            "${_totalArea.toStringAsFixed(1)} sqft",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: (_currentPolyPoints.isNotEmpty)
                                ? _undo
                                : null,
                            icon: const Icon(Icons.undo),
                            color: AppColors.warningOrange,
                            tooltip: "Undo Last Point",
                          ),
                          IconButton(
                            onPressed: (_currentPolyPoints.length >= 3)
                                ? _finishCurrentPolygon
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppColors.fieldGreen,
                            tooltip: "Finish this section",
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_totalArea > 0)
                          ? () {
                              widget.onAreaCalculated(
                                _totalArea,
                                // We return the map target (initialPosition) or the last point?
                                // Or we just return the initialPosition since we didn't change "user location".
                                // Actually, if the user panned, we might want the center?
                                // But onAreaCalculated expects a LatLng.
                                // Let's return the widget.initialPosition for now, as the prompt said "new location should be sent to backend"
                                // which implies the SEARCHED location (which is initialPosition).
                                // If we want the map center, we'd need to track it via onCameraMove.
                                // But the user selected the location in previous screen.
                                widget.initialPosition,
                              );
                              Navigator.pop(context);
                            }
                          : null,
                      icon: const Icon(Icons.check),
                      label: const Text("Confirm Area"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_totalArea > 0)
                            ? theme.colorScheme.primary
                            : theme.disabledColor,
                        foregroundColor: (_totalArea > 0)
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface.withOpacity(0.38),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

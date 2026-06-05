import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

import '../../../core/models/analytics_data.dart';
import '../../../core/models/groundwater_data.dart';
import '../../../core/services/dashboard_api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../widgets/custom_gradient_appbar.dart';
import 'dart:developer' as developer;

class AnalyticsScreen extends StatefulWidget {
  final GroundwaterData? groundwaterData;

  const AnalyticsScreen({super.key, this.groundwaterData});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late GroundwaterData _currentData;
  final DashboardApiService _apiService = DashboardApiService();
  late Timer _autoRefreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 10);
  bool _isLoading = false;

  // Filter state
  String _selectedPeriod = '30 Days';
  final List<String> _periods = ['7 Days', '14 Days', '30 Days'];

  @override
  void initState() {
    super.initState();
    if (widget.groundwaterData != null) {
      _currentData = widget.groundwaterData!;
    } else {
      _currentData = GroundwaterData.mockCurrentData();
    }

    Future.microtask(() {
      final socketService = Provider.of<SocketService>(context, listen: false);
      socketService.addSensorUpdateListener(_onSensorDataReceived);
    });

    _startAutoRefresh();
  }

  void _onSensorDataReceived(Map<String, dynamic> data) {
    try {
      final updatedData = _currentData.mergeWithSensorUpdate(data);
      if (mounted) {
        setState(() {
          _currentData = updatedData;
        });
      }
    } catch (e) {
      developer.log('Error updating with socket sensor data in AnalyticsScreen: $e');
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) {
        _fetchLatestData();
      }
    });
  }

  Future<void> _fetchLatestData() async {
    if (!mounted) return;
    try {
      final data = await _apiService.fetchDashboardData();
      if (!mounted) return;
      setState(() {
        _currentData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer.cancel();
    final socketService = Provider.of<SocketService>(context, listen: false);
    socketService.removeSensorUpdateListener(_onSensorDataReceived);
    super.dispose();
  }

  // Helper colors based on the image
  final Color _primaryPurple = const Color(0xFF6A5ACD);
  final Color _lightPurple = const Color(0xFFB0A4E5);
  final Color _greenColor = const Color(0xFF5BD166);
  final Color _bgSoftPurple = const Color(0xFFF9F7FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSoftPurple,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.get('prediction'),
          style: const TextStyle(
            color: Color(0xFF1E1E2D),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1E1E2D)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildChartCard(),
            const SizedBox(height: 16),
            _buildCurrentDepthCard(),
            const SizedBox(height: 16),
            _buildCurrentVsAverageCard(),
            const SizedBox(height: 16),
            _buildBestTimeToPumpCard(),
            const SizedBox(height: 100), // For floating nav bar
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryPurple.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)?.get('water_depth_trends') ?? 'Depth Comparison',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    isDense: true,
                    icon: Icon(Icons.keyboard_arrow_down, color: _primaryPurple, size: 16),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _primaryPurple,
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedPeriod = newValue;
                        });
                      }
                    },
                    items: _periods.map<DropdownMenuItem<String>>((String value) {
                      String localizedValue = value;
                      if (value == '7 Days') localizedValue = AppLocalizations.of(context)?.get('days_7') ?? '7 Days';
                      if (value == '14 Days') localizedValue = AppLocalizations.of(context)?.get('days_14') ?? '14 Days';
                      if (value == '30 Days') localizedValue = AppLocalizations.of(context)?.get('days_30') ?? '30 Days';

                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(localizedValue),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Depth (m)',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildLineChart(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(AppLocalizations.of(context)?.get('current_value') ?? 'Current Value', _primaryPurple),
              _buildLegendItem(AppLocalizations.of(context)?.get('previous_avg') ?? 'Previous Avg', _lightPurple),
              _buildLegendItem(AppLocalizations.of(context)?.get('community_avg') ?? 'Community Avg', _greenColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    // Generate data points based on selection
    int count = _selectedPeriod == '7 Days' ? 7 : _selectedPeriod == '14 Days' ? 14 : 30;
    
    // Mocking some nice looking data based on current depth
    double current = _currentData.currentDepth;
    List<FlSpot> currentSpots = [];
    List<FlSpot> prevSpots = [];
    List<FlSpot> commSpots = [];

    double step = count / 5.0; // Show 5 points on x-axis
    for (int i = 0; i < 6; i++) {
      double x = i * step;
      // create some ascending curves
      currentSpots.add(FlSpot(x, current - 4 + (i * 0.8)));
      prevSpots.add(FlSpot(x, current - 7 + (i * 0.6)));
      commSpots.add(FlSpot(x, current - 11 + (i * 0.7)));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                // Generate labels based on selection
                List<String> labels = [];
                if (_selectedPeriod == '7 Days') {
                  labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                } else if (_selectedPeriod == '14 Days') {
                  labels = ['W1', '', 'W2', '', 'W3', ''];
                } else {
                  labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                }
                int index = (value / step).round();
                if (index >= 0 && index < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(labels[index], style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: count.toDouble(),
        minY: 20,
        maxY: 45,
        lineBarsData: [
          _createChartLine(currentSpots, _primaryPurple),
          _createChartLine(prevSpots, _lightPurple),
          _createChartLine(commSpots, _greenColor),
        ],
      ),
    );
  }

  LineChartBarData _createChartLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: Colors.white,
            strokeWidth: 2.5,
            strokeColor: color,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildCurrentDepthCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryPurple.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildIconBadge(Icons.water_drop, _primaryPurple),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)?.get('current_data') ?? 'Current Depth',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
              Row(
                children: [
                  Text(
                    _currentData.currentDepth.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1E1E2D)),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'm',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E1E2D)),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _greenColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: _greenColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'SAFE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _greenColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentVsAverageCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryPurple.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)?.get('current_vs_average') ?? 'Current vs Average',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildIconBadge(Icons.bar_chart_rounded, _primaryPurple),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          '+4.0',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E1E2D)),
                        ),
                        const SizedBox(width: 4),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            'm',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E1E2D)),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.arrow_upward, color: _greenColor, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '12.5% Better',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _greenColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _greenColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.water_drop, color: _greenColor, size: 24),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.get('water_quality') ?? 'Water Condition',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                        ),
                        Text(
                          AppLocalizations.of(context)?.get('excellent') ?? 'Excellent',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _greenColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBestTimeToPumpCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryPurple.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)?.get('best_time_pump') ?? 'Best Time to Pump',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildIconBadge(Icons.access_time_filled, _primaryPurple),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '06:00 AM - 08:00 AM',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E1E2D)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)?.get('optimal_time_desc') ?? 'Optimal time based on usage pattern\nand energy efficiency.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade500, height: 1.4),
                    ),
                  ],
                ),
              ),
              // Simulated illustration
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _primaryPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.water_drop, color: _lightPurple.withOpacity(0.5), size: 50),
                    Icon(Icons.access_time, color: _primaryPurple, size: 24),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconBadge(IconData icon, Color color) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: -5,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }
}

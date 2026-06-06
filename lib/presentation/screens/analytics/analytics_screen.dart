import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

import '../../../core/models/groundwater_data.dart';
import '../../../core/services/dashboard_api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
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
  String _selectedPeriod = '7 Days';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.get('prediction'),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
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
            _buildCurrentAndAverageRow(),
            const SizedBox(height: 16),
            _buildBestTimeToPumpCard(),
            const SizedBox(height: 100),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)?.get('water_depth_trends') ?? 'Water Depth Trends',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 16),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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
          const SizedBox(height: 20),
          // Y-axis label
          Text(
            'Depth (meters)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 12),
          // Chart
          SizedBox(
            height: 200,
            child: _buildLineChart(),
          ),
          const SizedBox(height: 20),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(
                AppLocalizations.of(context)?.get('current_value') ?? 'Current',
                AppColors.accentBlue,
              ),
              _buildLegendItem(
                AppLocalizations.of(context)?.get('previous_avg') ?? 'Previous Avg',
                AppColors.mediumGrey,
              ),
              _buildLegendItem(
                AppLocalizations.of(context)?.get('community_avg') ?? 'Community Avg',
                AppColors.accentTeal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    int count = _selectedPeriod == '7 Days' ? 7 : _selectedPeriod == '14 Days' ? 14 : 30;
    double current = _currentData.currentDepth;

    List<FlSpot> currentSpots = [];
    List<FlSpot> prevSpots = [];
    List<FlSpot> commSpots = [];

    int pointCount = 6;
    double step = count / pointCount.toDouble();

    for (int i = 0; i <= pointCount; i++) {
      double x = i * step;
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
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
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
                List<String> labels = [];
                if (_selectedPeriod == '7 Days') {
                  labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                } else if (_selectedPeriod == '14 Days') {
                  labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5', 'Week 6', 'Week 7'];
                } else {
                  labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
                }
                int index = (value / step).round();
                if (index >= 0 && index < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      labels[index],
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}m',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: count.toDouble(),
        minY: 20,
        maxY: 45,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                Color color;
                String label;
                if (spot.barIndex == 0) {
                  color = AppColors.accentBlue;
                  label = 'Current';
                } else if (spot.barIndex == 1) {
                  color = AppColors.mediumGrey;
                  label = 'Prev Avg';
                } else {
                  color = AppColors.accentTeal;
                  label = 'Community';
                }
                return LineTooltipItem(
                  '$label: ${spot.y.toStringAsFixed(1)}m',
                  TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          _createChartLine(currentSpots, AppColors.accentBlue, 2.5),
          _createChartLine(prevSpots, AppColors.mediumGrey, 2),
          _createChartLine(commSpots, AppColors.accentTeal, 2),
        ],
      ),
    );
  }

  LineChartBarData _createChartLine(List<FlSpot> spots, Color color, double barWidth) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: barWidth,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3,
            color: Colors.white,
            strokeWidth: 2,
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
          width: 16,
          height: 3,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildCurrentAndAverageRow() {
    double currentDepth = _currentData.currentDepth;
    double previousAvg = currentDepth - 4.0;
    double diff = currentDepth - previousAvg;
    double percentChange = ((diff / previousAvg) * 100).abs();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Row(
        children: [
          // Current Data
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.get('current_data') ?? 'Current Depth',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currentDepth.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentBlue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 50,
            color: AppColors.lightGrey,
          ),
          // Average Data
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)?.get('previous_avg') ?? 'Average Depth',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        previousAvg.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentTeal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        diff >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        color: diff >= 0 ? AppColors.accentGreen : AppColors.error,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${percentChange.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: diff >= 0 ? AppColors.accentGreen : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)?.get('best_time_pump') ?? 'Best Time to Pump',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '06:00 AM - 08:00 AM',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)?.get('optimal_time_desc') ??
                    'Optimal time based on usage pattern and energy efficiency.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

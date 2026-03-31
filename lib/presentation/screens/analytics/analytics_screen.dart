import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/models/analytics_data.dart';
import '../../../core/models/groundwater_data.dart';
import '../../../core/services/dashboard_api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/water_alert_service.dart';
import '../../../core/theme/app_colors.dart';
import 'dart:developer' as developer;

class AnalyticsScreen extends StatefulWidget {
  final GroundwaterData? groundwaterData;

  const AnalyticsScreen({super.key, this.groundwaterData});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late TrendData _groundwaterTrend;
  late GroundwaterData _currentData;

  // API Service
  final DashboardApiService _apiService = DashboardApiService();

  // Auto-refresh timer
  late Timer _autoRefreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 10);

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with provided data or mock
    if (widget.groundwaterData != null) {
      _currentData = widget.groundwaterData!;
      _groundwaterTrend = _createGroundwaterTrendFromData(_currentData);
    } else {
      _currentData = GroundwaterData.mockCurrentData();
      _groundwaterTrend = TrendData.mockGroundwaterTrends();
    }

    // Initialize Socket.IO listener
    Future.microtask(() {
      final socketService = Provider.of<SocketService>(context, listen: false);
      socketService.addSensorUpdateListener(_onSensorDataReceived);
    });

    // Start auto-refresh timer as fallback
    _startAutoRefresh();
  }

  /// Callback when Socket.IO receives new sensor data
  /// Socket.IO only sends RAW SENSOR DATA
  /// We merge this with existing calculated data from REST API
  void _onSensorDataReceived(Map<String, dynamic> data) {
    developer.log('🔄 AnalyticsScreen received Socket sensor update: $data');

    try {
      // Merge raw sensor data with existing calculated data
      final updatedData = _currentData.mergeWithSensorUpdate(data);

      if (mounted) {
        setState(() {
          _currentData = updatedData;
          _groundwaterTrend = _createGroundwaterTrendFromData(updatedData);
        });
        developer.log('✅ AnalyticsScreen UI updated with fresh sensor values from Socket');
      }
    } catch (e) {
      developer.log('❌ Error updating with socket sensor data in AnalyticsScreen: $e');
    }
  }

  /// Start the auto-refresh timer
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) {
        _fetchLatestData();
      }
    });
  }

  /// Fetch latest data from API
  Future<void> _fetchLatestData() async {
    if (!mounted) return;

    try {
      final data = await _apiService.fetchDashboardData();

      if (!mounted) return;

      setState(() {
        _currentData = data;
        _groundwaterTrend = _createGroundwaterTrendFromData(data);
        _isLoading = false;
      });

      // Trigger notifications for water quality alerts
      developer.log('📢 Checking water quality from Analytics API data: pH=${data.phLevel}, TDS=${data.tdsLevel}');
      WaterAlertService.checkAndNotify(
        ph: data.phLevel,
        tds: data.tdsLevel,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      developer.log('Analytics API Error: $e');
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer.cancel();

    // Remove socket listener
    Future.microtask(() {
      final socketService = Provider.of<SocketService>(context, listen: false);
      socketService.removeSensorUpdateListener(_onSensorDataReceived);
    });

    super.dispose();
  }

  /// Create TrendData from GroundwaterData API response
  TrendData _createGroundwaterTrendFromData(GroundwaterData data) {
    final points = <AnalyticsPoint>[
      AnalyticsPoint(x: 0, value: data.currentDepth, isPredicted: false), // Today
      AnalyticsPoint(x: 1, value: data.predictedDepth7Days, isPredicted: true), // 7 days
      AnalyticsPoint(x: 2, value: data.predictedDepth14Days, isPredicted: true), // 14 days
      AnalyticsPoint(x: 3, value: data.predictedDepth30Days, isPredicted: true), // 30 days
    ];

    return TrendData(
      title: 'Groundwater Depth',
      currentValue: data.currentDepth.toStringAsFixed(1),
      unit: 'm',
      trend: data.trend30Days,
      trendStatus: data.trend30Days == 'falling' ? 'down' : 'up',
      status: data.waterStressLevel == 'high' ? 'critical' :
              data.waterStressLevel == 'moderate' ? 'warning' : 'safe',
      criticalZone: 'Below 30m',
      weeklyData: const [],
      monthlyData: points,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'critical':
        return AppColors.criticalRed;
      case 'warning':
        return AppColors.warningOrange;
      default:
        return AppColors.fieldGreen;
    }
  }

  Color _getTrendLineColor(String title) {
    if (title.contains('Groundwater')) {
      return AppColors.deepAquiferBlue;
    }
    return AppColors.tealStart;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.deepAquiferBlue,
                  AppColors.tealStart,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'AI Prediction - 30 Days',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Groundwater Depth Forecast',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI-powered prediction of groundwater levels for the next 30 days based on current trends and usage patterns.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mediumGrey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Graph Card
                  _buildTrendCard(_groundwaterTrend),
                  const SizedBox(height: 24),
                  // Insight Card
                  _buildInsightCard(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(TrendData data) {
    final chartData = data.monthlyData;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            data.currentValue,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepAquiferBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            data.unit,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(data.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(data.status).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    data.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(data.status),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Chart
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppColors.lightGrey.withOpacity(0.5),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          const labels = ['Now', '+7D', '+14D', '+30D'];
                          if (value.toInt() >= 0 && value.toInt() < labels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                labels[value.toInt()],
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mediumGrey,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mediumGrey,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: -0.5,
                  maxX: 3.5,
                  minY: _getMinY(chartData),
                  maxY: _getMaxY(chartData),
                  lineBarsData: [
                    // History line (current data)
                    LineChartBarData(
                      spots: chartData
                          .where((p) => !p.isPredicted)
                          .map((p) => FlSpot(p.x, p.value))
                          .toList(),
                      isCurved: true,
                      color: _getTrendLineColor(data.title),
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: _getTrendLineColor(data.title),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _getTrendLineColor(data.title).withOpacity(0.1),
                      ),
                    ),
                    // Prediction line (dashed effect)
                    LineChartBarData(
                      spots: chartData
                          .where((p) => p.isPredicted)
                          .map((p) => FlSpot(p.x, p.value))
                          .toList(),
                      isCurved: true,
                      color: _getTrendLineColor(data.title).withOpacity(0.6),
                      barWidth: 2.5,
                      dashArray: [5, 5],
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: _getTrendLineColor(data.title).withOpacity(0.6),
                            strokeWidth: 1.5,
                            strokeColor: Colors.white.withOpacity(0.8),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 2.5,
                      color: _getTrendLineColor(data.title),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'CURRENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mediumGrey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: _getTrendLineColor(data.title).withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'PREDICTED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mediumGrey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard() {
    final trend = _groundwaterTrend.trendStatus;
    final status = _groundwaterTrend.status;

    String insightText = '';
    if (trend == 'down') {
      insightText = 'Groundwater levels are predicted to decline over the next 30 days. Consider reducing extraction or implementing water conservation measures.';
    } else if (trend == 'up') {
      insightText = 'Groundwater levels are predicted to improve over the next 30 days. Conditions appear favorable for continued extraction.';
    } else {
      insightText = 'Groundwater levels are predicted to remain stable over the next 30 days.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                trend == 'down' ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                color: _getStatusColor(status),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Insight',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _getStatusColor(status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insightText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.mediumGrey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Prediction values grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPredictionBox(
                days: '7 Days',
                depth: _currentData.predictedDepth7Days,
              ),
              _buildPredictionBox(
                days: '14 Days',
                depth: _currentData.predictedDepth14Days,
              ),
              _buildPredictionBox(
                days: '30 Days',
                depth: _currentData.predictedDepth30Days,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionBox({required String days, required double depth}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.deepAquiferBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.deepAquiferBlue.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              days,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${depth.toStringAsFixed(1)}m',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.deepAquiferBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getMinY(List<AnalyticsPoint> data) {
    return data.map((p) => p.value).reduce((a, b) => a < b ? a : b) - 5;
  }

  double _getMaxY(List<AnalyticsPoint> data) {
    return data.map((p) => p.value).reduce((a, b) => a > b ? a : b) + 5;
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/models/analytics_data.dart';
import '../../../core/models/groundwater_data.dart';
import '../../../core/services/dashboard_api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/water_alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/app_icons.dart';
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
    } else {
      _currentData = GroundwaterData.mockCurrentData();
    }
    // _groundwaterTrend is built in didChangeDependencies once context is available

    // Initialize Socket.IO listener
    Future.microtask(() {
      final socketService = Provider.of<SocketService>(context, listen: false);
      socketService.addSensorUpdateListener(_onSensorDataReceived);
    });

    // Start auto-refresh timer as fallback
    _startAutoRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _groundwaterTrend = _createGroundwaterTrendFromData(_currentData);
  }

  /// Callback when Socket.IO receives new sensor data
  /// Socket.IO only sends RAW SENSOR DATA
  /// We merge this with existing calculated data from REST API
  void _onSensorDataReceived(Map<String, dynamic> data) {
    developer.log('🔄 AnalyticsScreen received Socket sensor update: $data');

    try {
      // Only update real-time sensor fields, not predictions
      final updatedData = _currentData.mergeWithSensorUpdate(data);

      if (mounted) {
        setState(() {
          // Only update the fields that come from the socket
          _currentData = updatedData;
          // _groundwaterTrend should always be built from the latest REST API data (predictions)
          _groundwaterTrend = _createGroundwaterTrendFromData(_currentData);
        });
        developer.log(
          '✅ AnalyticsScreen UI updated with fresh sensor values from Socket',
        );
      }
    } catch (e) {
      developer.log(
        '❌ Error updating with socket sensor data in AnalyticsScreen: $e',
      );
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
      developer.log(
        '📢 Checking water quality from Analytics API data: pH=${data.phLevel}, TDS=${data.tdsLevel}',
      );
      WaterAlertService.checkAndNotify(ph: data.phLevel, tds: data.tdsLevel);
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

    // Access context before super.dispose() deactivates it
    final socketService = Provider.of<SocketService>(context, listen: false);
    socketService.removeSensorUpdateListener(_onSensorDataReceived);

    super.dispose();
  }

  /// Create TrendData from GroundwaterData API response
  TrendData _createGroundwaterTrendFromData(GroundwaterData data) {
    final points = <AnalyticsPoint>[
      AnalyticsPoint(x: 0, value: data.currentDepth, isPredicted: false),
      AnalyticsPoint(x: 1, value: data.predictedDepth7Days, isPredicted: true),
      AnalyticsPoint(x: 2, value: data.predictedDepth14Days, isPredicted: true),
      AnalyticsPoint(x: 3, value: data.predictedDepth30Days, isPredicted: true),
    ];

    final title =
        AppLocalizations.of(context)?.get('groundwater_depth_title') ??
        'Groundwater Depth';

    return TrendData(
      title: title,
      currentValue: data.currentDepth.toStringAsFixed(1),
      unit: 'm',
      trend: data.trend30Days,
      trendStatus: data.trend30Days == 'falling' ? 'down' : 'up',
      status: data.waterStressLevel == 'high'
          ? 'critical'
          : data.waterStressLevel == 'moderate'
          ? 'warning'
          : 'safe',
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
                colors: [AppColors.deepAquiferBlue, AppColors.tealStart],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.get('prediction'),
                        style: const TextStyle(
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
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.get('groundwater_trends'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.get('predict_info'),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                          if (value.toInt() >= 0 &&
                              value.toInt() < labels.length) {
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
                            color: _getTrendLineColor(
                              data.title,
                            ).withOpacity(0.6),
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
                    Text(
                      AppLocalizations.of(context)!.get('current'),
                      style: const TextStyle(
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
                    Text(
                      AppLocalizations.of(context)!.get('predicted'),
                      style: const TextStyle(
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
    final l10n = AppLocalizations.of(context)!;
    final current = _currentData.currentDepth;
    final d7 = _currentData.predictedDepth7Days;
    final d14 = _currentData.predictedDepth14Days;
    final d30 = _currentData.predictedDepth30Days;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: AppColors.deepAquiferBlue,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.get('insight'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ),
        ),

        // Trend summary banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: trend == 'down'
                  ? [
                      AppColors.criticalRed.withOpacity(0.12),
                      AppColors.warningOrange.withOpacity(0.08),
                    ]
                  : [
                      AppColors.fieldGreen.withOpacity(0.12),
                      AppColors.tealStart.withOpacity(0.08),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getStatusColor(status).withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  trend == 'down'
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  color: _getStatusColor(status),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trend == 'down'
                          ? l10n.get('insight_declining')
                          : trend == 'up'
                          ? l10n.get('insight_improving')
                          : l10n.get('insight_stable'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGrey,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.get('water_stress_level')}: ${_currentData.waterStressLevel.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Interactive prediction cards
        _buildInteractivePredictionCards(current, d7, d14, d30, l10n),

        const SizedBox(height: 16),

        // Comparison bar chart
        _buildComparisonBars(current, d7, d14, d30, l10n),

        const SizedBox(height: 16),

        // Change delta stats
        _buildDeltaStats(current, d7, d14, d30, l10n),
      ],
    );
  }

  Widget _buildInteractivePredictionCards(
    double current,
    double d7,
    double d14,
    double d30,
    AppLocalizations l10n,
  ) {
    final predictions = [
      {
        'label': l10n.get('current_value'),
        'days': 'Now',
        'value': current,
        'isPredicted': false,
      },
      {
        'label': l10n.get('days_7'),
        'days': '+7D',
        'value': d7,
        'isPredicted': true,
      },
      {
        'label': l10n.get('days_14'),
        'days': '+14D',
        'value': d14,
        'isPredicted': true,
      },
      {
        'label': l10n.get('days_30'),
        'days': '+30D',
        'value': d30,
        'isPredicted': true,
      },
    ];

    return Row(
      children: predictions.asMap().entries.map((entry) {
        final p = entry.value;
        final val = p['value'] as double;
        final isPredicted = p['isPredicted'] as bool;
        final delta = isPredicted ? val - current : 0.0;
        final isWorse = delta > 0; // deeper = worse for groundwater
        final deltaColor = !isPredicted
            ? AppColors.deepAquiferBlue
            : isWorse
            ? AppColors.criticalRed
            : AppColors.fieldGreen;

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: deltaColor.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: deltaColor.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: deltaColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p['days'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: deltaColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${val.toStringAsFixed(1)}m',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: deltaColor,
                  ),
                ),
                if (isPredicted) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isWorse
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 10,
                        color: deltaColor,
                      ),
                      Text(
                        '${delta.abs().toStringAsFixed(1)}m',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: deltaColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildComparisonBars(
    double current,
    double d7,
    double d14,
    double d30,
    AppLocalizations l10n,
  ) {
    final maxVal = [current, d7, d14, d30].reduce((a, b) => a > b ? a : b);
    final entries = [
      {'label': 'Now', 'value': current, 'color': AppColors.deepAquiferBlue},
      {'label': '+7D', 'value': d7, 'color': AppColors.tealStart},
      {'label': '+14D', 'value': d14, 'color': AppColors.warningOrange},
      {'label': '+30D', 'value': d30, 'color': AppColors.criticalRed},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Depth Comparison',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 16),
          ...entries.map((e) {
            final val = e['value'] as double;
            final color = e['color'] as Color;
            final ratio = maxVal > 0 ? val / maxVal : 0.0;
            final delta = val - current;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      e['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mediumGrey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(height: 22, color: color.withOpacity(0.1)),
                          FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              height: 22,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${val.toStringAsFixed(1)}m',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 40,
                    child: e['label'] == 'Now'
                        ? const SizedBox()
                        : Text(
                            '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: delta > 0
                                  ? AppColors.criticalRed
                                  : AppColors.fieldGreen,
                            ),
                            textAlign: TextAlign.right,
                          ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDeltaStats(
    double current,
    double d7,
    double d14,
    double d30,
    AppLocalizations l10n,
  ) {
    final stats = [
      {
        'title': '7-Day Change',
        'value': d7 - current,
        'from': current,
        'to': d7,
        'icon': Icons.calendar_view_week_rounded,
      },
      {
        'title': '14-Day Change',
        'value': d14 - current,
        'from': current,
        'to': d14,
        'icon': Icons.date_range_rounded,
      },
      {
        'title': '30-Day Change',
        'value': d30 - current,
        'from': current,
        'to': d30,
        'icon': Icons.calendar_month_rounded,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Predicted Changes vs Now',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: stats.map((s) {
              final delta = s['value'] as double;
              final isWorse = delta > 0;
              final color = isWorse
                  ? AppColors.criticalRed
                  : AppColors.fieldGreen;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(s['icon'] as IconData, color: color, size: 20),
                      const SizedBox(height: 6),
                      Text(
                        '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)}m',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s['title'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mediumGrey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(s['from'] as double).toStringAsFixed(1)} → ${(s['to'] as double).toStringAsFixed(1)}m',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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

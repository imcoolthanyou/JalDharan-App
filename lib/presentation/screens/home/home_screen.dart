import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/models/groundwater_data.dart';
import '../../../core/services/dashboard_api_service.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/app_icons.dart';
import '../../widgets/home_widgets.dart';
import '../../widgets/animated_gradient_background.dart';
import '../../widgets/jal_shayak_overlay.dart';
import '../../widgets/water_metrics_analytics.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/water_alert_service.dart';

import '../rainwater_harvesting/rainwater_harvesting_screen.dart';
import 'homedigitaltwin_clean.dart';
import '../auth/onboarding_screen.dart';
import 'dart:developer' as developer;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late GroundwaterData _currentData;
  final DashboardApiService _apiService = DashboardApiService();
  bool _isLoading = false;
  bool _isPumpOn = false;
  bool _isLoadingPump = false;
  bool _noDevice =
      false; // only true on first load with no device — never flips back
  bool _everHadDevice = false; // once true, never show "no device" again
  String? _cachedToken; // cached once in initState, reused for all polls
  late Timer _autoRefreshTimer;
  Timer? _zeroFlowTimer;
  static const Duration _refreshInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _currentData = GroundwaterData.mockCurrentData();
    _isPumpOn = false;

    WaterAlertService.initialize();

    // Cache JWT once — reuse for all polls to avoid null on rebuild
    AuthService().getToken().then((token) {
      _cachedToken = token;
      // First fetch after token is ready
      _fetchDashboardData();
    });

    // Initialize Socket.IO
    Future.microtask(() {
      final socketService = Provider.of<SocketService>(context, listen: false);
      if (!socketService.isConnected && !socketService.isConnecting) {
        socketService.initSocket();
      }
      socketService.addSensorUpdateListener(_onSensorDataReceived);
      socketService.addConnectionStatusListener(_onConnectionStatusChanged);
    });

    _startAutoRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Do NOT call _fetchDashboardData here — it fires on every rebuild
    // and causes the "no device" flash. Token caching in initState handles first load.
  }

  /// Callback when Socket.IO receives new sensor data
  /// Socket.IO only sends RAW SENSOR DATA:
  /// { water_depth_m, flow_rate_L_min, tds_value, ph, voltage, pump_current_amps, timestamp }
  ///
  /// We merge this with existing calculated data from REST API
  void _onSensorDataReceived(Map<String, dynamic> data) {
    developer.log('🔄 HomeScreen received Socket sensor update: $data');

    try {
      // Handle pump state updates from socket
      if (data.containsKey('state') && data.containsKey('source')) {
        // This is a pump_state event
        setState(() {
          _isPumpOn = (data['state'] == "ON");
        });
      } else if (data.containsKey('motor_status')) {
        // This is from sensor_update with motor status
        bool physicalState = (data['motor_status'] == "ON");
        if (physicalState != _isPumpOn) {
          setState(() {
            _isPumpOn = physicalState;
          });
        }
      }

      // Merge raw sensor data with existing calculated data
      final updatedData = _currentData.mergeWithSensorUpdate(data);

      if (mounted && _hasDataChanged(updatedData)) {
        setState(() {
          _currentData = updatedData;
        });
        developer.log(
          '✅ HomeScreen UI updated with fresh sensor values from Socket',
        );
        // Trigger notifications if water quality is bad
        WaterAlertService.checkAndNotify(
          ph: updatedData.phLevel,
          tds: updatedData.tdsLevel,
        );
        // Auto-shutoff watchdog
        _checkZeroFlowWatchdog();
      }
    } catch (e) {
      developer.log('❌ Error updating with socket sensor data: $e');
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) {
        _fetchDashboardData();
      }
    });
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;

    // Refresh token if not cached yet
    _cachedToken ??= await AuthService().getToken();

    try {
      final data = await _apiService.fetchDashboardData();

      if (!mounted) return;

      // Once we've seen a device, never go back to "no device" state
      _everHadDevice = true;

      if (_hasDataChanged(data)) {
        setState(() {
          _currentData = data;
          _isLoading = false;
          _noDevice = false;
        });
        developer.log('📢 pH=${data.phLevel}, TDS=${data.tdsLevel}');
        WaterAlertService.checkAndNotify(ph: data.phLevel, tds: data.tdsLevel);
      } else {
        setState(() {
          _isLoading = false;
          _noDevice = false;
        });
      }
    } on NoDeviceException {
      if (!mounted) return;
      // Only show "no device" if we've NEVER seen a device in this session
      if (!_everHadDevice) {
        setState(() {
          _isLoading = false;
          _noDevice = true;
        });
      }
      developer.log('ℹ️ No device in response (everHadDevice=$_everHadDevice)');
    } catch (e) {
      if (!mounted) return;
      // Network/auth error — keep last known state, do NOT set _noDevice
      setState(() => _isLoading = false);
      developer.log('Dashboard API Error: $e');
    }
  }

  bool _hasDataChanged(GroundwaterData newData) {
    return _currentData.currentDepth != newData.currentDepth ||
        _currentData.flowRate != newData.flowRate ||
        _currentData.tdsLevel != newData.tdsLevel ||
        _currentData.phLevel != newData.phLevel ||
        _currentData.voltage != newData.voltage ||
        _currentData.current != newData.current ||
        _currentData.motorStatus != newData.motorStatus ||
        _currentData.currentSession != newData.currentSession ||
        _currentData.estimatedExtraction != newData.estimatedExtraction ||
        _currentData.qualityStatus != newData.qualityStatus ||
        _currentData.lastUpdated != newData.lastUpdated ||
        _currentData.predictedDepth7Days != newData.predictedDepth7Days ||
        _currentData.predictedDepth14Days != newData.predictedDepth14Days ||
        _currentData.predictedDepth30Days != newData.predictedDepth30Days ||
        _currentData.trend30Days != newData.trend30Days ||
        _currentData.waterStressLevel != newData.waterStressLevel ||
        _currentData.weatherTemp != newData.weatherTemp ||
        _currentData.weatherCondition != newData.weatherCondition ||
        _currentData.rainAlert != newData.rainAlert ||
        _currentData.flowRateThisSession != newData.flowRateThisSession ||
        _currentData.totalExtractionPerSession !=
            newData.totalExtractionPerSession ||
        _currentData.totalLifetimeExtractionL !=
            newData.totalLifetimeExtractionL ||
        _currentData.waterHealthAI?.contaminationScore !=
            newData.waterHealthAI?.contaminationScore ||
        _currentData.waterHealthAI?.sensorInsights.toString() !=
            newData.waterHealthAI?.sensorInsights.toString();
  }

  /// Handle connection status changes
  /// When disconnected, set pump to OFF state (natural state)
  void _onConnectionStatusChanged(bool isConnected) {
    if (!isConnected && mounted) {
      setState(() {
        _isPumpOn = false; // Natural state when not connected
        developer.log('🔌 Connection lost - pump set to OFF state');
      });
    }
  }

  /// Toggle pump state and send request to backend
  Future<void> _togglePump(bool value) async {
    setState(() {
      _isLoadingPump = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.pumpControlEndpoint),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"action": value ? "ON" : "OFF"}),
          )
          .timeout(
            ApiConfig.requestTimeout,
            onTimeout: () {
              throw TimeoutException(
                'Pump control request timed out',
                ApiConfig.requestTimeout,
              );
            },
          );

      if (response.statusCode == 200) {
        setState(() {
          _isPumpOn = value;
          _isLoadingPump = false;
        });
        developer.log('✅ Pump toggled successfully: ${value ? "ON" : "OFF"}');
      } else {
        setState(() {
          _isLoadingPump = false;
        });
        developer.log('❌ Pump toggle failed: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingPump = false;
        _isPumpOn = false; // Reset to OFF state on communication error
      });
      developer.log("❌ Error toggling pump: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Error communicating with pump controller - pump set to OFF",
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer.cancel();
    _zeroFlowTimer?.cancel();
    _zeroFlowTimer = null;

    // Access context before super.dispose() deactivates it
    final socketService = Provider.of<SocketService>(context, listen: false);
    socketService.removeSensorUpdateListener(_onSensorDataReceived);
    socketService.removeConnectionStatusListener(_onConnectionStatusChanged);

    super.dispose();
  }

  /// Auto-shutoff: if pump is ON and flow rate is 0 for 10 seconds, turn off pump
  void _checkZeroFlowWatchdog() {
    final bool pumpOn = _isPumpOn;
    final bool zeroFlow = _currentData.flowRate <= 0.0;

    if (pumpOn && zeroFlow) {
      // Start the watchdog timer if not already running
      _zeroFlowTimer ??= Timer(const Duration(seconds: 10), () {
        if (_isPumpOn && _currentData.flowRate <= 0.0 && mounted) {
          developer.log('⚠️ Zero-flow watchdog: pump auto-shutoff triggered.');
          _togglePump(false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '🚫 Pump auto-turned OFF — Zero flow detected for 10 seconds.',
              ),
              backgroundColor: AppColors.warningOrange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Turn ON',
                textColor: Colors.white,
                onPressed: () => _togglePump(true),
              ),
            ),
          );
        }
        _zeroFlowTimer = null;
      });
    } else {
      // Flow is back or pump is off — cancel the watchdog
      _zeroFlowTimer?.cancel();
      _zeroFlowTimer = null;
    }
  }

  Color _getWaterStressColor(String stressLevel) {
    switch (stressLevel.toLowerCase()) {
      case 'high':
        return AppColors.criticalRed;
      case 'moderate':
        return AppColors.warningOrange;
      case 'low':
      default:
        return AppColors.fieldGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: _noDevice
              ? _buildNoDeviceScreen()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Digital Twin Section - 85% of screen height
                      SizedBox(
                        height: screenHeight * 0.85,
                        child: HomeDigitalTwin(initialData: _currentData),
                      ),

                      // Swipe Up Indicator - 15% of screen height
                      Container(
                        height: screenHeight * 0.15,
                        color: const Color(0xFF0F172A),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.get('swipe_up_to_view'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Main Home Screen Content
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with Animated Gradient
                          AnimatedGradientBackground(
                            colors: [
                              AppColors.deepAquiferBlue,
                              AppColors.tealStart,
                              AppColors.tealEnd,
                              AppColors.deepAquiferBlue,
                            ],
                            duration: const Duration(seconds: 8),
                            showDebugIndicator: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      AppIcons.waterDrop,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.get('water_quality'),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        Text(
                                          'Real-time sensor data',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/notifications',
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        AppIcons.notification,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Last Updated Chip
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.lightGrey,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppIcons.temperature,
                                      size: 16,
                                      color: AppColors.deepAquiferBlue,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _currentData.formattedTime,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.deepAquiferBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Quality Score Card
                                QualityScoreCard(
                                  qualityScore: _currentData.qualityScore,
                                  qualityStatus: _currentData.qualityStatus,
                                ),
                                const SizedBox(height: 16),

                                // Parameter Cards Grid
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.0,
                                  children: [
                                    _buildParameterCard(
                                      icon: AppIcons.waterLevel,
                                      label: AppLocalizations.of(
                                        context,
                                      )!.get('water_depth'),
                                      value: _currentData.currentDepth
                                          .toStringAsFixed(1),
                                      unit: 'm',
                                      color: AppColors.deepAquiferBlue,
                                    ),
                                    _buildParameterCard(
                                      icon: AppIcons.flowRate,
                                      label: AppLocalizations.of(
                                        context,
                                      )!.get('flow_rate'),
                                      value: _currentData.flowRate
                                          .toStringAsFixed(1),
                                      unit: 'L/min',
                                      color: AppColors.tealStart,
                                    ),
                                    _buildParameterCard(
                                      icon: AppIcons.tds,
                                      label: AppLocalizations.of(
                                        context,
                                      )!.get('tds_level'),
                                      value: _currentData.tdsLevel
                                          .toStringAsFixed(0),
                                      unit: 'ppm',
                                      color: AppColors.warningOrange,
                                    ),
                                    _buildParameterCard(
                                      icon: AppIcons.ph,
                                      label: AppLocalizations.of(
                                        context,
                                      )!.get('ph_level'),
                                      value: _currentData.phLevel
                                          .toStringAsFixed(1),
                                      unit: '',
                                      color: AppColors.fieldGreen,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // Water Metrics Analytics - Expandable Section
                                WaterMetricsAnalytics(
                                  data: _currentData,
                                  onRefresh: _fetchDashboardData,
                                ),

                                const SizedBox(height: 24),

                                // Pump Control Card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.lightGrey,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.get('pump_status'),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.mediumGrey,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _isPumpOn
                                                ? AppLocalizations.of(
                                                    context,
                                                  )!.get('pump_on')
                                                : AppLocalizations.of(
                                                    context,
                                                  )!.get('pump_off'),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: _isPumpOn
                                                  ? AppColors.fieldGreen
                                                  : AppColors.mediumGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_isLoadingPump)
                                        const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        Switch(
                                          value: _isPumpOn,
                                          onChanged: _togglePump,
                                          activeColor: AppColors.fieldGreen,
                                        ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Water Extraction & Flow Rate Card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.lightGrey,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.get('estimated_extraction'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.mediumGrey,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  )!.get('session'),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.mediumGrey,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_currentData.currentSession.toStringAsFixed(1)} m³',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors
                                                        .deepAquiferBlue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  )!.get('flow_rate_info'),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.mediumGrey,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_currentData.flowRate.toStringAsFixed(1)} L/min',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        _currentData.flowRate >
                                                            0
                                                        ? AppColors.fieldGreen
                                                        : AppColors
                                                              .warningOrange,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Rainwater Harvesting Section
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RainwaterHarvestingScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.tealStart.withOpacity(0.2),
                                          AppColors.tealEnd.withOpacity(0.2),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.tealStart.withOpacity(
                                          0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.tealStart
                                                .withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.water_drop,
                                            color: AppColors.tealStart,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.get('rainwater_harvesting'),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.darkGrey,
                                                ),
                                              ),
                                              Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.get(
                                                  'rainwater_harvesting_desc',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.mediumGrey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          AppIcons.back,
                                          color: AppColors.tealStart,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Knowledge Hub Section
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/knowledge_hub',
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.fieldGreen.withOpacity(0.2),
                                          AppColors.deepAquiferBlue.withOpacity(
                                            0.2,
                                          ),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.fieldGreen.withOpacity(
                                          0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.fieldGreen
                                                .withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            AppIcons.knowledge,
                                            color: AppColors.fieldGreen,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.get('knowledge_hub'),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.darkGrey,
                                                ),
                                              ),
                                              Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.get('knowledge_hub_desc'),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.mediumGrey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          AppIcons.back,
                                          color: AppColors.fieldGreen,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Water Health AI Card
                                if (_currentData.waterHealthAI != null)
                                  _buildWaterHealthAICard(
                                    _currentData.waterHealthAI!,
                                  ),

                                const SizedBox(height: 24),

                                // Download Report Button
                                _buildDownloadReportButton(),

                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Jal Shayak Overlay
                ),
        ),
        const JalShayakOverlay(),
      ],
    );
  }

  Widget _buildNoDeviceScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.deepAquiferBlue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sensors_off_rounded,
                size: 64,
                color: AppColors.deepAquiferBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Sensor Connected',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.darkGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'You haven\'t linked a JalDharan sensor yet. Connect your device to start monitoring your water.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mediumGrey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to onboarding to connect sensor
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const _OnboardingRedirect(),
                  ),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.sensors_rounded),
              label: const Text(
                'Connect Sensor',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepAquiferBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _fetchDashboardData,
              child: const Text(
                'Refresh',
                style: TextStyle(color: AppColors.mediumGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGrey,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.mediumGrey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mediumGrey,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // ── Download Report button ────────────────────────────────────────────────
  Widget _buildDownloadReportButton() {
    return GestureDetector(
      onTap: () async {
        if (_currentData.waterHealthAI == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Wait for data to load completely before generating report.',
              ),
              backgroundColor: AppColors.warningOrange,
            ),
          );
          return;
        }

        // 1. Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Jal Dharan AI is writing your report...'),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          // 2. Fetch AI summary from local Ollama via our service
          final summary = await DashboardApiService().generateAiReport(
            _currentData,
          );

          // 3. Close the loading dialog
          if (mounted) Navigator.pop(context);

          // 4. Generate and show the PDF right here
          await PdfReportService.generateAndShowReport(_currentData, summary);
        } catch (e) {
          if (mounted) Navigator.pop(context); // Close dialog on error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error generating report: $e'),
                backgroundColor: AppColors.criticalRed,
              ),
            );
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.deepAquiferBlue, AppColors.tealStart],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepAquiferBlue.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download Water Report',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'PDF · pH, TDS, Depth, AI Analysis',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(width: 14),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ── Water Health AI placeholder (shown while waiting for backend data) ────
  Widget _buildWaterHealthPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: AppColors.lightGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.biotech_rounded,
                color: AppColors.mediumGrey,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Water Health AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Waiting for AI analysis from backend…',
                    style: TextStyle(fontSize: 13, color: AppColors.mediumGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.deepAquiferBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Contamination Alert Banner — shown when pH or TDS is abnormal
  // ---------------------------------------------------------------
  Widget _buildContaminationBanner() {
    final bool phBad =
        _currentData.phLevel < WaterThresholds.phMin ||
        _currentData.phLevel > WaterThresholds.phMax;
    final bool tdsBad = _currentData.tdsLevel > WaterThresholds.tdsMax;
    final bool isContaminated = phBad || tdsBad;

    if (!isContaminated) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.fieldGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.fieldGreen.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.fieldGreen,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Water Quality: Safe',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.fieldGreen,
                    ),
                  ),
                  Text(
                    'All parameters are within safe limits.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.fieldGreen.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Build issue list for contamination advisory
    final List<Map<String, String>> issues = [];
    if (_currentData.phLevel < WaterThresholds.phMin) {
      issues.add({
        'label': 'Low pH (${_currentData.phLevel.toStringAsFixed(1)})',
        'step': 'Add lime or baking soda to neutralise acidic water.',
      });
    } else if (_currentData.phLevel > WaterThresholds.phMax) {
      issues.add({
        'label': 'High pH (${_currentData.phLevel.toStringAsFixed(1)})',
        'step': 'Use a water softener or acid-dosing system.',
      });
    }
    if (tdsBad) {
      issues.add({
        'label': 'High TDS (${_currentData.tdsLevel.toStringAsFixed(0)} ppm)',
        'step': 'Install an RO filter or activate the sediment pre-filter.',
      });
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.criticalRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.criticalRed.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.criticalRed,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                '⚠ Water Contamination Detected',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.criticalRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...issues.asMap().entries.map((entry) {
            final i = entry.key;
            final issue = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.criticalRed,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue['label']!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGrey,
                          ),
                        ),
                        Text(
                          '→ ${issue['step']!}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mediumGrey,
                            height: 1.4,
                          ),
                        ),
                      ],
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

  // ---------------------------------------------------------------
  // Live Water Score HUD — replaces old weather card position
  // ---------------------------------------------------------------
  Widget _buildWaterScoreHUD() {
    final ph = _currentData.phLevel;
    final tds = _currentData.tdsLevel;
    final depth = _currentData.currentDepth;

    Color phColor = ph >= WaterThresholds.phMin && ph <= WaterThresholds.phMax
        ? AppColors.fieldGreen
        : AppColors.criticalRed;
    Color tdsColor = tds <= WaterThresholds.tdsMax
        ? AppColors.fieldGreen
        : AppColors.criticalRed;
    Color depthColor = depth > 5
        ? AppColors.fieldGreen
        : AppColors.warningOrange;

    return Row(
      children: [
        Expanded(
          child: _hudTile(
            'pH',
            ph.toStringAsFixed(1),
            '6.5–8.5',
            phColor,
            Icons.science_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _hudTile(
            'TDS',
            '${tds.toStringAsFixed(0)} ppm',
            '< 500 ppm',
            tdsColor,
            Icons.water_drop_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _hudTile(
            'Depth',
            '${depth.toStringAsFixed(1)} m',
            AppLocalizations.of(context)!.get('current_value'),
            depthColor,
            Icons.layers_rounded,
          ),
        ),
      ],
    );
  }

  Widget _hudTile(
    String label,
    String value,
    String sub,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGrey,
            ),
          ),
          Text(
            sub,
            style: TextStyle(fontSize: 10, color: AppColors.mediumGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildModernParameterCard({
    required String title,
    required double value,
    required String unit,
    required String status,
    required IconData icon,
    required Color iconColor,
    required double maxWidth,
  }) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGrey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(
                    value.toStringAsFixed(value == value.toInt() ? 0 : 1),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mediumGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status.contains('Good') || status.contains('+')
                    ? AppColors.fieldGreen.withOpacity(0.1)
                    : AppColors.warningOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: status.contains('Good') || status.contains('+')
                      ? AppColors.fieldGreen
                      : AppColors.warningOrange,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernWarningCard() {
    // Determine rain status from weather data
    final rainAlert = _currentData.rainAlert ?? '';
    final bool rainExpected =
        rainAlert.isNotEmpty &&
        !rainAlert.toLowerCase().contains('no rain') &&
        (rainAlert.toLowerCase().contains('rain') ||
            rainAlert.toLowerCase().contains('shower') ||
            rainAlert.toLowerCase().contains('storm'));

    final String alertTitle = rainExpected
        ? 'Rain Expected Soon 🌧️'
        : 'Low Water Level Alert';
    final String alertBody = rainExpected
        ? '$rainAlert\nConsider harvesting rainwater from rooftops.'
        : 'No rain expected in the next 2 days.\nConsider reducing water usage.';
    final Color alertColor = rainExpected
        ? AppColors.deepAquiferBlue
        : AppColors.warningOrange;

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [alertColor.withOpacity(0.1), alertColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: alertColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: alertColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                rainExpected ? Icons.umbrella_rounded : Icons.warning_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alertTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alertBody,
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
          ],
        ),
      ),
    );
  }

  Widget _buildExtractionStat({
    required String label,
    required String value,
    bool isHighlights = false,
  }) {
    return Flexible(
      fit: FlexFit.tight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mediumGrey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlights ? 20 : 16,
              fontWeight: FontWeight.w700,
              color: isHighlights
                  ? AppColors.fieldGreen
                  : AppColors.deepAquiferBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    final temp = _currentData.weatherTemp ?? 25.0;
    final condition = _currentData.weatherCondition ?? 'Clear';
    final rainAlert = _currentData.rainAlert ?? '';
    final hasRain = rainAlert.toLowerCase().contains('rain expected');
    final iconCode = _currentData.weatherIcon ?? '01d';

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.deepAquiferBlue.withOpacity(0.08),
            AppColors.tealStart.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightGrey, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        hasRain
                            ? AppColors.warningOrange.withOpacity(0.2)
                            : AppColors.deepAquiferBlue.withOpacity(0.2),
                        hasRain
                            ? AppColors.warningOrange.withOpacity(0.1)
                            : AppColors.tealStart.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getWeatherEmoji(iconCode),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${temp.toStringAsFixed(1)}°C',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepAquiferBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        condition,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasRain)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.warningOrange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_queue_rounded,
                          size: 16,
                          color: AppColors.warningOrange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Rain Alert',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warningOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (rainAlert.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasRain
                        ? AppColors.warningOrange.withOpacity(0.08)
                        : AppColors.fieldGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasRain
                          ? AppColors.warningOrange.withOpacity(0.2)
                          : AppColors.fieldGreen.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasRain
                            ? Icons.info_rounded
                            : Icons.check_circle_rounded,
                        size: 18,
                        color: hasRain
                            ? AppColors.warningOrange
                            : AppColors.fieldGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rainAlert,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasRain
                                ? AppColors.warningOrange
                                : AppColors.fieldGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getWeatherEmoji(String iconCode) {
    final code = iconCode.replaceAll(RegExp(r'\D'), '');
    switch (code) {
      case '01':
        return '☀️';
      case '02':
        return '⛅';
      case '03':
        return '☁️';
      case '04':
        return '☁️';
      case '09':
        return '🌧️';
      case '10':
        return '🌦️';
      case '11':
        return '⛈️';
      case '13':
        return '❄️';
      case '50':
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  Widget _buildModernVisualizationCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RainwaterHarvestingScreen(),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.fieldGreen,
              AppColors.fieldGreen.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.fieldGreen.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rainwater Harvesting',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Design & Recommendations',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Get Structure Recommendations',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterHealthAICard(WaterHealthAI healthAI) {
    // Determine status color and icon based on contamination level
    final Color statusColor = healthAI.indicatorColor;
    final String statusLabel = healthAI.contaminationLevel;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Water Health Assessment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI-Powered Analysis',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Contamination Score Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Contamination Level',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mediumGrey,
                      ),
                    ),
                    Text(
                      '${healthAI.contaminationScore.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: healthAI.contaminationScore / 100,
                    minHeight: 6,
                    backgroundColor: statusColor.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Disease Risk Badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warningOrange.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.warningOrange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      size: 14,
                      color: AppColors.warningOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Health Risk',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mediumGrey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          healthAI.diseaseRisk,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warningOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Health Risk Tags
            if (healthAI.healthRiskTags.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Risk Factors',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: healthAI.healthRiskTags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),

            // Recommended Action
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.fieldGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.fieldGreen.withOpacity(0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.fieldGreen.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      size: 14,
                      color: AppColors.fieldGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recommended Action',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mediumGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          healthAI.recommendedAction,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.darkGrey,
                            height: 1.4,
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
      ),
    );
  }
}

/// Simple redirect widget that takes the user back to the onboarding flow
/// to connect their sensor. Clears the navigation stack.
class _OnboardingRedirect extends StatelessWidget {
  const _OnboardingRedirect();

  @override
  Widget build(BuildContext context) {
    return const OnboardingScreen();
  }
}

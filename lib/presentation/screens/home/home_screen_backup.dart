import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import '../jal_shayak/jal_shayak_screen.dart';
import '../rainwater_harvesting/rainwater_harvesting_screen.dart';
import '../../widgets/water_metrics_analytics.dart';
import '../../../core/models/groundwater_data.dart';
import '../../../core/services/dashboard_api_service.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/config/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';

class HOmeScreenBackup extends StatefulWidget {
  const HOmeScreenBackup({super.key});

  @override
  State<HOmeScreenBackup> createState() => _HOmeScreenBackupState();
}

class _HOmeScreenBackupState extends State<HOmeScreenBackup> {
  String name = FirebaseAuth.instance.currentUser?.displayName ?? '';
  String msg = 'Your Water Is Healthy';
  bool isShowingHouse = false;
  bool ispumpOn = false;
  bool _isLoadingPump = false;
  bool _isLoading = false;
  bool _noDevice = false;
  bool _everHadDevice = false;
  String? _cachedToken;

  // Groundwater Data
  late GroundwaterData groundwaterData;
  final DashboardApiService _apiService = DashboardApiService();
  late Timer _autoRefreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    groundwaterData = GroundwaterData.mockCurrentData();
    ispumpOn = false;

    // Cache JWT and fetch data
    AuthService().getToken().then((token) {
      _cachedToken = token;
      _fetchDashboardData();
    });

    // Initialize Socket.IO for real-time updates
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

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) {
        _fetchDashboardData();
      }
    });
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;

    _cachedToken ??= await AuthService().getToken();

    try {
      final data = await _apiService.fetchDashboardData();

      if (!mounted) return;

      _everHadDevice = true;

      if (_hasDataChanged(data)) {
        setState(() {
          groundwaterData = data;
          _isLoading = false;
          _noDevice = false;
          msg = _getHealthMessage(data.qualityStatus);
        });
        developer.log('📢 pH=${data.phLevel}, TDS=${data.tdsLevel}');
      } else {
        setState(() {
          _isLoading = false;
          _noDevice = false;
        });
      }
    } on NoDeviceException {
      if (!mounted) return;
      if (!_everHadDevice) {
        setState(() {
          _isLoading = false;
          _noDevice = true;
          msg = 'No Device Connected';
        });
      }
      developer.log('ℹ️ No device in response');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      developer.log('Dashboard API Error: $e');
    }
  }

  bool _hasDataChanged(GroundwaterData newData) {
    return groundwaterData.currentDepth != newData.currentDepth ||
        groundwaterData.flowRate != newData.flowRate ||
        groundwaterData.tdsLevel != newData.tdsLevel ||
        groundwaterData.phLevel != newData.phLevel ||
        groundwaterData.voltage != newData.voltage ||
        groundwaterData.current != newData.current ||
        groundwaterData.qualityStatus != newData.qualityStatus;
  }

  String _getHealthMessage(String qualityStatus) {
    if (!mounted) return qualityStatus;
    switch (qualityStatus.toLowerCase()) {
      case 'excellent':
        return AppLocalizations.of(context)?.get('water_excellent') ?? 'Your Water Is Healthy!';
      case 'good':
        return AppLocalizations.of(context)?.get('water_good') ?? 'Water Quality is Good';
      case 'poor':
        return AppLocalizations.of(context)?.get('water_poor') ?? 'Water Quality Needs Attention';
      default:
        return AppLocalizations.of(context)?.get('water_critical') ?? 'Water Quality Critical';
    }
  }

  void _onSensorDataReceived(Map<String, dynamic> data) {
    developer.log('🔄 HomeScreenBackup received Socket sensor update: $data');

    try {
      // Handle pump state updates
      if (data.containsKey('state') && data.containsKey('source')) {
        setState(() {
          ispumpOn = (data['state'] == "ON");
        });
      } else if (data.containsKey('motor_status')) {
        bool physicalState = (data['motor_status'] == "ON");
        if (physicalState != ispumpOn) {
          setState(() {
            ispumpOn = physicalState;
          });
        }
      }

      // Merge sensor data
      final updatedData = groundwaterData.mergeWithSensorUpdate(data);

      if (mounted && _hasDataChanged(updatedData)) {
        setState(() {
          groundwaterData = updatedData;
          msg = _getHealthMessage(updatedData.qualityStatus);
        });
        developer.log('✅ HomeScreenBackup UI updated with Socket data');
      }
    } catch (e) {
      developer.log('❌ Error updating with socket data: $e');
    }
  }

  void _onConnectionStatusChanged(bool isConnected) {
    if (!isConnected && mounted) {
      setState(() {
        ispumpOn = false;
        developer.log('🔌 Connection lost - pump set to OFF');
      });
    }
  }

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
          ispumpOn = value;
          _isLoadingPump = false;
        });
        developer.log('✅ Pump toggled: ${value ? "ON" : "OFF"}');
      } else {
        setState(() {
          _isLoadingPump = false;
        });
        developer.log('❌ Pump toggle failed: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed: ${response.statusCode}")),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingPump = false;
        ispumpOn = false;
      });
      developer.log("❌ Error toggling pump: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error communicating with pump - set to OFF"),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer.cancel();
    final socketService = Provider.of<SocketService>(context, listen: false);
    socketService.removeSensorUpdateListener(_onSensorDataReceived);
    socketService.removeConnectionStatusListener(_onConnectionStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Profile Button With Container
            Container(
              margin: EdgeInsets.only(bottom: 4),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: AppColors.mediumGrey),
            ),
            const SizedBox(width: 8),
            //Message Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)?.get('good_morning') ?? 'Good Morning, ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mediumGrey,
                        ),
                      ),
                      Text(
                        name.isEmpty ? 'User' : name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGrey,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.waving_hand,
                        color: Colors.amberAccent,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            //Notification Section which leads to notification pages with red dot if notification is unread
            Stack(
              alignment: Alignment.topCenter,
              children: [
                GestureDetector(
                  onTap: () {
                    // Navigate to notification page
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications,
                      color: AppColors.mediumGrey,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // 3D Model Section
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.deepAquiferBlue.withValues(alpha: 0.1),
                      AppColors.tealEnd.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isShowingHouse = !isShowingHouse;
                        });
                      },
                      child: Container(
                        height: 380,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: ModelViewer(
                            src: 'assets/models/house_model.glb',
                            cameraControls: true,
                            disableZoom: true,
                          ),
                        ),
                      ),
                    ),

                    //water quality section
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildMetricCard(
                              icon: Icons.water_drop,
                              iconColor: AppColors.deepAquiferBlue,
                              title: AppLocalizations.of(context)?.get('quality') ?? 'Quality',
                              value: groundwaterData.qualityScore
                                  .toStringAsFixed(0),
                              unit: '/100',
                              statusText: groundwaterData.qualityStatus,
                              statusColor: _getQualityColor(
                                groundwaterData.qualityStatus,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildMetricCard(
                              icon: Icons.height,
                              iconColor: AppColors.deepAquiferBlue,
                              title: AppLocalizations.of(context)?.get('depth') ?? 'Depth',
                              value: groundwaterData.currentDepth
                                  .toStringAsFixed(1),
                              unit: ' m',
                              statusText: AppLocalizations.of(context)?.get('safe_range') ?? 'Safe Range',
                              statusColor: AppColors.deepAquiferBlue,
                            ),
                            const SizedBox(width: 8),
                            // Pump card: match sizing and styling of _buildMetricCard
                            Container(
                              width: 140,
                              height: 110,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // pump control header
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.pest_control,
                                        size: 15,
                                        color: AppColors.deepAquiferBlue,
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          AppLocalizations.of(context)?.get('pump_status') ?? 'Pump Status',
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black54,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // Compact row with pump label and switch
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        ispumpOn ? 'ON' : 'OFF',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: ispumpOn
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (_isLoadingPump)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        Switch(
                                          value: ispumpOn,
                                          activeColor:
                                              AppColors.deepAquiferBlue,
                                          onChanged: _togglePump,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              //Ai Insight Section For Jal Shayak
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFF4EFFF,
                  ), // Soft purple background matching the image
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    // The water smile image
                    Image.asset(
                      'assets/water_smile.png', // Make sure to add your image to assets
                      width: 50,
                      height: 50,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.water_drop,
                        size: 50,
                        color: AppColors.deepAquiferBlue,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Text Column
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: AppColors.tealStart,
                              ), // Sparkle icon
                              const SizedBox(width: 4),
                              Text(
                                AppLocalizations.of(context)?.get('ai_insight') ?? 'AI Insight',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.tealStart,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            groundwaterData.waterHealthAI?.recommendedAction ?? AppLocalizations.of(context)?.get('ai_insight_default') ?? 'Great news! Your groundwater level and water quality are in excellent condition. Keep up the good work!',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              height:
                                  1.3, // Slight line height adjustment for readability
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Ask Jal Shayak Button
                    ElevatedButton.icon(
                      onPressed: () {
                        // Triggers the chatbot bottom sheet
                        _showJalShayakBottomSheet(context);
                      },
                      icon: const Icon(
                        Icons.chat_bubble_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        AppLocalizations.of(context)?.get('ask_jal_shayak') ?? 'Ask Jal Shayak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealStart,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Water Metrics Analytics Section
              WaterMetricsAnalytics(
                data: groundwaterData,
                onRefresh: _fetchDashboardData,
              ),

              const SizedBox(height: 16),

              // Rainwater Harvesting Section
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return RainwaterHarvestingScreen();
                      },
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.tealEnd.withValues(alpha: 0.2),
                        AppColors.deepAquiferBlue.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.tealEnd.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.tealEnd.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.water_drop,
                          color: AppColors.tealEnd,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)?.get('rainwater_harvesting') ?? 'Rainwater Harvesting',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkGrey,
                              ),
                            ),
                            Text(
                              AppLocalizations.of(context)?.get('rainwater_harvesting_desc') ?? 'Learn about structure & setup',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.mediumGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.tealEnd,
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
                  Navigator.pushNamed(context, '/knowledge_hub');
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.fieldGreen.withValues(alpha: 0.2),
                        AppColors.deepAquiferBlue.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.fieldGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.fieldGreen.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.school,
                          color: AppColors.fieldGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)?.get('knowledge_hub') ?? 'Knowledge Hub',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkGrey,
                              ),
                            ),
                            Text(
                              AppLocalizations.of(context)?.get('knowledge_hub_desc') ?? 'Explore educational resources',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.mediumGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.fieldGreen,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Download Report Button
              GestureDetector(
                onTap: () async {
                  if (groundwaterData.waterHealthAI == null) {
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

                  // Show loading dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(AppLocalizations.of(context)?.get('writing_report') ?? 'Jal Dharan AI is writing your report...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );

                  try {
                    // Fetch AI summary
                    final summary = await DashboardApiService()
                        .generateAiReport(groundwaterData);

                    if (mounted) Navigator.pop(context);

                    // Generate and show PDF
                    await PdfReportService.generateAndShowReport(
                      groundwaterData,
                      summary,
                    );
                  } catch (e) {
                    if (mounted) Navigator.pop(context);
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
                    gradient: AppColors.aquaFlowGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.deepAquiferBlue.withValues(
                          alpha: 0.35,
                        ),
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
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)?.get('download_report') ?? 'Download Water Report',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context)?.get('download_report_desc') ?? 'PDF · pH, TDS, Depth, AI Analysis',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
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
              ),

              const SizedBox(height: 32),
              //quick overview section
            ],
          ),
        ),
      ),
    );
  }

  void _showJalShayakBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows us to set a custom height
      backgroundColor:
          Colors.transparent, // Transparent so our custom rounded corners show
      builder: (BuildContext context) {
        // This container controls the size and shape of the popup
        return Container(
          height:
              MediaQuery.of(context).size.height *
              0.6, // Sets it to 60% of the screen height
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),

          // ClipRRect ensures your JalShayakScreen respects the rounded corners above
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),

            // This calls your actual screen directly into the bottom half of the UI!
            child: const JalShayakScreen(),
          ),
        );
      },
    );
  }

  Color _getQualityColor(String qualityStatus) {
    switch (qualityStatus.toLowerCase()) {
      case 'excellent':
        return AppColors.fieldGreen;
      case 'good':
        return AppColors.deepAquiferBlue;
      case 'poor':
        return AppColors.warningOrange;
      default:
        return AppColors.criticalRed;
    }
  }
}

Widget _buildMetricCard({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String value,
  required String unit,
  required String statusText,
  required Color statusColor,
}) {
  return Container(
    width: 110, // Fixed width for consistent horizontal scrolling layout
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(
        0.9,
      ), // Slight transparency for the overlay effect
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: unit,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.check, size: 12, color: statusColor),
            ],
          ),
        ),
      ],
    ),
  );
}

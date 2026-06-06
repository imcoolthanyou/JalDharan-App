import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_svg/flutter_svg.dart';

import '../jal_shayak/jal_shayak_screen.dart';
import '../rainwater_harvesting/rainwater_harvesting_screen.dart';
import '../../../core/models/groundwater_data.dart';
import '../../../core/services/dashboard_api_service.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/config/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../notifications/notifications_screen.dart';
import '../community_settings/profile.dart';

class HOmeScreenBackup extends StatefulWidget {
  const HOmeScreenBackup({super.key});

  @override
  State<HOmeScreenBackup> createState() => _HOmeScreenBackupState();
}

class _HOmeScreenBackupState extends State<HOmeScreenBackup> {
  String name = FirebaseAuth.instance.currentUser?.displayName ?? '';
  bool ispumpOn = false;
  bool _isLoadingPump = false;
  bool _isLoading = false;
  bool _noDevice = false;
  bool _everHadDevice = false;
  String? _cachedToken;

  late GroundwaterData groundwaterData;
  final DashboardApiService _apiService = DashboardApiService();
  late Timer _autoRefreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    groundwaterData = GroundwaterData.mockCurrentData();
    ispumpOn = false;
    AuthService().getToken().then((token) {
      _cachedToken = token;
      _fetchDashboardData();
    });
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
      if (mounted) _fetchDashboardData();
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

  void _onSensorDataReceived(Map<String, dynamic> data) {
    developer.log('🔄 HomeScreenBackup received Socket sensor update: $data');
    try {
      if (data.containsKey('state') && data.containsKey('source')) {
        setState(() {
          ispumpOn = (data['state'] == "ON");
        });
      } else if (data.containsKey('motor_status')) {
        bool physicalState = (data['motor_status'] == "ON");
        if (physicalState != ispumpOn)
          setState(() {
            ispumpOn = physicalState;
          });
      }
      final updatedData = groundwaterData.mergeWithSensorUpdate(data);
      if (mounted && _hasDataChanged(updatedData)) {
        setState(() {
          groundwaterData = updatedData;
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
    final l = AppLocalizations.of(context);
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
            SnackBar(
              content: Text(
                l?.get('pump_toggle_failed') ?? 'Failed to toggle pump',
              ),
            ),
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
          SnackBar(
            content: Text(
              l?.get('pump_comm_error') ??
                  'Error communicating with pump - set to OFF',
            ),
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

  String _getInitials() {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Profile avatar
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getInitials(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            // Notifications
            Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.darkGrey,
                      size: 24,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        "3",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

              // ── Analytics Section (2×2 grid) ──
              _buildAnalyticsSection(l),
              const SizedBox(height: 16),

              // ── Pump Control Card ──
              _buildPumpControlCard(l),
              const SizedBox(height: 16),

              // ── AI Insight / Jal Shayak ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/Icons/jal_Shayak.svg',
                      width: 50,
                      height: 50,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l.get('ai_insight'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            groundwaterData.waterHealthAI?.recommendedAction ??
                                l.get('ai_insight_default'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showJalShayakBottomSheet(context),
                      icon: const Icon(
                        Icons.chat_bubble_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        l.get('ask_jal_shayak'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
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

              // ── Quick Links Row ──
              _buildQuickLinksRow(l),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WIDGETS
  // ──────────────────────────────────────────────────────────────────────────

  /// 2×2 Analytics Grid
  Widget _buildAnalyticsSection(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.get('analytics'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                svgIconPath: 'assets/Icons/water_depth.svg',
                label: l.get('water_depth'),
                value: groundwaterData.currentDepth.toStringAsFixed(1),
                unit: 'm',
                statusText: groundwaterData.qualityStatus,
                statusColor: _getQualityColor(groundwaterData.qualityStatus),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsCard(
                svgIconPath: 'assets/Icons/flow_rate.svg',
                label: l.get('flow_rate'),
                value: groundwaterData.flowRate.toStringAsFixed(1),
                unit: 'L/min',
                statusText: l.get('normal'),
                statusColor: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                svgIconPath: 'assets/Icons/tds_level.svg',
                label: l.get('tds_level'),
                value: groundwaterData.tdsLevel.toStringAsFixed(0),
                unit: 'ppm',
                statusText: groundwaterData.tdsLevel < 500
                    ? l.get('safe')
                    : l.get('warning_level'),
                statusColor: groundwaterData.tdsLevel < 500
                    ? AppColors.primary
                    : AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsCard(
                svgIconPath: 'assets/Icons/PH_Icon.svg',
                label: l.get('ph_level'),
                value: groundwaterData.phLevel.toStringAsFixed(1),
                unit: '',
                statusText:
                    (groundwaterData.phLevel >= 6.5 &&
                        groundwaterData.phLevel <= 8.5)
                    ? l.get('safe')
                    : l.get('warning_level'),
                statusColor:
                    (groundwaterData.phLevel >= 6.5 &&
                        groundwaterData.phLevel <= 8.5)
                    ? AppColors.primary
                    : AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Single analytics metric card
  Widget _buildAnalyticsCard({
    required String svgIconPath,
    required String label,
    required String value,
    required String unit,
    required String statusText,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SVG Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              svgIconPath,
              width: 40,
              height: 40,
              placeholderBuilder: (_) =>
                  const Icon(Icons.water, size: 32, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mediumGrey,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGrey,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGrey,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
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

  /// Pump Control card with toggle switch
  Widget _buildPumpControlCard(AppLocalizations l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (ispumpOn ? AppColors.accentGreen : AppColors.mediumGrey)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/Icons/pump_valves.svg',
              width: 28,
              height: 28,
              placeholderBuilder: (_) => Icon(
                Icons.pest_control,
                size: 28,
                color: ispumpOn ? AppColors.accentGreen : AppColors.mediumGrey,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Label + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.get('pump_status'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ispumpOn ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ispumpOn
                        ? AppColors.accentGreen
                        : AppColors.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
          // Toggle
          if (_isLoadingPump)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: ispumpOn,
              activeColor: Colors.white,
              activeTrackColor: AppColors.accentGreen,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: AppColors.lightGrey,
              onChanged: _togglePump,
            ),
        ],
      ),
    );
  }

  /// Compact horizontal row: Rainwater · Knowledge Hub · Download Report
  Widget _buildQuickLinksRow(AppLocalizations l) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickLinkCard(
            label: l.get('rainwater_harvesting'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RainwaterHarvestingScreen(),
                ),
              );
            },
            icon: Icons.water_drop_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickLinkCard(
            svgIconPath: 'assets/Icons/Knowledge_hub.svg',
            label: l.get('knowledge_hub'),
            onTap: () => Navigator.pushNamed(context, '/knowledge_hub'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickLinkCard(
            label: l.get('report'),
            onTap: _downloadReport,
            icon: Icons.download_rounded,
          ),
        ),
      ],
    );
  }

  /// Single compact quick link card
  Widget _buildQuickLinkCard({
    String? svgIconPath,
    IconData? icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightGrey),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, size: 32, color: AppColors.primary)
            else if (svgIconPath != null)
              SvgPicture.asset(
                svgIconPath,
                width: 32,
                height: 32,
                placeholderBuilder: (_) => const Icon(
                  Icons.circle,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGrey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  void _showJalShayakBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            child: const JalShayakScreen(),
          ),
        );
      },
    );
  }

  Future<void> _downloadReport() async {
    final l = AppLocalizations.of(context);
    if (groundwaterData.waterHealthAI == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l?.get('wait_data_load') ?? 'Wait for data to load completely.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('...'),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final summary = await DashboardApiService().generateAiReport(
        groundwaterData,
      );
      if (mounted) Navigator.pop(context);
      await PdfReportService.generateAndShowReport(groundwaterData, summary);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l?.get('error_generating_report') ?? 'Error'}: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Color _getQualityColor(String qualityStatus) {
    switch (qualityStatus.toLowerCase()) {
      case 'excellent':
        return AppColors.primary;
      case 'good':
        return AppColors.primary;
      case 'poor':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }
}

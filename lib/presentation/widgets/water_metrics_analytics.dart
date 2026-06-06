import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/models/groundwater_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_localizations.dart';

/// Quick Overview Widget - Displays key water metrics in a modern card layout
/// Matches the design with horizontal scrollable cards and expandable analytics
class WaterMetricsAnalytics extends StatefulWidget {
  final GroundwaterData data;
  final VoidCallback? onRefresh;

  const WaterMetricsAnalytics({super.key, required this.data, this.onRefresh});

  @override
  State<WaterMetricsAnalytics> createState() => _WaterMetricsAnalyticsState();
}

class _WaterMetricsAnalyticsState extends State<WaterMetricsAnalytics> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Quick Overview Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.lightGrey,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)?.get('quick_overview') ?? 'Quick Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGrey,
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleExpanded,
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)?.get('view_analytics') ?? 'View Analytics',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_right,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Horizontal Scrollable Metric Cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildQuickMetricCard(
                      icon: Icons.water,
                      iconColor: AppColors.primary,
                      iconBg: AppColors.primary.withValues(alpha: 0.1),
                      label: AppLocalizations.of(context)?.get('water_depth') ?? 'Water Depth',
                      value: widget.data.currentDepth.toStringAsFixed(1),
                      unit: 'm',
                      change: '1.2 m',
                      isIncrease: false,
                      changeLabel: AppLocalizations.of(context)?.get('from_last_week') ?? 'from last week',
                    ),
                    const SizedBox(width: 12),
                    _buildQuickMetricCard(
                      icon: Icons.water_drop,
                      iconColor: AppColors.darkGrey,
                      iconBg: AppColors.darkGrey.withValues(alpha: 0.1),
                      label: AppLocalizations.of(context)?.get('flow_rate') ?? 'Flow Rate',
                      value: widget.data.flowRate.toStringAsFixed(1),
                      unit: 'L/min',
                      change: '2.1 L/min',
                      isIncrease: true,
                      changeLabel: AppLocalizations.of(context)?.get('from_last_week') ?? 'from last week',
                    ),
                    const SizedBox(width: 12),
                    _buildQuickMetricCard(
                      icon: Icons.science,
                      iconColor: AppColors.warning,
                      iconBg: AppColors.warning.withValues(alpha: 0.1),
                      label: AppLocalizations.of(context)?.get('tds_level') ?? 'TDS Level',
                      value: widget.data.tdsLevel.toStringAsFixed(0),
                      unit: 'ppm',
                      change: '20 ppm',
                      isIncrease: false,
                      changeLabel: AppLocalizations.of(context)?.get('from_last_week') ?? 'from last week',
                    ),
                    const SizedBox(width: 12),
                    _buildQuickMetricCard(
                      iconWidget: SvgPicture.asset(
                        'assets/Icons/PH_Icon.svg',
                        width: 24,
                        height: 24,
                      ),
                      iconColor: AppColors.primary,
                      iconBg: AppColors.primary.withValues(alpha: 0.1),
                      label: AppLocalizations.of(context)?.get('ph_level') ?? 'pH Level',
                      value: widget.data.phLevel.toStringAsFixed(1),
                      unit: '',
                      change: '0.3',
                      isIncrease: true,
                      changeLabel: AppLocalizations.of(context)?.get('from_last_week') ?? 'from last week',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Expanded Analytics Section
        if (_isExpanded) ...[
          const SizedBox(height: 16),
          _buildExpandedAnalytics(),
        ],

        // Water Saved This Month Card
        const SizedBox(height: 16),
        _buildWaterSavedCard(),
      ],
    );
  }

  Widget _buildQuickMetricCard({
    IconData? icon,
    Widget? iconWidget,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    required String unit,
    required String change,
    required bool isIncrease,
    required String changeLabel,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: iconWidget ?? Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 12),

          // Label
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.mediumGrey,
            ),
          ),
          const SizedBox(height: 8),

          // Value
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGrey,
                  ),
                ),
                TextSpan(
                  text: unit.isNotEmpty ? ' $unit' : '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Change Indicator
          Row(
            children: [
              Icon(
                isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: isIncrease ? AppColors.primary : AppColors.darkGrey,
              ),
              const SizedBox(width: 4),
              Text(
                change,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isIncrease ? AppColors.primary : AppColors.darkGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            changeLabel,
            style: const TextStyle(fontSize: 11, color: AppColors.mediumGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedAnalytics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)?.get('detailed_sensor_data') ?? 'Detailed Sensor Data',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 16),

          // Grid of all sensor data with icon cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildDetailMetricCard(
                  icon: Icons.flash_on,
                  iconColor: AppColors.warning,
                  iconBg: AppColors.warning.withValues(alpha: 0.1),
                  label: AppLocalizations.of(context)?.get('voltage') ?? 'Voltage',
                  value: widget.data.voltage.toStringAsFixed(0),
                  unit: 'V',
                ),
                const SizedBox(width: 12),
                _buildDetailMetricCard(
                  icon: Icons.electric_bolt,
                  iconColor: AppColors.error,
                  iconBg: AppColors.error.withValues(alpha: 0.1),
                  label: AppLocalizations.of(context)?.get('ampere') ?? 'Current',
                  value: widget.data.current.toStringAsFixed(1),
                  unit: 'A',
                ),
                const SizedBox(width: 12),
                _buildDetailMetricCard(
                  icon: Icons.power,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primary.withValues(alpha: 0.1),
                  label: AppLocalizations.of(context)?.get('kilowatt') ?? 'Power',
                  value: widget.data.powerKw.toStringAsFixed(2),
                  unit: 'kW',
                ),
                const SizedBox(width: 12),
                _buildDetailMetricCard(
                  icon: Icons.access_time,
                  iconColor: AppColors.darkGrey,
                  iconBg: AppColors.darkGrey.withValues(alpha: 0.1),
                  label: AppLocalizations.of(context)?.get('session') ?? 'Session',
                  value: widget.data.currentSession.toStringAsFixed(2),
                  unit: 'm³',
                ),
                const SizedBox(width: 12),
                _buildDetailMetricCard(
                  icon: Icons.water_damage,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primary.withValues(alpha: 0.1),
                  label: AppLocalizations.of(context)?.get('extracted') ?? 'Extracted',
                  value: widget.data.estimatedExtraction.toStringAsFixed(1),
                  unit: 'm³',
                ),
                const SizedBox(width: 12),
                _buildDetailMetricCard(
                  icon: Icons.calendar_month,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primary.withValues(alpha: 0.1),
                  label: AppLocalizations.of(context)?.get('lifetime') ?? 'Lifetime',
                  value: (widget.data.totalLifetimeExtractionL / 1000)
                      .toStringAsFixed(1),
                  unit: 'm³',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Last Updated
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: AppColors.mediumGrey),
              const SizedBox(width: 8),
              Text(
                '${AppLocalizations.of(context)?.get('last_updated') ?? 'Last updated:'} ${widget.data.formattedTime}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mediumGrey,
                ),
              ),
              const Spacer(),
              if (widget.onRefresh != null)
                GestureDetector(
                  onTap: widget.onRefresh,
                  child: const Icon(
                    Icons.refresh,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),

          // Label
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mediumGrey,
            ),
          ),
          const SizedBox(height: 6),

          // Value
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGrey,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterSavedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Leaf Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco, color: AppColors.primary, size: 32),
          ),
          const SizedBox(width: 16),

          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.get('water_saved_month') ?? 'Water Saved This Month',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: '2,450',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGrey,
                        ),
                      ),
                      TextSpan(
                        text: ' ${AppLocalizations.of(context)?.get('liters') ?? 'Liters'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)?.get('keep_conserving') ?? 'Keep conserving! You\'re doing great.',
                  style: const TextStyle(fontSize: 12, color: AppColors.mediumGrey),
                ),
              ],
            ),
          ),

          // Wave icon with colored text instead of badge
          Column(
            children: [
              const Icon(Icons.waves, color: AppColors.primary, size: 32),
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(
                    Icons.arrow_upward,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  SizedBox(width: 2),
                  Text(
                    '18%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.of(context)?.get('vs_last_month') ?? 'vs last month',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

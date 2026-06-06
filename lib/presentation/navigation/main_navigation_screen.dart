import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../screens/analytics/analytics_screen.dart';
import '../screens/gamification/gamification_v2_screen.dart';
import '../screens/community_settings/profile.dart';
import '../screens/map_grind/map_grind_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/app_icons.dart';
import 'package:jal_dharan/presentation/screens/home/home_screen_backup.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HOmeScreenBackup(),
    const AnalyticsScreen(),
    const MapGrindScreen(),
    const GamificationV2Screen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.mediumGrey,
        elevation: 12,
        items: [
          BottomNavigationBarItem(
            icon: Icon(AppIcons.home),
            activeIcon: Icon(AppIcons.home),
            label: AppLocalizations.of(context)!.get('home'),
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.trend),
            activeIcon: Icon(AppIcons.trend),
            label: AppLocalizations.of(context)!.get('prediction'),
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.mapGrid),
            activeIcon: Icon(AppIcons.mapGrid),
            label: AppLocalizations.of(context)!.get('map_grid'),
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.leaderboard),
            activeIcon: Icon(AppIcons.leaderboard),
            label: AppLocalizations.of(context)!.get('gamification'),
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.settings),
            activeIcon: Icon(AppIcons.settings),
            label: AppLocalizations.of(context)!.get('app_settings'),
          ),
        ],
      ),
    );
  }
}
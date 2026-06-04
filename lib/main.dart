import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/socket_service.dart';
import 'core/providers/language_provider.dart';
import 'core/localization/app_localizations.dart';
import 'firebase_options.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/signup_screen.dart';
import 'presentation/screens/auth/onboarding_screen.dart';
import 'presentation/screens/rainwater_harvesting/rainwater_harvesting_screen.dart';
import 'presentation/screens/analytics/analytics_screen.dart';
import 'presentation/screens/gamification/water_hero_screen.dart';
import 'presentation/screens/knowledge_hub/knowledge_hub_screen.dart';
import 'presentation/screens/community_settings/community_settings_screen.dart';
import 'presentation/screens/jal_shayak/jal_shayak_screen.dart';
import 'presentation/screens/notifications/notifications_screen.dart';
import 'presentation/screens/map_grind/map_grind_screen.dart';
import 'presentation/navigation/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final socketService = SocketService();

    return MultiProvider(
      providers: [
        // Socket Service Provider
        ChangeNotifierProvider<SocketService>.value(value: socketService),
        // Language Provider
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(),
        ),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: 'Jal Dharan',
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            locale: languageProvider.getLocale(),
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('hi')],
            home: _buildHome(authService),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignUpScreen(),
              '/home': (context) => const MainNavigationScreen(),
              '/rainwater_harvesting': (context) =>
                  const RainwaterHarvestingScreen(),
              '/analytics': (context) => const AnalyticsScreen(),
              '/water_hero': (context) => const WaterHeroScreen(),
              '/knowledge_hub': (context) => const KnowledgeHubScreen(),
              '/community_settings': (context) =>
                  const CommunitySettingsScreen(),
              '/jal_shayak': (context) => const JalShayakScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/map_grind': (context) => const MapGrindScreen(),
            },
          );
        },
      ),
    );
  }

  Widget _buildHome(AuthService authService) {
    return FutureBuilder<_AppStartState>(
      future: _resolveStartState(authService),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        switch (snapshot.data!) {
          case _AppStartState.home:
            // Init socket for returning signed-in users
            Future.microtask(() {
              final socketService = Provider.of<SocketService>(
                context,
                listen: false,
              );
              if (!socketService.isConnected && !socketService.isConnecting) {
                socketService.initSocket();
              }
            });
            return const MainNavigationScreen();
          case _AppStartState.onboarding:
            return const OnboardingScreen();
          case _AppStartState.login:
            return const LoginScreen();
        }
      },
    );
  }

  Future<_AppStartState> _resolveStartState(AuthService authService) async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
    final currentUser = authService.currentUser;

    // Only auto-restore session if user has completed onboarding before
    // (i.e., they're a known returning user)
    if (currentUser != null && onboardingDone) {
      return _AppStartState.home;
    }

    // Everyone else sees the login screen — including users with a cached
    // Firebase session who haven't completed onboarding
    return _AppStartState.login;
  }
}

enum _AppStartState { home, onboarding, login }

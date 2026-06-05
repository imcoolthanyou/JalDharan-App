import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'animated_gradient_background.dart';

class CustomGradientAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onNotificationTap;
  final bool showNotification;

  const CustomGradientAppBar({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onNotificationTap,
    this.showNotification = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedGradientBackground(
      colors: const [
        AppColors.deepAquiferBlue,
        AppColors.tealStart,
        AppColors.tealEnd,
        AppColors.deepAquiferBlue,
      ],
      duration: const Duration(seconds: 8),
      showDebugIndicator: false,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (showNotification)
                GestureDetector(
                  onTap: onNotificationTap ??
                      () {
                        Navigator.pushNamed(context, '/notifications');
                      },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
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
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 40); // Accounts for padding + icon size
}

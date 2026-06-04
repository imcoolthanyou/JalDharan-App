import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/app_icons.dart';
import '../../../core/services/auth_service.dart';

class CommunitySettingsScreen extends StatefulWidget {
  const CommunitySettingsScreen({Key? key}) : super(key: key);

  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  bool _notificationsEnabled = true;
  bool _dataSharing = true;
  bool _communityUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.get('app_settings'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.darkGrey,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildSettingsContent(),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Settings Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.get('app_settings'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGrey,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingTile(
                  context: context,
                  title: AppLocalizations.of(context)!.get('notifications'),
                  subtitle: AppLocalizations.of(
                    context,
                  )!.get('enable_notifications_desc'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                  },
                ),
                const SizedBox(height: 12),
                _buildSettingTile(
                  context: context,
                  title: AppLocalizations.of(context)!.get('data_sharing'),
                  subtitle: AppLocalizations.of(
                    context,
                  )!.get('data_sharing_desc'),
                  value: _dataSharing,
                  onChanged: (value) {
                    setState(() => _dataSharing = value);
                  },
                ),
                const SizedBox(height: 12),
                _buildSettingTile(
                  context: context,
                  title: AppLocalizations.of(context)!.get('community_updates'),
                  subtitle: AppLocalizations.of(
                    context,
                  )!.get('community_updates_desc'),
                  value: _communityUpdates,
                  onChanged: (value) {
                    setState(() => _communityUpdates = value);
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // Language Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.get('language'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGrey,
                  ),
                ),
                const SizedBox(height: 16),
                Consumer<LanguageProvider>(
                  builder: (context, languageProvider, _) => Column(
                    children: [
                      _buildLanguageOptionTile(
                        languageName: 'English',
                        languageCode: 'en',
                        isSelected: languageProvider.currentLanguage == 'en',
                        onTap: () => languageProvider.changeLanguage('en'),
                      ),
                      const SizedBox(height: 12),
                      _buildLanguageOptionTile(
                        languageName: 'हिंदी',
                        languageCode: 'hi',
                        isSelected: languageProvider.currentLanguage == 'hi',
                        onTap: () => languageProvider.changeLanguage('hi'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // About Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.get('about'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGrey,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingButton(
                  icon: AppIcons.info,
                  title: AppLocalizations.of(context)!.get('about_jal_dharan'),
                  subtitle: AppLocalizations.of(
                    context,
                  )!.get('about_jal_dharan_desc'),
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                _buildSettingButton(
                  icon: AppIcons.lock,
                  title: AppLocalizations.of(context)!.get('privacy_policy'),
                  subtitle: AppLocalizations.of(
                    context,
                  )!.get('privacy_policy_desc'),
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                _buildSettingButton(
                  icon: AppIcons.book,
                  title: AppLocalizations.of(context)!.get('terms_conditions'),
                  subtitle: AppLocalizations.of(context)!.get('terms_desc'),
                  onTap: () {},
                ),
              ],
            ),
          ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // Account Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.get('account'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGrey,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingButton(
                  icon: AppIcons.logout,
                  title: AppLocalizations.of(context)!.get('logout'),
                  subtitle: AppLocalizations.of(context)!.get('logout_desc'),
                  isDestructive: true,
                  onTap: () {
                    _showLogoutDialog();
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.deepAquiferBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.criticalRed.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDestructive
              ? Border.all(color: AppColors.criticalRed.withOpacity(0.2))
              : null,
          boxShadow: isDestructive
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppColors.criticalRed.withOpacity(0.1)
                    : AppColors.deepAquiferBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDestructive
                    ? AppColors.criticalRed
                    : AppColors.deepAquiferBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDestructive
                          ? AppColors.criticalRed
                          : AppColors.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
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
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isDestructive
                  ? AppColors.criticalRed
                  : AppColors.mediumGrey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOptionTile({
    required String languageName,
    required String languageCode,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.deepAquiferBlue.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.deepAquiferBlue : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.deepAquiferBlue.withOpacity(0.15)
                    : AppColors.deepAquiferBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                AppIcons.language,
                color: AppColors.deepAquiferBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                languageName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.deepAquiferBlue
                      : AppColors.darkGrey,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                AppIcons.checkmark,
                color: AppColors.deepAquiferBlue,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.get('logout_confirm_title')),
        content: Text(
          AppLocalizations.of(context)!.get('logout_confirm_message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.get('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog

              // Capture navigator before async gap
              final navigator = Navigator.of(context);

              try {
                // Sign out from Firebase + Google + clear JWT
                await AuthService().signOut();

                // Clear onboarding flag so next login goes through fresh flow
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('onboarding_complete');

                // Navigate to login, clearing the entire stack
                navigator.pushNamedAndRemoveUntil('/login', (route) => false);
              } catch (e) {
                // Even if signOut fails, force navigate to login
                navigator.pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: Text(
              AppLocalizations.of(context)!.get('logout_confirm'),
              style: const TextStyle(color: AppColors.criticalRed),
            ),
          ),
        ],
      ),
    );
  }
}

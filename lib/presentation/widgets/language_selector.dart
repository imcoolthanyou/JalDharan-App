import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/providers/language_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_icons.dart';

class LanguageSelectorButton extends StatelessWidget {
  final bool isCompact;
  final VoidCallback? onChanged;

  const LanguageSelectorButton({
    Key? key,
    this.isCompact = false,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final localizations = AppLocalizations.of(context);

        if (isCompact) {
          return PopupMenuButton<String>(
            onSelected: (String languageCode) {
              languageProvider.changeLanguage(languageCode);
              onChanged?.call();
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'en',
                child: Row(
                  children: [
                    Icon(
                      AppIcons.language,
                      color: AppColors.deepAquiferBlue,
                    ),
                    const SizedBox(width: 8),
                    const Text('English'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'hi',
                child: Row(
                  children: [
                    Icon(
                      AppIcons.language,
                      color: AppColors.deepAquiferBlue,
                    ),
                    const SizedBox(width: 8),
                    const Text('हिंदी'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Icon(
                    AppIcons.language,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    languageProvider.currentLanguage.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: PopupMenuButton<String>(
            onSelected: (String languageCode) {
              languageProvider.changeLanguage(languageCode);
              onChanged?.call();
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'en',
                child: Row(
                  children: [
                    Icon(
                      AppIcons.language,
                      color: AppColors.deepAquiferBlue,
                    ),
                    const SizedBox(width: 12),
                    const Text('English'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'hi',
                child: Row(
                  children: [
                    Icon(
                      AppIcons.language,
                      color: AppColors.deepAquiferBlue,
                    ),
                    const SizedBox(width: 12),
                    const Text('हिंदी'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.language,
                    color: AppColors.deepAquiferBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    languageProvider.currentLanguage == 'en'
                        ? 'English'
                        : 'हिंदी',
                    style: TextStyle(
                      color: AppColors.deepAquiferBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    PhosphorIconsDuotone.caretDown,
                    color: AppColors.deepAquiferBlue,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class LanguageSelectorDialog extends StatelessWidget {
  const LanguageSelectorDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final localizations = AppLocalizations.of(context);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      AppIcons.language,
                      color: AppColors.deepAquiferBlue,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      localizations!.get('language_selector'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildLanguageTile(
                  context: context,
                  languageName: 'English',
                  languageCode: 'en',
                  isSelected: languageProvider.currentLanguage == 'en',
                  onTap: () {
                    Navigator.pop(context);
                    languageProvider.changeLanguage('en');
                  },
                ),
                const SizedBox(height: 12),
                _buildLanguageTile(
                  context: context,
                  languageName: 'हिंदी',
                  languageCode: 'hi',
                  isSelected: languageProvider.currentLanguage == 'hi',
                  onTap: () {
                    Navigator.pop(context);
                    languageProvider.changeLanguage('hi');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageTile({
    required BuildContext context,
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
          color: isSelected ? AppColors.deepAquiferBlue.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.deepAquiferBlue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  AppIcons.language,
                  color: isSelected ? AppColors.deepAquiferBlue : AppColors.mediumGrey,
                ),
                const SizedBox(width: 12),
                Text(
                  languageName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.deepAquiferBlue : Colors.black,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Icon(
                AppIcons.checkmark,
                color: AppColors.deepAquiferBlue,
              ),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';

extension LocalizationExtension on BuildContext {
  String get(String key) {
    return AppLocalizations.of(this)!.get(key);
  }

  String getTranslated(String key) {
    return AppLocalizations.of(this)!.get(key);
  }

  bool get isEnglish {
    return Provider.of<LanguageProvider>(this, listen: false).isEnglish();
  }

  bool get isHindi {
    return Provider.of<LanguageProvider>(this, listen: false).isHindi();
  }

  String get currentLanguage {
    return Provider.of<LanguageProvider>(this, listen: false).currentLanguage;
  }

  Future<void> setLanguage(String languageCode) async {
    return Provider.of<LanguageProvider>(this, listen: false)
        .changeLanguage(languageCode);
  }
}


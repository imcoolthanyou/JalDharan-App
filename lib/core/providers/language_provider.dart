import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  String _currentLanguage = 'en';
  late SharedPreferences _prefs;

  String get currentLanguage => _currentLanguage;

  LanguageProvider() {
    _initPreferences();
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _currentLanguage = _prefs.getString('language') ?? 'en';
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    if (_currentLanguage != languageCode) {
      _currentLanguage = languageCode;
      await _prefs.setString('language', languageCode);
      notifyListeners();
    }
  }

  bool isEnglish() => _currentLanguage == 'en';

  bool isHindi() => _currentLanguage == 'hi';

  Locale getLocale() => Locale(_currentLanguage);
}

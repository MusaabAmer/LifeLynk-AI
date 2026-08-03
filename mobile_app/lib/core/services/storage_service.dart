import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String keyAuthToken = 'auth_token';
  static const String keyUserJson = 'user_json';
  static const String keyIsDarkMode = 'is_dark_mode';
  static const String keyHasCompletedOnboarding = 'has_completed_onboarding';
  static const String keyLanguage = 'app_language';

  static Future<bool> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(keyAuthToken, token);
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyAuthToken);
  }

  static Future<bool> removeAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(keyAuthToken);
  }

  static Future<bool> saveDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(keyIsDarkMode, isDark);
  }

  static Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyIsDarkMode) ?? false;
  }

  static Future<bool> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(keyHasCompletedOnboarding, true);
  }

  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyHasCompletedOnboarding) ?? false;
  }
}

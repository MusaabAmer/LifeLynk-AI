import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvService {
  EnvService._();

  static Future<void> init() async {
    await dotenv.load(fileName: '.env');

    debugPrint('==========================================');
    debugPrint('ENVIRONMENT CONFIGURATION');
    debugPrint('==========================================');
    debugPrint('SUPABASE_URL: $supabaseUrl');
    debugPrint(
      'SUPABASE_ANON_KEY loaded: ${supabaseAnonKey.isNotEmpty}',
    );
    debugPrint('API_BASE_URL: $apiBaseUrl');
    debugPrint('==========================================');
  }

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? '';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static String get apiBaseUrl {
    final configuredUrl =
        dotenv.env['API_BASE_URL']?.trim() ?? '';

    if (configuredUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not configured in .env',
      );
    }

    return configuredUrl;
  }
}
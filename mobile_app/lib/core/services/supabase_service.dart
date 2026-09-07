import 'package:supabase_flutter/supabase_flutter.dart';

import 'env_service.dart';

class SupabaseService {
  SupabaseService._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: EnvService.supabaseUrl,
      publishableKey: EnvService.supabaseAnonKey,
    );
  }

  static SupabaseClient get client =>
      Supabase.instance.client;
}

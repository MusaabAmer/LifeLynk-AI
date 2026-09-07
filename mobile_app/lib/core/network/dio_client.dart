import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/env_service.dart';

class DioClient {
  DioClient._();

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: EnvService.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',

        // Required to bypass ngrok's free-tier browser warning
        // for API requests.
        'ngrok-skip-browser-warning': 'true',
      },
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final session =
              Supabase.instance.client.auth.currentSession;

          final accessToken = session?.accessToken;

          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] =
                'Bearer $accessToken';
          }

          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // The server rejected the Supabase access token.
            // Do not silently retry because an expired/invalid
            // token must be refreshed by Supabase Auth.
          }

          handler.next(error);
        },
      ),
    );
}


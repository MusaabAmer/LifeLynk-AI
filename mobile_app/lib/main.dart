import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';

// Core
import 'core/providers/theme_provider.dart';
import 'core/services/env_service.dart';
import 'core/services/supabase_service.dart';

// Auth
import 'features/auth/presentation/providers/auth_provider.dart';

// Profile
import 'features/profile/providers/profile_provider.dart';

// Dashboard
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/dashboard/repositories/dashboard_repository.dart';

// Search
import 'features/search/providers/search_provider.dart';
import 'features/search/data/repositories/search_repository.dart';

// SOS
import 'features/sos/presentation/providers/sos_provider.dart';
import 'features/sos/data/repositories/sos_repository.dart';

// AI
import 'features/ai/data/repositories/ai_repository.dart';
import 'features/ai/presentation/providers/ai_provider.dart';

// Donor
import 'features/donor/providers/donor_provider.dart';

// Notifications
import 'features/notifications/presentation/providers/notification_provider.dart';
import 'features/notifications/data/repositories/notification_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // ENVIRONMENT
  // ============================================================

  await EnvService.init();

  // ============================================================
  // SUPABASE
  // ============================================================

  await SupabaseService.initialize();

  // ============================================================
  // APPLICATION
  // ============================================================

  runApp(
    MultiProvider(
      providers: [
        // ==========================================================
        // THEME
        // ==========================================================

        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),

        // ==========================================================
        // AUTHENTICATION
        // ==========================================================

        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),

        // ==========================================================
        // PROFILE
        // ==========================================================

        ChangeNotifierProvider(
          create: (_) => ProfileProvider(),
        ),

        // ==========================================================
        // DASHBOARD
        // ==========================================================

        ChangeNotifierProvider(
          create: (_) => DashboardProvider(
            repository: DashboardRepository(
              supabase: SupabaseService.client,
            ),
          ),
        ),

        // ==========================================================
        // SEARCH
        // ==========================================================

        ChangeNotifierProvider(
          create: (_) => SearchProvider(
            repository: SearchRepository(),
          ),
        ),

        // ==========================================================
        // SOS
        // ==========================================================

        ChangeNotifierProvider(
          create: (_) => SosProvider(
            repository: SosRepository(
              supabase: SupabaseService.client,
            ),
          ),
        ),

        // ==========================================================
        // AI
        // ==========================================================

        ChangeNotifierProvider(
          create: (_) => AiProvider(
            repository: AiRepository(),
          ),
        ),

        // ==========================================================
        // DONOR
        // ==========================================================

        ChangeNotifierProvider(
          create: (_) => DonorProvider(),
        ),

        // ==========================================================
        // NOTIFICATIONS
        // ==========================================================
        //
        // The provider is intentionally created eagerly.
        //
        // Lifecycle:
        //
        // App starts
        //      ↓
        // NotificationProvider created
        //      ↓
        // Supabase Auth listener registered
        //      ↓
        // Authenticated session detected
        //      ↓
        // loadNotifications()
        //      ↓
        // startRealtimeListener()
        //
        // Authentication changes:
        //
        // signedIn / initialSession
        //      ↓
        // initializeForCurrentUser()
        //
        // signedOut
        //      ↓
        // stopRealtimeListener()
        //      ↓
        // clearNotifications()
        //
        // The provider itself is responsible for notification
        // loading and realtime synchronization.
        // ==========================================================

        ChangeNotifierProvider<NotificationProvider>(
          lazy: false,
          create: (_) {
            final provider = NotificationProvider(
              repository: NotificationRepository(
                supabase: SupabaseService.client,
              ),
            );

            provider.startAuthListener();

            return provider;
          },
        ),
      ],

      // ============================================================
      // APP
      // ============================================================

      child: const LifeLynkApp(),
    ),
  );
}
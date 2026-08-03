import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/models/hospital_model.dart';
import '../../shared/models/reservation_model.dart';
import '../../shared/widgets/main_wrapper_scaffold.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/search/search_results_screen.dart';
import '../../features/hospital/hospital_screen.dart';
import '../../features/reservation/reservation_screen.dart';
import '../../features/reservation/reservation_confirmation_screen.dart';
import '../../features/reservation/reservation_history_screen.dart';
import '../../features/maps/maps_screen.dart';
import '../../features/emergency/emergency_sos_screen.dart';
import '../../features/notification/notification_list_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/change_password_screen.dart';
import '../../features/settings/settings_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRoutes {
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      
      // Main shell navigation routes (Bottom bar)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainWrapperScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/maps',
            builder: (context, state) => const NearbyMapsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const UserProfileScreen(),
          ),
        ],
      ),

      // Secondary feature screens
      GoRoute(
        path: '/search-results',
        builder: (context, state) => const SearchResultsScreen(),
      ),
      GoRoute(
        path: '/hospital-details',
        builder: (context, state) {
          final hospital = state.extra as HospitalModel;
          return HospitalDetailsScreen(hospital: hospital);
        },
      ),
      GoRoute(
        path: '/reserve',
        builder: (context, state) {
          final hospital = state.extra as HospitalModel;
          return BloodReservationScreen(hospital: hospital);
        },
      ),
      GoRoute(
        path: '/reservation-confirmation',
        builder: (context, state) {
          final reservation = state.extra as ReservationModel;
          return ReservationConfirmationScreen(reservation: reservation);
        },
      ),
      GoRoute(
        path: '/reservation-history',
        builder: (context, state) => const ReservationHistoryScreen(),
      ),
      GoRoute(
        path: '/emergency-sos',
        builder: (context, state) => const EmergencySosScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationListScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}

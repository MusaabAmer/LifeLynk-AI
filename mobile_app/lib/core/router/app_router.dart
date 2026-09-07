import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/router/routes.dart';

import '../../features/splash/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/screens/complete_profile_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/password_changed_screen.dart';

import '../../features/dashboard/presentation/screens/dashboard_screen.dart';

import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/search/presentation/screens/organization_detail_screen.dart';

import '../../features/donor/presentation/screens/become_donor_screen.dart';
import '../../features/donor/presentation/screens/donor_profile_screen.dart';
import '../../features/donor/presentation/screens/edit_donor_profile_screen.dart';
import '../../features/donor/presentation/screens/donation_history_screen.dart';

import '../../features/map/presentation/screens/emergency_full_map_screen.dart';
import '../../features/sos/data/models/nearby_resource_model.dart';
import '../../features/sos/presentation/screens/sos_screen.dart';

import '../../features/notifications/presentation/screens/notifications_screen.dart';

import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/personal_information_screen.dart';
import '../../features/settings/presentation/screens/change_password_screen.dart';
import '../../features/settings/presentation/screens/location_settings_screen.dart';

class AppRouter {
AppRouter._();

static final GoRouter router = GoRouter(
initialLocation: Routes.splash,


routes: [
  // ============================================================
  // AUTH / SPLASH / ONBOARDING
  // ============================================================

  GoRoute(
    path: Routes.splash,
    name: 'splash',
    builder: (context, state) {
      return const SplashScreen();
    },
  ),

  GoRoute(
    path: Routes.onboarding,
    name: 'onboarding',
    builder: (context, state) {
      return const OnboardingScreen();
    },
  ),

  GoRoute(
    path: Routes.login,
    name: 'login',
    builder: (context, state) {
      return const LoginScreen();
    },
  ),

  GoRoute(
    path: Routes.register,
    name: 'register',
    builder: (context, state) {
      return const RegisterScreen();
    },
  ),

  GoRoute(
    path: Routes.forgotPassword,
    name: 'forgot-password',
    builder: (context, state) {
      return const ForgotPasswordScreen();
    },
  ),

  GoRoute(
    path: Routes.verifyEmail,
    name: 'verify-email',
    builder: (context, state) {
      final extra = state.extra;

      String email = '';
      String fullName = '';

      if (extra is Map) {
        final emailValue = extra['email'];
        final fullNameValue = extra['fullName'];

        if (emailValue is String) {
          email = emailValue;
        }

        if (fullNameValue is String) {
          fullName = fullNameValue;
        }
      }

      return VerifyEmailScreen(
        email: email,
        fullName: fullName,
      );
    },
  ),

  GoRoute(
    path: Routes.completeProfile,
    name: 'complete-profile',
    builder: (context, state) {
      final extra = state.extra;

      String fullName = '';

      if (extra is Map) {
        final fullNameValue = extra['fullName'];

        if (fullNameValue is String) {
          fullName = fullNameValue;
        }
      } else if (extra is String) {
        fullName = extra;
      }

      return CompleteProfileScreen(
        fullName: fullName,
      );
    },
  ),

  GoRoute(
    path: Routes.resetPassword,
    name: 'reset-password',
    builder: (context, state) {
      return const ResetPasswordScreen();
    },
  ),

  GoRoute(
    path: Routes.passwordChanged,
    name: 'password-changed',
    builder: (context, state) {
      return const PasswordChangedScreen();
    },
  ),

  // ============================================================
  // DASHBOARD
  // ============================================================
  //
  // IMPORTANT:
  // DashboardScreen contains:
  //
  // Home
  // Search
  // SOS
  // AI
  // Profile
  //
  // AND DashboardBottomNav.
  //
  // Therefore /dashboard MUST open DashboardScreen,
  // NOT HomeScreen directly.
  // ============================================================

  GoRoute(
    path: Routes.dashboard,
    name: 'dashboard',
    builder: (context, state) {
      return const DashboardScreen();
    },
  ),

  // ============================================================
  // SEARCH BLOOD
  // ============================================================

  GoRoute(
    path: Routes.search,
    name: 'search',
    builder: (context, state) {
      return const SearchScreen();
    },
  ),

  // ============================================================
  // SOS
  // ============================================================

  GoRoute(
    path: Routes.sos,
    name: 'sos',
    builder: (context, state) {
      return const SosScreen();
    },
  ),

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  GoRoute(
    path: Routes.notifications,
    name: 'notifications',
    builder: (context, state) {
      return const NotificationsScreen();
    },
  ),

  // ============================================================
  // SETTINGS
  // ============================================================

  GoRoute(
    path: Routes.settings,
    name: 'settings',
    builder: (context, state) {
      return const SettingsScreen();
    },
  ),

  GoRoute(
    path: Routes.personalInformation,
    name: 'personal-information',
    builder: (context, state) {
      return const PersonalInformationScreen();
    },
  ),

  GoRoute(
    path: Routes.changePassword,
    name: 'change-password',
    builder: (context, state) {
      return const ChangePasswordScreen();
    },
  ),

  GoRoute(
    path: Routes.locationSettings,
    name: 'location-settings',
    builder: (context, state) {
      return const LocationSettingsScreen();
    },
  ),

  // ============================================================
  // ORGANIZATION
  // ============================================================

  GoRoute(
    path: Routes.organizationDetail,
    name: 'organization-detail',
    builder: (context, state) {
      final organizationId =
          state.pathParameters['id'] ?? '';

      return OrganizationDetailScreen(
        organizationId: organizationId,
      );
    },
  ),

  // ============================================================
  // DONOR
  // ============================================================

  GoRoute(
    path: Routes.becomeDonor,
    name: 'become-donor',
    builder: (context, state) {
      return const BecomeDonorScreen();
    },
  ),

  GoRoute(
    path: Routes.donorProfile,
    name: 'donor-profile',
    builder: (context, state) {
      return const DonorProfileScreen();
    },
  ),

  GoRoute(
    path: Routes.editDonorProfile,
    name: 'edit-donor-profile',
    builder: (context, state) {
      return const EditDonorProfileScreen();
    },
  ),

  GoRoute(
    path: Routes.donationHistory,
    name: 'donation-history',
    builder: (context, state) {
      return const DonationHistoryScreen();
    },
  ),

  // ============================================================
  // EMERGENCY FULL MAP
  // ============================================================

  GoRoute(
    path: Routes.emergencyMap,
    name: 'emergency-map',
    builder: (context, state) {
      final extra = state.extra;

      LatLng? initialLocation;
      List<NearbyResourceModel> resources = const [];

      if (extra is Map) {
        final location = extra['initialLocation'];

        if (location is LatLng) {
          initialLocation = location;
        }

        final resourceData = extra['resources'];

        if (resourceData is List<NearbyResourceModel>) {
          resources = List<NearbyResourceModel>.from(
            resourceData,
          );
        } else if (resourceData is List) {
          resources = resourceData
              .whereType<NearbyResourceModel>()
              .toList();
        }
      }

      return EmergencyFullMapScreen(
        initialLocation: initialLocation,
        resources: resources,
      );
    },
  ),
],


);
}

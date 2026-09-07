from pathlib import Path

BASE = Path.cwd()

folders = [

    # Flutter
    "lib",

    # Core
    "lib/core",
    "lib/core/constants",
    "lib/core/theme",
    "lib/core/router",
    "lib/core/network",
    "lib/core/storage",
    "lib/core/errors",
    "lib/core/utils",
    "lib/core/config",

    # Shared
    "lib/shared",
    "lib/shared/widgets",
    "lib/shared/models",
    "lib/shared/providers",
    "lib/shared/extensions",

    # Features
    "lib/features",

    # Splash
    "lib/features/splash",
    "lib/features/splash/presentation",

    # Onboarding
    "lib/features/onboarding",
    "lib/features/onboarding/presentation",

    # Authentication
    "lib/features/auth",
    "lib/features/auth/data",
    "lib/features/auth/domain",
    "lib/features/auth/presentation",

    # Dashboard
    "lib/features/dashboard",
    "lib/features/dashboard/data",
    "lib/features/dashboard/domain",
    "lib/features/dashboard/presentation",

    # Blood Search
    "lib/features/blood_search",
    "lib/features/blood_search/data",
    "lib/features/blood_search/domain",
    "lib/features/blood_search/presentation",

    # Organizations
    "lib/features/organizations",
    "lib/features/organizations/data",
    "lib/features/organizations/domain",
    "lib/features/organizations/presentation",

    # Inventory
    "lib/features/inventory",
    "lib/features/inventory/data",
    "lib/features/inventory/domain",
    "lib/features/inventory/presentation",

    # Requests
    "lib/features/requests",
    "lib/features/requests/data",
    "lib/features/requests/domain",
    "lib/features/requests/presentation",

    # Reservations
    "lib/features/reservations",
    "lib/features/reservations/data",
    "lib/features/reservations/domain",
    "lib/features/reservations/presentation",

    # Donations
    "lib/features/donations",
    "lib/features/donations/data",
    "lib/features/donations/domain",
    "lib/features/donations/presentation",

    # Emergency
    "lib/features/emergency",
    "lib/features/emergency/data",
    "lib/features/emergency/domain",
    "lib/features/emergency/presentation",

    # Notifications
    "lib/features/notifications",
    "lib/features/notifications/data",
    "lib/features/notifications/domain",
    "lib/features/notifications/presentation",

    # AI Assistant
    "lib/features/ai_assistant",
    "lib/features/ai_assistant/data",
    "lib/features/ai_assistant/domain",
    "lib/features/ai_assistant/presentation",

    # Maps
    "lib/features/maps",
    "lib/features/maps/data",
    "lib/features/maps/domain",
    "lib/features/maps/presentation",

    # Profile
    "lib/features/profile",
    "lib/features/profile/data",
    "lib/features/profile/domain",
    "lib/features/profile/presentation",

    # Settings
    "lib/features/settings",
    "lib/features/settings/presentation",

    # Help
    "lib/features/help",
    "lib/features/help/presentation",

    # Assets
    "assets",
    "assets/images",
    "assets/icons",
    "assets/illustrations",
    "assets/animations",
    "assets/fonts",

    # Test
    "test"
]

files = [

    # Main
    "lib/main.dart",

    # Config
    "lib/core/config/app_config.dart",

    # Constants
    "lib/core/constants/app_colors.dart",
    "lib/core/constants/app_strings.dart",
    "lib/core/constants/app_sizes.dart",

    # Theme
    "lib/core/theme/light_theme.dart",
    "lib/core/theme/dark_theme.dart",
    "lib/core/theme/theme.dart",

    # Router
    "lib/core/router/app_router.dart",
    "lib/core/router/routes.dart",

    # Network
    "lib/core/network/api_client.dart",
    "lib/core/network/api_endpoints.dart",

    # Storage
    "lib/core/storage/secure_storage.dart",
    "lib/core/storage/preferences.dart",

    # Utils
    "lib/core/utils/validators.dart",
    "lib/core/utils/date_formatter.dart",

    # Errors
    "lib/core/errors/exceptions.dart",
    "lib/core/errors/failures.dart",

    # Shared
    "lib/shared/widgets/custom_button.dart",
    "lib/shared/widgets/custom_textfield.dart",
    "lib/shared/widgets/loading_widget.dart",
    "lib/shared/widgets/error_widget.dart",

    "lib/shared/models/api_response.dart",

    "lib/shared/providers/providers.dart",

    "lib/shared/extensions/context_extension.dart",

    # Feature Entry Files

    "lib/features/splash/presentation/splash_screen.dart",

    "lib/features/onboarding/presentation/onboarding_screen.dart",

    "lib/features/auth/presentation/login_screen.dart",
    "lib/features/auth/presentation/register_screen.dart",
    "lib/features/auth/presentation/forgot_password_screen.dart",
    "lib/features/auth/presentation/otp_screen.dart",

    "lib/features/dashboard/presentation/dashboard_screen.dart",

    "lib/features/blood_search/presentation/search_screen.dart",

    "lib/features/organizations/presentation/organization_details_screen.dart",

    "lib/features/inventory/presentation/inventory_screen.dart",

    "lib/features/requests/presentation/request_screen.dart",

    "lib/features/reservations/presentation/reservation_screen.dart",

    "lib/features/donations/presentation/donation_history_screen.dart",

    "lib/features/emergency/presentation/emergency_screen.dart",

    "lib/features/notifications/presentation/notifications_screen.dart",

    "lib/features/ai_assistant/presentation/chat_screen.dart",

    "lib/features/maps/presentation/maps_screen.dart",

    "lib/features/profile/presentation/profile_screen.dart",
    "lib/features/profile/presentation/edit_profile_screen.dart",

    "lib/features/settings/presentation/settings_screen.dart",

    "lib/features/help/presentation/help_screen.dart",
]

for folder in folders:
    Path(folder).mkdir(parents=True, exist_ok=True)

for file in files:
    Path(file).touch(exist_ok=True)

print("=" * 60)
print(" LifeLynk AI Folder Structure Created Successfully ")
print("=" * 60)
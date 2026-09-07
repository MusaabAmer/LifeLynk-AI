class Routes {
Routes._();

// ============================================================
// AUTH
// ============================================================

static const String splash = "/";
static const String onboarding = "/onboarding";
static const String login = "/login";
static const String register = "/register";
static const String forgotPassword = "/forgot-password";
static const String verifyEmail = "/verify-email";
static const String completeProfile = "/complete-profile";
static const String resetPassword = "/reset-password";
static const String passwordChanged = "/password-changed";

// ============================================================
// DASHBOARD
// ============================================================

static const String dashboard = "/dashboard";

// ============================================================
// SEARCH
// ============================================================

static const String search = "/search";

// ============================================================
// SOS
// ============================================================

static const String sos = "/sos";

// ============================================================
// NOTIFICATIONS
// ============================================================

static const String notifications = "/notifications";

// ============================================================
// SETTINGS
// ============================================================

static const String settings = "/settings";
static const String personalInformation =
"/personal-information";
static const String changePassword =
"/change-password";
static const String locationSettings =
"/location-settings";

// ============================================================
// ORGANIZATION
// ============================================================

static const String organizationDetail =
"/organization-detail/:id";

// ============================================================
// DONOR
// ============================================================

static const String becomeDonor =
"/become-donor";

static const String donorProfile =
"/donor-profile";

static const String editDonorProfile =
"/edit-donor-profile";

static const String donationHistory =
"/donation-history";

// ============================================================
// EMERGENCY MAP
// ============================================================

static const String emergencyMap =
"/emergency-map";
}

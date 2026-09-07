import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/router/routes.dart';

import '../../../dashboard/providers/dashboard_provider.dart';
import '../../../donor/providers/donor_provider.dart';

class ProfileScreen extends StatefulWidget {
const ProfileScreen({
super.key,
});

@override
State<ProfileScreen> createState() =>
_ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
@override
void initState() {
super.initState();


WidgetsBinding.instance.addPostFrameCallback((_) {
  _loadData();
});


}

// ============================================================
// LOAD PROFILE + DONOR DATA
// ============================================================

Future<void> _loadData() async {
if (!mounted) return;


final dashboardProvider =
    context.read<DashboardProvider>();

final donorProvider =
    context.read<DonorProvider>();

final user =
    Supabase.instance.client.auth.currentUser;

if (user == null) {
  return;
}

// ----------------------------------------------------------
// Load dashboard/user information
// ----------------------------------------------------------

await dashboardProvider.loadDashboard(
  user.id,
);

if (!mounted) return;

// ----------------------------------------------------------
// Load donor information
// ----------------------------------------------------------

if (donorProvider.donorProfile == null &&
    !donorProvider.loading) {
  await donorProvider.loadDonorProfile();
}


}

// ============================================================
// REFRESH
// ============================================================

Future<void> _refreshData() async {
if (!mounted) return;


final dashboardProvider =
    context.read<DashboardProvider>();

final donorProvider =
    context.read<DonorProvider>();

final user =
    Supabase.instance.client.auth.currentUser;

if (user == null) return;

await Future.wait([
  dashboardProvider.loadDashboard(user.id),
  donorProvider.loadDonorProfile(),
]);


}

// ============================================================
// OPEN DONOR PROFILE
// ============================================================

Future<void> _openDonorProfile() async {
await context.push(
Routes.donorProfile,
);


if (!mounted) return;

await context
    .read<DonorProvider>()
    .loadDonorProfile();


}

// ============================================================
// BECOME DONOR
// ============================================================

Future<void> _openBecomeDonor() async {
await context.push(
Routes.becomeDonor,
);


if (!mounted) return;

await context
    .read<DonorProvider>()
    .loadDonorProfile();


}

// ============================================================
// DONATION HISTORY
// ============================================================

Future<void> _openDonationHistory() async {
await context.push(
Routes.donationHistory,
);
}

// ============================================================
// PERSONAL INFORMATION
// ============================================================

Future<void> _openPersonalInformation() async {
final dashboard =
context.read<DashboardProvider>();


await context.push(
  Routes.completeProfile,
  extra: {
    'fullName': dashboard.userName,
    'phoneNumber': null,
  },
);

if (!mounted) return;

final user =
    Supabase.instance.client.auth.currentUser;

if (user != null) {
  await context
      .read<DashboardProvider>()
      .loadDashboard(user.id);
}


}

// ============================================================
// BUILD
// ============================================================

@override
Widget build(BuildContext context) {
final colors =
Theme.of(context).colorScheme;


return Scaffold(
  backgroundColor: colors.surface,

  appBar: AppBar(
    title: const Text(
      'Profile',
      style: TextStyle(
        fontWeight: FontWeight.w800,
      ),
    ),
    centerTitle: true,
  ),

  body: Consumer2<
      DashboardProvider,
      DonorProvider>(
    builder: (
      context,
      dashboard,
      donorProvider,
      child,
    ) {
      final donor =
          donorProvider.donorProfile;

      final isDonor =
          donor != null;

      final isAvailable =
          donor?.availabilityStatus ==
              'available';

      final isEligible =
          donor?.eligibilityStatus ==
              'eligible';

      return RefreshIndicator(
        onRefresh: _refreshData,

        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            32,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,

            children: [
              // ==================================================
              // PROFILE HEADER
              // ==================================================

              _ProfileHeader(
                userName:
                    dashboard.userName,
                profileImage:
                    dashboard.profileImage,
                bloodGroup:
                    dashboard.bloodGroup,
                isLoading:
                    dashboard.isLoading &&
                        dashboard.userName.isEmpty,
              ),

              const SizedBox(
                height: 24,
              ),

              // ==================================================
              // DONOR SECTION
              // ==================================================

              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration:
                        BoxDecoration(
                      color: colors
                          .primaryContainer,
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .volunteer_activism_outlined,
                      color: colors
                          .onPrimaryContainer,
                      size: 21,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Blood Donation',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          isDonor
                              ? 'Manage your donor profile'
                              : 'Become a blood donor',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 14,
              ),

              // ==================================================
              // DONOR CARD
              // ==================================================

              if (donorProvider.loading &&
                  donor == null)
                const _DonorLoadingCard()
              else if (isDonor) ...[
                _DonorCard(
                  isAvailable:
                      isAvailable,
                  isEligible:
                      isEligible,
                  eligibilityStatus:
                      donor.eligibilityStatus,
                  onTap:
                      _openDonorProfile,
                ),

                const SizedBox(
                  height: 10,
                ),

                _ProfileActionCard(
                  icon:
                      Icons.history_rounded,
                  title:
                      'Donation History',
                  subtitle:
                      'View your previous blood donations',
                  onTap:
                      _openDonationHistory,
                ),
              ]
              else
                _BecomeDonorCard(
                  onTap:
                      _openBecomeDonor,
                ),

              const SizedBox(
                height: 28,
              ),

              // ==================================================
              // ACCOUNT
              // ==================================================

              const _SectionHeader(
                title: 'Account',
                icon:
                    Icons.manage_accounts_outlined,
              ),

              const SizedBox(
                height: 12,
              ),

              // --------------------------------------------------
              // Personal Information
              // --------------------------------------------------

              _ProfileActionCard(
                icon:
                    Icons.person_outline_rounded,
                title:
                    'Personal Information',
                subtitle:
                    'View and update your personal details',
                onTap:
                    _openPersonalInformation,
              ),

              const SizedBox(
                height: 10,
              ),

              // --------------------------------------------------
              // Notifications
              // --------------------------------------------------

              _ProfileActionCard(
                icon:
                    Icons.notifications_none_rounded,
                title:
                    'Notifications',
                subtitle:
                    'Manage your notification preferences',
                onTap: () {
                  context.push(
                    Routes.notifications,
                  );
                },
              ),

              const SizedBox(
                height: 10,
              ),

              // --------------------------------------------------
              // Settings
              // --------------------------------------------------

              _ProfileActionCard(
                icon:
                    Icons.settings_outlined,
                title:
                    'Settings',
                subtitle:
                    'Manage application settings',
                onTap: () {
                  context.push(
                    Routes.settings,
                  );
                },
              ),

              const SizedBox(
                height: 28,
              ),

              // ==================================================
              // SECURITY
              // ==================================================

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: colors
                        .onSurfaceVariant,
                  ),

                  const SizedBox(
                    width: 6,
                  ),

                  Flexible(
                    child: Text(
                      'Your information is securely protected.',
                      textAlign:
                          TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  ),
);


}
}

// ============================================================================
// PROFILE HEADER
// ============================================================================

class _ProfileHeader extends StatelessWidget {
final String userName;
final String profileImage;
final String bloodGroup;
final bool isLoading;

const _ProfileHeader({
required this.userName,
required this.profileImage,
required this.bloodGroup,
required this.isLoading,
});

@override
Widget build(BuildContext context) {
final theme =
Theme.of(context);


final colors =
    theme.colorScheme;

final displayName =
    userName.trim().isEmpty
        ? 'User'
        : userName;

final displayBloodGroup =
    bloodGroup.trim().isEmpty
        ? 'Blood group not set'
        : bloodGroup;

return Container(
  padding:
      const EdgeInsets.all(24),

  decoration:
      BoxDecoration(
    color:
        colors.primaryContainer,

    borderRadius:
        BorderRadius.circular(26),
  ),

  child: Column(
    children: [
      // ==========================================================
      // PROFILE IMAGE
      // ==========================================================

      Container(
        width: 92,
        height: 92,

        decoration:
            BoxDecoration(
          color:
              colors.primary,

          shape:
              BoxShape.circle,

          border: Border.all(
            color:
                colors.onPrimary
                    .withValues(
              alpha: 0.8,
            ),
            width: 3,
          ),
        ),

        child:
            profileImage.trim().isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      profileImage,
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,

                      errorBuilder:
                          (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return Icon(
                          Icons.person_rounded,
                          size: 48,
                          color:
                              colors.onPrimary,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.person_rounded,
                    size: 48,
                    color:
                        colors.onPrimary,
                  ),
      ),

      const SizedBox(
        height: 14,
      ),

      // ==========================================================
      // NAME
      // ==========================================================

      if (isLoading)
        const SizedBox(
          height: 26,
          width: 26,
          child:
              CircularProgressIndicator(
            strokeWidth: 2.5,
          ),
        )
      else
        Text(
          displayName,
          textAlign:
              TextAlign.center,

          style: theme
              .textTheme
              .headlineSmall
              ?.copyWith(
            fontWeight:
                FontWeight.w800,
            color:
                colors.onPrimaryContainer,
          ),
        ),

      const SizedBox(
        height: 7,
      ),

      // ==========================================================
      // BLOOD GROUP
      // ==========================================================

      Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),

        decoration:
            BoxDecoration(
          color:
              colors.surface
                  .withValues(
            alpha: 0.75,
          ),

          borderRadius:
              BorderRadius.circular(20),
        ),

        child: Row(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            Icon(
              Icons.bloodtype_rounded,
              size: 16,
              color:
                  colors.primary,
            ),

            const SizedBox(
              width: 6,
            ),

            Text(
              displayBloodGroup,
              style: TextStyle(
                color:
                    colors.primary,
                fontWeight:
                    FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(
        height: 12,
      ),

      Text(
        'Manage your personal and donor information.',
        textAlign:
            TextAlign.center,

        style: theme
            .textTheme
            .bodyMedium
            ?.copyWith(
          color:
              colors.onPrimaryContainer,
          height: 1.4,
        ),
      ),
    ],
  ),
);


}
}

// ============================================================================
// DONOR CARD
// ============================================================================

class _DonorCard extends StatelessWidget {
final bool isAvailable;
final bool isEligible;
final String eligibilityStatus;
final VoidCallback onTap;

const _DonorCard({
required this.isAvailable,
required this.isEligible,
required this.eligibilityStatus,
required this.onTap,
});

@override
Widget build(BuildContext context) {
final theme =
Theme.of(context);


final colors =
    theme.colorScheme;

return InkWell(
  onTap: onTap,

  borderRadius:
      BorderRadius.circular(22),

  child: Container(
    padding:
        const EdgeInsets.all(18),

    decoration:
        BoxDecoration(
      color:
          colors.surface,

      borderRadius:
          BorderRadius.circular(22),

      border:
          Border.all(
        color:
            colors.outlineVariant
                .withValues(
          alpha: 0.55,
        ),
      ),

      boxShadow: [
        BoxShadow(
          color:
              Colors.black.withValues(
            alpha: 0.025,
          ),

          blurRadius:
              16,

          offset:
              const Offset(0, 5),
        ),
      ],
    ),

    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,

          decoration:
              BoxDecoration(
            color:
                colors.primaryContainer,

            borderRadius:
                BorderRadius.circular(15),
          ),

          child: Icon(
            Icons
                .volunteer_activism_rounded,
            color:
                colors.onPrimaryContainer,
            size: 27,
          ),
        ),

        const SizedBox(
          width: 14,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const Text(
                'Donor Profile',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 16,
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                isAvailable
                    ? 'Available to donate'
                    : 'Currently unavailable',

                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color:
                      isAvailable
                          ? Colors.green
                          : colors
                              .onSurfaceVariant,

                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                isEligible
                    ? 'Eligible'
                    : _formatEligibility(
                        eligibilityStatus,
                      ),

                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color:
                      colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color:
              colors.onSurfaceVariant,
        ),
      ],
    ),
  ),
);


}

String _formatEligibility(
String status,
) {
switch (status.trim().toLowerCase()) {
case 'eligible':
return 'Eligible';


  case 'ineligible':
  case 'not_eligible':
    return 'Not eligible';

  case 'pending':
  default:
    return 'Eligibility pending';
}


}
}

// ============================================================================
// BECOME DONOR CARD
// ============================================================================

class _BecomeDonorCard extends StatelessWidget {
final VoidCallback onTap;

const _BecomeDonorCard({
required this.onTap,
});

@override
Widget build(BuildContext context) {
final colors =
Theme.of(context).colorScheme;


return InkWell(
  onTap:
      onTap,

  borderRadius:
      BorderRadius.circular(22),

  child: Container(
    padding:
        const EdgeInsets.all(18),

    decoration:
        BoxDecoration(
      color:
          colors.primaryContainer
              .withValues(
        alpha: 0.45,
      ),

      borderRadius:
          BorderRadius.circular(22),

      border:
          Border.all(
        color:
            colors.primary
                .withValues(
          alpha: 0.3,
        ),
      ),
    ),

    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,

          decoration:
              BoxDecoration(
            color:
                colors.primary,

            borderRadius:
                BorderRadius.circular(15),
          ),

          child: Icon(
            Icons
                .volunteer_activism_rounded,
            color:
                colors.onPrimary,
            size: 27,
          ),
        ),

        const SizedBox(
          width: 14,
        ),

        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                'Become a Blood Donor',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 16,
                ),
              ),

              SizedBox(
                height: 5,
              ),

              Text(
                'Help save lives by joining the donor program.',
                style: TextStyle(
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
        ),
      ],
    ),
  ),
);


}
}

// ============================================================================
// DONOR LOADING
// ============================================================================

class _DonorLoadingCard extends StatelessWidget {
const _DonorLoadingCard();

@override
Widget build(BuildContext context) {
final colors =
Theme.of(context)
.colorScheme;


return Container(
  height: 100,

  decoration:
      BoxDecoration(
    color:
        colors.surfaceContainerHighest
            .withValues(
      alpha: 0.45,
    ),

    borderRadius:
        BorderRadius.circular(22),
  ),

  child: const Center(
    child:
        CircularProgressIndicator(),
  ),
);


}
}

// ============================================================================
// SECTION HEADER
// ============================================================================

class _SectionHeader extends StatelessWidget {
final String title;
final IconData icon;

const _SectionHeader({
required this.title,
required this.icon,
});

@override
Widget build(BuildContext context) {
final theme =
Theme.of(context);


final colors =
    theme.colorScheme;

return Row(
  children: [
    Container(
      width: 40,
      height: 40,

      decoration:
          BoxDecoration(
        color:
            colors.primaryContainer,

        borderRadius:
            BorderRadius.circular(12),
      ),

      child: Icon(
        icon,
        size: 20,
        color:
            colors.onPrimaryContainer,
      ),
    ),

    const SizedBox(
      width: 12,
    ),

    Text(
      title,

      style: theme
          .textTheme
          .titleMedium
          ?.copyWith(
        fontWeight:
            FontWeight.w800,
      ),
    ),
  ],
);


}
}

// ============================================================================
// PROFILE ACTION CARD
// ============================================================================

class _ProfileActionCard extends StatelessWidget {
final IconData icon;
final String title;
final String subtitle;
final VoidCallback onTap;

const _ProfileActionCard({
required this.icon,
required this.title,
required this.subtitle,
required this.onTap,
});

@override
Widget build(BuildContext context) {
final colors =
Theme.of(context)
.colorScheme;


return InkWell(
  onTap:
      onTap,

  borderRadius:
      BorderRadius.circular(18),

  child: Container(
    padding:
        const EdgeInsets.all(14),

    decoration:
        BoxDecoration(
      color:
          colors.surface,

      borderRadius:
          BorderRadius.circular(18),

      border:
          Border.all(
        color:
            colors.outlineVariant
                .withValues(
          alpha: 0.5,
        ),
      ),
    ),

    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,

          decoration:
              BoxDecoration(
            color:
                colors.surfaceContainerHighest,

            borderRadius:
                BorderRadius.circular(13),
          ),

          child: Icon(
            icon,
            color:
                colors.primary,
          ),
        ),

        const SizedBox(
          width: 13,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color:
                      colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        Icon(
          Icons.arrow_forward_ios_rounded,
          size: 15,
          color:
              colors.onSurfaceVariant,
        ),
      ],
    ),
  ),
);

}
}

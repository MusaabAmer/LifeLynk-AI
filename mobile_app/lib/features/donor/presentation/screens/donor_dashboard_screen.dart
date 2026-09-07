import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/routes.dart';
import '../../providers/donor_provider.dart';

class DonorDashboardScreen extends StatefulWidget {
  const DonorDashboardScreen({super.key});

  @override
  State<DonorDashboardScreen> createState() =>
      _DonorDashboardScreenState();
}

class _DonorDashboardScreenState
    extends State<DonorDashboardScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DonorProvider>().loadDonorProfile();
    });
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refresh() async {
    if (!mounted) return;

    await context.read<DonorProvider>().loadDonorProfile();
  }

  // ============================================================
  // AVAILABILITY
  // ============================================================

  Future<void> changeAvailability(bool value) async {
    final provider = context.read<DonorProvider>();

    final success = await provider.setAvailability(value);

    if (!mounted) return;

    if (!success) {
      showMessage(
        provider.error ?? 'Unable to update availability.',
      );
    }
  }

  // ============================================================
  // LEAVE DONOR PROGRAM
  // ============================================================

  Future<void> leaveDonorProgram() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;

        return AlertDialog(
          title: const Text('Leave Donor Program?'),
          content: const Text(
            'Your donor profile will be deactivated. '
            'You can reactivate it later if needed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave Program'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final provider = context.read<DonorProvider>();

    final success = await provider.leaveDonorProgram();

    if (!mounted) return;

    if (success) {
      showMessage('You have left the donor program.');

      context.pop(true);
    } else {
      showMessage(
        provider.error ?? 'Unable to leave donor program.',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Donor Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<DonorProvider>(
        builder: (
          context,
          provider,
          child,
        ) {
          if (provider.loading &&
              provider.donorProfile == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null &&
              provider.donorProfile == null) {
            return _ErrorState(
              message: provider.error!,
              onRetry: refresh,
            );
          }

          final donor = provider.donorProfile;

          if (donor == null) {
            return _EmptyDonorState(
              onBecomeDonor: () async {
                await context.push(
                  Routes.becomeDonor,
                );

                if (!mounted) return;

                await refresh();
              },
            );
          }

          final availabilityStatus =
              donor.availabilityStatus.trim().toLowerCase();

          final eligibilityStatus =
              donor.eligibilityStatus.trim().toLowerCase();

          final available =
              availabilityStatus == 'available';

          final eligible =
              eligibilityStatus == 'eligible';

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                30,
              ),
              children: [
                // ==================================================
                // STATUS HEADER
                // ==================================================

                _DonorStatusCard(
                  availability: available,
                  eligibilityStatus: eligibilityStatus,
                ),

                const SizedBox(height: 20),

                // ==================================================
                // AVAILABILITY
                // ==================================================

                _SectionTitle(
                  icon: Icons.volunteer_activism_outlined,
                  title: 'Availability',
                  subtitle:
                      'Control whether patients can find you',
                ),

                const SizedBox(height: 12),

                _AvailabilityCard(
                  available: available,
                  loading: provider.loading,
                  onChanged: changeAvailability,
                ),

                const SizedBox(height: 24),

                // ==================================================
                // ELIGIBILITY
                // ==================================================

                _SectionTitle(
                  icon: Icons.verified_outlined,
                  title: 'Eligibility',
                  subtitle:
                      'Your donor eligibility status',
                ),

                const SizedBox(height: 12),

                _EligibilityCard(
                  status: eligibilityStatus,
                ),

                const SizedBox(height: 24),

                // ==================================================
                // DONOR INFORMATION
                // ==================================================

                _SectionTitle(
                  icon: Icons.person_outline_rounded,
                  title: 'Donor Information',
                  subtitle:
                      'Your registered donor details',
                ),

                const SizedBox(height: 12),

                _InformationCard(
                  dateOfBirth: donor.dateOfBirth,
                  weight: donor.weight,
                  lastDonationDate:
                      donor.lastDonationDate,
                ),

                const SizedBox(height: 24),

                // ==================================================
                // ELIGIBILITY NOTICE
                // ==================================================

                if (!eligible)
                  _EligibilityNotice(
                    status: eligibilityStatus,
                  ),

                if (!eligible)
                  const SizedBox(height: 24),

                // ==================================================
                // ACTIONS
                // ==================================================

                _SectionTitle(
                  icon: Icons.settings_outlined,
                  title: 'Donor Actions',
                  subtitle:
                      'Manage your donor profile',
                ),

                const SizedBox(height: 12),

                _ActionButton(
                  icon: Icons.edit_outlined,
                  title: 'Edit Donor Profile',
                  subtitle:
                      'Update your donor information',
                  onTap: () async {
                    await context.push(
                      Routes.editDonorProfile,
                    );

                    if (!mounted) return;

                    await refresh();
                  },
                ),

                const SizedBox(height: 10),

                _ActionButton(
                  icon: Icons.logout_rounded,
                  title: 'Leave Donor Program',
                  subtitle:
                      'Deactivate your donor profile',
                  destructive: true,
                  onTap: provider.loading
                      ? null
                      : leaveDonorProgram,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// DONOR STATUS CARD
// ============================================================================

class _DonorStatusCard extends StatelessWidget {
  final bool availability;
  final String eligibilityStatus;

  const _DonorStatusCard({
    required this.availability,
    required this.eligibilityStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final normalizedStatus =
        eligibilityStatus.trim().toLowerCase();

    final eligible = normalizedStatus == 'eligible';
    final ineligible = normalizedStatus == 'ineligible';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bloodtype_rounded,
              size: 40,
              color: colors.onPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Blood Donor',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            availability
                ? 'Available to donate'
                : 'Currently unavailable',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatusChip(
                  icon: availability
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                  label: availability
                      ? 'Available'
                      : 'Unavailable',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatusChip(
                  icon: eligible
                      ? Icons.verified_outlined
                      : ineligible
                          ? Icons.cancel_outlined
                          : Icons.pending_outlined,
                  label: _formatEligibility(
                    normalizedStatus,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatEligibility(String status) {
    switch (status.trim().toLowerCase()) {
      case 'eligible':
        return 'Eligible';

      case 'ineligible':
      case 'not_eligible':
        return 'Ineligible';

      case 'pending':
      default:
        return 'Pending';
    }
  }
}

// ============================================================================
// STATUS CHIP
// ============================================================================

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// AVAILABILITY CARD
// ============================================================================

class _AvailabilityCard extends StatelessWidget {
  final bool available;
  final bool loading;
  final ValueChanged<bool> onChanged;

  const _AvailabilityCard({
    required this.available,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: available
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              available
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
              color: available
                  ? colors.primary
                  : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  available
                      ? 'You are available'
                      : 'You are unavailable',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  available
                      ? 'Patients may find you when blood is needed.'
                      : 'You will not be shown as currently available.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          else
            Switch(
              value: available,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// ELIGIBILITY CARD
// ============================================================================

class _EligibilityCard extends StatelessWidget {
  final String status;

  const _EligibilityCard({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final normalizedStatus =
        status.trim().toLowerCase();

    final isEligible =
        normalizedStatus == 'eligible';

    final isIneligible =
        normalizedStatus == 'ineligible' ||
        normalizedStatus == 'not_eligible';

    final icon = isEligible
        ? Icons.verified_rounded
        : isIneligible
            ? Icons.cancel_outlined
            : Icons.pending_outlined;

    final title = isEligible
        ? 'Eligible to Donate'
        : isIneligible
            ? 'Not Currently Eligible'
            : 'Eligibility Pending';

    final description = isEligible
        ? 'You can be considered for blood donation matching.'
        : isIneligible
            ? 'You are currently not eligible for donation matching.'
            : 'Your donor eligibility is being reviewed.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 34,
            color: isIneligible
                ? colors.error
                : colors.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INFORMATION CARD
// ============================================================================

class _InformationCard extends StatelessWidget {
  final DateTime? dateOfBirth;
  final double? weight;
  final DateTime? lastDonationDate;

  const _InformationCard({
    required this.dateOfBirth,
    required this.weight,
    required this.lastDonationDate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.calendar_month_outlined,
            title: 'Date of Birth',
            value: _formatDate(dateOfBirth),
          ),
          const Divider(height: 24),
          _InfoRow(
            icon: Icons.monitor_weight_outlined,
            title: 'Weight',
            value: weight == null
                ? 'Not provided'
                : '${weight!.toStringAsFixed(1)} kg',
          ),
          const Divider(height: 24),
          _InfoRow(
            icon: Icons.bloodtype_outlined,
            title: 'Last Donation',
            value: lastDonationDate == null
                ? 'No previous donation'
                : _formatDate(lastDonationDate),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not provided';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ============================================================================
// INFO ROW
// ============================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          color: colors.primary,
          size: 22,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ELIGIBILITY NOTICE
// ============================================================================

class _EligibilityNotice extends StatelessWidget {
  final String status;

  const _EligibilityNotice({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final normalizedStatus =
        status.trim().toLowerCase();

    final isIneligible =
        normalizedStatus == 'ineligible' ||
        normalizedStatus == 'not_eligible';

    final message = isIneligible
        ? 'You are currently not eligible for donor matching. '
            'Please follow the guidance provided by the healthcare team.'
        : 'Your donor eligibility is still pending review. '
            'You will become available for matching once approved.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isIneligible
            ? colors.errorContainer.withValues(alpha: 0.55)
            : colors.surfaceContainerHighest
                .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            isIneligible
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            color: isIneligible
                ? colors.error
                : colors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION TITLE
// ============================================================================

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: colors.onPrimaryContainer,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ACTION BUTTON
// ============================================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final color = destructive
        ? colors.error
        : colors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: destructive
                    ? colors.error.withValues(alpha: 0.25)
                    : colors.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
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
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR STATE
// ============================================================================

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: colors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load donor profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyDonorState extends StatelessWidget {
  final VoidCallback onBecomeDonor;

  const _EmptyDonorState({
    required this.onBecomeDonor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.volunteer_activism_rounded,
                size: 42,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'You are not a donor yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join the LifeLynk donor network '
              'and help save lives.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onBecomeDonor,
              icon: const Icon(
                Icons.volunteer_activism_rounded,
              ),
              label: const Text(
                'Become a Donor',
              ),
            ),
          ],
        ),
      ),
    );
  }
}


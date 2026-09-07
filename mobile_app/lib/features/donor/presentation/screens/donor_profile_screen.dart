import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:lifelynk_ai/core/router/routes.dart';
import '../../providers/donor_provider.dart';

class DonorProfileScreen extends StatefulWidget {
  const DonorProfileScreen({
    super.key,
  });

  @override
  State<DonorProfileScreen> createState() => _DonorProfileScreenState();
}

class _DonorProfileScreenState extends State<DonorProfileScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;

    final provider = context.read<DonorProvider>();

    if (provider.donorProfile == null && !provider.loading) {
      await provider.loadDonorProfile();
    }
  }

  // ============================================================
  // EDIT PROFILE
  // ============================================================

  Future<void> _editProfile() async {
    final result = await context.push(
      Routes.editDonorProfile,
    );

    if (!mounted) return;

    if (result == true) {
      await context.read<DonorProvider>().loadDonorProfile();
    }
  }

  // ============================================================
  // LEAVE DONOR PROGRAM
  // ============================================================

  Future<void> _leaveDonorProgram() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text(
            'Leave Donor Program?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Your donor profile will be deactivated. '
            'You will no longer appear as an available donor '
            'until you become a donor again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Leave Program',
              ),
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'You have left the donor program.',
            ),
          ),
        );

      context.pop(true);
    } else {
      _showMessage(
        provider.error ?? 'Failed to leave donor program.',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
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
  // DATE FORMAT
  // ============================================================

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not provided';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // STATUS NORMALIZATION
  // ============================================================

  String _normalizeAvailability(String status) {
    final normalized = status.trim().toLowerCase();

    return normalized == 'unavailable'
        ? 'unavailable'
        : 'available';
  }

  String _normalizeEligibility(String status) {
    final normalized = status.trim().toLowerCase();

    switch (normalized) {
      case 'eligible':
        return 'eligible';

      case 'ineligible':
      case 'not_eligible':
      case 'not eligible':
        return 'ineligible';

      case 'pending':
      default:
        return 'pending';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text(
          'Donor Profile',
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
          // ------------------------------------------------------
          // LOADING
          // ------------------------------------------------------

          if (provider.loading && provider.donorProfile == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ------------------------------------------------------
          // EMPTY / ERROR
          // ------------------------------------------------------

          if (provider.donorProfile == null) {
            return _EmptyDonorProfile(
              error: provider.error,
              onRetry: () {
                provider.loadDonorProfile();
              },
              onBack: () {
                context.pop();
              },
            );
          }

          final donor = provider.donorProfile!;

          final availabilityStatus = _normalizeAvailability(
            donor.availabilityStatus,
          );

          final eligibilityStatus = _normalizeEligibility(
            donor.eligibilityStatus,
          );

          final isAvailable = availabilityStatus == 'available';
          final isEligible = eligibilityStatus == 'eligible';
          final isIneligible = eligibilityStatus == 'ineligible';

          final availabilityColor = isAvailable
              ? Colors.green
              : colors.onSurfaceVariant;

          final eligibilityColor = isEligible
              ? Colors.green
              : isIneligible
                  ? colors.error
                  : colors.primary;

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: provider.loadDonorProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==================================================
                    // HEADER
                    // ==================================================

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              color: colors.error,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bloodtype_rounded,
                              size: 46,
                              color: colors.onError,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Blood Donor',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Thank you for helping save lives.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onErrorContainer,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _StatusBadge(
                            icon: isAvailable
                                ? Icons.check_circle_rounded
                                : Icons.pause_circle_rounded,
                            text: isAvailable
                                ? 'Available to Donate'
                                : 'Currently Unavailable',
                            color: availabilityColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // DONOR STATUS
                    // ==================================================

                    const _SectionTitle(
                      icon: Icons.volunteer_activism_outlined,
                      title: 'Donor Status',
                    ),

                    const SizedBox(height: 12),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _StatusCard(
                            icon: Icons.favorite_rounded,
                            title: 'Availability',
                            value: isAvailable
                                ? 'Available'
                                : 'Unavailable',
                            iconColor: availabilityColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatusCard(
                            icon: Icons.verified_rounded,
                            title: 'Eligibility',
                            value: _formatEligibility(
                              eligibilityStatus,
                            ),
                            iconColor: eligibilityColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // DONOR INFORMATION
                    // ==================================================

                    const _SectionTitle(
                      icon: Icons.medical_information_outlined,
                      title: 'Donor Information',
                    ),

                    const SizedBox(height: 12),

                    _InformationCard(
                      children: [
                        _InformationRow(
                          icon: Icons.calendar_month_outlined,
                          title: 'Date of Birth',
                          value: _formatDate(
                            donor.dateOfBirth,
                          ),
                        ),
                        _InformationRow(
                          icon: Icons.monitor_weight_outlined,
                          title: 'Weight',
                          value: donor.weight != null
                              ? '${donor.weight!.toStringAsFixed(1)} kg'
                              : 'Not provided',
                        ),
                        _InformationRow(
                          icon: Icons.bloodtype_outlined,
                          title: 'Last Blood Donation',
                          value: donor.lastDonationDate != null
                              ? _formatDate(
                                  donor.lastDonationDate,
                                )
                              : 'Not donated before',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // ELIGIBILITY
                    // ==================================================

                    const _SectionTitle(
                      icon: Icons.verified_outlined,
                      title: 'Eligibility',
                    ),

                    const SizedBox(height: 12),

                    _EligibilityCard(
                      status: eligibilityStatus,
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // EDIT BUTTON
                    // ==================================================

                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: provider.loading
                            ? null
                            : _editProfile,
                        icon: const Icon(
                          Icons.edit_outlined,
                        ),
                        label: const Text(
                          'Edit Donor Profile',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==================================================
                    // LEAVE PROGRAM
                    // ==================================================

                    OutlinedButton.icon(
                      onPressed: provider.loading
                          ? null
                          : _leaveDonorProgram,
                      icon: Icon(
                        Icons.exit_to_app_outlined,
                        color: colors.error,
                      ),
                      label: Text(
                        'Leave Donor Program',
                        style: TextStyle(
                          color: colors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          52,
                        ),
                        side: BorderSide(
                          color: colors.error.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // SECURITY
                    // ==================================================

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Your donor information is securely protected.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // ELIGIBILITY FORMAT
  // ============================================================

  String _formatEligibility(String status) {
    switch (_normalizeEligibility(status)) {
      case 'eligible':
        return 'Eligible';

      case 'ineligible':
        return 'Not Eligible';

      case 'pending':
      default:
        return 'Pending';
    }
  }
}

// ============================================================================
// SECTION TITLE
// ============================================================================

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STATUS BADGE
// ============================================================================

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATUS CARD
// ============================================================================

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(
            alpha: 0.55,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 25,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
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
  final List<Widget> children;

  const _InformationCard({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(
            alpha: 0.55,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

// ============================================================================
// INFORMATION ROW
// ============================================================================

class _InformationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InformationRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
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

    late IconData icon;
    late String title;
    late String description;
    late Color color;

    switch (status.trim().toLowerCase()) {
      case 'eligible':
        icon = Icons.verified_rounded;
        title = 'Eligible to Donate';
        description =
            'Your donor profile is currently marked as eligible.';
        color = Colors.green;
        break;

      case 'ineligible':
      case 'not_eligible':
      case 'not eligible':
        icon = Icons.remove_circle_outline_rounded;
        title = 'Not Currently Eligible';
        description =
            'Your current eligibility status does not allow donation.';
        color = colors.error;
        break;

      case 'pending':
      default:
        icon = Icons.pending_actions_rounded;
        title = 'Eligibility Pending';
        description =
            'Your eligibility is being reviewed by the LifeLynk system.';
        color = colors.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.45,
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
// EMPTY DONOR PROFILE
// ============================================================================

class _EmptyDonorProfile extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _EmptyDonorProfile({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.volunteer_activism_outlined,
              size: 70,
              color: colors.primary,
            ),
            const SizedBox(height: 18),
            const Text(
              'Donor Profile Not Found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'We could not find your donor profile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onBack,
                  child: const Text('Go Back'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


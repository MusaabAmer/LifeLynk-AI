import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/donation_history_model.dart';
import '../../providers/donor_provider.dart';

class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({
    super.key,
  });

  @override
  State<DonationHistoryScreen> createState() =>
      _DonationHistoryScreenState();
}

class _DonationHistoryScreenState
    extends State<DonationHistoryScreen> {
  bool _realtimeStarted = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _load() async {
    if (!mounted) return;

    final provider = context.read<DonorProvider>();

    await provider.loadDonationHistory();

    if (!mounted) return;

    await provider.startDonationHistoryRealtime();

    if (!mounted) return;

    _realtimeStarted = true;
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    if (!mounted) return;

    await context
        .read<DonorProvider>()
        .loadDonationHistory();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    if (_realtimeStarted) {
      context
          .read<DonorProvider>()
          .stopDonationHistoryRealtime();
    }

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Donation History',
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
          if (provider.donationHistoryLoading &&
              provider.donationHistory.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.donationHistoryError != null &&
              provider.donationHistory.isEmpty) {
            return _ErrorView(
              message: provider.donationHistoryError!,
              onRetry: _load,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _SummaryCard(
                    donationCount:
                        provider.donationHistory.length,
                    totalUnits:
                        provider.totalDonationUnits,
                    verifiedCount:
                        provider.verifiedDonationCount,
                  ),
                ),
                if (provider.donationHistory.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyHistory(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      32,
                    ),
                    sliver: SliverList(
                      delegate:
                          SliverChildBuilderDelegate(
                        (context, index) {
                          final donation =
                              provider.donationHistory[
                                  index];

                          return Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: _DonationCard(
                              donation: donation,
                            ),
                          );
                        },
                        childCount:
                            provider
                                .donationHistory
                                .length,
                      ),
                    ),
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
// SUMMARY CARD
// ============================================================================

class _SummaryCard extends StatelessWidget {
  final int donationCount;
  final int totalUnits;
  final int verifiedCount;

  const _SummaryCard({
    required this.donationCount,
    required this.totalUnits,
    required this.verifiedCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.volunteer_activism_rounded,
                size: 34,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your Donation Impact',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    value: donationCount.toString(),
                    label: 'Donations',
                    icon: Icons.bloodtype_rounded,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    value: totalUnits.toString(),
                    label: 'Units',
                    icon: Icons.water_drop_rounded,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    value: verifiedCount.toString(),
                    label: 'Verified',
                    icon: Icons.verified_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SUMMARY ITEM
// ============================================================================

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _SummaryItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(
          icon,
          size: 22,
          color: colors.primary,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ============================================================================
// DONATION CARD
// ============================================================================

class _DonationCard extends StatelessWidget {
  final DonationHistoryModel donation;

  const _DonationCard({
    required this.donation,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final date = _formatDate(
      donation.donationDate,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ================================================================
            // ORGANIZATION + DATE + VERIFICATION
            // ================================================================

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primaryContainer,
                  ),
                  child: Icon(
                    Icons.bloodtype_rounded,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        donation.displayOrganization,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
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
                const SizedBox(width: 8),
                _VerificationBadge(
                  verified: donation.verified,
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // ================================================================
            // DONATION DETAILS
            // ================================================================

            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.bloodtype_rounded,
                    label: 'Blood group',
                    value:
                        donation.displayBloodGroup,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.water_drop_rounded,
                    label: 'Units',
                    value:
                        donation.unitsDonated
                            .toString(),
                  ),
                ),
              ],
            ),

            // ================================================================
            // NOTES
            // ================================================================

            if (donation.notes != null &&
                donation.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors
                      .surfaceContainerHighest
                      .withValues(alpha: 0.55),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        donation.notes!.trim(),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              height: 1.45,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day =
        local.day.toString().padLeft(2, '0');
    final month =
        local.month.toString().padLeft(2, '0');

    return '$day/$month/${local.year}';
  }
}

// ============================================================================
// INFO ITEM
// ============================================================================

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: colors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(
                      color:
                          colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? '—' : value,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
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
// VERIFICATION BADGE
// ============================================================================

class _VerificationBadge extends StatelessWidget {
  final bool verified;

  const _VerificationBadge({
    required this.verified,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final backgroundColor = verified
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;

    final foregroundColor = verified
        ? colors.primary
        : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified
                ? Icons.verified_rounded
                : Icons.pending_rounded,
            size: 14,
            color: foregroundColor,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verified' : 'Pending',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EMPTY HISTORY
// ============================================================================

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bloodtype_outlined,
                size: 44,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No donation history yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your verified donations will appear here automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
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
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: colors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load donation history',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
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

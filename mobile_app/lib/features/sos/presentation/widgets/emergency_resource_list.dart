import 'package:flutter/material.dart';

import '../../data/models/nearby_resource_model.dart';
import 'nearby_resource_card.dart';

class EmergencyResourceList extends StatelessWidget {
  // ============================================================
  // DATA
  // ============================================================

  /// Realtime resources supplied by the parent/provider.
  ///
  /// This widget does not fetch or mutate resource data.
  final List<NearbyResourceModel> resources;

  /// Initial/loading state.
  final bool loading;

  // ============================================================
  // CALLBACKS
  // ============================================================

  /// Refresh/retry callback.
  final VoidCallback? onRefresh;

  /// Opens the selected resource details.
  final ValueChanged<NearbyResourceModel>? onResourceTap;

  /// Starts navigation to the selected resource.
  final ValueChanged<NearbyResourceModel>? onNavigate;

  const EmergencyResourceList({
    super.key,
    required this.resources,
    this.loading = false,
    this.onRefresh,
    this.onResourceTap,
    this.onNavigate,
  });

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // INITIAL LOADING
    // ==========================================================
    //
    // Show the full loading state only when no previous data is
    // available.
    //
    // If realtime data already exists, keep displaying it while
    // a refresh is running.
    //

    if (loading && resources.isEmpty) {
      return const _ResourceLoadingState();
    }

    // ==========================================================
    // EMPTY STATE
    // ==========================================================

    if (resources.isEmpty) {
      return _EmptyResourceState(
        onRefresh: onRefresh,
      );
    }

    // ==========================================================
    // GROUP RESOURCES
    // ==========================================================

    final hospitals = resources
        .where(
          (resource) =>
              resource.type ==
              NearbyResourceType.hospital,
        )
        .toList();

    final bloodBanks = resources
        .where(
          (resource) =>
              resource.type ==
              NearbyResourceType.bloodBank,
        )
        .toList();

    final donors = resources
        .where(
          (resource) =>
              resource.type ==
              NearbyResourceType.donor,
        )
        .toList();

    // ==========================================================
    // BUILD
    // ==========================================================

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ========================================================
        // HEADER
        // ========================================================

        _ResourceListHeader(
          resourceCount: resources.length,
          loading: loading,
          onRefresh: onRefresh,
        ),

        const SizedBox(height: 4),

        Text(
          'Real-time emergency resources near your current GPS location.',
          style:
              Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 18),

        // ========================================================
        // HOSPITALS
        // ========================================================

        if (hospitals.isNotEmpty) ...[
          _ResourceSectionTitle(
            icon: Icons.local_hospital_rounded,
            title: 'Hospitals',
            count: hospitals.length,
          ),

          const SizedBox(height: 10),

          ...hospitals.map(
            (resource) => Padding(
              key: ValueKey(
                'hospital_${resource.id}',
              ),
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: NearbyResourceCard(
                resource: resource,
                onTap: onResourceTap == null
                    ? null
                    : () => onResourceTap!(
                          resource,
                        ),
                onNavigate: onNavigate == null
                    ? null
                    : () => onNavigate!(
                          resource,
                        ),
              ),
            ),
          ),

          const SizedBox(height: 10),
        ],

        // ========================================================
        // BLOOD BANKS
        // ========================================================

        if (bloodBanks.isNotEmpty) ...[
          _ResourceSectionTitle(
            icon: Icons.bloodtype_rounded,
            title: 'Blood Banks',
            count: bloodBanks.length,
          ),

          const SizedBox(height: 10),

          ...bloodBanks.map(
            (resource) => Padding(
              key: ValueKey(
                'blood_bank_${resource.id}',
              ),
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: NearbyResourceCard(
                resource: resource,
                onTap: onResourceTap == null
                    ? null
                    : () => onResourceTap!(
                          resource,
                        ),
                onNavigate: onNavigate == null
                    ? null
                    : () => onNavigate!(
                          resource,
                        ),
              ),
            ),
          ),

          const SizedBox(height: 10),
        ],

        // ========================================================
        // POTENTIAL DONORS
        // ========================================================

        if (donors.isNotEmpty) ...[
          _ResourceSectionTitle(
            icon: Icons.volunteer_activism_rounded,
            title: 'Potential Donors',
            count: donors.length,
          ),

          const SizedBox(height: 10),

          ...donors.map(
            (resource) => Padding(
              key: ValueKey(
                'donor_${resource.id}',
              ),
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: NearbyResourceCard(
                resource: resource,
                onTap: onResourceTap == null
                    ? null
                    : () => onResourceTap!(
                          resource,
                        ),
                onNavigate: onNavigate == null
                    ? null
                    : () => onNavigate!(
                          resource,
                        ),
              ),
            ),
          ),
        ],

        // ========================================================
        // REALTIME UPDATE INDICATOR
        // ========================================================
        //
        // When resources already exist, don't replace the list
        // with a loading spinner. Instead show a small update
        // indicator at the bottom.
        //

        if (loading) ...[
          const SizedBox(height: 6),

          const _RealtimeUpdatingIndicator(),
        ],
      ],
    );
  }
}

// ============================================================================
// RESOURCE LIST HEADER
// ============================================================================

class _ResourceListHeader extends StatelessWidget {
  final int resourceCount;
  final bool loading;
  final VoidCallback? onRefresh;

  const _ResourceListHeader({
    required this.resourceCount,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Nearby Resources',
            style:
                theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        // --------------------------------------------------------
        // RESOURCE COUNT
        // --------------------------------------------------------

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$resourceCount',
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        // --------------------------------------------------------
        // REFRESH
        // --------------------------------------------------------

        if (onRefresh != null)
          IconButton(
            tooltip: 'Refresh resources',
            onPressed: loading ? null : onRefresh,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                  ),
          ),
      ],
    );
  }
}

// ============================================================================
// SECTION TITLE
// ============================================================================

class _ResourceSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _ResourceSectionTitle({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 19,
            color: colors.onPrimaryContainer,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            title,
            style:
                theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// REALTIME UPDATING INDICATOR
// ============================================================================

class _RealtimeUpdatingIndicator extends StatelessWidget {
  const _RealtimeUpdatingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        top: 4,
        bottom: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: colors.primary,
            ),
          ),

          const SizedBox(width: 8),

          Text(
            'Updating nearby resources...',
            style:
                theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LOADING STATE
// ============================================================================

class _ResourceLoadingState extends StatelessWidget {
  const _ResourceLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 40,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color:
            colors.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'Finding nearby resources...',
            style:
                theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Searching hospitals, blood banks, and available donors near your location.',
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyResourceState extends StatelessWidget {
  final VoidCallback? onRefresh;

  const _EmptyResourceState({
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              colors.outlineVariant.withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // ------------------------------------------------------
          // ICON
          // ------------------------------------------------------

          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_searching_rounded,
              size: 30,
              color: colors.onPrimaryContainer,
            ),
          ),

          const SizedBox(height: 15),

          // ------------------------------------------------------
          // TITLE
          // ------------------------------------------------------

          Text(
            'No nearby resources found',
            textAlign: TextAlign.center,
            style:
                theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          // ------------------------------------------------------
          // DESCRIPTION
          // ------------------------------------------------------

          Text(
            'We could not find hospitals, blood banks, or available donors within the emergency search area.',
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),

          // ------------------------------------------------------
          // RETRY
          // ------------------------------------------------------

          if (onRefresh != null) ...[
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
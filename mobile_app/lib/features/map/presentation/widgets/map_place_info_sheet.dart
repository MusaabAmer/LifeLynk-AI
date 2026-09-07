import 'package:flutter/material.dart';

import '../../data/models/map_place_model.dart';

/// Bottom sheet displaying details about a selected map place.
///
/// This widget is presentation-only:
/// - It does not query OpenStreetMap places.
/// - It does not calculate routes.
/// - It does not perform navigation.
/// - It does not modify SOS data.
///
/// Actions are provided through callbacks so [MapScreen] remains
/// responsible for coordinating map behavior.
class MapPlaceInfoSheet extends StatelessWidget {
  // ============================================================
  // DATA
  // ============================================================

  final MapPlaceModel place;

  // ============================================================
  // ACTIONS
  // ============================================================

  /// Called when the user wants to calculate/show a route.
  final VoidCallback? onDirections;

  /// Called when the user wants to call the place.
  final VoidCallback? onCall;

  /// Called when the user wants to open external navigation.
  final VoidCallback? onNavigate;

  /// Called when the sheet should be closed.
  final VoidCallback? onClose;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  const MapPlaceInfoSheet({
    super.key,
    required this.place,
    this.onDirections,
    this.onCall,
    this.onNavigate,
    this.onClose,
  });

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(28),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==================================================
                // SHEET HANDLE
                // ==================================================

                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          colors.onSurfaceVariant.withAlpha(80),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ==================================================
                // HEADER
                // ==================================================

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlaceIcon(
                      place: place,
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),

                          const SizedBox(height: 5),

                          _CategoryLabel(
                            place: place,
                          ),
                        ],
                      ),
                    ),

                    if (onClose != null)
                      IconButton(
                        tooltip: 'Close',
                        onPressed: onClose,
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 18),

                // ==================================================
                // RATING / OPEN STATUS
                // ==================================================

                Row(
                  children: [
                    if (place.hasRating)
                      _RatingBadge(
                        place: place,
                      ),

                    if (place.hasRating &&
                        place.isOpen != null)
                      const SizedBox(width: 10),

                    if (place.isOpen != null)
                      _OpenStatusBadge(
                        place: place,
                      ),
                  ],
                ),

                // ==================================================
                // ADDRESS
                // ==================================================

                if (place.hasAddress) ...[
                  const SizedBox(height: 17),

                  _InfoTile(
                    icon: Icons.location_on_outlined,
                    title: 'Address',
                    value: place.address!.trim(),
                  ),
                ],

                // ==================================================
                // PHONE
                // ==================================================

                if (place.hasPhone) ...[
                  const SizedBox(height: 12),

                  _InfoTile(
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    value: place.phone!.trim(),
                  ),
                ],

                const SizedBox(height: 20),

                // ==================================================
                // ACTIONS
                // ==================================================

                _buildActions(
                  context,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Widget _buildActions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final hasPrimaryAction =
        onDirections != null ||
        onNavigate != null;

    if (!hasPrimaryAction && onCall == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (onDirections != null)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onDirections,
              icon: const Icon(
                Icons.directions_rounded,
              ),
              label: const Text(
                'Get Directions',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

        if (onNavigate != null &&
            onDirections == null)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onNavigate,
              icon: const Icon(
                Icons.navigation_rounded,
              ),
              label: const Text(
                'Start Navigation',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

        if (onCall != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: onCall,
              icon: Icon(
                Icons.call_rounded,
                color: colors.primary,
              ),
              label: const Text(
                'Call',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ================================================================
// PLACE ICON
// ================================================================

class _PlaceIcon extends StatelessWidget {
  final MapPlaceModel place;

  const _PlaceIcon({
    required this.place,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        _iconForPlace(place),
        size: 28,
        color: colors.onPrimaryContainer,
      ),
    );
  }

  IconData _iconForPlace(MapPlaceModel place) {
    final category =
        place.category?.toLowerCase().trim() ?? '';

    if (category.contains('hospital')) {
      return Icons.local_hospital_rounded;
    }

    if (category.contains('blood')) {
      return Icons.bloodtype_rounded;
    }

    if (category.contains('clinic')) {
      return Icons.medical_services_rounded;
    }

    if (category.contains('pharmacy')) {
      return Icons.local_pharmacy_rounded;
    }

    if (category.contains('donor')) {
      return Icons.volunteer_activism_rounded;
    }

    return Icons.place_rounded;
  }
}

// ================================================================
// CATEGORY LABEL
// ================================================================

class _CategoryLabel extends StatelessWidget {
  final MapPlaceModel place;

  const _CategoryLabel({
    required this.place,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final category = place.category?.trim();

    if (category == null || category.isEmpty) {
      return Text(
        'Medical resource',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Text(
      category,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ================================================================
// RATING BADGE
// ================================================================

class _RatingBadge extends StatelessWidget {
  final MapPlaceModel place;

  const _RatingBadge({
    required this.place,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 18,
            color: Colors.amber.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            place.ratingLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            place.reviewsLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// OPEN STATUS BADGE
// ================================================================

class _OpenStatusBadge extends StatelessWidget {
  final MapPlaceModel place;

  const _OpenStatusBadge({
    required this.place,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isOpen = place.isOpen == true;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: isOpen
            ? Colors.green.withAlpha(18)
            : colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            size: 16,
            color: isOpen
                ? Colors.green.shade700
                : colors.onErrorContainer,
          ),
          const SizedBox(width: 5),
          Text(
            place.openStatusLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isOpen
                  ? Colors.green.shade700
                  : colors.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// INFO TILE
// ================================================================

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: colors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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

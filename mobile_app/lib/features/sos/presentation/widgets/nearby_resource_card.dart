import 'package:flutter/material.dart';

import '../../data/models/nearby_resource_model.dart';
import '../../services/emergency_navigation_service.dart';

/// ============================================================================
/// NEARBY RESOURCE CARD
/// ============================================================================
///
/// Displays a nearby emergency resource:
///
/// 1. Hospital
/// 2. Blood Bank
/// 3. Potential Donor
///
/// The card is UI-only and does not access Supabase directly.
///
/// Navigation:
/// - [onNavigate] can be supplied by the parent.
/// - Otherwise [EmergencyNavigationService.navigateToResource] is used.
///
class NearbyResourceCard extends StatelessWidget {
  // ==========================================================================
  // PROPERTIES
  // ==========================================================================

  final NearbyResourceModel resource;

  /// Called when the user wants to view resource details.
  final VoidCallback? onTap;

  /// Optional custom navigation callback.
  ///
  /// If not supplied, the card uses
  /// [EmergencyNavigationService.navigateToResource].
  final VoidCallback? onNavigate;

  const NearbyResourceCard({
    super.key,
    required this.resource,
    this.onTap,
    this.onNavigate,
  });

  // ==========================================================================
  // RESOURCE TYPE LABEL
  // ==========================================================================

  String get _typeLabel {
    switch (resource.type) {
      case NearbyResourceType.hospital:
        return 'Hospital';

      case NearbyResourceType.bloodBank:
        return 'Blood Bank';

      case NearbyResourceType.donor:
        return 'Potential Donor';
    }
  }

  // ==========================================================================
  // RESOURCE ICON
  // ==========================================================================

  IconData get _typeIcon {
    switch (resource.type) {
      case NearbyResourceType.hospital:
        return Icons.local_hospital_rounded;

      case NearbyResourceType.bloodBank:
        return Icons.bloodtype_rounded;

      case NearbyResourceType.donor:
        return Icons.volunteer_activism_rounded;
    }
  }

  // ==========================================================================
  // RESOURCE COLOR
  // ==========================================================================

  Color _typeColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    switch (resource.type) {
      case NearbyResourceType.hospital:
        return colors.primary;

      case NearbyResourceType.bloodBank:
        return Colors.red;

      case NearbyResourceType.donor:
        return Colors.deepPurple;
    }
  }

  // ==========================================================================
  // BLOOD GROUP CHECK
  // ==========================================================================

  bool get _hasBloodGroup {
    final value = resource.bloodGroup;

    return value != null && value.trim().isNotEmpty;
  }

  // ==========================================================================
  // ADDRESS CHECK
  // ==========================================================================

  bool get _hasAddress {
    final value = resource.address;

    return value != null && value.trim().isNotEmpty;
  }

  // ==========================================================================
  // CONTACT CHECK
  // ==========================================================================

  bool get _hasEmergencyContact {
    final value = resource.emergencyContact;

    return value != null && value.trim().isNotEmpty;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final typeColor = _typeColor(context);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
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
              // =================================================================
              // HEADER
              // =================================================================

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ----------------------------------------------------------------
                  // RESOURCE ICON
                  // ----------------------------------------------------------------

                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _typeIcon,
                      color: typeColor,
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ----------------------------------------------------------------
                  // NAME + TYPE
                  // ----------------------------------------------------------------

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _typeLabel,
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ----------------------------------------------------------------
                  // DISTANCE BADGE
                  // ----------------------------------------------------------------

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(
                        alpha: 0.08,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.near_me_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDistance(
                            resource.distanceKm,
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // =================================================================
              // DISTANCE
              // =================================================================

              _ResourceInfoRow(
                icon: Icons.location_on_outlined,
                text:
                    '${_formatDistance(resource.distanceKm)} away',
              ),

              // =================================================================
              // ADDRESS
              // =================================================================

              if (_hasAddress) ...[
                const SizedBox(height: 8),
                _ResourceInfoRow(
                  icon: Icons.place_outlined,
                  text: resource.address!.trim(),
                ),
              ],

              // =================================================================
              // BLOOD GROUP
              // =================================================================

              if (_hasBloodGroup) ...[
                const SizedBox(height: 8),
                _ResourceInfoRow(
                  icon: Icons.bloodtype_outlined,
                  text:
                      'Blood group: ${resource.bloodGroup!.trim()}',
                ),
              ],

              // =================================================================
              // TRAVEL TIME
              // =================================================================

              if (resource.estimatedTravelTimeMinutes != null) ...[
                const SizedBox(height: 8),
                _ResourceInfoRow(
                  icon: Icons.directions_car_outlined,
                  text: resource.travelTimeLabel,
                ),
              ],

              // =================================================================
              // BLOOD AVAILABILITY
              // =================================================================
              //
              // Hospitals / Blood Banks:
              //     X units available
              //
              // Donors:
              //     Available donor
              //
              // =================================================================

              if (resource.isDonor) ...[
                const SizedBox(height: 10),
                const _DonorAvailability(),
              ] else if (resource.availableUnits != null) ...[
                const SizedBox(height: 10),
                _BloodAvailability(
                  units: resource.availableUnits!,
                ),
              ],

              // =================================================================
              // EMERGENCY CONTACT
              // =================================================================

              if (_hasEmergencyContact) ...[
                const SizedBox(height: 8),
                _ResourceInfoRow(
                  icon: Icons.phone_outlined,
                  text: resource.emergencyContact!.trim(),
                ),
              ],

              const SizedBox(height: 16),

              // =================================================================
              // ACTION BUTTONS
              // =================================================================

              Row(
                children: [
                  // ----------------------------------------------------------------
                  // VIEW DETAILS
                  // ----------------------------------------------------------------

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'View Details',
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ----------------------------------------------------------------
                  // NAVIGATE
                  // ----------------------------------------------------------------

                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          onNavigate ??
                          () => _navigateToResource(
                            context,
                          ),
                      icon: const Icon(
                        Icons.navigation_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Navigate',
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
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  Future<void> _navigateToResource(
    BuildContext context,
  ) async {
    final success =
        await EmergencyNavigationService.navigateToResource(
      resource,
    );

    if (!success || !context.mounted) {
      return;
    }

    // Navigation succeeded.
    //
    // Do not show a success snackbar because the user
    
  }

  // ==========================================================================
  // DISTANCE FORMAT
  // ==========================================================================

  String _formatDistance(
    double distanceKm,
  ) {
    // --------------------------------------------------------------------------
    // Invalid distance
    // --------------------------------------------------------------------------

    if (distanceKm < 0) {
      return 'Unknown';
    }

    // --------------------------------------------------------------------------
    // Less than 1 km
    // --------------------------------------------------------------------------

    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).round();

      if (meters <= 0) {
        return '<1 m';
      }

      return '$meters m';
    }

    // --------------------------------------------------------------------------
    // Kilometers
    // --------------------------------------------------------------------------

    return '${distanceKm.toStringAsFixed(1)} km';
  }
}

// ============================================================================
// RESOURCE INFO ROW
// ============================================================================

class _ResourceInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ResourceInfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: colors.onSurfaceVariant,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// BLOOD AVAILABILITY
// ============================================================================

class _BloodAvailability extends StatelessWidget {
  final int units;

  const _BloodAvailability({
    required this.units,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final available = units > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: available
            ? Colors.green.withValues(
                alpha: 0.08,
              )
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            available
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            size: 18,
            color: available
                ? Colors.green
                : colors.onSurfaceVariant,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              available
                  ? '$units units available'
                  : 'Currently unavailable',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: available
                    ? Colors.green
                    : colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DONOR AVAILABILITY
// ============================================================================

class _DonorAvailability extends StatelessWidget {
  const _DonorAvailability();

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.green.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: Colors.green,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              'Available donor',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
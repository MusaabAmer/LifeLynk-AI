import 'package:flutter/material.dart';

import '../../data/models/route_model.dart';

/// Displays information about the currently selected route.
///
/// Responsibilities:
/// - Show route distance.
/// - Show estimated travel time.
/// - Show optional route summary.
/// - Show optional route warning.
/// - Allow the user to start navigation.
///
/// This widget does not calculate routes and does not call
/// OpenStreetMap APIs. Route data is supplied by [RouteModel].
class RouteInfoCard extends StatelessWidget {
  // ============================================================
  // DATA
  // ============================================================

  final RouteModel route;

  // ============================================================
  // ACTIONS
  // ============================================================

  /// Called when the user wants to start external navigation.
  final VoidCallback? onNavigate;

  /// Called when the user wants to close/remove the route.
  final VoidCallback? onClose;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  const RouteInfoCard({
    super.key,
    required this.route,
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
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HANDLE
              // ==================================================

              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withAlpha(80),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // HEADER
              // ==================================================

              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.directions_rounded,
                      color: colors.onPrimaryContainer,
                      size: 25,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route to destination',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Recommended driving route',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (onClose != null)
                    IconButton(
                      tooltip: 'Close route',
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 18),

              // ==================================================
              // ROUTE STATISTICS
              // ==================================================

              Row(
                children: [
                  Expanded(
                    child: _RouteStat(
                      icon: Icons.straighten_rounded,
                      label: 'Distance',
                      value: _distanceLabel,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _RouteStat(
                      icon: Icons.access_time_rounded,
                      label: 'Travel time',
                      value: _durationLabel,
                    ),
                  ),
                ],
              ),

              // ==================================================
              // ROUTE SUMMARY
              // ==================================================

              if (route.hasSummary) ...[
                const SizedBox(height: 14),
                _InfoRow(
                  icon: Icons.alt_route_rounded,
                  text: route.summary!.trim(),
                ),
              ],

              // ==================================================
              // ROUTE WARNING
              // ==================================================

              if (route.hasWarning) ...[
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: colors.onErrorContainer,
                      ),

                      const SizedBox(width: 9),

                      Expanded(
                        child: Text(
                          route.warning!.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onErrorContainer,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ==================================================
              // NAVIGATION BUTTON
              // ==================================================

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
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  /// Uses the formatting provided by [RouteModel].
  String get _distanceLabel {
    return route.distanceLabel;
  }

  // ============================================================
  // DURATION
  // ============================================================

  /// Uses the formatting provided by [RouteModel].
  String get _durationLabel {
    return route.durationLabel;
  }
}

// ================================================================
// ROUTE STAT
// ================================================================

class _RouteStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RouteStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
            color: colors.primary,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
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

// ================================================================
// INFO ROW
// ================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: colors.primary,
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

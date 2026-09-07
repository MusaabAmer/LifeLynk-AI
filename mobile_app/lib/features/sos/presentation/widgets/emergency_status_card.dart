import 'package:flutter/material.dart';

import '../../data/models/emergency_sos_model.dart';

class EmergencyStatusCard extends StatelessWidget {
  final EmergencySosModel sos;
  final VoidCallback? onCancel;
  final VoidCallback? onComplete;
  final bool cancelling;
  final bool completing;

  const EmergencyStatusCard({
    super.key,
    required this.sos,
    this.onCancel,
    this.onComplete,
    this.cancelling = false,
    this.completing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final status = _statusInfo(
      context,
      sos.status,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: status.color.withValues(
            alpha: 0.35,
          ),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ========================================================
          // HEADER
          // ========================================================

          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: status.backgroundColor,
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: Icon(
                  status.icon,
                  color: status.color,
                  size: 26,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency SOS',
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      status.title,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: status.color,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              _StatusBadge(
                label: status.label,
                color: status.color,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ========================================================
          // STATUS MESSAGE
          // ========================================================

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors
                  .surfaceContainerHighest
                  .withValues(
                alpha: 0.45,
              ),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                  color:
                      colors.primary,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    status.message,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      height: 1.45,
                      color: colors
                          .onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ========================================================
          // EMERGENCY DETAILS
          // ========================================================

          _DetailRow(
            icon: Icons.bloodtype_rounded,
            title: 'Blood Group',
            value: sos.bloodGroupId,
          ),

          const SizedBox(height: 10),

          _DetailRow(
            icon: Icons.medical_services_outlined,
            title: 'Units Required',
            value:
                '${sos.unitsRequired} ${sos.unitsRequired == 1 ? 'unit' : 'units'}',
          ),

          const SizedBox(height: 10),

          _DetailRow(
            icon: Icons.priority_high_rounded,
            title: 'Urgency',
            value:
                _formatUrgency(
              sos.urgencyLevel,
            ),
          ),

          const SizedBox(height: 10),

          _DetailRow(
            icon: Icons.location_on_outlined,
            title: 'Emergency Location',
            value: sos.hasLocation
                ? 'Current GPS location captured'
                : 'Location unavailable',
          ),

          if (sos.hasLocation) ...[
            const SizedBox(height: 10),

            _DetailRow(
              icon:
                  Icons.gps_fixed_rounded,
              title: 'GPS Accuracy',
              value:
                  sos.gpsAccuracy != null
                      ? '${sos.gpsAccuracy!.toStringAsFixed(1)} m'
                      : 'Not available',
            ),
          ],

          if (sos.createdAt != null) ...[
            const SizedBox(height: 10),

            _DetailRow(
              icon:
                  Icons.access_time_rounded,
              title: 'Activated',
              value:
                  _formatDateTime(
                sos.createdAt!,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ========================================================
          // ACTIONS
          // ========================================================

          if (sos.isActive) ...[
            Row(
              children: [
                if (onCancel != null)
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          cancelling ||
                                  completing
                              ? null
                              : onCancel,
                      icon: cancelling
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .close_rounded,
                              size: 18,
                            ),
                      label: Text(
                        cancelling
                            ? 'Cancelling...'
                            : 'Cancel SOS',
                      ),
                    ),
                  ),

                if (onComplete != null &&
                    onCancel != null)
                  const SizedBox(width: 10),

                if (onComplete != null)
                  Expanded(
                    child:
                        FilledButton.icon(
                      onPressed:
                          cancelling ||
                                  completing
                              ? null
                              : onComplete,
                      icon: completing
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .check_circle_outline_rounded,
                              size: 18,
                            ),
                      label: Text(
                        completing
                            ? 'Completing...'
                            : 'Complete',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==============================================================
  // STATUS INFORMATION
  // ==============================================================

  _SosStatusInfo _statusInfo(
    BuildContext context,
    String status,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    switch (status) {
      case 'pending':
        return _SosStatusInfo(
          title:
              'Emergency request is active',
          label: 'ACTIVE',
          message:
              'Your SOS has been created. Nearby emergency resources can now be searched using your current GPS location.',
          icon:
              Icons.warning_amber_rounded,
          color: colors.primary,
          backgroundColor:
              colors.primaryContainer,
        );

      case 'matched':
        return _SosStatusInfo(
          title:
              'Emergency resources matched',
          label: 'MATCHED',
          message:
              'Potential emergency resources have been matched to your request. Keep your location available while assistance is coordinated.',
          icon:
              Icons.people_alt_outlined,
          color: Colors.orange.shade800,
          backgroundColor:
              Colors.orange.shade50,
        );

      case 'in_progress':
        return _SosStatusInfo(
          title:
              'Emergency assistance in progress',
          label: 'IN PROGRESS',
          message:
              'Your emergency request is currently being handled. Continue following instructions from qualified emergency or healthcare personnel.',
          icon:
              Icons.emergency_rounded,
          color: Colors.red.shade700,
          backgroundColor:
              Colors.red.shade50,
        );

      case 'completed':
        return _SosStatusInfo(
          title:
              'Emergency request completed',
          label: 'COMPLETED',
          message:
              'This emergency request has been marked as completed.',
          icon:
              Icons.check_circle_rounded,
          color: Colors.green.shade700,
          backgroundColor:
              Colors.green.shade50,
        );

      case 'cancelled':
        return _SosStatusInfo(
          title:
              'Emergency request cancelled',
          label: 'CANCELLED',
          message:
              'This emergency request has been cancelled.',
          icon:
              Icons.cancel_rounded,
          color:
              colors.onSurfaceVariant,
          backgroundColor:
              colors.surfaceContainerHighest,
        );

      default:
        return _SosStatusInfo(
          title:
              'Emergency request',
          label:
              status.toUpperCase(),
          message:
              'Emergency request status: $status.',
          icon:
              Icons.info_outline_rounded,
          color:
              colors.primary,
          backgroundColor:
              colors.primaryContainer,
        );
    }
  }

  // ==============================================================
  // FORMAT URGENCY
  // ==============================================================

  String _formatUrgency(
    String value,
  ) {
    switch (value) {
      case 'critical':
        return 'Critical';

      case 'high':
        return 'High';

      case 'medium':
        return 'Medium';

      case 'low':
        return 'Low';

      default:
        if (value.trim().isEmpty) {
          return 'Unknown';
        }

        return value
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) {
                if (word.isEmpty) {
                  return word;
                }

                return word[0].toUpperCase() +
                    word.substring(1);
              },
            )
            .join(' ');
    }
  }

  // ==============================================================
  // FORMAT DATE
  // ==============================================================

  String _formatDateTime(
    DateTime dateTime,
  ) {
    final local =
        dateTime.toLocal();

    final hour =
        local.hour == 0
            ? 12
            : local.hour > 12
                ? local.hour - 12
                : local.hour;

    final minute =
        local.minute
            .toString()
            .padLeft(
          2,
          '0',
        );

    final period =
        local.hour >= 12
            ? 'PM'
            : 'AM';

    return '${local.day}/${local.month}/${local.year} '
        '$hour:$minute $period';
  }
}

// ============================================================================
// STATUS BADGE
// ============================================================================

class _StatusBadge
    extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight:
              FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ============================================================================
// DETAIL ROW
// ============================================================================

class _DetailRow
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: colors.primary,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
              color: colors
                  .onSurfaceVariant,
            ),
          ),
        ),

        const SizedBox(width: 10),

        Flexible(
          child: Text(
            value,
            textAlign:
                TextAlign.end,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STATUS DATA
// ============================================================================

class _SosStatusInfo {
  final String title;
  final String label;
  final String message;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _SosStatusInfo({
    required this.title,
    required this.label,
    required this.message,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}
import 'package:flutter/material.dart';

import '../../data/models/emergency_sos_model.dart';

class SosHistoryCard extends StatelessWidget {
  final EmergencySosModel sos;

  /// Resolved blood group name/code.
  /// Example: O+, A+, B+, AB+
  final String bloodGroupName;

  /// Resolved city name.
  final String cityName;

  /// Resolved province name.
  final String? provinceName;

  /// Human-readable address resolved from the SOS GPS coordinates.
  ///
  /// GPS coordinates remain the source of truth. This value is only a
  /// presentation-friendly reverse-geocoded address.
  final String? locationAddress;

  /// Called when the user requests deletion of a terminal SOS record.
  final VoidCallback? onDelete;

  const SosHistoryCard({
    super.key,
    required this.sos,
    required this.bloodGroupName,
    required this.cityName,
    this.provinceName,
    this.locationAddress,
    this.onDelete,
  });

  // ============================================================
  // STATUS LABEL
  // ============================================================

  String get _statusLabel {
    switch (sos.status.trim().toLowerCase()) {
      case 'pending':
        return 'Pending';

      case 'matched':
        return 'Matched';

      case 'in_progress':
        return 'In Progress';

      case 'completed':
        return 'Completed';

      case 'cancelled':
        return 'Cancelled';

      default:
        return sos.status
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
    }
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData get _statusIcon {
    switch (sos.status.trim().toLowerCase()) {
      case 'pending':
        return Icons.schedule_rounded;

      case 'matched':
        return Icons.person_search_rounded;

      case 'in_progress':
        return Icons.emergency_rounded;

      case 'completed':
        return Icons.check_circle_rounded;

      case 'cancelled':
        return Icons.cancel_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    switch (sos.status.trim().toLowerCase()) {
      case 'pending':
        return colors.tertiary;

      case 'matched':
        return colors.primary;

      case 'in_progress':
        return colors.error;

      case 'completed':
        return Colors.green;

      case 'cancelled':
        return colors.onSurfaceVariant;

      default:
        return colors.primary;
    }
  }

  // ============================================================
  // URGENCY LABEL
  // ============================================================

  String get _urgencyLabel {
    switch (sos.urgencyLevel.trim().toLowerCase()) {
      case 'critical':
        return 'Critical';

      case 'high':
        return 'High';

      case 'medium':
        return 'Medium';

      case 'low':
        return 'Low';

      default:
        return sos.urgencyLevel;
    }
  }

  // ============================================================
  // LOCATION LABEL
  // ============================================================

  String get _locationLabel {
    final address = locationAddress?.trim();

    if (address != null && address.isNotEmpty) {
      return address;
    }

    final city = cityName.trim();
    final province = provinceName?.trim();

    if (city.isNotEmpty &&
        province != null &&
        province.isNotEmpty) {
      return '$city, $province';
    }

    if (city.isNotEmpty) {
      return city;
    }

    if (sos.hasLocation) {
      return 'GPS captured';
    }

    return 'Unavailable';
  }

  // ============================================================
  // TERMINAL STATUS
  // ============================================================

  bool get _canDelete {
    final status = sos.status.trim().toLowerCase();

    return status == 'completed' ||
        status == 'cancelled';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final statusColor = _statusColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(
            alpha: 0.55,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======================================================
          // HEADER
          // ======================================================

          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _statusIcon,
                  size: 21,
                  color: statusColor,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency SOS',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDateTime(sos.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // STATUS
              // ==================================================

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // ======================================================
          // DETAILS ROW 1
          // ======================================================

          Row(
            children: [
              Expanded(
                child: _HistoryInfo(
                  icon: Icons.bloodtype_rounded,
                  label: 'Blood Group',
                  value: bloodGroupName.trim().isNotEmpty
                      ? bloodGroupName.trim()
                      : 'Unknown',
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _HistoryInfo(
                  icon: Icons.water_drop_rounded,
                  label: 'Units',
                  value: '${sos.unitsRequired}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ======================================================
          // DETAILS ROW 2
          // ======================================================

          Row(
            children: [
              Expanded(
                child: _HistoryInfo(
                  icon: Icons.priority_high_rounded,
                  label: 'Urgency',
                  value: _urgencyLabel,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _HistoryInfo(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: _locationLabel,
                ),
              ),
            ],
          ),

          // ======================================================
          // GPS INFORMATION
          // ======================================================

          if (sos.hasLocation) ...[
            const SizedBox(height: 10),

            _HistoryInfo(
              icon: Icons.gps_fixed_rounded,
              label: 'GPS Location',
              value: _gpsLabel,
            ),
          ],

          // ======================================================
          // DESCRIPTION
          // ======================================================

          if (sos.description != null &&
              sos.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(
                  alpha: 0.40,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: 17,
                    color: colors.onSurfaceVariant,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      sos.description!.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ======================================================
          // DELETE HISTORY
          // ======================================================

          if (onDelete != null && _canDelete) ...[
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                ),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // GPS LABEL
  // ============================================================

  String get _gpsLabel {
    if (!sos.hasLocation) {
      return 'Unavailable';
    }

    final lat = sos.latitude!;
    final lng = sos.longitude!;

    if (sos.hasGpsAccuracy) {
      return '${lat.toStringAsFixed(5)}, '
          '${lng.toStringAsFixed(5)} '
          '• ±${sos.gpsAccuracy!.round()} m';
    }

    return '${lat.toStringAsFixed(5)}, '
        '${lng.toStringAsFixed(5)}';
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Date unavailable';
    }

    final local = dateTime.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year • $hour:$minute $period';
  }
}

// ============================================================================
// HISTORY INFO
// ============================================================================

class _HistoryInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HistoryInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(
          alpha: 0.40,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: colors.primary,
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
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
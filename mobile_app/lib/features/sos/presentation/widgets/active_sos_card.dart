import 'package:flutter/material.dart';

import '../../data/models/emergency_sos_model.dart';

class ActiveSosCard extends StatelessWidget {
  final EmergencySosModel sos;
  final bool loading;
  final VoidCallback? onCancel;
  final VoidCallback? onComplete;

  const ActiveSosCard({
    super.key,
    required this.sos,
    this.loading = false,
    this.onCancel,
    this.onComplete,
  });

  Color _statusColor(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    switch (sos.status) {
      case 'matched':
        return Colors.orange;

      case 'in_progress':
        return colors.primary;

      case 'pending':
      default:
        return colors.error;
    }
  }

  String _statusLabel() {
    switch (sos.status) {
      case 'matched':
        return 'MATCHED';

      case 'in_progress':
        return 'IN PROGRESS';

      case 'pending':
      default:
        return 'ACTIVE';
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final statusColor =
        _statusColor(context);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: statusColor
              .withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.06),
            blurRadius: 14,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color: statusColor
                      .withValues(
                    alpha: 0.12,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child: Icon(
                  Icons
                      .emergency_rounded,
                  color:
                      statusColor,
                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency SOS Active',
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
                      'Help is being coordinated.',
                      style: theme
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

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  color: statusColor
                      .withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  _statusLabel(),
                  style: TextStyle(
                    color:
                        statusColor,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _InfoRow(
            icon:
                Icons.bloodtype_rounded,
            title: 'Blood units',
            value:
                '${sos.unitsRequired} unit',
          ),

          const SizedBox(height: 10),

          _InfoRow(
            icon:
                Icons.priority_high_rounded,
            title: 'Urgency',
            value:
                sos.urgencyLevel
                    .toUpperCase(),
          ),

          const SizedBox(height: 10),

          _InfoRow(
            icon:
                Icons.location_on_rounded,
            title: 'Location',
            value: sos.hasLocation
                ? 'GPS location captured'
                : 'Location unavailable',
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      loading
                          ? null
                          : onCancel,
                  style:
                      OutlinedButton.styleFrom(
                    minimumSize:
                        const Size(
                      0,
                      46,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Cancel SOS',
                        ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: FilledButton(
                  onPressed:
                      loading
                          ? null
                          : onComplete,
                  style:
                      FilledButton.styleFrom(
                    minimumSize:
                        const Size(
                      0,
                      46,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Mark Complete',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
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
      children: [
        Icon(
          icon,
          size: 18,
          color: colors.primary,
        ),

        const SizedBox(width: 9),

        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
            color:
                colors.onSurfaceVariant,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        const Spacer(),

        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
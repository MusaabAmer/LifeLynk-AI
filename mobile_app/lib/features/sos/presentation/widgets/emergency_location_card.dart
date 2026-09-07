import 'package:flutter/material.dart';

class EmergencyLocationCard extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double? accuracy;

  const EmergencyLocationCard({
    super.key,
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              colors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_rounded,
            color:
                colors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency Location',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${latitude.toStringAsFixed(6)}, '
                  '${longitude.toStringAsFixed(6)}',
                ),
                if (accuracy != null)
                  Text(
                    'Accuracy: ${accuracy!.toStringAsFixed(1)} m',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

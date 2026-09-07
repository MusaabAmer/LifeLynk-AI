import 'package:flutter/material.dart';

class OrganizationActions extends StatelessWidget {
  final VoidCallback? onReserve;
  final VoidCallback? onEmergencyRequest;
  final VoidCallback? onCall;
  final VoidCallback? onDirections;
  final VoidCallback? onShare;

  final bool canReserve;
  final bool canCall;
  final bool canOpenDirections;

  final bool isReserving;
  final bool isEmergencyRequesting;

  const OrganizationActions({
    super.key,
    this.onReserve,
    this.onEmergencyRequest,
    this.onCall,
    this.onDirections,
    this.onShare,
    this.canReserve = true,
    this.canCall = true,
    this.canOpenDirections = false,
    this.isReserving = false,
    this.isEmergencyRequesting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed:
              canReserve && !isReserving
                  ? onReserve
                  : null,
          icon: isReserving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.bloodtype,
                ),
          label: Text(
            isReserving
                ? 'Submitting Reservation...'
                : 'Reserve Blood',
          ),
        ),

        const SizedBox(height: 10),

        OutlinedButton.icon(
          onPressed:
              isEmergencyRequesting
                  ? null
                  : onEmergencyRequest,
          icon: isEmergencyRequesting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.emergency,
                ),
          label: Text(
            isEmergencyRequesting
                ? 'Sending Emergency Request...'
                : 'Emergency Request',
          ),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    canCall ? onCall : null,
                icon:
                    const Icon(Icons.call),
                label:
                    const Text('Call'),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    canOpenDirections
                        ? onDirections
                        : null,
                icon: const Icon(
                  Icons.directions,
                ),
                label: const Text(
                  'Directions',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        OutlinedButton.icon(
          onPressed: onShare,
          icon:
              const Icon(Icons.share),
          label: const Text(
            'Share Organization',
          ),
        ),
      ],
    );
  }
}
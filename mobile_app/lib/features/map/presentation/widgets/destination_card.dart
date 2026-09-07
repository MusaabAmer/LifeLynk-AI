import 'package:flutter/material.dart';

import '../../data/models/map_place_model.dart';

/// Displays the currently selected destination.
///
/// Presentation-only:
/// - does not navigate
/// - does not calculate routes
/// - does not access SOS
class DestinationCard extends StatelessWidget {
  final MapPlaceModel place;

  final VoidCallback? onDirections;

  final VoidCallback? onCall;

  final VoidCallback? onClose;

  final bool isLoadingRoute;

  const DestinationCard({
    super.key,
    required this.place,
    this.onDirections,
    this.onCall,
    this.onClose,
    this.isLoadingRoute = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      elevation: 8,
      shadowColor:
          Colors.black.withAlpha(45),
      borderRadius:
          BorderRadius.circular(22),
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          14,
          16,
          16,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ----------------------------------------------------
            // HEADER
            // ----------------------------------------------------

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _PlaceIcon(
                  place: place,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w800,
                            ),
                      ),

                      if (place.category != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          place.category!,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color:
                                    colors.primary,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Close',
                    visualDensity:
                        VisualDensity.compact,
                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                  ),
              ],
            ),

            // ----------------------------------------------------
            // ADDRESS
            // ----------------------------------------------------

            if (place.hasAddress) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color:
                        colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      place.address!,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color:
                                colors
                                    .onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ],

            // ----------------------------------------------------
            // RATING / OPEN STATUS
            // ----------------------------------------------------

            if (place.hasRating ||
                place.isOpen != null)
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 10,
                ),
                child: Row(
                  children: [
                    if (place.hasRating) ...[
                      Icon(
                        Icons.star_rounded,
                        size: 18,
                        color:
                            Colors.amber.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        place.ratingLabel,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${place.reviewsLabel})',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color:
                                  colors
                                      .onSurfaceVariant,
                            ),
                      ),
                    ],

                    if (place.hasRating &&
                        place.isOpen != null)
                      const SizedBox(width: 14),

                    if (place.isOpen != null)
                      _OpenStatus(
                        isOpen:
                            place.isOpen!,
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // ----------------------------------------------------
            // ACTIONS
            // ----------------------------------------------------

            Row(
              children: [
                Expanded(
                  child:
                      FilledButton.icon(
                    onPressed:
                        isLoadingRoute
                            ? null
                            : onDirections,
                    icon: isLoadingRoute
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons
                                .directions_rounded,
                            size: 19,
                          ),
                    label: Text(
                      isLoadingRoute
                          ? 'Finding route...'
                          : 'Directions',
                    ),
                    style:
                        FilledButton.styleFrom(
                      minimumSize:
                          const Size(
                        0,
                        48,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                  ),
                ),

                if (place.hasPhone &&
                    onCall != null) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    height: 48,
                    child:
                        OutlinedButton(
                      onPressed: onCall,
                      style:
                          OutlinedButton.styleFrom(
                        padding:
                            EdgeInsets.zero,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                      child:
                          const Icon(
                        Icons.call_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// PLACE ICON
// ================================================================

class _PlaceIcon
    extends StatelessWidget {
  final MapPlaceModel place;

  const _PlaceIcon({
    required this.place,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    IconData icon;

    switch (
        place.category?.toLowerCase()) {
      case 'hospital':
        icon =
            Icons.local_hospital_rounded;
        break;

      case 'blood bank':
        icon =
            Icons.bloodtype_rounded;
        break;

      case 'pharmacy':
        icon =
            Icons.local_pharmacy_rounded;
        break;

      case 'doctor':
        icon =
            Icons.medical_services_rounded;
        break;

      case 'healthcare':
        icon =
            Icons.health_and_safety_rounded;
        break;

      default:
        icon =
            Icons.location_on_rounded;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color:
            colors.primaryContainer,
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Icon(
        icon,
        color:
            colors.onPrimaryContainer,
        size: 25,
      ),
    );
  }
}

// ================================================================
// OPEN STATUS
// ================================================================

class _OpenStatus
    extends StatelessWidget {
  final bool isOpen;

  const _OpenStatus({
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOpen
        ? Colors.green.shade700
        : Colors.red.shade700;

    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration:
              BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          isOpen
              ? 'Open now'
              : 'Closed',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                color: color,
                fontWeight:
                    FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

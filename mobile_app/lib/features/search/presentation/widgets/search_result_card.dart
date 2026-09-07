import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/search_result_model.dart';

class SearchResultCard extends StatelessWidget {
  final SearchResultModel result;

  const SearchResultCard({
    super.key,
    required this.result,
  });

  Future<void> _callOrganization(
    BuildContext context,
  ) async {
    final phone = result.phone?.trim();

    if (phone == null || phone.isEmpty) {
      _showMessage(
        context,
        'Phone number is not available.',
      );
      return;
    }

    final cleanedPhone =
        phone.replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );

    final uri = Uri(
      scheme: 'tel',
      path: cleanedPhone,
    );

    try {
      final launched = await launchUrl(uri);

      if (!launched && context.mounted) {
        _showMessage(
          context,
          'Unable to open the phone dialer.',
        );
      }
    } catch (e) {
      debugPrint(
        'Organization call error: $e',
      );

      if (context.mounted) {
        _showMessage(
          context,
          'Unable to make the call.',
        );
      }
    }
  }

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasPhone =
        result.phone?.trim().isNotEmpty ?? false;

    final organizationId =
        result.organizationId.trim();

    return Card(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor:
                      colorScheme.primaryContainer,
                  child: Icon(
                    result.organizationType
                                .toLowerCase() ==
                            'hospital'
                        ? Icons
                            .local_hospital_outlined
                        : Icons
                            .bloodtype_outlined,
                    color: colorScheme
                        .onPrimaryContainer,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.organizationName,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        result.organizationType,
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: colorScheme
                              .onSurfaceVariant,
                        ),
                      ),

                      if (result.isVerified) ...[
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified,
                              size: 15,
                              color:
                                  colorScheme.primary,
                            ),
                            const SizedBox(
                              width: 4,
                            ),
                            Text(
                              'Verified',
                              style: theme
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color:
                                    colorScheme
                                        .primary,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme
                        .errorContainer,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: Text(
                    result.bloodGroup.isNotEmpty
                        ? result.bloodGroup
                        : '—',
                    style: theme
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                      color: colorScheme
                          .onErrorContainer,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme
                    .surfaceContainerHighest,
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color:
                        colorScheme.primary,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      'Available Blood',
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),

                  Text(
                    '${result.availableUnits} units',
                    style: theme
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                      color:
                          result.availableUnits >
                                  0
                              ? colorScheme
                                  .primary
                              : colorScheme
                                  .error,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _InfoRow(
              icon:
                  Icons.location_on_outlined,
              text: [
                result.address,
                result.city,
                result.province,
              ]
                  .where(
                    (value) =>
                        value.trim().isNotEmpty,
                  )
                  .join(', '),
            ),

            if (hasPhone) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.phone_outlined,
                text: result.phone!,
              ),
            ],

            if (result.distanceKm != null) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon:
                    Icons.near_me_outlined,
                text:
                    '${result.distanceKm!.toStringAsFixed(1)} km away',
              ),
            ],

            if (result.rating != null) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.star_outline,
                text: result.reviewCount != null
                    ? '${result.rating!.toStringAsFixed(1)} '
                        '(${result.reviewCount} reviews)'
                    : result.rating!
                        .toStringAsFixed(1),
              ),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: result.isOpen
                        ? Colors.green
                        : Colors.red,
                  ),
                ),

                const SizedBox(width: 8),

                Text(
                  result.isOpen
                      ? 'Open'
                      : 'Closed',
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w600,
                    color: result.isOpen
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),

                const Spacer(),

                Text(
                  result.availableUnits > 0
                      ? 'Blood available'
                      : 'Currently unavailable',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color:
                        result.availableUnits >
                                0
                            ? colorScheme
                                .primary
                            : colorScheme
                                .error,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        organizationId.isEmpty
                            ? null
                            : () {
                                context.push(
                                  '/organization-detail/$organizationId',
                                );
                              },
                    icon: const Icon(
                      Icons.info_outline,
                    ),
                    label:
                        const Text('Details'),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed: hasPhone
                        ? () =>
                            _callOrganization(
                              context,
                            )
                        : null,
                    icon: const Icon(
                      Icons.call_outlined,
                    ),
                    label:
                        const Text('Call'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme
              .onSurfaceVariant,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            text.isNotEmpty
                ? text
                : 'Not available',
            style:
                theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
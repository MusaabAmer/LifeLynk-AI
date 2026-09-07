import 'package:flutter/material.dart';

import '../../data/models/organization_detail_model.dart';

class OrganizationHeader extends StatelessWidget {
  final OrganizationDetailModel organization;

  const OrganizationHeader({
    super.key,
    required this.organization,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool isHospital =
        organization.organizationType.toLowerCase() == 'hospital';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                isHospital
                    ? Icons.local_hospital
                    : Icons.bloodtype,
                size: 32,
                color: colorScheme.onPrimaryContainer,
              ),
            ),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          organization.organizationName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      if (organization.isVerified) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Verified organization',
                          child: Icon(
                            Icons.verified,
                            size: 21,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 5),

                  Text(
                    organization.organizationType,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 11,
                        color: organization.isOpen
                            ? Colors.green
                            : Colors.red,
                      ),

                      const SizedBox(width: 6),

                      Text(
                        organization.isOpen
                            ? 'Open'
                            : 'Closed',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


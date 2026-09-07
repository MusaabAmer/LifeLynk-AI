import 'package:flutter/material.dart';

import '../../data/models/organization_detail_model.dart';

class ContactCard extends StatelessWidget {
  final OrganizationDetailModel organization;

  const ContactCard({
    super.key,
    required this.organization,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final List<Widget> rows = [];

    if (organization.phone != null &&
        organization.phone!.trim().isNotEmpty) {
      rows.add(
        _InfoRow(
          icon: Icons.phone_outlined,
          text: organization.phone!,
        ),
      );
    }

    if (organization.email != null &&
        organization.email!.trim().isNotEmpty) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 12));
      }

      rows.add(
        _InfoRow(
          icon: Icons.email_outlined,
          text: organization.email!,
        ),
      );
    }

    if (organization.website != null &&
        organization.website!.trim().isNotEmpty) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 12));
      }

      rows.add(
        _InfoRow(
          icon: Icons.language_outlined,
          text: organization.website!,
        ),
      );
    }

    if (rows.isEmpty) {
      rows.add(
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No contact information available.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            ...rows,
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: colorScheme.primary,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}


import 'package:flutter/material.dart';

import '../../data/models/service_model.dart';

class ServicesWrap extends StatelessWidget {
  final List<ServiceModel> services;

  const ServicesWrap({
    super.key,
    required this.services,
  });

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Services',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: services.map(
                (service) {
                  return Chip(
                    avatar: Icon(
                      service.isAvailable
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 18,
                    ),
                    label: Text(
                      service.name,
                    ),
                  );
                },
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
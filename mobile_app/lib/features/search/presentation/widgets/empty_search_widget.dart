import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/search_provider.dart';

class EmptySearchWidget extends StatelessWidget {
  final String? message;

  const EmptySearchWidget({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off,
                size: 60,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'No Blood Found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              message ??
                  'No hospitals or blood banks match your filters.\n'
                  'Try changing your search criteria.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: () {
                context.read<SearchProvider>().clearFilters();
              },
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Clear Filters',
              ),
            ),
          ],
        ),
      ),
    );
  }
}


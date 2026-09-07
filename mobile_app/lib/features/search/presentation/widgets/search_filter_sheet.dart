import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/search_provider.dart';

import 'blood_group_filter.dart';
import 'province_filter.dart';
import 'city_filter.dart';

class SearchFilterSheet extends StatelessWidget {
  const SearchFilterSheet({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter Blood Availability',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Choose the blood group and location '
              'you want to search.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),

            const SizedBox(height: 20),

            // Blood Group
            const BloodGroupFilter(),

            const SizedBox(height: 16),

            // Province
            const ProvinceFilter(),

            const SizedBox(height: 16),

            // City
            const CityFilter(),

            const SizedBox(height: 24),

            // Apply Filters
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  context
                      .read<SearchProvider>()
                      .search();

                  Navigator.pop(context);
                },
                icon: const Icon(Icons.search),
                label: const Text('Apply Filters'),
              ),
            ),

            const SizedBox(height: 10),

            // Clear Filters
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context
                      .read<SearchProvider>()
                      .clearFilters();

                  Navigator.pop(context);
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


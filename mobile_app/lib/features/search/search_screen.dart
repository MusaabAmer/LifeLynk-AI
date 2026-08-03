import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/providers/search_provider.dart';
import '../../shared/widgets/blood_group_chip.dart';
import '../../shared/widgets/custom_button.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);
    final searchNotifier = ref.read(searchProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Blood Availability'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Required Blood Group',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemCount: AppConstants.bloodGroups.length,
              itemBuilder: (context, index) {
                final bg = AppConstants.bloodGroups[index];
                return BloodGroupChip(
                  bloodGroup: bg,
                  isSelected: searchState.selectedBloodGroup == bg,
                  onTap: () => searchNotifier.setBloodGroup(bg),
                );
              },
            ),

            const SizedBox(height: 24),

            const Text(
              'Select City',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: searchState.selectedCity,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_city),
              ),
              items: AppConstants.cities
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                if (val != null) searchNotifier.setCity(val);
              },
            ),

            const SizedBox(height: 24),

            const Text(
              'Optional Filters',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Hospital or Blood Bank Name',
                prefixIcon: Icon(Icons.local_hospital),
                hintText: 'e.g. Shaukat Khanum',
              ),
              onChanged: (val) => searchNotifier.setHospitalFilter(val),
            ),

            const SizedBox(height: 36),

            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Clear Filters',
                    isOutlined: true,
                    onPressed: () => searchNotifier.clearFilters(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'Search',
                    icon: Icons.search,
                    isLoading: searchState.isLoading,
                    onPressed: () async {
                      await searchNotifier.performSearch();
                      if (context.mounted) {
                        context.push('/search-results');
                      }
                    },
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

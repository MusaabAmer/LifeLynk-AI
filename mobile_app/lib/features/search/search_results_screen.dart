import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/providers/search_provider.dart';
import '../../shared/widgets/hospital_card.dart';

class SearchResultsScreen extends ConsumerWidget {
  const SearchResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Search Results (${searchState.results.length})'),
      ),
      body: searchState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : searchState.results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'No Available Units Found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try searching for another blood group or nearby city.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: searchState.results.length,
                  itemBuilder: (context, index) {
                    final hospital = searchState.results[index];
                    return HospitalCard(
                      hospital: hospital,
                      selectedBloodGroup: searchState.selectedBloodGroup,
                      onTap: () => context.push('/hospital-details', extra: hospital),
                      onReserveTap: () => context.push('/reserve', extra: hospital),
                    );
                  },
                ),
    );
  }
}

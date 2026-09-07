import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../providers/search_provider.dart';

import '../widgets/search_bar_widget.dart';
import '../widgets/blood_group_filter.dart';
import '../widgets/province_filter.dart';
import '../widgets/city_filter.dart';
import '../widgets/search_result_card.dart';
import '../widgets/search_loading.dart';
import '../widgets/empty_search_widget.dart';
import '../widgets/search_filter_sheet.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, provider, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,

          // ============================================================
          // APP BAR
          // ============================================================

          appBar: AppBar(
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 20,

            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find Blood',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'Find available blood near you',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton.filledTonal(
                  tooltip: 'Filters',
                  icon: const Icon(Icons.tune_rounded),
                  color: AppColors.primary,
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) {
                        return const SearchFilterSheet();
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // ============================================================
          // BODY
          // ============================================================

          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,

              onRefresh: () async {
                await provider.search();
              },

              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),

                slivers: [
                  // ======================================================
                  // SEARCH HEADER
                  // ======================================================

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        0,
                      ),

                      child: Container(
                        padding: const EdgeInsets.all(16),

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),

                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withAlpha(18),
                              AppColors.info.withAlpha(10),
                            ],
                          ),

                          border: Border.all(
                            color: AppColors.primary.withAlpha(20),
                          ),
                        ),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,

                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),

                                  child: const Icon(
                                    Icons.bloodtype_rounded,
                                    color: Colors.white,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Find the blood you need',
                                        style: theme
                                            .textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),

                                      const SizedBox(height: 3),

                                      Text(
                                        'Search hospitals and blood banks with available stock.',
                                        style: theme
                                            .textTheme.bodySmall
                                            ?.copyWith(
                                          color: colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Container(
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius:
                                    BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withAlpha(8),
                                    blurRadius: 12,
                                    offset:
                                        const Offset(0, 4),
                                  ),
                                ],
                              ),

                              child: const SearchBarWidget(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ======================================================
                  // BLOOD GROUP
                  // ======================================================

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        20,
                        16,
                        0,
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          const _SectionHeader(
                            title: 'Blood Group',
                            icon: Icons.bloodtype_outlined,
                          ),

                          const SizedBox(height: 10),

                          const BloodGroupFilter(),
                        ],
                      ),
                    ),
                  ),

                  // ======================================================
                  // LOCATION
                  // ======================================================

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        20,
                        16,
                        0,
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          const _SectionHeader(
                            title: 'Location',
                            icon: Icons.location_on_outlined,
                          ),

                          const SizedBox(height: 10),

                          // IMPORTANT:
                          // Do NOT put Province + City inside a Row.
                          //
                          // This prevents pixel overflow on small phones
                          // and gives both fields enough horizontal space.

                          _FilterContainer(
                            child: const ProvinceFilter(),
                          ),

                          const SizedBox(height: 12),

                          _FilterContainer(
                            child: const CityFilter(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ======================================================
                  // RESULTS HEADER
                  // ======================================================

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        24,
                        16,
                        10,
                      ),

                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Available Organizations',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          if (!provider.loading &&
                              provider.results.isNotEmpty)
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),

                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withAlpha(18),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),

                              child: Text(
                                '${provider.results.length} found',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ======================================================
                  // LOADING
                  // ======================================================

                  if (provider.loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: SearchLoading(),
                    )

                  // ======================================================
                  // ERROR
                  // ======================================================

                  else if (provider.error != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _SearchErrorState(
                        message: provider.error!,
                        onRetry: provider.search,
                      ),
                    )

                  // ======================================================
                  // EMPTY
                  // ======================================================

                  else if (provider.results.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptySearchWidget(),
                    )

                  // ======================================================
                  // RESULTS
                  // ======================================================

                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        120,
                      ),

                      sliver: SliverList.builder(
                        itemCount: provider.results.length,

                        itemBuilder: (context, index) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 12),

                            child: SearchResultCard(
                              result: provider.results[index],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ============================================================
          // SEARCH BUTTON
          // ============================================================

          floatingActionButton: SafeArea(
            child: SizedBox(
              width: 155,
              height: 52,

              child: FloatingActionButton.extended(
                elevation: 4,

                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,

                onPressed: provider.loading
                    ? null
                    : provider.search,

                icon: const Icon(
                  Icons.search_rounded,
                ),

                label: const Text(
                  'Search Blood',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}

// ============================================================
// SECTION HEADER
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: AppColors.primary,
        ),

        const SizedBox(width: 7),

        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// FILTER CONTAINER
// ============================================================

class _FilterContainer extends StatelessWidget {
  final Widget child;

  const _FilterContainer({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(
        minHeight: 56,
      ),

      padding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),

      decoration: BoxDecoration(
        color: theme.cardColor,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(90),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: child,
    );
  }
}

// ============================================================
// ERROR STATE
// ============================================================

class _SearchErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SearchErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(30),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Container(
            width: 76,
            height: 76,

            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Unable to search',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
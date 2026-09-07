import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/city_service.dart';
import '../../providers/search_provider.dart';

class CityFilter extends StatefulWidget {
  const CityFilter({
    super.key,
  });

  @override
  State<CityFilter> createState() => _CityFilterState();
}

class _CityFilterState extends State<CityFilter> {
  List<String> cities = [];

  String? lastProvince;

  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, provider, child) {
        final selectedProvince =
            provider.selectedProvince;

        final selectedCity =
            provider.selectedCity;

        if (selectedProvince != lastProvince) {
          lastProvince = selectedProvince;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadCities(selectedProvince);
            }
          });
        }

        return InkWell(
          borderRadius: BorderRadius.circular(14),

          onTap: loading
              ? null
              : () => _showCityPicker(
                    context,
                    provider,
                  ),

          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'City',

              prefixIcon: Icon(
                Icons.location_on_outlined,
              ),

              border: InputBorder.none,

              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),

            child: Row(
              children: [
                Expanded(
                  child: Text(
                    loading
                        ? 'Loading...'
                        : selectedCity ?? 'All Cities',

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: selectedCity == null
                          ? Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                          : Theme.of(context)
                              .colorScheme
                              .onSurface,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadCities(
    String? province,
  ) async {
    if (province == null || province.isEmpty) {
      if (!mounted) return;

      setState(() {
        cities = [];
        loading = false;
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      loading = true;
      cities = [];
    });

    try {
      final loadedCities =
          await CityService.getCities(province);

      loadedCities.sort();

      if (!mounted) return;

      setState(() {
        cities =
            List<String>.from(loadedCities);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        cities = [];
        loading = false;
      });
    }
  }

  Future<void> _showCityPicker(
    BuildContext context,
    SearchProvider provider,
  ) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      builder: (_) {
        return _CitySearchSheet(
          cities: cities,
          selectedCity: provider.selectedCity,
        );
      },
    );

    if (!mounted || result == null) return;

    provider.setCity(
      result.isEmpty ? null : result,
    );
  }
}

// ============================================================
// CITY SEARCH SHEET
// ============================================================

class _CitySearchSheet extends StatefulWidget {
  final List<String> cities;
  final String? selectedCity;

  const _CitySearchSheet({
    required this.cities,
    required this.selectedCity,
  });

  @override
  State<_CitySearchSheet> createState() =>
      _CitySearchSheetState();
}

class _CitySearchSheetState
    extends State<_CitySearchSheet> {
  final TextEditingController controller =
      TextEditingController();

  late List<String> filteredCities;

  @override
  void initState() {
    super.initState();

    filteredCities =
        List<String>.from(widget.cities);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _filterCities(String value) {
    final query = value.trim().toLowerCase();

    setState(() {
      filteredCities = widget.cities
          .where(
            (city) => city
                .toLowerCase()
                .contains(query),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Container(
        height:
            MediaQuery.sizeOf(context).height * 0.75,

        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,

          borderRadius:
              const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),

        child: Column(
          children: [
            const SizedBox(height: 12),

            Container(
              width: 42,
              height: 5,

              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius:
                    BorderRadius.circular(10),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                12,
              ),

              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select City',
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },

                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),

              child: TextField(
                controller: controller,

                autofocus: true,

                onChanged: _filterCities,

                decoration: InputDecoration(
                  hintText: 'Search city...',

                  prefixIcon: const Icon(
                    Icons.search_rounded,
                  ),

                  suffixIcon:
                      controller.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                controller.clear();
                                _filterCities('');
                              },

                              icon: const Icon(
                                Icons.clear_rounded,
                              ),
                            )
                          : null,

                  filled: true,

                  fillColor: colorScheme
                      .surfaceContainerHighest
                      .withAlpha(100),

                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(16),

                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: filteredCities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 42,
                            color: colorScheme
                                .onSurfaceVariant,
                          ),

                          const SizedBox(height: 10),

                          Text(
                            'No cities found',
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'Try another city name.',
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )

                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior
                              .onDrag,

                      padding:
                          const EdgeInsets.fromLTRB(
                        12,
                        4,
                        12,
                        20,
                      ),

                      itemCount:
                          filteredCities.length + 1,

                      itemBuilder:
                          (context, index) {
                        // All cities
                        if (index == 0) {
                          final selected =
                              widget.selectedCity ==
                                  null;

                          return ListTile(
                            leading: Icon(
                              Icons.location_city_rounded,
                              color: selected
                                  ? AppColors.primary
                                  : null,
                            ),

                            title: Text(
                              'All Cities',
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),

                            trailing: selected
                                ? const Icon(
                                    Icons
                                        .check_circle_rounded,
                                    color:
                                        AppColors.primary,
                                  )
                                : null,

                            onTap: () {
                              Navigator.pop(
                                context,
                                '',
                              );
                            },
                          );
                        }

                        final city =
                            filteredCities[index - 1];

                        final selected =
                            city ==
                                widget.selectedCity;

                        return ListTile(
                          leading: Icon(
                            Icons
                                .location_on_outlined,
                            color: selected
                                ? AppColors.primary
                                : null,
                          ),

                          title: Text(
                            city,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,

                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),

                          trailing: selected
                              ? const Icon(
                                  Icons
                                      .check_circle_rounded,
                                  color:
                                      AppColors.primary,
                                )
                              : null,

                          onTap: () {
                            Navigator.pop(
                              context,
                              city,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
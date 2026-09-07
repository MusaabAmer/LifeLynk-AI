import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/city_service.dart';
import '../../providers/search_provider.dart';

class ProvinceFilter extends StatefulWidget {
  const ProvinceFilter({
    super.key,
  });

  @override
  State<ProvinceFilter> createState() => _ProvinceFilterState();
}

class _ProvinceFilterState extends State<ProvinceFilter> {
  List<String> provinces = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final loaded = await CityService.getProvinces();

      if (!mounted) return;

      setState(() {
        provinces = List<String>.from(loaded);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        provinces = [];
        loading = false;
      });
    }
  }

  Future<void> _showProvincePicker(
    BuildContext context,
    SearchProvider provider,
  ) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      builder: (sheetContext) {
        return _SearchSelectionSheet(
          title: 'Select Province',
          searchHint: 'Search province...',
          items: provinces,
          selectedValue: provider.selectedProvince,
          allowAll: true,
          allLabel: 'All Provinces',
        );
      },
    );

    if (!mounted || result == null) return;

    provider.setProvince(
      result.isEmpty ? null : result,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, provider, child) {
        final selected = provider.selectedProvince;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: loading
              ? null
              : () => _showProvincePicker(
                    context,
                    provider,
                  ),

          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Province',
              prefixIcon: Icon(
                Icons.location_city_outlined,
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
                        : selected ?? 'All Provinces',

                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: selected == null
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
}

// ============================================================
// SEARCHABLE SELECTION SHEET
// ============================================================

class _SearchSelectionSheet extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<String> items;
  final String? selectedValue;
  final bool allowAll;
  final String allLabel;

  const _SearchSelectionSheet({
    required this.title,
    required this.searchHint,
    required this.items,
    required this.selectedValue,
    required this.allowAll,
    required this.allLabel,
  });

  @override
  State<_SearchSelectionSheet> createState() =>
      _SearchSelectionSheetState();
}

class _SearchSelectionSheetState
    extends State<_SearchSelectionSheet> {
  final TextEditingController controller =
      TextEditingController();

  late List<String> filteredItems;

  @override
  void initState() {
    super.initState();
    filteredItems = List<String>.from(widget.items);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    final query = value.trim().toLowerCase();

    setState(() {
      filteredItems = widget.items
          .where(
            (item) => item.toLowerCase().contains(query),
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
        height: MediaQuery.sizeOf(context).height * 0.75,

        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
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
                borderRadius: BorderRadius.circular(10),
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
                      widget.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close_rounded),
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
                onChanged: _search,

                autofocus: true,

                decoration: InputDecoration(
                  hintText: widget.searchHint,

                  prefixIcon: const Icon(
                    Icons.search_rounded,
                  ),

                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            controller.clear();
                            _search('');
                          },
                          icon: const Icon(
                            Icons.clear_rounded,
                          ),
                        )
                      : null,

                  filled: true,

                  fillColor:
                      colorScheme.surfaceContainerHighest
                          .withAlpha(100),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,

                padding: const EdgeInsets.fromLTRB(
                  12,
                  4,
                  12,
                  20,
                ),

                itemCount:
                    filteredItems.length +
                    (widget.allowAll ? 1 : 0),

                itemBuilder: (context, index) {
                  if (widget.allowAll && index == 0) {
                    final selected =
                        widget.selectedValue == null;

                    return ListTile(
                      leading: Icon(
                        Icons.public_rounded,
                        color: selected
                            ? AppColors.primary
                            : null,
                      ),

                      title: Text(
                        widget.allLabel,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),

                      trailing: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                            )
                          : null,

                      onTap: () {
                        Navigator.pop(context, '');
                      },
                    );
                  }

                  final item = filteredItems[
                    widget.allowAll
                        ? index - 1
                        : index
                  ];

                  final selected =
                      item == widget.selectedValue;

                  return ListTile(
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: selected
                          ? AppColors.primary
                          : null,
                    ),

                    title: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),

                    trailing: selected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                          )
                        : null,

                    onTap: () {
                      Navigator.pop(context, item);
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
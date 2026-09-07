import 'package:flutter/material.dart';

/// Categories available on the full-screen map.
enum MapCategory {
  all,
  hospitals,
  bloodBanks,
  donors,
  medical,
}

/// Horizontal category filter for the full-screen map.
class MapCategoryFilter extends StatelessWidget {
  final MapCategory selectedCategory;

  final ValueChanged<MapCategory> onCategorySelected;

  const MapCategoryFilter({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        physics: const BouncingScrollPhysics(),
        itemCount: MapCategory.values.length,

        // FIX:
        // separatorBuilder requires (BuildContext, int).
        separatorBuilder: (_, _) => const SizedBox(
          width: 8,
        ),

        itemBuilder: (context, index) {
          final category = MapCategory.values[index];

          return _CategoryChip(
            category: category,
            selected: category == selectedCategory,
            onTap: () => onCategorySelected(category),
          );
        },
      ),
    );
  }
}

// ================================================================
// CATEGORY CHIP
// ================================================================

class _CategoryChip extends StatelessWidget {
  final MapCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colors.primary
          : colors.surface,
      borderRadius: BorderRadius.circular(24),
      elevation: selected ? 2 : 1,
      shadowColor: Colors.black.withAlpha(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category.icon,
                size: 18,
                color: selected
                    ? colors.onPrimary
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                category.label,
                style: TextStyle(
                  color: selected
                      ? colors.onPrimary
                      : colors.onSurface,
                  fontSize: 13,
                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// EXTENSIONS
// ================================================================

extension MapCategoryExtension on MapCategory {
  String get label {
    switch (this) {
      case MapCategory.all:
        return 'All';

      case MapCategory.hospitals:
        return 'Hospitals';

      case MapCategory.bloodBanks:
        return 'Blood Banks';

      case MapCategory.donors:
        return 'Donors';

      case MapCategory.medical:
        return 'Medical';
    }
  }

  IconData get icon {
    switch (this) {
      case MapCategory.all:
        return Icons.map_rounded;

      case MapCategory.hospitals:
        return Icons.local_hospital_rounded;

      case MapCategory.bloodBanks:
        return Icons.bloodtype_rounded;

      case MapCategory.donors:
        return Icons.volunteer_activism_rounded;

      case MapCategory.medical:
        return Icons.medical_services_rounded;
    }
  }
}

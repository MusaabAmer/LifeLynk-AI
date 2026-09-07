import 'package:flutter/material.dart';

class BloodGroupDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const BloodGroupDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  // ============================================================
  // SUPPORTED BLOOD GROUP CODES
  // ============================================================

  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  // ============================================================
  // LEGACY / DATABASE NAME NORMALIZATION
  //
  // The database blood_groups table can return either:
  //
  // A+       -> code
  // A Positive -> name
  //
  // The dropdown itself always uses the canonical code.
  // ============================================================

  static String? normalizeBloodGroup(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    // Already a canonical code.
    if (bloodGroups.contains(normalized)) {
      return normalized;
    }

    // Normalize database/display names.
    switch (normalized.toLowerCase()) {
      case 'a positive':
      case 'a pos':
      case 'apos':
        return 'A+';

      case 'a negative':
      case 'a neg':
      case 'aneg':
        return 'A-';

      case 'b positive':
      case 'b pos':
      case 'bpos':
        return 'B+';

      case 'b negative':
      case 'b neg':
      case 'bneg':
        return 'B-';

      case 'ab positive':
      case 'ab pos':
      case 'abpos':
        return 'AB+';

      case 'ab negative':
      case 'ab neg':
      case 'abneg':
        return 'AB-';

      case 'o positive':
      case 'o pos':
      case 'opos':
        return 'O+';

      case 'o negative':
      case 'o neg':
      case 'oneg':
        return 'O-';
    }

    // Unknown value should not be passed to DropdownButtonFormField
    // because Flutter requires its value to match exactly one item.
    return null;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final normalizedValue = normalizeBloodGroup(value);

    return DropdownButtonFormField<String>(
      initialValue: normalizedValue,

      decoration: const InputDecoration(
        labelText: 'Blood Group',
        prefixIcon: Icon(Icons.bloodtype),
      ),

      items: bloodGroups
          .map(
            (group) => DropdownMenuItem<String>(
              value: group,
              child: Text(group),
            ),
          )
          .toList(),

      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please select your blood group';
        }

        return null;
      },

      onChanged: (selectedValue) {
        // Always return the canonical blood-group code.
        onChanged(
          normalizeBloodGroup(selectedValue),
        );
      },
    );
  }
}
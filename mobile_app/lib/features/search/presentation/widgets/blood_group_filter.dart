import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/search_provider.dart';

class BloodGroupFilter extends StatelessWidget {
  const BloodGroupFilter({
    super.key,
  });

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

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, provider, child) {
        return DropdownButtonFormField<String>(
          initialValue: provider.selectedBloodGroup,
          decoration: const InputDecoration(
            labelText: 'Blood Group',
            prefixIcon: Icon(
              Icons.bloodtype,
            ),
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text(
                'All Blood Groups',
              ),
            ),
            ...bloodGroups.map(
              (group) => DropdownMenuItem<String>(
                value: group,
                child: Text(group),
              ),
            ),
          ],
          onChanged: provider.setBloodGroup,
        );
      },
    );
  }
}
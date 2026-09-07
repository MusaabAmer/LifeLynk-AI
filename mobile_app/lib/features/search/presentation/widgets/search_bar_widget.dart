import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search hospital or blood bank...',

        hintStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 14,
        ),

        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.primary,
        ),

        filled: true,

        fillColor:
            Theme.of(context).cardColor,

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(16),

          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(16),

          borderSide: BorderSide.none,
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(16),

          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.3,
          ),
        ),

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
    );
  }
}
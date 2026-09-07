import 'package:flutter/material.dart';

class AiSuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const AiSuggestionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ActionChip(
      onPressed: onTap,
      avatar: Icon(
        icon,
        size: 18,
        color: theme.colorScheme.primary,
      ),
      label: Text(label),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide(
        color: theme.colorScheme.outline.withValues(
          alpha: 0.25,
        ),
      ),
    );
  }
}
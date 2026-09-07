import 'package:flutter/material.dart';

class AiEmptyState extends StatelessWidget {
  const AiEmptyState({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(
              alpha: 0.10,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_awesome,
            size: 46,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'LifeLynk AI',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your intelligent healthcare assistant',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ask questions about blood groups, donation, '
          'blood availability, emergency support, '
          'and other healthcare topics.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(
              alpha: 0.65,
            ),
          ),
        ),
      ],
    );
  }
}
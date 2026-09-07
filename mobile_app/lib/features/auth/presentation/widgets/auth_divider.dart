import 'package:flutter/material.dart';

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Divider(
            color: colorScheme.outline.withAlpha(45),
            thickness: 1,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest
                .withAlpha(80),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'OR',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
          ),
        ),
        Expanded(
          child: Divider(
            color: colorScheme.outline.withAlpha(45),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}


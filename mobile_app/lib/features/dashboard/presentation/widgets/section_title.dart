import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  /// Optional unread notification count.
  ///
  /// When greater than zero, a compact badge is displayed beside
  /// the section title.
  final int? badgeCount;

  const SectionTitle({
    super.key,
    required this.title,
    this.onSeeAll,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final hasBadge =
        badgeCount != null && badgeCount! > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),

              if (hasBadge) ...[
                const SizedBox(width: 8),

                Container(
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.error,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colors.surface,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount! > 99
                        ? '99+'
                        : badgeCount.toString(),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onError,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const Spacer(),

        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text('See All'),
          ),
      ],
    );
  }
}
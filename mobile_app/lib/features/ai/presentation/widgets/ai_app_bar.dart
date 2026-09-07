import 'package:flutter/material.dart';

class AiAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final VoidCallback? onNewConversation;
  final VoidCallback? onHistory;

  const AiAppBar({
    super.key,
    this.onNewConversation,
    this.onHistory,
  });

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  'LifeLynk AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Your healthcare assistant',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: onNewConversation,
          tooltip: 'New conversation',
          icon: const Icon(
            Icons.add_comment_outlined,
          ),
        ),
        IconButton(
          onPressed: onHistory,
          tooltip: 'Conversation history',
          icon: const Icon(
            Icons.history,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
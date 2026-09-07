import 'package:flutter/material.dart';

import '../../data/models/ai_conversation_model.dart';

class AiConversationTile extends StatelessWidget {
  final AiConversationModel conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const AiConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastMessage = conversation.lastMessage;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(
              alpha: 0.10,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_awesome,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            lastMessage?.content ??
                'No messages in this conversation',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: IconButton(
          onPressed: onDelete,
          tooltip: 'Delete conversation',
          icon: const Icon(
            Icons.delete_outline,
          ),
        ),
      ),
    );
  }
}
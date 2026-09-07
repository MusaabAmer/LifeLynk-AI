import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ai_provider.dart';
import '../widgets/ai_conversation_tile.dart';

class AiHistoryScreen extends StatefulWidget {
  const AiHistoryScreen({
    super.key,
  });

  @override
  State<AiHistoryScreen> createState() =>
      _AiHistoryScreenState();
}

class _AiHistoryScreenState extends State<AiHistoryScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<AiProvider>().loadConversations();
    });
  }

  // ============================================================
  // OPEN CONVERSATION
  // ============================================================

  Future<void> _openConversation(
    String conversationId,
  ) async {
    final provider = context.read<AiProvider>();

    final success = await provider.openConversation(
      conversationId,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    }
  }

  // ============================================================
  // DELETE CONVERSATION
  // ============================================================

  Future<void> _deleteConversation(
    String conversationId,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete conversation?',
          ),
          content: Text(
            'Are you sure you want to delete '
            '"$title"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final provider = context.read<AiProvider>();

    await provider.deleteConversation(
      conversationId,
    );

    if (!mounted) return;

    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error!,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // NEW CONVERSATION
  // ============================================================

  Future<void> _newConversation() async {
    final provider = context.read<AiProvider>();

    provider.startNewChat();

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  // ============================================================
  // CLEAR ALL
  // ============================================================

  Future<void> _clearAllConversations() async {
    final provider = context.read<AiProvider>();

    if (provider.conversations.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Clear all conversations?',
          ),
          content: const Text(
            'This will permanently remove all '
            'saved AI conversations.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await provider.clearAllConversations();
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    await context.read<AiProvider>().loadConversations();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI History',
        ),
        actions: [
          if (provider.conversations.isNotEmpty)
            IconButton(
              onPressed:
                  provider.loading ? null : _clearAllConversations,
              tooltip: 'Clear all',
              icon: const Icon(
                Icons.delete_sweep_outlined,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(
          context,
          provider,
        ),
      ),
      floatingActionButton:
          provider.conversations.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _newConversation,
                  icon: const Icon(
                    Icons.add_comment_outlined,
                  ),
                  label: const Text(
                    'New Chat',
                  ),
                )
              : null,
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(
    BuildContext context,
    AiProvider provider,
  ) {
    // ----------------------------------------------------------
    // Loading
    // ----------------------------------------------------------

    if (provider.loading &&
        provider.conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // ----------------------------------------------------------
    // Error
    // ----------------------------------------------------------

    if (provider.error != null &&
        provider.conversations.isEmpty) {
      return _ErrorState(
        message: provider.error!,
        onRetry: _refresh,
      );
    }

    // ----------------------------------------------------------
    // Empty
    // ----------------------------------------------------------

    if (provider.conversations.isEmpty) {
      return _EmptyHistoryState(
        onNewConversation: _newConversation,
      );
    }

    // ----------------------------------------------------------
    // Conversations
    // ----------------------------------------------------------

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          100,
        ),
        itemCount: provider.conversations.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final conversation =
              provider.conversations[index];

          return AiConversationTile(
            conversation: conversation,
            onTap: () {
              _openConversation(
                conversation.id,
              );
            },
            onDelete: () {
              _deleteConversation(
                conversation.id,
                conversation.title,
              );
            },
          );
        },
      ),
    );
  }
}

// =================================================================
// EMPTY HISTORY
// =================================================================

class _EmptyHistoryState extends StatelessWidget {
  final VoidCallback onNewConversation;

  const _EmptyHistoryState({
    required this.onNewConversation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 48,
                color:
                    theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Conversations Yet',
              textAlign: TextAlign.center,
              style: theme
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your LifeLynk AI conversations '
              'will appear here.',
              textAlign: TextAlign.center,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: theme
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onNewConversation,
              icon: const Icon(
                Icons.add_comment_outlined,
              ),
              label: const Text(
                'Start New Chat',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// ERROR STATE
// =================================================================

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load History',
              textAlign: TextAlign.center,
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
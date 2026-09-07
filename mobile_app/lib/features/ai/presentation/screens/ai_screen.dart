  
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ai_provider.dart';
import '../widgets/ai_app_bar.dart';
import '../widgets/ai_input_field.dart';
import '../widgets/ai_message_bubble.dart';
import '../widgets/ai_suggestions.dart';
import '../widgets/ai_typing_indicator.dart';
import '../widgets/ai_empty_state.dart';
import '../widgets/ai_loading.dart';
import 'ai_history_screen.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final ScrollController _scrollController =
      ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _loadConversations();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD CONVERSATIONS
  // ============================================================

  Future<void> _loadConversations() async {
    final provider = context.read<AiProvider>();

    await provider.loadConversations();

    if (!mounted) return;

    if (provider.hasMessages) {
      _scrollToBottom();
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage(String message) async {
    final trimmedMessage = message.trim();

    if (trimmedMessage.isEmpty) {
      return;
    }

    final provider = context.read<AiProvider>();

    if (provider.sending) {
      return;
    }

    final success = await provider.sendMessage(
      trimmedMessage,
    );

    if (!mounted) return;

    // The provider adds the user's message immediately,
    // so scroll even when the backend request fails.
    _scrollToBottom();

    if (success) {
      // Give the assistant response one more frame to appear
      // before moving to the newest message.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _scrollToBottom();
      });
    }
  }

  // ============================================================
  // NEW CONVERSATION
  // ============================================================

  void _startNewConversation() {
    final provider = context.read<AiProvider>();

    provider.startNewChat();

    _scrollToTop();
  }

  // ============================================================
  // HISTORY
  // ============================================================

  Future<void> _openHistory() async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AiHistoryScreen(),
      ),
    );

    if (!mounted) return;

    final provider = context.read<AiProvider>();

    if (provider.hasMessages) {
      _scrollToBottom();
    } else {
      _scrollToTop();
    }
  }

  // ============================================================
  // SCROLL TO BOTTOM
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!_scrollController.hasClients) {
        return;
      }

      final position =
          _scrollController.position;

      if (!position.hasContentDimensions) {
        return;
      }

      _scrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 250,
        ),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // SCROLL TO TOP
  // ============================================================

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!_scrollController.hasClients) {
        return;
      }

      final position =
          _scrollController.position;

      if (!position.hasContentDimensions) {
        return;
      }

      _scrollController.animateTo(
        0,
        duration: const Duration(
          milliseconds: 200,
        ),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // CLEAR CONVERSATION
  // ============================================================

  Future<void> _clearConversation() async {
    final provider = context.read<AiProvider>();

    if (!provider.hasConversation ||
        provider.sending) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Clear conversation?',
          ),
          content: const Text(
            'All messages in this conversation '
            'will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  true,
                );
              },
              child: const Text(
                'Clear',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await provider.clearCurrentConversation();

    if (!mounted) return;

    _scrollToTop();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Consumer<AiProvider>(
      builder: (
        context,
        provider,
        _,
      ) {
        return Scaffold(
          appBar: AiAppBar(
            onNewConversation:
                provider.sending
                    ? null
                    : _startNewConversation,
            onHistory:
                provider.sending
                    ? null
                    : _openHistory,
          ),
          body: Column(
            children: [
              Expanded(
                child: _buildContent(
                  context,
                  provider,
                ),
              ),

              if (provider.error != null)
                _buildErrorBanner(
                  context,
                  provider,
                ),

              AiInputField(
                enabled: !provider.sending,
                onSend: _sendMessage,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent(
    BuildContext context,
    AiProvider provider,
  ) {
    if (provider.loading &&
        !provider.hasMessages) {
      return const AiLoading();
    }

    if (!provider.hasMessages) {
      return _buildEmptyState(
        context,
        provider,
      );
    }

    return _buildConversation(
      context,
      provider,
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(
    BuildContext context,
    AiProvider provider,
  ) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        20,
        32,
        20,
        24,
      ),
      children: [
        const AiEmptyState(),

        const SizedBox(height: 28),

        AiSuggestions(
          onSuggestionSelected: _sendMessage,
        ),
      ],
    );
  }

  // ============================================================
  // CONVERSATION
  // ============================================================

  Widget _buildConversation(
    BuildContext context,
    AiProvider provider,
  ) {
    final messages = provider.messages;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              16,
              20,
              16,
              20,
            ),
            itemCount:
                messages.length +
                (provider.sending ? 1 : 0),
            itemBuilder: (
              context,
              index,
            ) {
              if (provider.sending &&
                  index == messages.length) {
                return const AiTypingIndicator();
              }

              final message = messages[index];

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: AiMessageBubble(
                  message: message,
                ),
              );
            },
          ),
        ),

        if (provider.hasMessages)
          _buildConversationActions(
            context,
            provider,
          ),
      ],
    );
  }

  // ============================================================
  // CONVERSATION ACTIONS
  // ============================================================

  Widget _buildConversationActions(
    BuildContext context,
    AiProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        8,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed:
              provider.sending
                  ? null
                  : _clearConversation,
          icon: const Icon(
            Icons.delete_outline,
            size: 18,
          ),
          label: const Text(
            'Clear conversation',
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR BANNER
  // ============================================================

  Widget _buildErrorBanner(
    BuildContext context,
    AiProvider provider,
  ) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.errorContainer,
      child: InkWell(
        onTap: provider.clearError,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme
                    .colorScheme
                    .onErrorContainer,
                size: 20,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  provider.error!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme
                        .colorScheme
                        .onErrorContainer,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.close,
                size: 18,
                color: theme
                    .colorScheme
                    .onErrorContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


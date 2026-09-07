import 'package:flutter/foundation.dart';

import '../../data/models/ai_conversation_model.dart';
import '../../data/models/ai_message_model.dart';
import '../../data/repositories/ai_repository.dart';

class AiProvider extends ChangeNotifier {
  final AiRepository repository;

  AiProvider({
    required this.repository,
  });

  // ============================================================
  // STATE
  // ============================================================

  List<AiConversationModel> _conversations = [];

  List<AiConversationModel> get conversations =>
      List.unmodifiable(_conversations);

  AiConversationModel? _currentConversation;

  AiConversationModel? get currentConversation =>
      _currentConversation;

  bool _loading = false;

  bool get loading => _loading;

  bool _sending = false;

  bool get sending => _sending;

  bool _deleting = false;

  bool get deleting => _deleting;

  String? _error;

  String? get error => _error;

  // ============================================================
  // CONVENIENCE GETTERS
  // ============================================================

  List<AiMessageModel> get messages =>
      _currentConversation?.messages ?? const [];

  bool get hasConversation =>
      _currentConversation != null;

  bool get hasMessages =>
      messages.isNotEmpty;

  bool get isEmpty =>
      !hasMessages;

  // ============================================================
  // LOAD CONVERSATIONS
  // ============================================================

  Future<void> loadConversations() async {
    _loading = true;
    _error = null;

    notifyListeners();

    try {
      _conversations = await repository.getConversations();
    } catch (e, stackTrace) {
      debugPrint(
        'AI load conversations error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _error = _friendlyError(
        e,
        fallback: 'Unable to load AI conversations.',
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // CREATE CONVERSATION
  // ============================================================

  Future<AiConversationModel?> createConversation() async {
    _error = null;

    try {
      final conversation =
          await repository.createConversation();

      _currentConversation = conversation;

      _insertOrUpdateConversation(
        conversation,
      );

      notifyListeners();

      return conversation;
    } catch (e, stackTrace) {
      debugPrint(
        'AI create conversation error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _error = _friendlyError(
        e,
        fallback: 'Unable to create a new conversation.',
      );

      notifyListeners();

      return null;
    }
  }

  // ============================================================
  // OPEN CONVERSATION
  // ============================================================

  Future<bool> openConversation(
    String conversationId,
  ) async {
    _loading = true;
    _error = null;

    notifyListeners();

    try {
      final conversation =
          await repository.getConversation(
        conversationId,
      );

      if (conversation == null) {
        _error = 'Conversation could not be found.';
        return false;
      }

      _currentConversation = conversation;

      return true;
    } catch (e, stackTrace) {
      debugPrint(
        'AI open conversation error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _error = _friendlyError(
        e,
        fallback: 'Unable to open conversation.',
      );

      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<bool> sendMessage(
    String text,
  ) async {
    final message = text.trim();

    if (message.isEmpty) {
      _error = 'Please enter a message so I can help you.';
      notifyListeners();
      return false;
    }

    if (_sending) {
      return false;
    }

    _error = null;

    // ----------------------------------------------------------
    // Create conversation automatically when required
    // ----------------------------------------------------------

    if (_currentConversation == null) {
      final conversation =
          await createConversation();

      if (conversation == null) {
        return false;
      }
    }

    final conversation =
        _currentConversation!;

    // ----------------------------------------------------------
    // Add user message immediately
    // ----------------------------------------------------------

    final userMessage =
        AiMessageModel.user(
      content: message,
    );

    var updatedConversation =
        conversation.addMessage(
      userMessage,
    );

    // Generate a useful title from the first user message.
    updatedConversation =
        updatedConversation.generateTitleFromFirstMessage();

    _currentConversation =
        updatedConversation;

    _insertOrUpdateConversation(
      updatedConversation,
    );

    notifyListeners();

    // ----------------------------------------------------------
    // Request real AI response
    // ----------------------------------------------------------

    _sending = true;
    notifyListeners();

    try {
      final assistantMessage =
          await repository.sendMessage(
        message: message,
        conversation: updatedConversation,
      );

      updatedConversation =
          updatedConversation.addMessage(
        assistantMessage,
      );

      _currentConversation =
          updatedConversation;

      await repository.saveConversation(
        updatedConversation,
      );

      _insertOrUpdateConversation(
        updatedConversation,
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint(
        'AI send message error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _error = _friendlyError(
        e,
        fallback:
            'Unable to get a response from LifeLynk AI.',
      );

      // Keep the user's message in the current conversation.
      // This allows the UI to display the question even if the
      // backend temporarily fails.
      _currentConversation =
          updatedConversation;

      _insertOrUpdateConversation(
        updatedConversation,
      );

      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  // ============================================================
  // DELETE CONVERSATION
  // ============================================================

  Future<bool> deleteConversation(
    String conversationId,
  ) async {
    _deleting = true;
    _error = null;

    notifyListeners();

    try {
      final deleted =
          await repository.deleteConversation(
        conversationId,
      );

      if (!deleted) {
        _error =
            'Conversation could not be deleted.';

        return false;
      }

      _conversations.removeWhere(
        (conversation) =>
            conversation.id == conversationId,
      );

      if (_currentConversation?.id ==
          conversationId) {
        _currentConversation = null;
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint(
        'AI delete conversation error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _error = _friendlyError(
        e,
        fallback: 'Unable to delete conversation.',
      );

      return false;
    } finally {
      _deleting = false;
      notifyListeners();
    }
  }

  // ============================================================
  // CLEAR CURRENT CONVERSATION
  // ============================================================

  Future<void> clearCurrentConversation() async {
    if (_currentConversation == null) {
      return;
    }

    _error = null;

    try {
      final cleared =
          _currentConversation!.clearMessages();

      _currentConversation = cleared;

      await repository.saveConversation(
        cleared,
      );

      _insertOrUpdateConversation(
        cleared,
      );

      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint(
        'AI clear conversation error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _error = _friendlyError(
        e,
        fallback:
            'Unable to clear the conversation.',
      );

      notifyListeners();
    }
  }

  // ============================================================
  // START NEW CHAT
  // ============================================================

  void startNewChat() {
    _currentConversation = null;
    _error = null;

    notifyListeners();
  }

  // ============================================================
  // CLEAR ERROR
  // ============================================================

  void clearError() {
    if (_error == null) {
      return;
    }

    _error = null;

    notifyListeners();
  }

  // ============================================================
  // CLEAR ALL CONVERSATIONS
  // ============================================================

  Future<bool> clearAllConversations() async {
    _loading = true;
    _error = null;

    notifyListeners();

    try {
      await repository.clearConversations();

      _conversations = [];
      _currentConversation = null;

      return true;
    } catch (e, stackTrace) {
      debugPrint(
        'AI clear all conversations error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _error = _friendlyError(
        e,
        fallback:
            'Unable to clear conversations.',
      );

      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  void _insertOrUpdateConversation(
    AiConversationModel conversation,
  ) {
    final index =
        _conversations.indexWhere(
      (item) => item.id == conversation.id,
    );

    if (index == -1) {
      _conversations.insert(
        0,
        conversation,
      );
    } else {
      _conversations[index] =
          conversation;
    }

    _conversations.sort(
      (a, b) =>
          b.updatedAt.compareTo(
        a.updatedAt,
      ),
    );
  }

  String _friendlyError(
    Object error, {
    required String fallback,
  }) {
    if (error is AiRepositoryException) {
      final message = error.message.trim();

      if (message.isNotEmpty) {
        return message;
      }
    }

    return fallback;
  }

  @override
  void dispose() {
    _conversations = [];
    _currentConversation = null;

    super.dispose();
  }
}

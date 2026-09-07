import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AiInputField extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool enabled;
  final String hintText;

  const AiInputField({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.hintText = 'Ask LifeLynk AI...',
  });

  @override
  State<AiInputField> createState() => _AiInputFieldState();
}

class _AiInputFieldState extends State<AiInputField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _speechInitialized = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant AiInputField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.enabled && _isListening) {
      _stopListening();
    }
  }

  @override
  void dispose() {
    _speechToText.stop();
    _controller.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  // ============================================================
  // TEXT MESSAGE
  // ============================================================

  void _send() {
    if (!widget.enabled || _isListening) {
      return;
    }

    final text = _controller.text.trim();

    if (text.isEmpty) {
      return;
    }

    widget.onSend(text);

    _controller.clear();

    _focusNode.requestFocus();
  }

  void _handleSubmitted(String value) {
    _send();
  }

  // ============================================================
  // SPEECH INITIALIZATION
  // ============================================================

  Future<bool> _initializeSpeech() async {
    if (_speechInitialized) {
      return true;
    }

    try {
      final available = await _speechToText.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );

      if (!mounted) {
        return available;
      }

      setState(() {
        _speechInitialized = available;
      });

      if (!available) {
        _showSpeechMessage(
          'Speech recognition is not available on this device.',
        );
      }

      return available;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      setState(() {
        _speechInitialized = false;
        _isListening = false;
      });

      _showSpeechMessage(
        'Unable to start speech recognition. '
        'Please check microphone permission.',
      );

      return false;
    }
  }

  // ============================================================
  // START LISTENING
  // ============================================================

  Future<void> _startListening() async {
    if (!widget.enabled) {
      return;
    }

    if (_isListening) {
      await _stopListening();
      return;
    }

    final available = await _initializeSpeech();

    if (!available || !mounted || !widget.enabled) {
      return;
    }

    setState(() {
      _isListening = true;
    });

    _focusNode.unfocus();

    try {
      await _speechToText.listen(
        onResult: _handleSpeechResult,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          autoPunctuation: true,
        ),
      );

      if (!mounted) {
        return;
      }

      if (!_speechToText.isListening) {
        setState(() {
          _isListening = false;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isListening = false;
      });

      _showSpeechMessage(
        'Could not start the microphone. '
        'Please check your microphone permission.',
      );
    }
  }

  // ============================================================
  // STOP LISTENING
  // ============================================================

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
    } catch (_) {
      // The speech plugin can already be stopped by the platform.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = false;
    });

    if (_controller.text.trim().isNotEmpty) {
      _focusNode.requestFocus();
    }
  }

  // ============================================================
  // SPEECH RESULT
  // ============================================================

  void _handleSpeechResult(
    SpeechRecognitionResult result,
  ) {
    if (!mounted) {
      return;
    }

    final recognizedText = result.recognizedWords.trim();

    if (recognizedText.isEmpty) {
      return;
    }

    _controller.value = TextEditingValue(
      text: recognizedText,
      selection: TextSelection.collapsed(
        offset: recognizedText.length,
      ),
    );

    if (result.finalResult) {
      setState(() {
        _isListening = false;
      });

      _focusNode.requestFocus();
    } else {
      setState(() {});
    }
  }

  // ============================================================
  // SPEECH STATUS
  // ============================================================

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }

    final normalizedStatus = status.toLowerCase();

    if (normalizedStatus == 'listening') {
      setState(() {
        _isListening = true;
      });
      return;
    }

    if (normalizedStatus == 'notlistening' ||
        normalizedStatus == 'done') {
      setState(() {
        _isListening = false;
      });

      if (_controller.text.trim().isNotEmpty) {
        _focusNode.requestFocus();
      }
    }
  }

  // ============================================================
  // SPEECH ERROR
  // ============================================================

  void _handleSpeechError(dynamic error) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = false;
    });

    _showSpeechMessage(
      'Speech recognition stopped. '
      'Please try again if needed.',
    );
  }

  // ============================================================
  // USER FEEDBACK
  // ============================================================

  void _showSpeechMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasText = _controller.text.trim().isNotEmpty;

    final canSend =
        widget.enabled &&
        hasText &&
        !_isListening;

    final canUseMicrophone = widget.enabled;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: _handleSubmitted,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? 'Listening...'
                        : widget.hintText,
                    hintStyle: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: theme
                          .colorScheme
                          .onSurface
                          .withValues(
                        alpha: 0.55,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    prefixIcon: Icon(
                      _isListening
                          ? Icons.mic
                          : Icons.auto_awesome_outlined,
                      size: 20,
                      color: _isListening
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(
                        right: 6,
                      ),
                      child: IconButton(
                        onPressed: canUseMicrophone
                            ? _startListening
                            : null,
                        tooltip: _isListening
                            ? 'Stop listening'
                            : 'Voice input',
                        icon: Icon(
                          _isListening
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none_rounded,
                          color: _isListening
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(
                milliseconds: 180,
              ),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canSend
                    ? theme.colorScheme.primary
                    : theme
                        .colorScheme
                        .surfaceContainerHighest,
              ),
              child: IconButton(
                onPressed: canSend ? _send : null,
                tooltip: 'Send',
                icon: Icon(
                  Icons.arrow_upward_rounded,
                  color: canSend
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface
                          .withValues(
                          alpha: 0.4,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


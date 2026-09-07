import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/models/ai_message_model.dart';

class AiMessageBubble extends StatefulWidget {
  final AiMessageModel message;

  const AiMessageBubble({
    super.key,
    required this.message,
  });

  @override
  State<AiMessageBubble> createState() => _AiMessageBubbleState();
}

class _AiMessageBubbleState extends State<AiMessageBubble> {
  late final FlutterTts _flutterTts;

  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();

    _flutterTts = FlutterTts();

    _configureTts();
  }

  Future<void> _configureTts() async {
    try {
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);

      _flutterTts.setStartHandler(() {
        if (!mounted) {
          return;
        }

        setState(() {
          _isSpeaking = true;
        });
      });

      _flutterTts.setCompletionHandler(() {
        if (!mounted) {
          return;
        }

        setState(() {
          _isSpeaking = false;
        });
      });

      _flutterTts.setCancelHandler(() {
        if (!mounted) {
          return;
        }

        setState(() {
          _isSpeaking = false;
        });
      });

      _flutterTts.setErrorHandler((message) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isSpeaking = false;
        });
      });
    } catch (_) {
      // TTS configuration is platform-dependent.
      // The Listen button will still fail gracefully if unavailable.
    }
  }

  Future<void> _toggleSpeech() async {
    if (widget.message.isUser) {
      return;
    }

    try {
      if (_isSpeaking) {
        await _flutterTts.stop();

        if (!mounted) {
          return;
        }

        setState(() {
          _isSpeaking = false;
        });

        return;
      }

      final text = widget.message.content.trim();

      if (text.isEmpty) {
        return;
      }

      // Stop anything currently being spoken by this TTS instance
      // before starting the new response.
      await _flutterTts.stop();

      // LifeLynk AI can return English, Urdu, or Roman Urdu.
      // English is the safest default because platform TTS engines
      // may not have an Urdu voice installed.
      await _flutterTts.setLanguage('en-US');

      if (!mounted) {
        return;
      }

      setState(() {
        _isSpeaking = true;
      });

      final result = await _flutterTts.speak(text);

      // flutter_tts normally triggers the completion/error handlers.
      // This fallback keeps the button state correct on platforms
      // that return a non-success result immediately.
      if (result != null &&
          result != 1 &&
          mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSpeaking = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Voice playback is not available on this device.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = widget.message;
    final isUser = message.isUser;

    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              _AiAvatar(
                color: theme.colorScheme.primary,
                icon: Icons.auto_awesome,
              ),
              const SizedBox(width: 8),
            ],

            Flexible(
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? theme.colorScheme.primary
                          : theme
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(
                          isUser ? 18 : 4,
                        ),
                        bottomRight: Radius.circular(
                          isUser ? 4 : 18,
                        ),
                      ),
                    ),
                    child: SelectableText(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                        color: isUser
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  Padding(
                    padding: EdgeInsets.only(
                      left: isUser ? 0 : 4,
                      right: isUser ? 4 : 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isUser) ...[
                          InkWell(
                            onTap: _toggleSpeech,
                            borderRadius:
                                BorderRadius.circular(18),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isSpeaking
                                        ? Icons.stop_circle_outlined
                                        : Icons.volume_up_outlined,
                                    size: 16,
                                    color: _isSpeaking
                                        ? theme.colorScheme.error
                                        : theme
                                            .colorScheme
                                            .onSurface
                                            .withValues(
                                          alpha: 0.55,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isSpeaking
                                        ? 'Stop'
                                        : 'Listen',
                                    style: theme
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                      color: _isSpeaking
                                          ? theme
                                              .colorScheme
                                              .error
                                          : theme
                                              .colorScheme
                                              .onSurface
                                              .withValues(
                                            alpha: 0.55,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],

                        Text(
                          _formatTime(message.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (isUser) ...[
              const SizedBox(width: 8),
              _AiAvatar(
                color: theme.colorScheme.primary,
                icon: Icons.person_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');

    final period = hour >= 12 ? 'PM' : 'AM';

    final displayHour =
        hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:$minute $period';
  }
}

// ============================================================
// AVATAR
// ============================================================

class _AiAvatar extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _AiAvatar({
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 18,
        color: color,
      ),
    );
  }
}


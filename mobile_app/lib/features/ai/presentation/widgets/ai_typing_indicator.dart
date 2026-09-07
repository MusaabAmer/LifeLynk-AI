import 'package:flutter/material.dart';

class AiTypingIndicator extends StatefulWidget {
  const AiTypingIndicator({
    super.key,
  });

  @override
  State<AiTypingIndicator> createState() =>
      _AiTypingIndicatorState();
}

class _AiTypingIndicatorState
    extends State<AiTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1200,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.auto_awesome,
              size: 19,
              color:
                  theme.colorScheme.onPrimaryContainer,
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: theme
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (
                context,
                child,
              ) {
                return Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) {
                      final value =
                          (_controller.value -
                                  index * 0.15)
                              .clamp(0.0, 1.0);

                      final opacity =
                          0.35 +
                          (value * 0.65);

                      return Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 2.5,
                        ),
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration:
                                BoxDecoration(
                              shape:
                                  BoxShape.circle,
                              color: theme
                                  .colorScheme
                                  .onSurface
                                  .withValues(
                                    alpha: 0.65,
                                  ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
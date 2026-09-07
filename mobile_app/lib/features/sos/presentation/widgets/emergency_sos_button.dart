import 'package:flutter/material.dart';

class EmergencySosButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final bool active;

  const EmergencySosButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final bool disabled =
        loading || onPressed == null;

    return Semantics(
      button: true,
      label: active
          ? 'Emergency SOS is active'
          : 'Activate emergency SOS',
      hint: active
          ? 'Emergency response is currently active'
          : 'Tap once to activate emergency response',
      child: GestureDetector(
        onTap: disabled ? null : onPressed,
        child: AnimatedOpacity(
          duration: const Duration(
            milliseconds: 200,
          ),
          opacity: disabled && !loading ? 0.65 : 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(
                alpha: 0.10,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(
                  alpha: 0.16,
                ),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? colors.error
                        : colors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (active
                                ? colors.error
                                : colors.primary)
                            .withValues(
                          alpha: 0.30,
                        ),
                        blurRadius: 28,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap:
                          disabled ? null : onPressed,
                      customBorder:
                          const CircleBorder(),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(
                            milliseconds: 250,
                          ),
                          child: loading
                              ? const SizedBox(
                                  key: ValueKey(
                                    'loading',
                                  ),
                                  width: 46,
                                  height: 46,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 4,
                                    color: Colors.white,
                                  ),
                                )
                              : Column(
                                  key: ValueKey(
                                    active
                                        ? 'active'
                                        : 'ready',
                                  ),
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      active
                                          ? Icons
                                              .emergency_rounded
                                          : Icons
                                              .sos_rounded,
                                      size: 54,
                                      color:
                                          Colors.white,
                                    ),
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    Text(
                                      active
                                          ? 'SOS ACTIVE'
                                          : 'SOS',
                                      style: theme
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                        color:
                                            Colors.white,
                                        fontWeight:
                                            FontWeight.w900,
                                        letterSpacing:
                                            1.2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
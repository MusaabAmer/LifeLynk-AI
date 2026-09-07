import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String animation;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // ------------------------------------------------------------
        // Lottie Animation
        // ------------------------------------------------------------

        SizedBox(
          width: double.infinity,
          height: 210,
          child: Lottie.asset(
            animation,

            fit: BoxFit.contain,

            repeat: true,
            animate: true,

            // Smooth animation on supported devices.
            frameRate: FrameRate.max,

            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              debugPrint(
                'AUTH LOTTIE ERROR: $error',
              );

              debugPrint(
                'AUTH LOTTIE ASSET: $animation',
              );

              debugPrint(
                'AUTH LOTTIE STACK: $stackTrace',
              );

              return Container(
                width: double.infinity,
                height: 210,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 50,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Animation failed',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 18),

        // ------------------------------------------------------------
        // Title
        // ------------------------------------------------------------

        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 8),

        // ------------------------------------------------------------
        // Subtitle
        // ------------------------------------------------------------

        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
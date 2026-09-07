import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/router/routes.dart';
import '../widgets/primary_button.dart';

class PasswordChangedScreen extends StatelessWidget {
  const PasswordChangedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 460,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  // --------------------------------------------------
                  // Success illustration
                  // --------------------------------------------------

                  Container(
                    padding:
                        const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color:
                          colorScheme.primaryContainer
                              .withValues(alpha: 0.35),
                      borderRadius:
                          BorderRadius.circular(36),
                    ),
                    child: Lottie.asset(
                      "assets/animations/success.json",
                      height: 220,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --------------------------------------------------
                  // Success badge
                  // --------------------------------------------------

                  Center(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green
                            .withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons
                                .verified_rounded,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Account Secured",
                            style: theme
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                              color:
                                  Colors.green.shade700,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    "Password Changed!",
                    textAlign: TextAlign.center,
                    style: theme
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    "Your password has been updated successfully.\n\nYou can now sign in securely using your new password.",
                    textAlign: TextAlign.center,
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 36),

                  PrimaryButton(
                    text: "Continue to Login",
                    icon: Icons.login_rounded,
                    onPressed: () {
                      context.go(
                        Routes.login,
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  Text(
                    "Thank you for keeping your LifeLynk AI account secure.",
                    textAlign: TextAlign.center,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/routes.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
  });

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[^@]+@[^@]+\.[^@]+',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }

    return null;
  }

  // ============================================================
  // SEND PASSWORD RESET EMAIL
  // ============================================================

  Future<void> _sendResetEmail() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.sendPasswordResetEmail(
      _emailController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Password reset email sent successfully.',
          ),
        ),
      );

      context.go(Routes.login);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            authProvider.error ??
                'Unable to send reset email.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),
            child: ScrollConfiguration(
              behavior:
                  ScrollConfiguration.of(context).copyWith(
                scrollbars: false,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      // ==================================================
                      // BACK
                      // ==================================================

                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () {
                            context.go(Routes.login);
                          },
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ==================================================
                      // ILLUSTRATION
                      // ==================================================

                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer
                              .withAlpha(90),
                          borderRadius:
                              BorderRadius.circular(28),
                        ),
                        child: Lottie.asset(
                          'assets/animations/forgot_password.json',
                          height: 190,
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==================================================
                      // TITLE
                      // ==================================================

                      Text(
                        'Forgot Password?',
                        textAlign: TextAlign.center,
                        style: theme
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'No worries. Enter your registered '
                        'email and we will help you recover '
                        'your account.',
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

                      const SizedBox(height: 32),

                      // ==================================================
                      // EMAIL
                      // ==================================================

                      Text(
                        'Email Address',
                        style: theme
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 8),

                      AuthTextField(
                        controller: _emailController,
                        hint: 'Enter your email',
                        icon: Icons.email_outlined,
                        keyboardType:
                            TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),

                      const SizedBox(height: 24),

                      // ==================================================
                      // RESET BUTTON
                      // ==================================================

                      Consumer<AuthProvider>(
                        builder: (
                          context,
                          authProvider,
                          child,
                        ) {
                          return PrimaryButton(
                            text: authProvider.loading
                                ? 'Sending...'
                                : 'Send Reset Link',
                            icon: authProvider.loading
                                ? null
                                : Icons.send_rounded,
                            onPressed:
                                authProvider.loading
                                    ? null
                                    : _sendResetEmail,
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // BACK TO LOGIN
                      // ==================================================

                      OutlinedButton.icon(
                        onPressed: () {
                          context.go(Routes.login);
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                        ),
                        label: const Text(
                          'Back to Login',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(54),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==================================================
                      // SECURITY INFORMATION
                      // ==================================================

                      Container(
                        padding:
                            const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme
                              .surfaceContainerHighest
                              .withAlpha(100),
                          borderRadius:
                              BorderRadius.circular(18),
                          border: Border.all(
                            color:
                                colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.security_outlined,
                              color:
                                  colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'For your security, we will '
                                'send recovery instructions '
                                'only to the email associated '
                                'with your account.',
                                style: theme
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: colorScheme
                                      .onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}
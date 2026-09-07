import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/routes.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_text_field.dart';
import '../widgets/social_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool agreeToTerms = false;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!formKey.currentState!.validate()) {
      return;
    }

    if (!agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to the Terms of Service and Privacy Policy.',
          ),
        ),
      );

      return;
    }

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.register(
      emailController.text.trim(),
      passwordController.text,
      fullNameController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      context.go(
        Routes.verifyEmail,
        extra: {
          'email': emailController.text.trim(),
          'fullName': fullNameController.text.trim(),
        },
      );

      return;
    }

    final error = authProvider.error;

    if (error != null && error.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
    }
  }

  // ============================================================
  // GOOGLE SIGN IN
  // ============================================================

  Future<void> _continueWithGoogle() async {
    FocusScope.of(context).unfocus();

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.loginWithGoogle();

    if (!mounted) {
      return;
    }

    if (!success) {
      final error = authProvider.error;

      if (error != null && error.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
          ),
        );
      }

      return;
    }

    context.go(
      Routes.completeProfile,
      extra: {
        'fullName':
            authProvider.user?.userMetadata?['full_name']?.toString() ??
                authProvider.user?.userMetadata?['name']?.toString() ??
                '',
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                24,
                24,
                24,
                32,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==================================================
                    // HEADER
                    // ==================================================

                    const AuthHeader(
                      title: 'Create Your Account',
                      subtitle:
                          'Join LifeLynk AI and help build a faster '
                          'blood emergency response network.',
                      animation: 'assets/animations/register.json',
                    ),

                    const SizedBox(height: 30),

                    // ==================================================
                    // FULL NAME
                    // ==================================================

                    AuthTextField(
                      controller: fullNameController,
                      hint: 'Enter your full name',
                      icon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.name,
                      validator: (value) {
                        final name = value?.trim() ?? '';

                        if (name.isEmpty) {
                          return 'Full name is required.';
                        }

                        if (name.length < 2) {
                          return 'Please enter your full name.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // EMAIL
                    // ==================================================

                    AuthTextField(
                      controller: emailController,
                      hint: 'Enter your email address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Email address is required.';
                        }

                        final emailRegex = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        );

                        if (!emailRegex.hasMatch(email)) {
                          return 'Please enter a valid email address.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // PASSWORD
                    // ==================================================

                    PasswordTextField(
                      controller: passwordController,
                      hint: 'Create a password',
                      validator: (value) {
                        final password = value ?? '';

                        if (password.isEmpty) {
                          return 'Password is required.';
                        }

                        if (password.length < 6) {
                          return 'Password must contain at least 6 characters.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // CONFIRM PASSWORD
                    // ==================================================

                    PasswordTextField(
                      controller: confirmPasswordController,
                      hint: 'Re-enter your password',
                      validator: (value) {
                        final password = value ?? '';

                        if (password.isEmpty) {
                          return 'Please confirm your password.';
                        }

                        if (password != passwordController.text) {
                          return 'Passwords do not match.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // TERMS
                    // ==================================================

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              agreeToTerms = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 12,
                            ),
                            child: Text(
                              'I agree to the Terms of Service and '
                              'Privacy Policy.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ==================================================
                    // CREATE ACCOUNT
                    // ==================================================

                    Consumer<AuthProvider>(
                      builder: (
                        context,
                        authProvider,
                        _,
                      ) {
                        return SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: authProvider.loading
                                ? null
                                : _register,
                            child: authProvider.loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // DIVIDER
                    // ==================================================

                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: colors.outlineVariant,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                          child: Text(
                            'OR',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: colors.outlineVariant,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // GOOGLE
                    // ==================================================

                    Consumer<AuthProvider>(
                      builder: (
                        context,
                        authProvider,
                        _,
                      ) {
                        return SocialButton(
                          onPressed: authProvider.loading
                              ? null
                              : _continueWithGoogle,
                        );
                      },
                    ),

                    const SizedBox(height: 26),

                    // ==================================================
                    // LOGIN
                    // ==================================================

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            context.go(Routes.login);
                          },
                          child: const Text(
                            'Log In',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ==================================================
                    // SECURITY
                    // ==================================================

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Your account information is securely protected.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
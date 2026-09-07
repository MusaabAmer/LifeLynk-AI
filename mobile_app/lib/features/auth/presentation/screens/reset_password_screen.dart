import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/routes.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_header.dart';
import '../widgets/password_text_field.dart';
import '../widgets/primary_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _passwordController =
      TextEditingController();

  final _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider =
        context.read<AuthProvider>();

    final success =
        await provider.updatePassword(
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      context.go(
        Routes.passwordChanged,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ??
                'Unable to update password.',
          ),
        ),
      );
    }
  }

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
              maxWidth: 460,
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
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const AuthHeader(
                        title: 'Create New Password',
                        subtitle:
                            'Protect your LifeLynk AI account with a strong password.',
                        animation:
                            'assets/animations/reset_password.json',
                      ),

                      const SizedBox(height: 28),

                      Container(
                        padding:
                            const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius:
                              BorderRadius.circular(24),
                          border: Border.all(
                            color:
                                colorScheme.outlineVariant,
                          ),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 24,
                              offset:
                                  const Offset(0, 8),
                              color: Colors.black
                                  .withValues(alpha: 0.05),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.all(10),
                                  decoration:
                                      BoxDecoration(
                                    color: colorScheme
                                        .primaryContainer,
                                    shape:
                                        BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons
                                        .lock_reset_rounded,
                                    color:
                                        colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Secure your account',
                                  style: theme
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 22),

                            PasswordTextField(
                              controller:
                                  _passwordController,
                              hint: 'New Password',
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty) {
                                  return 'Password is required';
                                }

                                if (value.length < 8) {
                                  return 'Minimum 8 characters';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 18),

                            PasswordTextField(
                              controller:
                                  _confirmPasswordController,
                              hint:
                                  'Confirm New Password',
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty) {
                                  return 'Please confirm password';
                                }

                                if (value !=
                                    _passwordController
                                        .text) {
                                  return 'Passwords do not match';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            Container(
                              padding:
                                  const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorScheme
                                    .surfaceContainerHighest,
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: const Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons
                                        .info_outline_rounded,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Use at least 8 characters. A combination of letters, numbers and symbols is recommended.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Consumer<AuthProvider>(
                        builder: (
                          context,
                          provider,
                          child,
                        ) {
                          return PrimaryButton(
                            text: provider.loading
                                ? 'Updating...'
                                : 'Update Password',
                            icon: provider.loading
                                ? null
                                : Icons
                                    .check_circle_outline,
                            onPressed:
                                provider.loading
                                    ? null
                                    : _updatePassword,
                          );
                        },
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'Your new password will be used the next time you sign in.',
                        textAlign: TextAlign.center,
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: colorScheme
                              .onSurfaceVariant,
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
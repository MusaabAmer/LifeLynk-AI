import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/password_text_field.dart';
import '../../../auth/presentation/widgets/primary_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState
    extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController =
      TextEditingController();

  final _newPasswordController =
      TextEditingController();

  final _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // VALIDATORS
  // ============================================================

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Current password is required';
    }

    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'New password is required';
    }

    if (value.length < 8) {
      return 'Minimum 8 characters';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentPasswordController.text ==
        _newPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'New password must be different from your current password.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final provider = context.read<AuthProvider>();

    final success = await provider.changePassword(
      currentPassword:
          _currentPasswordController.text,
      newPassword:
          _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      context.go(Routes.passwordChanged);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          provider.error ??
              'Unable to change password.',
        ),
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
    final colors = theme.colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        title: const Text(
          'Password & Security',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 460,
            ),

            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,

              padding: const EdgeInsets.fromLTRB(
                24,
                20,
                24,
                32,
              ),

              child: Form(
                key: _formKey,

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,

                  children: [
                    // ==================================================
                    // SECURITY HEADER
                    // ==================================================

                    Container(
                      padding:
                          const EdgeInsets.all(20),

                      decoration: BoxDecoration(
                        color: colors.primaryContainer
                            .withValues(alpha: 0.35),

                        borderRadius:
                            BorderRadius.circular(24),

                        border: Border.all(
                          color:
                              colors.outlineVariant,
                        ),
                      ),

                      child: Column(
                        children: [
                          // ==========================================
                          // LOTTIE SECURITY ANIMATION
                          // ==========================================

                          Lottie.asset(
                            'assets/animations/success.json',
                            height: 150,
                            fit: BoxFit.contain,
                            repeat: true,
                          ),

                          const SizedBox(height: 8),

                          // ==========================================
                          // TITLE
                          // ==========================================

                          Text(
                            'Change your password',
                            textAlign:
                                TextAlign.center,

                            style: theme
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // ==========================================
                          // DESCRIPTION
                          // ==========================================

                          Text(
                            'Update your password to keep '
                            'your LifeLynk AI account secure.',
                            textAlign:
                                TextAlign.center,

                            style: theme
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                              color: colors
                                  .onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ==================================================
                    // CURRENT PASSWORD
                    // ==================================================

                    Text(
                      'Current Password',
                      style: theme
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    PasswordTextField(
                      controller:
                          _currentPasswordController,
                      hint:
                          'Enter current password',
                      validator:
                          _validateCurrentPassword,
                    ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // NEW PASSWORD
                    // ==================================================

                    Text(
                      'New Password',
                      style: theme
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    PasswordTextField(
                      controller:
                          _newPasswordController,
                      hint:
                          'Enter new password',
                      validator:
                          _validateNewPassword,
                    ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // CONFIRM PASSWORD
                    // ==================================================

                    Text(
                      'Confirm New Password',
                      style: theme
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    PasswordTextField(
                      controller:
                          _confirmPasswordController,
                      hint:
                          'Confirm new password',
                      validator:
                          _validateConfirmPassword,
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // SECURITY INFO
                    // ==================================================

                    Container(
                      padding:
                          const EdgeInsets.all(14),

                      decoration: BoxDecoration(
                        color: colors
                            .surfaceContainerHighest,

                        borderRadius:
                            BorderRadius.circular(16),
                      ),

                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Icon(
                            Icons
                                .verified_user_outlined,
                            size: 20,
                            color:
                                colors.primary,
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              'Your current password will be '
                              'verified before your new password '
                              'is applied.',

                              style: theme
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: colors
                                    .onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ==================================================
                    // UPDATE BUTTON
                    // ==================================================

                    Consumer<AuthProvider>(
                      builder: (
                        context,
                        provider,
                        child,
                      ) {
                        return PrimaryButton(
                          text: provider.loading
                              ? 'Updating...'
                              : 'Change Password',

                          icon: provider.loading
                              ? null
                              : Icons
                                  .lock_reset_rounded,

                          onPressed:
                              provider.loading
                                  ? null
                                  : _changePassword,
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // ==================================================
                    // CANCEL
                    // ==================================================

                    OutlinedButton(
                      onPressed: () {
                        context.pop();
                      },

                      style:
                          OutlinedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(
                          54,
                        ),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),
                      ),

                      child: const Text(
                        'Cancel',
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // PASSWORD REQUIREMENT
                    // ==================================================

                    Text(
                      'Use at least 8 characters. A combination '
                      'of letters, numbers and symbols is recommended.',

                      textAlign:
                          TextAlign.center,

                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                        height: 1.5,
                      ),
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
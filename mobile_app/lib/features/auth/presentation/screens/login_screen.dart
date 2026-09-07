import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/routes.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_text_field.dart';
import '../widgets/social_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // PROFILE COMPLETENESS
  // ============================================================

  Future<bool> _isProfileComplete() async {
    final authProvider = context.read<AuthProvider>();

    final user = authProvider.user;

    if (user == null) {
      return false;
    }

    try {
      final profileData = await authProvider.getCurrentProfile();

      if (profileData == null) {
        return false;
      }

      final fullName =
          (profileData['full_name'] as String?)?.trim() ?? '';

      final phoneNumber =
          (profileData['phone_number'] as String?)?.trim() ?? '';

      return fullName.isNotEmpty && phoneNumber.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _continueAfterLogin() async {
    if (!mounted) {
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final profileComplete = await _isProfileComplete();

    if (!mounted) {
      return;
    }

    if (profileComplete) {
      context.go(Routes.dashboard);
      return;
    }

    final user = authProvider.user;
    final metadata = user?.userMetadata;

    final fullName =
        (metadata?['full_name'] as String?)?.trim().isNotEmpty == true
            ? (metadata?['full_name'] as String).trim()
            : ((metadata?['name'] as String?)?.trim() ?? '');

    context.go(
      Routes.completeProfile,
      extra: {
        'fullName': fullName,
      },
    );
  }

  // ============================================================
  // EMAIL LOGIN
  // ============================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            authProvider.error ??
                'Unable to sign in. Please check your credentials.',
          ),
        ),
      );

      return;
    }

    await _continueAfterLogin();
  }

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================

  Future<void> _loginWithGoogle() async {
    FocusScope.of(context).unfocus();

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.loginWithGoogle();

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            authProvider.error ?? 'Unable to sign in with Google.',
          ),
        ),
      );

      return;
    }

    await _continueAfterLogin();
  }

  // ============================================================
  // VALIDATORS
  // ============================================================

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    return null;
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
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 480,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    28,
                    24,
                    32,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                      22,
                      26,
                      22,
                      24,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: colorScheme.outline.withAlpha(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withAlpha(18),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          // ==================================================
                          // HEADER
                          // ==================================================

                          const AuthHeader(
                            title: 'Welcome Back',
                            subtitle:
                                'Sign in to continue using LifeLynk AI',
                            animation:
                                'assets/animations/login.json',
                          ),

                          const SizedBox(height: 32),

                          // ==================================================
                          // EMAIL
                          // ==================================================

                          AuthTextField(
                            controller: _emailController,
                            hint: 'Email Address',
                            icon: Icons.email_outlined,
                            keyboardType:
                                TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),

                          const SizedBox(height: 18),

                          // ==================================================
                          // PASSWORD
                          // ==================================================

                          PasswordTextField(
                            controller: _passwordController,
                            hint: 'Password',
                            validator: _validatePassword,
                          ),

                          const SizedBox(height: 8),

                          // ==================================================
                          // FORGOT PASSWORD
                          // ==================================================

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: authProvider.loading
                                  ? null
                                  : () {
                                      context.push(
                                        Routes.forgotPassword,
                                      );
                                    },
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize
                                        .shrinkWrap,
                              ),
                              icon: Icon(
                                Icons.lock_reset_outlined,
                                size: 17,
                                color: colorScheme.primary,
                              ),
                              label: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ==================================================
                          // SIGN IN
                          // ==================================================

                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: authProvider.loading
                                  ? null
                                  : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.primary.withValues(
                                  alpha: 0.45,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: authProvider.loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<
                                                Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 26),

                          // ==================================================
                          // DIVIDER
                          // ==================================================

                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: colorScheme.outline
                                      .withAlpha(55),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Text(
                                  'OR',
                                  style: theme
                                      .textTheme.bodySmall
                                      ?.copyWith(
                                    color: colorScheme
                                        .onSurfaceVariant,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: colorScheme.outline
                                      .withAlpha(55),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 26),

                          // ==================================================
                          // GOOGLE SIGN IN
                          // ==================================================

                          AbsorbPointer(
                            absorbing: authProvider.loading,
                            child: Opacity(
                              opacity:
                                  authProvider.loading ? 0.55 : 1.0,
                              child: SocialButton(
                                onPressed: _loginWithGoogle,
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // ==================================================
                          // REGISTER
                          // ==================================================

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  "Don't have an account?",
                                  textAlign: TextAlign.center,
                                  style: theme
                                      .textTheme.bodyMedium
                                      ?.copyWith(
                                    color: colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: authProvider.loading
                                    ? null
                                    : () {
                                        context.go(
                                          Routes.register,
                                        );
                                      },
                                child: const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
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
            );
          },
        ),
      ),
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/routes.dart';
import '../providers/auth_provider.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String fullName;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.fullName,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  Timer? _verificationTimer;
  StreamSubscription<AuthState>? _authSubscription;

  bool _checkingVerification = false;
  bool _resending = false;
  bool _emailVerified = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _listenForAuthChanges();
    _startVerificationPolling();

    // Check once immediately rather than waiting for the first
    // three-second polling interval.
    unawaited(_checkVerification());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _verificationTimer?.cancel();
    _authSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    super.didChangeAppLifecycleState(state);

    /*
     * The user may open Gmail/Chrome, tap the verification link,
     * and then return to LifeLynk AI.
     *
     * When Flutter becomes active again, immediately check the
     * Supabase authentication state instead of waiting for the
     * next polling cycle.
     */
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkVerification());
    }
  }

  // ============================================================
  // SUPABASE AUTH STATE
  // ============================================================

  void _listenForAuthChanges() {
    final supabase = Supabase.instance.client;

    _authSubscription =
        supabase.auth.onAuthStateChange.listen(
      (authState) {
        if (!mounted || _emailVerified) {
          return;
        }

        /*
         * SIGNED_IN, TOKEN_REFRESHED, USER_UPDATED and other
         * Supabase auth events can indicate that the SDK now has
         * newer user/session information.
         */
        switch (authState.event) {
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
          case AuthChangeEvent.initialSession:
            unawaited(_checkVerification());
            break;

          default:
            break;
        }
      },
      onError: (_) {
        // Auth stream errors are intentionally silent here.
        // The periodic check remains active.
      },
    );
  }

  // ============================================================
  // EMAIL VERIFICATION
  // ============================================================

  void _startVerificationPolling() {
    _verificationTimer?.cancel();

    _verificationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        unawaited(_checkVerification());
      },
    );
  }

  Future<void> _checkVerification() async {
    if (!mounted ||
        _checkingVerification ||
        _emailVerified) {
      return;
    }

    setState(() {
      _checkingVerification = true;
    });

    try {
      final supabase = Supabase.instance.client;

      /*
       * First inspect the current user.
       *
       * This is important because the user may already have a
       * refreshed auth state without requiring another network
       * request.
       */
      User? user = supabase.auth.currentUser;

      /*
       * Try refreshing the session when possible.
       *
       * A missing refresh token is NOT treated as a fatal error.
       * This was the source of the repeated:
       *
       * "Can't refresh session, no refresh token found."
       *
       * messages in the previous implementation.
       */
      try {
        final session = supabase.auth.currentSession;

        if (session != null) {
          final response =
              await supabase.auth.refreshSession();

          user = response.user ??
              supabase.auth.currentUser;
        }
      } catch (_) {
        /*
         * If there is no refresh token/session, continue using
         * the current Supabase user.
         *
         * Native deep-link/session handling may update the user
         * separately when the verification URL returns to the
         * application.
         */
      }

      /*
       * Read the newest user object maintained by Supabase.
       */
      user = supabase.auth.currentUser ?? user;

      if (user == null) {
        return;
      }

      final confirmedAt = user.emailConfirmedAt;

      if (confirmedAt == null) {
        return;
      }

      await _handleVerifiedEmail();
    } catch (_) {
      /*
       * Verification polling must remain silent for temporary
       * network/session errors.
       */
    } finally {
      if (mounted) {
        setState(() {
          _checkingVerification = false;
        });
      }
    }
  }

  Future<void> _handleVerifiedEmail() async {
    if (!mounted || _emailVerified) {
      return;
    }

    _emailVerified = true;
    _verificationTimer?.cancel();

    await _goToCompleteProfile();
  }

  Future<void> _goToCompleteProfile() async {
    if (!mounted) {
      return;
    }

    context.go(
      Routes.completeProfile,
      extra: {
        'fullName': widget.fullName,
      },
    );
  }

  Future<void> _checkNow() async {
    await _checkVerification();
  }

  // ============================================================
  // RESEND VERIFICATION
  // ============================================================

  Future<void> _resendVerification() async {
    if (_resending) {
      return;
    }

    setState(() {
      _resending = true;
    });

    final authProvider = context.read<AuthProvider>();

    try {
      final success =
          await authProvider.resendVerificationEmail(
        widget.email,
      );

      if (!mounted) {
        return;
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Verification email sent. Please check your inbox.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              authProvider.error ??
                  'Unable to resend verification email.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Unable to resend verification email: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _resending = false;
        });
      }
    }
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> _signOut() async {
    final authProvider = context.read<AuthProvider>();

    await authProvider.logout();

    if (!mounted) {
      return;
    }

    context.go(Routes.login);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ==================================================
                  // ICON
                  // ==================================================

                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(
                        alpha: 0.10,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 44,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // TITLE
                  // ==================================================

                  Text(
                    'Verify Your Email',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'We sent a verification link to',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Open the email and tap the verification link. '
                    'After verification, return to LifeLynk AI and '
                    'your account will continue automatically.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ==================================================
                  // CHECK VERIFICATION
                  // ==================================================

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _checkingVerification
                          ? null
                          : _checkNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(
                          alpha: 0.45,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _checkingVerification
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'I Have Verified My Email',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // RESEND
                  // ==================================================

                  TextButton(
                    onPressed: _resending
                        ? null
                        : _resendVerification,
                    child: _resending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Resend Verification Email',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // NEXT STEP INFORMATION
                  // ==================================================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.outline.withAlpha(45),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 21,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'After verification, you will complete '
                            'your profile, including your required '
                            'phone number, blood group, gender and '
                            'location.',
                            style:
                                theme.textTheme.bodySmall?.copyWith(
                              height: 1.45,
                              color:
                                  colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // SIGN OUT
                  // ==================================================

                  TextButton(
                    onPressed: _signOut,
                    child: Text(
                      'Use a different account',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
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
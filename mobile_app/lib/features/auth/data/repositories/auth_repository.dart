import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static const String _webGoogleClientId =
      '341079157455-am1qrvogpn4gssroq3bsr1ks6gim2jqu.apps.googleusercontent.com';

  bool _googleInitialized = false;

  // ============================================================
  // AUTH STATE
  // ============================================================

  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }

  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  Session? getCurrentSession() {
    return _supabase.auth.currentSession;
  }

  bool get isLoggedIn {
    return _supabase.auth.currentSession != null;
  }

  // ============================================================
  // EMAIL SIGN UP
  // ============================================================

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedFullName = fullName.trim();

    if (normalizedEmail.isEmpty) {
      throw const AuthException(
        'Email address is required.',
      );
    }

    if (normalizedFullName.isEmpty) {
      throw const AuthException(
        'Full name is required.',
      );
    }

    if (password.isEmpty) {
      throw const AuthException(
        'Password is required.',
      );
    }

    // ----------------------------------------------------------
    // Phone is intentionally NOT collected here.
    //
    // The user enters their required phone number on
    // Complete Profile after email verification.
    //
    // This keeps public.users.phone_number as the authoritative
    // profile value rather than relying on Auth metadata.
    // ----------------------------------------------------------

    return await _supabase.auth.signUp(
      email: normalizedEmail,
      password: password,
      emailRedirectTo: 'lifelynk://auth/confirm',
      data: {
        'full_name': normalizedFullName,
      },
    );
  }

  // ============================================================
  // EMAIL VERIFICATION
  // ============================================================

  Future<void> resendVerificationEmail(
    String email,
  ) async {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      throw const AuthException(
        'Email address is required.',
      );
    }

    await _supabase.auth.resend(
      type: OtpType.signup,
      email: normalizedEmail,
    );
  }

  // ============================================================
  // EMAIL / PASSWORD SIGN IN
  // ============================================================

  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      throw const AuthException(
        'Email address is required.',
      );
    }

    if (password.isEmpty) {
      throw const AuthException(
        'Password is required.',
      );
    }

    final response = await _supabase.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );

    return response.user;
  }

  // ============================================================
  // GOOGLE SIGN IN
  // ============================================================

  Future<User?> signInWithGoogle() async {
    await _initializeGoogleSignIn();

    // ----------------------------------------------------------
    // Native Google Sign-In
    // ----------------------------------------------------------

    final GoogleSignInAccount googleUser;

    try {
      googleUser = await _googleSignIn.authenticate();
    } catch (error) {
      throw AuthException(
        'Google sign-in was cancelled or could not be completed.',
      );
    }

    final GoogleSignInAuthentication googleAuth;

    try {
      googleAuth = googleUser.authentication;
    } catch (error) {
      throw AuthException(
        'Unable to retrieve Google authentication credentials.',
      );
    }

    final idToken = googleAuth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw const AuthException(
        'Google sign-in did not return a valid ID token.',
      );
    }

    // ----------------------------------------------------------
    // Request the access token when available.
    // ----------------------------------------------------------

    String? accessToken;

    try {
      final authorization = await googleUser.authorizationClient
          .authorizationForScopes(
        const [
          'openid',
          'email',
          'profile',
        ],
      );

      accessToken = authorization?.accessToken;

      if (accessToken == null || accessToken.isEmpty) {
        final requestedAuthorization = await googleUser.authorizationClient
            .authorizeScopes(
          const [
            'openid',
            'email',
            'profile',
          ],
        );

        accessToken = requestedAuthorization.accessToken;
      }
    } catch (_) {
      // Supabase can authenticate with the ID token alone for the
      // configured Google provider. Keep accessToken nullable.
      accessToken = null;
    }

    // ----------------------------------------------------------
    // Authenticate the Google identity with Supabase.
    // ----------------------------------------------------------

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    return response.user;
  }

  // ============================================================
  // INITIALIZE GOOGLE SIGN IN
  // ============================================================

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) {
      return;
    }

    await _googleSignIn.initialize(
      serverClientId: _webGoogleClientId,
    );

    _googleInitialized = true;
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  Future<void> sendPasswordResetEmail(
    String email,
  ) async {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      throw const AuthException(
        'Email address is required.',
      );
    }

    await _supabase.auth.resetPasswordForEmail(
      normalizedEmail,
      redirectTo: 'lifelynk://auth/reset-password',
    );
  }

  // ============================================================
  // UPDATE PASSWORD
  // ============================================================

  Future<User?> updatePassword({
    required String newPassword,
  }) async {
    if (newPassword.isEmpty) {
      throw const AuthException(
        'New password is required.',
      );
    }

    if (newPassword.length < 6) {
      throw const AuthException(
        'Password must contain at least 6 characters.',
      );
    }

    final response = await _supabase.auth.updateUser(
      UserAttributes(
        password: newPassword,
      ),
    );

    return response.user;
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw const AuthException(
        'You must be signed in to change your password.',
      );
    }

    final email = user.email?.trim();

    if (email == null || email.isEmpty) {
      throw const AuthException(
        'Your account does not have a valid email address.',
      );
    }

    if (currentPassword.isEmpty) {
      throw const AuthException(
        'Current password is required.',
      );
    }

    if (newPassword.isEmpty) {
      throw const AuthException(
        'New password is required.',
      );
    }

    if (newPassword.length < 6) {
      throw const AuthException(
        'New password must contain at least 6 characters.',
      );
    }

    // ----------------------------------------------------------
    // Re-authenticate before changing the password.
    // ----------------------------------------------------------

    await _supabase.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );

    await _supabase.auth.updateUser(
      UserAttributes(
        password: newPassword,
      ),
    );
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Google may not have an active native session. Supabase
      // sign-out must still continue.
    }

    await _supabase.auth.signOut();
  }
}
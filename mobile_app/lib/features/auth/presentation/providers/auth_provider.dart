import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;

  AuthProvider({
    AuthRepository? repository,
  }) : _repository = repository ?? AuthRepository() {
    _user = _repository.getCurrentUser();

    _authStateSubscription =
        _repository.authStateChanges.listen((state) {
      final session = state.session;

      if (session?.user != null) {
        _user = session!.user;
        notifyListeners();
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }

  // ============================================================
  // STATE
  // ============================================================

  User? _user;

  User? get user => _user;

  bool _loading = false;

  bool get loading => _loading;

  String? _error;

  String? get error => _error;

  StreamSubscription<AuthState>? _authStateSubscription;

  // ============================================================
  // LOGIN
  // ============================================================

  Future<bool> login(
    String email,
    String password,
  ) async {
    if (_loading) {
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final User? user = await _repository.signIn(
        email: email.trim(),
        password: password,
      );

      _user = user;

      return user != null;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<bool> register(
    String email,
    String password,
    String fullName,
  ) async {
    if (_loading) {
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final AuthResponse response = await _repository.signUp(
        email: email.trim(),
        password: password,
        fullName: fullName.trim(),
      );

      // Supabase can return a null session when email confirmation
      // is required. Keep the authenticated user when available.
      final User? user = response.user;

      if (user != null) {
        _user = user;
      }

      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // GOOGLE
  // ============================================================

  Future<bool> loginWithGoogle() async {
    if (_loading) {
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final User? user =
          await _repository.signInWithGoogle();

      if (user == null) {
        _error = 'Google sign-in was cancelled.';
        return false;
      }

      _user = user;

      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // REAL USER PROFILE
  // ============================================================

  /// Returns the authenticated user's real profile from
  /// public.users.
  ///
  /// Authentication and profile completeness are intentionally
  /// kept separate.
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user =
        _user ?? _repository.getCurrentUser();

    if (user == null) {
      return null;
    }

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('users')
          .select(
            'id, full_name, phone_number',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      _error = _cleanError(e);
      notifyListeners();
      return null;
    }
  }

  /// Checks the actual public.users profile to determine whether
  /// the minimum required personal information exists.
  Future<bool> isProfileComplete() async {
    final profile = await getCurrentProfile();

    if (profile == null) {
      return false;
    }

    final fullName =
        (profile['full_name'] as String?)?.trim() ?? '';

    final phoneNumber =
        (profile['phone_number'] as String?)?.trim() ?? '';

    return fullName.isNotEmpty &&
        phoneNumber.isNotEmpty;
  }

  // ============================================================
  // EMAIL VERIFICATION
  // ============================================================

  Future<bool> resendVerificationEmail(
    String email,
  ) async {
    if (_loading) {
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      await _repository.resendVerificationEmail(
        email.trim(),
      );

      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  Future<bool> sendPasswordResetEmail(
    String email,
  ) async {
    if (_loading) {
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      await _repository.sendPasswordResetEmail(
        email.trim(),
      );

      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // UPDATE PASSWORD
  // ============================================================

  Future<bool> updatePassword(
    String newPassword,
  ) async {
    if (_loading) {
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final User? user =
          await _repository.updatePassword(
        newPassword: newPassword,
      );

      if (user != null) {
        _user = user;
      }

      return user != null;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_loading) {
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      // The authenticated Supabase user remains the same after
      // a successful password change.
      _user = _repository.getCurrentUser();

      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    if (_loading) {
      return;
    }

    _setLoading(true);
    _error = null;

    try {
      await _repository.signOut();

      _user = null;
    } catch (e) {
      _error = _cleanError(e);
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // REFRESH USER
  // ============================================================

  Future<void> refreshUser() async {
    try {
      final user = _repository.getCurrentUser();

      if (user != null) {
        _user = user;
      } else {
        _user = null;
      }

      notifyListeners();
    } catch (e) {
      _error = _cleanError(e);
      notifyListeners();
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _cleanError(Object error) {
    if (error is AuthException) {
      return error.message;
    }

    if (error is PostgrestException) {
      return error.message;
    }

    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ============================================================
  // LOADING
  // ============================================================

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
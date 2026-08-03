import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../../services/api_service.dart';
import '../../core/services/storage_service.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _checkAuthStatus();
    return const AuthState();
  }

  Future<void> _checkAuthStatus() async {
    final token = await StorageService.getAuthToken();
    if (token != null && token.isNotEmpty) {
      state = state.copyWith(
        isAuthenticated: true,
        user: const UserModel(
          id: 'user-77',
          fullName: 'Mueeza Khan',
          email: 'mueeza.patient@lifelynk.ai',
          phone: '+92 300 1234567',
          bloodGroup: 'O+',
          address: 'Johar Town, Lahore',
        ),
      );
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await ApiService.login(email, password);
      await StorageService.saveAuthToken('dummy_jwt_token_sample');
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid credentials. Please try again.',
      );
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String bloodGroup,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await ApiService.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        bloodGroup: bloodGroup,
      );
      await StorageService.saveAuthToken('dummy_jwt_token_sample');
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Registration failed. Please check details.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await StorageService.removeAuthToken();
    state = const AuthState();
  }

  void updateProfile(UserModel updatedUser) {
    state = state.copyWith(user: updatedUser);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

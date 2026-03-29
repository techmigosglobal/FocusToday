import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/user.dart';
import '../../features/auth/data/repositories/auth_repository.dart';

/// Auth state provider — manages authentication state globally via Riverpod.
/// Replaces the previous ChangeNotifier-based AuthProvider.
///
/// Usage in widgets:
///   final authState = ref.watch(authStateProvider);
///   authState.when(
///     data: (user) => user != null ? HomeScreen() : LoginScreen(),
///     loading: () => LoadingScreen(),
///     error: (e, s) => ErrorScreen(),
///   );
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<User?>>((ref) {
      return AuthStateNotifier();
    });

class AuthStateNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthStateNotifier() : super(const AsyncValue.loading());

  /// Initialize and restore session from local storage
  Future<void> initialize() async {
    state = const AsyncValue.loading();
    try {
      final authRepo = await AuthRepository.init();
      final user = await authRepo.restoreSession();
      state = AsyncValue.data(user);
    } catch (e, st) {
      debugPrint('[AuthState] Initialize error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Set authenticated user (after login)
  void setUser(User user) {
    state = AsyncValue.data(user);
  }

  /// Update current user fields (after profile edit)
  void updateUser(User Function(User) updater) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(updater(current));
    }
  }

  /// Logout — clear user state
  Future<void> logout() async {
    try {
      final authRepo = await AuthRepository.init();
      await authRepo.clearSession();
    } catch (e) {
      debugPrint('[AuthState] Logout error: $e');
    }
    state = const AsyncValue.data(null);
  }
}

/// Convenience provider — current user (nullable)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// Convenience provider — whether user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

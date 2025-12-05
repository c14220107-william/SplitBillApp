import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Current User Provider
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges.map((state) => state.session?.user);
});

// Current User Profile Provider
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final user = authService.currentUser;
  
  if (user == null) return null;
  
  try {
    return await authService.getProfile(user.id);
  } catch (e) {
    return null;
  }
});

// Auth State Notifier
class AuthNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final profile = await _authService.getProfile(user.id);
      state = AsyncValue.data(profile);
    } catch (e) {
      // Jangan throw error saat initialization, set state ke null
      print('Error initializing auth: $e');
      state = const AsyncValue.data(null);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    // JANGAN update state sama sekali untuk mencegah rebuild
    // State akan tetap di nilai sebelumnya (biasanya null)
    try {
      // Lakukan sign up
      await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      
      // Langsung sign out setelah registrasi berhasil
      await _authService.signOut();
      
      // JANGAN update state - biarkan tetap seperti sebelumnya
      // Ini mencegah widget unmount
    } catch (e) {
      // Jangan update state, langsung throw
      rethrow; // Throw ke UI untuk ditangkap try-catch di page
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authService.signIn(
        email: email,
        password: password,
      );
      state = AsyncValue.data(profile);
    } catch (e) {
      state = const AsyncValue.data(null); // Set ke null, jangan error state
      rethrow; // Throw ke UI untuk ditangkap try-catch di page
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    final currentProfile = state.value;
    if (currentProfile == null) return;

    try {
      final updatedProfile = await _authService.updateProfile(
        userId: currentProfile.id,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );
      state = AsyncValue.data(updatedProfile);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

// Auth State Provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserProfile?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

// All Users Provider (untuk invite)
final allUsersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getAllUsers();
});

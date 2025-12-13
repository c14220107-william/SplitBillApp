import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/fcm_service.dart';
import '../models/user_profile.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Sign Up
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Validasi email format terlebih dahulu
      if (!_isValidEmail(email)) {
        throw Exception('Format email tidak valid. Gunakan email yang benar (contoh: nama@gmail.com)');
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
        emailRedirectTo: 'io.supabase.splitbillapp://login-callback',
      );

      if (response.user == null) {
        throw Exception('Registrasi gagal. Silakan coba lagi.');
      }

      // Check if user was actually created (not just returned existing user)
      if (response.session == null) {
        // User already exists, Supabase returns user but no session
        throw Exception('Email sudah terdaftar. Gunakan email lain atau login.');
      }

      // Profile akan otomatis dibuat oleh trigger di database
      // Tunggu sebentar untuk trigger selesai
      await Future.delayed(const Duration(seconds: 2));

      // Fetch profile yang baru dibuat, retry jika belum ada
      UserProfile? profile;
      for (int i = 0; i < 3; i++) {
        try {
          profile = await getProfile(response.user!.id);
          break;
        } catch (e) {
          if (i < 2) {
            await Future.delayed(const Duration(seconds: 1));
          } else {
            // Jika masih gagal setelah retry, create manual
            await _supabase.from('profiles').insert({
              'id': response.user!.id,
              'email': email,
              'full_name': fullName,
              'updated_at': DateTime.now().toIso8601String(),
            });
            profile = await getProfile(response.user!.id);
          }
        }
      }

      return profile!;
    } on AuthException catch (e) {
      // Handle Supabase specific errors
      if (e.message.contains('User already registered')) {
        throw Exception('Email sudah terdaftar. Gunakan email lain atau login.');
      } else if (e.message.contains('invalid') || e.message.contains('Invalid')) {
        throw Exception('Email tidak valid. Pastikan menggunakan email yang benar.');
      }
      throw Exception(e.message);
    } catch (e) {
      // Re-throw custom exceptions
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Registrasi gagal: ${e.toString()}');
    }
  }

  // Email validation helper
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Sign In
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign in failed');
      }

      // Get profile first (fast operation)
      final profile = await getProfile(response.user!.id);

      // Initialize FCM in background (don't wait for it)
      FCMService().initialize().catchError((e) {
        print('⚠️ FCM initialization failed (non-blocking): $e');
      });

      return profile;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      // Delete FCM token before logout
      await FCMService().deleteFCMToken();
      
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Get Profile
  Future<UserProfile> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get profile: $e');
    }
  }

  // Update Profile
  Future<UserProfile> updateProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final updates = {
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId);

      return await getProfile(userId);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Get all users (for inviting to bills)
  Future<List<UserProfile>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .order('full_name');

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream of current auth state
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Get current user id
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Check if logged in
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  // Sign Up
  Future<AuthResponse> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String role = 'citizen',
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': role, 'name': name, 'full_name': name},
      );

      // If user is created but session is null (email confirm enabled), attempt sign-in
      if (response.session == null) {
        try {
          return await _supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } catch (_) {}
      }

      // Upsert profile in DB
      if (response.user != null) {
        try {
          await _supabase.from('profiles').upsert({
            'id': response.user!.id,
            'name': name,
            'email': email,
            'role': role,
          });
        } catch (e) {
          debugPrint('Profile upsert warning: $e');
        }
      }

      return response;
    } catch (e) {
      // If user already registered, try direct sign-in
      if (e.toString().contains('already registered') || e.toString().contains('User already registered')) {
        return await signInWithEmail(email: email, password: password);
      }
      rethrow;
    }
  }

  // Reset Password
  Future<void> resetPasswordForEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // Sign In
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // Ensure profile exists
    if (response.user != null) {
      try {
        await _supabase.from('profiles').upsert({
          'id': response.user!.id,
          'name': response.user!.userMetadata?['name'] ?? email.split('@').first,
          'email': email,
          'role': 'citizen',
        });
      } catch (_) {}
    }

    return response;
  }

  // Sign Out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get current user profile
  Future<AppUser?> getCurrentUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response != null) {
      return AppUser.fromJson(response);
    }
    return null;
  }
}

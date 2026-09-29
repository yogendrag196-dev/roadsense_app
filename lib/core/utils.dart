import 'dart:convert';

class AppUtils {
  /// Cleans and formats raw Supabase / Auth exception messages for UI display.
  static String getFriendlyErrorMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred.';
    String message = error.toString();

    // Check if error is a JSON-encoded string (e.g. {"code":"...", "message":"..."})
    if (message.trim().startsWith('{') && message.trim().endsWith('}')) {
      try {
        final decoded = jsonDecode(message);
        if (decoded is Map && decoded.containsKey('message')) {
          message = decoded['message'].toString();
        }
      } catch (_) {}
    }

    // Common Supabase Auth error patterns
    if (message.contains('Database error granting user') ||
        message.contains('unexpected_failure') ||
        message.contains('Database error saving new user')) {
      return 'Database authentication sync error. Please run the provided SQL fix in Supabase SQL Editor or try demo sign-in.';
    }
    if (message.contains('Invalid login credentials')) {
      return 'Invalid email or password. Please check your credentials.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Please confirm your email address before signing in.';
    }
    if (message.contains('User already registered')) {
      return 'An account with this email already exists. Please sign in instead.';
    }
    if (message.contains('Password should be at least')) {
      return 'Password should be at least 6 characters.';
    }

    // Strip generic Exception prefix
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length);
    }
    if (message.startsWith('AuthException: ')) {
      message = message.substring('AuthException: '.length);
    }

    return message;
  }
}

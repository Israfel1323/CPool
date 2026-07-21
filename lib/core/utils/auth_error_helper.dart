import 'package:supabase_flutter/supabase_flutter.dart';

class AuthErrorHelper {
  static String getMessage(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();

      if (message.contains('already registered') ||
    message.contains('already exists')) {
  return 'An account with this email already exists. Please sign in instead.';
}

      if (message.contains('invalid login credentials')) {
        return 'Incorrect email or password.';
      }

      if (message.contains('email not confirmed') ||
    message.contains('email not verified')) {
  return 'Please verify your email before signing in.';
}

      if (message.contains('password')) {
        return 'Please choose a stronger password.';
      }

      if (message.contains('invalid email')) {
        return 'Please enter a valid email address.';
      }

      if (message.contains('network')) {
        return 'Please check your internet connection and try again.';
      }
  if (message.contains('rate limit') ||
    message.contains('too many requests')) {
  return "You've requested too many verification emails in a short time. Please wait about a minute before trying again.";
}

      return error.message;
    }

    return 'Something went wrong. Please try again.';
  }
}
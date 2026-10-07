import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class AppConfig {
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      /* .env optional for UI-only dev */
    }
    _loaded = true;
  }

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get apiBaseUrl {
    // Chrome runs on the Windows host, so it reaches the API through
    // localhost. The Android emulator needs 10.0.2.2 to reach the same
    // Windows host.
    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }

    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
  }

  static String get razorpayKeyId => dotenv.env['RAZORPAY_KEY_ID'] ?? '';
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasApi => apiBaseUrl.isNotEmpty;
  static bool get hasRazorpay => razorpayKeyId.isNotEmpty;
}

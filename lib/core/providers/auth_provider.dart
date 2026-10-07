import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/api_client.dart';
import '../config/app_config.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    if (AppConfig.hasSupabase) {
      _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (event) {
          if (event.event == AuthChangeEvent.passwordRecovery) {
            _isPasswordRecovery = true;
          } else if (event.event == AuthChangeEvent.signedOut) {
            _isPasswordRecovery = false;
          }

          notifyListeners();

          if (event.session != null && !_isPasswordRecovery) {
            _syncProfile();
          }
        },
        onError: (error, stackTrace) {
          debugPrint('Auth state error: $error');
        },
      );

      if (isSignedIn) {
        _syncProfile();
      }
    }
  }

  StreamSubscription<AuthState>? _subscription;
  final ApiClient _api = ApiClient();
  ApiClient get api => _api;
  String? _syncError;
  Map<String, dynamic>? _profile;
  bool _isPasswordRecovery = false;
  bool? _isNewProfile;
  Future<void>? _syncFuture;

  String? get syncError => _syncError;
  Map<String, dynamic>? get profile => _profile;
  bool get isPasswordRecovery => _isPasswordRecovery;

  bool get isConfigured => AppConfig.hasSupabase;
  User? get user =>
      AppConfig.hasSupabase ? Supabase.instance.client.auth.currentUser : null;
  bool get isSignedIn => user != null;
  String get displayName =>
      _profile?['display_name'] as String? ??
      user?.userMetadata?['full_name'] as String? ??
      user?.email?.split('@').first ??
      'Rider';

  Future<void> signInWithEmail(String email, String password) async {
    _ensureSupabase();
    await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await _syncProfile();
  }

  Future<void> signUpWithEmail(String email, String password) async {
    _ensureSupabase();
    await Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    await _syncProfile();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _ensureSupabase();

    final redirectUrl = kIsWeb ? Uri.base.origin : null;

    await Supabase.instance.client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectUrl,
    );
  }

  Future<void> updatePassword(String newPassword) async {
    _ensureSupabase();

    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signInWithGoogle() async {
    _ensureSupabase();
    if (kIsWeb) {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
      return;
    }

    final googleSignIn = GoogleSignIn(
      clientId: AppConfig.googleWebClientId.isNotEmpty
          ? AppConfig.googleWebClientId
          : null,
      serverClientId: AppConfig.googleWebClientId.isNotEmpty
          ? AppConfig.googleWebClientId
          : null,
    );
    final account = await googleSignIn.signIn();
    if (account == null) return;
    final auth = await account.authentication;
    final idToken = auth.idToken;
    final accessToken = auth.accessToken;
    if (idToken == null) {
      throw Exception('Google sign-in failed: no id token');
    }
    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    await _syncProfile();
  }

  Future<void> signOut() async {
    if (!AppConfig.hasSupabase) return;

    await Supabase.instance.client.auth.signOut();

    _profile = null;
    _syncError = null;
    _isPasswordRecovery = false;

    notifyListeners();
  }

  Future<void> _syncProfile() {
    if (_syncFuture != null) {
      return _syncFuture!;
    }

    final future = _performSyncProfile();
    _syncFuture = future;

    return future.whenComplete(() {
      _syncFuture = null;
    });
  }

  Future<void> _performSyncProfile() async {
    if (!isSignedIn || !AppConfig.hasApi) return;

    try {
      final data = await _api.syncProfile();
      _profile = data['profile'] as Map<String, dynamic>?;
      _isNewProfile = data['isNewProfile'] == true;
      _syncError = null;
    } catch (e) {
      _syncError = e.toString();
    }

    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (!isSignedIn || !AppConfig.hasApi) return;
    try {
      final data = await _api.getProfile();
      _profile = data['profile'] as Map<String, dynamic>?;
      _syncError = null;
    } catch (e) {
      _syncError = e.toString();
    }
    notifyListeners();
  }

  Future<void> syncProfile() async {
    await _syncProfile();
  }

  bool? get isNewProfile => _isNewProfile;

  bool get profileCompleted =>
      (_profile?['profile_completed'] ?? false) == true;

  bool get isProfileLoaded => _profile != null;

  bool get isAdmin => (_profile?['role'] as String?)?.toLowerCase() == 'admin';

  void _ensureSupabase() {
    if (!AppConfig.hasSupabase) {
      throw Exception(
        'Supabase not configured. Copy .env.example to .env and add keys.',
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../auth/reset_password_screen.dart';
import '../profile/complete_profile_screen.dart';
import '../shell/main_shell.dart';
import '../splash/splash_screen.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  StreamSubscription<AuthState>? _subscription;

  bool _loading = true;
  bool _isPasswordRecovery = false;

  Widget? _screen;

  @override
  void initState() {
    super.initState();

    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      authState,
    ) async {
      if (authState.event == AuthChangeEvent.passwordRecovery) {
        _showPasswordRecovery();
        return;
      }

      if (_isPasswordRecovery) {
        return;
      }

      if (authState.event == AuthChangeEvent.signedOut) {
        if (!mounted) return;

        setState(() {
          _loading = false;
          _screen = const LoginScreen();
        });

        return;
      }

      await _checkUser();
    });

    _handleInitialUrl();
  }

  void _showPasswordRecovery() {
    _isPasswordRecovery = true;

    if (!mounted) return;

    setState(() {
      _loading = false;
      _screen = const ResetPasswordScreen();
    });
  }

  Future<void> _handleInitialUrl() async {
    final uri = Uri.base;

    final code = uri.queryParameters['code'];

    if (code != null && code.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.exchangeCodeForSession(code);

        _showPasswordRecovery();
        return;
      } catch (e) {
        debugPrint('Password recovery code exchange failed: $e');
      }
    }

    await _checkUser();
  }

  Future<void> _checkUser() async {
    if (_isPasswordRecovery) return;

    final auth = context.read<AuthProvider>();

    if (auth.isPasswordRecovery) {
      _showPasswordRecovery();
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _screen = const LoginScreen();
      });

      return;
    }

    if (!auth.isProfileLoaded) {
      await auth.refreshProfile();
    }

    if (!mounted || _isPasswordRecovery) return;

    setState(() {
      _loading = false;
      _screen = auth.profileCompleted
          ? const MainShell()
          : const CompleteProfileScreen();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SplashScreen();
    }

    return _screen ?? const LoginScreen();
  }
}

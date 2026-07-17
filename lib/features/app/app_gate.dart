import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../auth/login_screen.dart';
import '../profile/complete_profile_screen.dart';
import '../shell/main_shell.dart';
import '../splash/splash_screen.dart';
import '../../core/providers/auth_provider.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {

  StreamSubscription<AuthState>? _subscription;

  bool _loading = true;

  Widget? _screen;

  @override
  void initState() {
    super.initState();

    _checkUser();

    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) {
        _checkUser();
      },
    );
  }

Future<void> _checkUser() async {
  final auth = context.read<AuthProvider>();

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

  if (!mounted) return;

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

    return _screen!;
  }
}
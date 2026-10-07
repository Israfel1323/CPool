import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/safety/trip_safety_share_screen.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/app/app_gate.dart';
import 'features/operations/presentation/providers/operations_provider.dart';

class CPoolApp extends StatelessWidget {
  const CPoolApp({super.key});
  String? _sharedTripSafetyToken() {
    final uri = Uri.base;

    final segments = uri.pathSegments;

    if (segments.length == 3 &&
        segments[0] == 'trip-safety' &&
        segments[1] == 'share' &&
        segments[2].isNotEmpty) {
      return segments[2];
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OperationsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'CPool',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            theme: AppTheme.light(),
            darkTheme: AppTheme.light(),
            home: _sharedTripSafetyToken() != null
                ? TripSafetyShareScreen(shareToken: _sharedTripSafetyToken()!)
                : themeProvider.isLoaded
                ? const AppGate()
                : const _BootstrapLoader(),
          );
        },
      ),
    );
  }
}

class _BootstrapLoader extends StatelessWidget {
  const _BootstrapLoader();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFFF8F7FB),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF8F7AA8),
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

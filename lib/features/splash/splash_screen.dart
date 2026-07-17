import 'package:flutter/material.dart';
import '../profile/complete_profile_screen.dart';
import '../auth/login_screen.dart';
import '../../core/api/api_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../shell/main_shell.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _appName = 'CPool';
  static const _tagline = 'Share the ride. Split the cost.';
  final ApiClient _api = ApiClient();

  late final AnimationController _logoController;
  late final AnimationController _taglineController;
  late final AnimationController _pulseController;
  late final List<Animation<double>> _letterAnimations;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _letterAnimations = List.generate(_appName.length, (index) {
      final start = index * 0.08;
      final end = (start + 0.55).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _logoController,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ),
      );
    });

    _startSequence();
  }

  Future<void> _startSequence() async {
  await Future<void>.delayed(const Duration(milliseconds: 200));

  if (!mounted) return;
  await _logoController.forward();

  if (!mounted) return;
  await _taglineController.forward();

  await Future<void>.delayed(const Duration(milliseconds: 900));

  if (!mounted) return;

  final session = Supabase.instance.client.auth.currentSession;

  Widget nextScreen;

  if (session == null) {
    nextScreen = const LoginScreen();
  } else {
    try {
      final profile = await _api.getProfile();

      final completed =
          profile['profile']['profile_completed'] == true;

      if (completed) {
        nextScreen = const MainShell();
      } else {
        nextScreen = const CompleteProfileScreen();
      }
    } catch (_) {
      nextScreen = const LoginScreen();
    }
  }

  if (!mounted) return;

  await Navigator.of(context).pushReplacement(
    PageRouteBuilder<void>(
      pageBuilder: (
        context,
        animation,
        secondaryAnimation,
      ) =>
          nextScreen,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder:
          (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
    ),
  );
}
  @override
  void dispose() {
    _logoController.dispose();
    _taglineController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: [
          _GradientBackdrop(isDark: isDark),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.06);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.violet600,
                              AppColors.violet800,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.violet600
                                  .withValues(alpha: isDark ? 0.45 : 0.3),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car_filled_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_appName.length, (i) {
                    return AnimatedBuilder(
                      animation: _letterAnimations[i],
                      builder: (context, child) {
                        final t = _letterAnimations[i].value;
                        return Transform.translate(
                          offset: Offset(0, 24 * (1 - t)),
                          child: Opacity(
                            opacity: t.clamp(0.0, 1.0),
                            child: Text(
                              _appName[i],
                              style: GoogleFonts.outfit(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                letterSpacing: i == 0 ? -1 : 0.5,
                                foreground: Paint()
                                  ..shader = LinearGradient(
                                    colors: isDark
                                        ? [
                                            AppColors.violet300,
                                            AppColors.violet500,
                                            Colors.white,
                                          ]
                                        : [
                                            AppColors.violet700,
                                            AppColors.violet600,
                                            AppColors.violet800,
                                          ],
                                  ).createShader(
                                    const Rect.fromLTWH(0, 0, 200, 60),
                                  ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _taglineController,
                    curve: Curves.easeOut,
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _taglineController,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: Text(
                      _tagline,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            letterSpacing: 0.3,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _taglineController,
                    curve: Curves.easeOut,
                  ),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.violet500.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientBackdrop extends StatelessWidget {
  const _GradientBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 1.2,
            colors: isDark
                ? [
                    AppColors.violet900.withValues(alpha: 0.35),
                    AppColors.darkBg,
                  ]
                : [
                    AppColors.violet100.withValues(alpha: 0.8),
                    AppColors.lightBg,
                  ],
          ),
        ),
      ),
    );
  }
}

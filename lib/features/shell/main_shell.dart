import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/api/api_client.dart';

import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../rides/my_rides_screen.dart';
import '../operations/presentation/pages/operations_home_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  bool _checkingActiveRide = true;
  bool _hasActiveRide = false;

  Map<String, dynamic>? _activeRide;
  bool _activeRideIsDriver = false;

  final ApiClient _api = ApiClient();

  Timer? _rideRefreshTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _checkActiveRide();

    // Backup synchronization for ride changes happening
    // from another user, such as passenger bookings.
    _rideRefreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkActiveRide(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rideRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkActiveRide();
    }
  }

  Future<void> _checkActiveRide() async {
    try {
      final result = await _api.getActiveRide();

      if (!mounted) return;

      final hasActiveRide = result['active'] == true;

      Map<String, dynamic>? nextRide;
      bool nextIsDriver = _activeRideIsDriver;

      if (hasActiveRide) {
        nextRide = Map<String, dynamic>.from(result['commute']);
        nextIsDriver = result['is_driver'] == true;
      } else if (_activeRide != null) {
        // IMPORTANT:
        // Keep the existing RideDetailsScreen mounted when the backend
        // stops reporting the ride as active.
        //
        // This is necessary because a completed ride is intentionally
        // removed from /commutes/active, but RideDetailsScreen still needs
        // to remain alive long enough to show payment/rating/thank-you.
        //
        // The existing onRideEnded callback will clear this ride after
        // the post-ride flow is finished.
        nextRide = _activeRide;
      }

      final effectiveHasRide = nextRide != null;

      final rideChanged =
          _hasActiveRide != effectiveHasRide ||
          _activeRide?['id'] != nextRide?['id'] ||
          _activeRide?['status'] != nextRide?['status'] ||
          _activeRideIsDriver != nextIsDriver;

      if (!rideChanged && !_checkingActiveRide) return;

      setState(() {
        _hasActiveRide = effectiveHasRide;
        _activeRide = nextRide;
        _activeRideIsDriver = nextIsDriver;
        _checkingActiveRide = false;
      });
    } catch (_) {
      // During normal refreshes, keep the existing ride state if there is
      // a temporary network/API failure.
      if (_checkingActiveRide && mounted) {
        setState(() {
          _checkingActiveRide = false;
        });
      }
    }
  }

  Future<void> _clearCompletedRide() async {
    if (!mounted) return;

    setState(() {
      _hasActiveRide = false;
      _activeRide = null;
      _activeRideIsDriver = false;
    });

    // Sync with backend after the UI has been cleared.
    await _checkActiveRide();
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;

    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;
    final auth = context.watch<AuthProvider>();

    if (_checkingActiveRide) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAdmin =
        auth.user?.email?.toLowerCase() == 'omar.afeef654@gmail.com';

    final destinations = [
      (icon: Icons.home_rounded, label: 'Home'),
      (icon: Icons.route_rounded, label: 'Rides'),
      if (isAdmin)
        (icon: Icons.admin_panel_settings_rounded, label: 'Operations'),
      (icon: Icons.person_rounded, label: 'Profile'),
    ];

    final screens = [
      HomeScreen(
        activeRide: _activeRide,
        activeRideIsDriver: _activeRideIsDriver,
        onRideEnded: _clearCompletedRide,
        onRideChanged: _checkActiveRide,
      ),
      const MyRidesScreen(),
      if (isAdmin) const OperationsHomePage(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.navBarBg,
          border: Border(top: BorderSide(color: theme.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.isDark ? 0.25 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            height: 68,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            animationDuration: const Duration(milliseconds: 350),
            destinations: [
              for (var i = 0; i < destinations.length; i++)
                NavigationDestination(
                  icon: Icon(
                    destinations[i].icon,
                    color: i == 0 && _hasActiveRide ? theme.border : null,
                  ),
                  selectedIcon: Icon(
                    destinations[i].icon,
                    color: i == 0 && _hasActiveRide ? theme.border : null,
                  ),
                  label: destinations[i].label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App bar used across tab screens.
class CPoolAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CPoolAppBar({
    super.key,
    required this.title,
    this.showThemeToggle = false,
    this.actions,
  });

  final String title;
  final bool showThemeToggle;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
    );
  }
}

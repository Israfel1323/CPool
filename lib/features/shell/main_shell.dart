import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/theme_toggle.dart';
import '../chat/chat_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../commutes/offer_ride_screen.dart';
import '../rides/my_rides_screen.dart';
import '../search/search_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _destinations = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.search_rounded, label: 'Search'),
    (icon: Icons.route_rounded, label: 'Rides'),
    (icon: Icons.chat_bubble_rounded, label: 'Chat'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  final _screens = const [
    HomeScreen(),
    SearchScreen(),
    MyRidesScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;

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
          child: _screens[_currentIndex],
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
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.icon),
                  label: d.label,
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
    this.showThemeToggle = true,
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
      actions: [
        ...?actions,
        if (showThemeToggle) ...[
          const ThemeToggle(compact: true),
          const SizedBox(width: 12),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/theme_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Sun = switch to light mode. Crescent = switch to dark mode.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;
    final provider = context.watch<ThemeProvider>();
    final isDark = provider.isDark;

    return Semantics(
      button: true,
      label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: Tooltip(
        message: isDark ? 'Light mode' : 'Dark mode',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => provider.toggleTheme(),
            borderRadius: BorderRadius.circular(compact ? 12 : 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 14,
                vertical: compact ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: theme.elevated,
                borderRadius: BorderRadius.circular(compact ? 12 : 20),
                border: Border.all(color: theme.border),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: AppColors.violet600.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      return RotationTransition(
                        turns: Tween(begin: 0.75, end: 1.0).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Icon(
                      isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                      key: ValueKey(isDark),
                      size: compact ? 20 : 22,
                      color: isDark
                          ? const Color(0xFFFBBF24)
                          : AppColors.violet600,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 8),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                            fontSize: 13,
                            color: theme.textSecondary,
                          ),
                      child: Text(isDark ? 'Light' : 'Night'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

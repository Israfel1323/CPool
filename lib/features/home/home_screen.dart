import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../shell/main_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;

    return Scaffold(
      appBar: const CPoolAppBar(title: 'CPool'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _HeroCard(theme: theme),
          const SizedBox(height: 20),
          Text(
            'Pool types',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _PoolChip(
                icon: Icons.directions_car_rounded,
                label: 'CarPool',
                color: AppColors.violet500,
              ),
              _PoolChip(
                icon: Icons.two_wheeler_rounded,
                label: 'BikePool',
                color: AppColors.violet600,
              ),
              _PoolChip(
                icon: Icons.school_rounded,
                label: 'StudentPool',
                color: AppColors.violet700,
              ),
              _PoolChip(
                icon: Icons.female_rounded,
                label: 'Women only',
                color: Color(0xFFDB2777),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Quick actions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _ActionTile(
            theme: theme,
            icon: Icons.search_rounded,
            title: 'Find a commute',
            subtitle: 'Search nearby rides',
          ),
          _ActionTile(
            theme: theme,
            icon: Icons.add_road_rounded,
            title: 'Create commute',
            subtitle: 'Offer seats on your route',
          ),
          _ActionTile(
            theme: theme,
            icon: Icons.emergency_rounded,
            title: 'SOS',
            subtitle: 'Emergency help — always visible',
            accent: AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.theme});

  final CPoolThemeExtension theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.isDark
              ? [AppColors.violet800, AppColors.darkCard]
              : [AppColors.violet600, AppColors.violet700],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.violet600.withValues(alpha: theme.isDark ? 0.2 : 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good to ride together',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'MVP: auth, profiles, commutes, cost split, chat & SOS.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
          ),
        ],
      ),
    );
  }
}

class _PoolChip extends StatelessWidget {
  const _PoolChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent,
  });

  final CPoolThemeExtension theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? theme.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'verification_screen.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/theme_toggle.dart';
import '../auth/login_screen.dart';
import '../payments/payments_screen.dart';
import '../shell/main_shell.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: const CPoolAppBar(title: 'Profile', showThemeToggle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: theme.accentMuted,
                  child: Icon(Icons.person_rounded, size: 44, color: theme.accent),
                ),
                const SizedBox(height: 12),
                Text(
                  auth.isSignedIn ? auth.displayName : 'Sign in to continue',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  auth.isSignedIn
                      ? (auth.user?.email ?? '')
                      : 'Email or Google — no Twilio OTP cost',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (auth.syncError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'API sync: ${auth.syncError}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                if (auth.isSignedIn)
                  OutlinedButton(
                    onPressed: () => auth.signOut(),
                    child: const Text('Sign out'),
                  )
                else
                  FilledButton(
                    onPressed: () => Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text('Sign in'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _SectionHeader(title: 'Appearance'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.border),
            ),
            child: Row(
              children: [
                Icon(
                  theme.isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  color: theme.isDark
                      ? AppColors.violet400
                      : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme', style: Theme.of(context).textTheme.labelLarge),
                      Text(
                        theme.isDark
                            ? 'Night — black, grey & violet'
                            : 'Day — light violet & grey',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const ThemeToggle(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Verification'),
          const SizedBox(height: 8),
          _ProfileTile(
  theme: theme,
  icon: Icons.badge_outlined,
  title: 'Identity Verification',
  subtitle: 'Verify your identity to build trust in the CPool community',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const VerificationScreen(),
      ),
    );
  },
),
          _ProfileTile(
            theme: theme,
            icon: Icons.drive_eta_outlined,
            title: 'Driver verification',
            subtitle: auth.profile?['driver_verified'] == true
                ? 'Verified'
                : 'License & vehicle details',
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Account'),
          const SizedBox(height: 8),
          _ProfileTile(
            theme: theme,
            icon: Icons.history_rounded,
            title: 'Ride history',
          ),
          _ProfileTile(
            theme: theme,
            icon: Icons.star_outline_rounded,
            title: 'Ratings',
          ),
          _ProfileTile(
            theme: theme,
            icon: Icons.payments_outlined,
            title: 'Payments',
            subtitle: 'Razorpay — pay only on transactions',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PaymentsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.theme,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final CPoolThemeExtension theme;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: theme.border),
        ),
        tileColor: theme.card,
        leading: Icon(icon, color: theme.accent),
        title: Text(title, style: Theme.of(context).textTheme.labelLarge),
        subtitle: subtitle != null
            ? Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)
            : null,
        trailing: Icon(Icons.chevron_right_rounded, color: theme.textSecondary),
        onTap: onTap ?? () {},
      ),
    );
  }
}

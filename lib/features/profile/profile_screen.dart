import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'verification_screen.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/theme_toggle.dart';
import '../payments/payments_screen.dart';
import '../shell/main_shell.dart';
import 'complete_profile_screen.dart';

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
  child: Container(
    constraints: const BoxConstraints(maxWidth: 420),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: theme.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: theme.border),
    ),
    child: Column(
      children: [
        CircleAvatar(
  radius: 46,
  backgroundColor: theme.accentMuted,
  backgroundImage:
      auth.profile?['avatar_url'] != null &&
              (auth.profile!['avatar_url'] as String).isNotEmpty
          ? NetworkImage(auth.profile!['avatar_url'])
          : null,
  child:
      auth.profile?['avatar_url'] == null ||
              (auth.profile!['avatar_url'] as String).isEmpty
          ? Icon(
              Icons.person_rounded,
              size: 48,
              color: theme.accent,
            )
          : null,
),

        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                auth.profile?['full_name'] ?? auth.displayName,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),

            const SizedBox(width: 8),

            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          "MGIT • ${auth.profile?['branch'] ?? ''}",
          style: Theme.of(context).textTheme.bodyMedium,
        ),

        const SizedBox(height: 22),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
  final updated = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => CompleteProfileScreen(
        isEditing: true,
        profile: auth.profile,
      ),
    ),
  );

  if (updated == true && context.mounted) {
    await auth.refreshProfile();
  }
},
            icon: const Icon(Icons.edit_outlined),
            label: const Text("Edit Profile"),
          ),
        ),
      ],
    ),
  ),
),
          const SizedBox(height: 36),
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
          const SizedBox(height: 32),
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
          const SizedBox(height: 32),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.border),
        ),
        tileColor: theme.card,
        leading: Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    color: theme.accentMuted,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Icon(
    icon,
    color: theme.accent,
    size: 22,
  ),
),
        title: Text(title, style: Theme.of(context).textTheme.labelLarge),
        subtitle: subtitle != null
            ? Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)
            : null,
        trailing: const Icon(
  Icons.arrow_forward_ios_rounded,
  size: 16,
),
        onTap: onTap ?? () {},
      ),
    );
  }
}

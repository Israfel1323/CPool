import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../shell/main_shell.dart';
import '../rides/ride_details_screen.dart';

import 'widgets/greeting_section.dart';
import 'widgets/action_card.dart';

import '../search/search_screen.dart';
import '../commutes/offer_ride_screen.dart';

import '../profile/become_driver_screen.dart';
import '../../core/services/verification_service.dart';
import '../profile/verification_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.activeRide,
    this.activeRideIsDriver = false,
    this.onRideEnded,
    this.onRideChanged,
  });

  final Map<String, dynamic>? activeRide;
  final bool activeRideIsDriver;
  final Future<void> Function()? onRideEnded;
  final Future<void> Function()? onRideChanged;

  @override
  Widget build(BuildContext context) {
    final hasActiveRide = activeRide != null;

    // RideDetailsScreen owns a scrollable when it is embedded. Keeping it out
    // of the home ListView avoids two competing vertical scroll views and an
    // unnecessary viewport-sized gap below the ride content.
    if (hasActiveRide) {
      return Scaffold(
        appBar: const CPoolAppBar(title: 'CPool'),
        body: RideDetailsScreen(
          ride: activeRide!,
          isDriver: activeRideIsDriver,
          embedded: true,
          onRideEnded: () {
            onRideEnded?.call();
          },
        ),
      );
    }

    return Scaffold(
      appBar: const CPoolAppBar(title: 'CPool'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 104),
          children: [
            const GreetingSection(),

            const SizedBox(height: 12),

            Text(
              'Plan your commute',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            ActionCard(
              icon: Icons.search_rounded,
              iconBackgroundColor: AppColors.ridePurple,
              title: 'Find a ride',
              subtitle:
                  'Choose your pickup and destination to see rides nearby.',
              prominent: true,
              onTap: () async {
                final service = VerificationService();

                final canFindRide = await service.canFindRide();

                if (!context.mounted) return;

                if (canFindRide) {
                  final booked = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );

                  if (!context.mounted) return;

                  if (booked == true) {
                    await onRideChanged?.call();
                  }
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VerificationScreen(),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 24),

            Text(
              'Driving today?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            ActionCard(
              icon: Icons.directions_car_rounded,
              iconBackgroundColor: AppColors.offerTeal,
              title: 'Offer a ride',
              subtitle: 'Share your route and let fellow students join.',
              onTap: () async {
                final service = VerificationService();

                final canOfferRide = await service.canOfferRide();

                if (!context.mounted) return;

                if (canOfferRide) {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OfferRideScreen(),
                    ),
                  );

                  if (!context.mounted) return;

                  if (created == true) {
                    await onRideChanged?.call();
                  }
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BecomeDriverScreen(),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

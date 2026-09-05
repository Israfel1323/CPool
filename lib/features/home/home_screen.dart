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

    return Scaffold(
      appBar: const CPoolAppBar(title: 'CPool'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            if (hasActiveRide)
              _ActiveRideGreeting(isDriver: activeRideIsDriver)
            else
              const GreetingSection(),

            const SizedBox(height: 24),

            if (hasActiveRide)
              SizedBox(
                height: MediaQuery.of(context).size.height,
                child: RideDetailsScreen(
                  ride: activeRide!,
                  isDriver: activeRideIsDriver,
                  embedded: true,
                  onRideEnded: () {
                    onRideEnded?.call();
                  },
                ),
              )
            else ...[
              ActionCard(
                icon: Icons.search_rounded,
                iconBackgroundColor: AppColors.ridePurple,
                title: 'Find a ride',
                subtitle: 'Search rides going to your destination.',
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

              const SizedBox(height: 16),

              ActionCard(
                icon: Icons.directions_car_rounded,
                iconBackgroundColor: AppColors.offerTeal,
                title: 'Offer a ride',
                subtitle: 'Create a ride for others to join.',
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
          ],
        ),
      ),
    );
  }
}

class _ActiveRideGreeting extends StatelessWidget {
  const _ActiveRideGreeting({required this.isDriver});

  final bool isDriver;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;

    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 6),

        Text(
          isDriver
              ? 'Enjoy your current ride — drive safe!'
              : 'Enjoy your current ride!',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _ActiveRideDashboard extends StatelessWidget {
  const _ActiveRideDashboard({
    required this.ride,
    required this.isDriver,
    required this.onRideEnded,
    this.onRideChanged,
  });

  final Map<String, dynamic> ride;
  final bool isDriver;
  final Future<void> Function()? onRideEnded;
  final Future<void> Function()? onRideChanged;

  @override
  Widget build(BuildContext context) {
    final from = ride['from_address']?.toString().split(',').first ?? 'Pickup';

    final to = ride['to_address']?.toString().split(',').first ?? 'Destination';

    final status = ride['status']?.toString().toUpperCase() ?? 'OPEN';

    final seatsTotal = int.tryParse(ride['seats_total']?.toString() ?? '') ?? 0;

    final seatsAvailable = int.tryParse(
      ride['seats_available']?.toString() ?? '',
    );

    final costPaise =
        int.tryParse(ride['cost_per_seat_paise']?.toString() ?? '') ?? 0;

    final costRupees = costPaise / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR CURRENT RIDE',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 12),

        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isDriver
                          ? Icons.directions_car_filled_rounded
                          : Icons.airline_seat_recline_normal_rounded,
                      size: 28,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDriver
                                ? 'You are driving'
                                : 'You are a passenger',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),

                          const SizedBox(height: 2),

                          Text(
                            'Ride currently in progress',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),

                    Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: status == 'FULL'
                            ? Colors.orange
                            : status == 'STARTED'
                            ? Colors.blue
                            : Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                _RoutePoint(
                  icon: Icons.trip_origin_rounded,
                  label: 'FROM',
                  address: from,
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                  child: Container(
                    width: 2,
                    height: 28,
                    color: Theme.of(context).dividerColor,
                  ),
                ),

                _RoutePoint(
                  icon: Icons.location_on_rounded,
                  label: 'TO',
                  address: to,
                ),

                const SizedBox(height: 28),

                Divider(color: Theme.of(context).dividerColor),

                const SizedBox(height: 16),

                if (seatsAvailable != null)
                  _InfoRow(
                    icon: Icons.event_seat_rounded,
                    label: isDriver ? 'Seats available' : 'Seats',
                    value: '$seatsAvailable / $seatsTotal',
                  ),

                if (costPaise > 0) ...[
                  const SizedBox(height: 14),

                  _InfoRow(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Cost per seat',
                    value:
                        '₹${costRupees.toStringAsFixed(costRupees.truncateToDouble() == costRupees ? 0 : 2)}',
                  ),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              RideDetailsScreen(ride: ride, isDriver: isDriver),
                        ),
                      );

                      if (result == true && onRideEnded != null) {
                        await onRideEnded!();
                      }
                    },
                    icon: const Icon(Icons.more_horiz_rounded),
                    label: const Text('More Ride Options'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.icon,
    required this.label,
    required this.address,
  });

  final IconData icon;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                address,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),

        const SizedBox(width: 12),

        Expanded(child: Text(label)),

        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

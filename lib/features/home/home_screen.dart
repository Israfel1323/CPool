import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../shell/main_shell.dart';
import 'widgets/greeting_section.dart';
import 'widgets/action_card.dart';
import '../search/search_screen.dart';
import '../commutes/offer_ride_screen.dart';
import '../profile/become_driver_screen.dart';
import '../../core/services/verification_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CPoolAppBar(title: 'CPool'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            const GreetingSection(),
            ActionCard(
              icon: Icons.search_rounded,
              iconBackgroundColor: AppColors.ridePurple,
              title: "Find a ride",
              subtitle: "Search rides going to your destination.",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),

            ActionCard(
              icon: Icons.directions_car_rounded,
              iconBackgroundColor: AppColors.offerTeal,
              title: "Offer a ride",
              subtitle: "Create a ride for others to join.",
              onTap: () async {
                final service = VerificationService();

                final canOfferRide = await service.canOfferRide();

                if (!context.mounted) return;

                if (canOfferRide) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OfferRideScreen()),
                  );
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

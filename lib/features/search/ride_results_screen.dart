import 'package:flutter/material.dart';

import '../../core/models/commute.dart';
import '../rides/ride_details_screen.dart';

class RideResultsScreen extends StatelessWidget {
  final List<Commute> commutes;

  const RideResultsScreen({super.key, required this.commutes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Available Rides")),
      body: commutes.isEmpty
          ? const Center(
              child: Text("No rides found", style: TextStyle(fontSize: 18)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: commutes.length,
              itemBuilder: (context, index) {
                final ride = commutes[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.fromAddress,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text("→ ${ride.toAddress}"),

                        const SizedBox(height: 12),

                        Text("💺 Seats: ${ride.seatsAvailable}"),

                        Text("💰 ${ride.costDisplay}"),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final booked = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => RideDetailsScreen(
                                        ride: {
                                          'id': ride.id,
                                          'from_address': ride.fromAddress,
                                          'to_address': ride.toAddress,
                                          'from_lat': ride.fromLat,
                                          'from_lng': ride.fromLng,
                                          'to_lat': ride.toLat,
                                          'to_lng': ride.toLng,
                                          'pool_type': ride.poolType,
                                          'women_only': ride.womenOnly,
                                          'seats_total': ride.seatsTotal,
                                          'seats_available':
                                              ride.seatsAvailable,
                                          'cost_per_seat_paise':
                                              ride.costPerSeatPaise,
                                          'departure_at': ride.departureAt,
                                          'status': ride.status,
                                          'driver_name': ride.driverName,
                                        },
                                        isDriver: false,
                                      ),
                                    ),
                                  );

                              if (booked == true && context.mounted) {
                                Navigator.of(context).pop(true);
                              }
                            },
                            child: const Text("View Details"),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

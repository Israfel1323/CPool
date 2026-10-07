import 'package:flutter/material.dart';

import '../../core/models/commute.dart';
import '../rides/ride_details_screen.dart';

class RideResultsScreen extends StatelessWidget {
  final List<Commute> commutes;

  const RideResultsScreen({super.key, required this.commutes});

  Widget _buildDriverRating(Commute ride) {
    final rating = ride.driverRating;
    final ratingCount = ride.driverRatingCount;

    if (rating == null || ratingCount == 0) {
      return const Text(
        'New',
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, size: 18, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)} · $ratingCount ${ratingCount == 1 ? 'rating' : 'ratings'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

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

                        // Driver reputation.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.person_outline, size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ride.driverName?.trim().isNotEmpty == true
                                        ? ride.driverName!
                                        : 'Driver',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  _buildDriverRating(ride),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        if (ride.departureAt != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 19),
                              const SizedBox(width: 6),
                              Text(
                                'Departure: ${MaterialLocalizations.of(context).formatMediumDate(ride.departureAt!)} • '
                                '${TimeOfDay.fromDateTime(ride.departureAt!).format(context)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                        ],

                        Text("Seats: ${ride.seatsAvailable}"),

                        Text(ride.costDisplay),

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
                                          'driver_rating': ride.driverRating,
                                          'driver_rating_count':
                                              ride.driverRatingCount,
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

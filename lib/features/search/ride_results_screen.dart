import 'package:flutter/material.dart';

import '../../core/models/commute.dart';

class RideResultsScreen extends StatelessWidget {
  final List<Commute> commutes;

  const RideResultsScreen({
    super.key,
    required this.commutes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Rides"),
      ),
      body: commutes.isEmpty
          ? const Center(
              child: Text(
                "No rides found",
                style: TextStyle(fontSize: 18),
              ),
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
                            onPressed: () {},
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
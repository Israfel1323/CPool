import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';

class RideDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
   final bool isDriver;

  const RideDetailsScreen({
    super.key,
    required this.ride,
    required this.isDriver,
  });

  @override
  State<RideDetailsScreen> createState() =>
      _RideDetailsScreenState();
}

class _RideDetailsScreenState
    extends State<RideDetailsScreen> {
  final _api = ApiClient();

  late Future<List<dynamic>> _passengersFuture;

  @override
  void initState() {
    super.initState();

    _passengersFuture =
        _api.getPassengers(widget.ride['id']);
  }

  @override
  Widget build(BuildContext context) {
    print('isDriver = ${widget.isDriver}');
    final departure =
        DateTime.tryParse(
              widget.ride['departure_at']
                      ?.toString() ??
                  '',
            ) ??
            DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ride Details',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.ride['from_address'].toString().split(',').first} → '
                '${widget.ride['to_address'].toString().split(',').first}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                '📅 ${DateFormat('dd MMM yyyy • hh:mm a').format(departure)}',
              ),

              const SizedBox(height: 12),

              Text(
                widget.ride['pool_type'] ==
                        'bikepool'
                    ? '🏍 Bikepool'
                    : '🚗 Carpool',
              ),

              const SizedBox(height: 12),

              Text(
                '👤 Driver: ${widget.ride['driver_name']}',
              ),

              const SizedBox(height: 12),

              Text(
                '💺 Seats Available: ${widget.ride['seats_available']} / ${widget.ride['seats_total']}',
              ),

              const SizedBox(height: 12),

              Text(
                '💰 ₹${(widget.ride['cost_per_seat_paise'] ?? 0) ~/ 100} per seat',
              ),

              const SizedBox(height: 12),

              Text(
                '📌 Status: ${widget.ride['status']}',
              ),

              if (widget.ride['status'] ==
                  'completed')
                const Text(
                  '✅ Ride Completed',
                ),

              if (widget.ride['status'] ==
                  'cancelled')
                const Text(
                  '❌ Ride Cancelled',
                ),

              const SizedBox(height: 24),
if (widget.isDriver)
              FutureBuilder<List<dynamic>>(
                future: _passengersFuture,
                builder: (context, snapshot) {
                  if (snapshot
                          .connectionState ==
                      ConnectionState
                          .waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  if (snapshot
                      .hasError) {
                    return Text(
                      'Error: ${snapshot.error}',
                    );
                  }

                  final passengers =
                      snapshot.data ?? [];

                  if (passengers
                      .isEmpty) {
                    return const SizedBox
                        .shrink();
                  }

                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'Passengers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      ...passengers
                          .map<Widget>(
                        (p) => ListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          leading:
                              const Icon(
                            Icons.person,
                          ),
                          title: Text(
                            p['display_name'] ??
                                'Unknown',
                          ),
                          subtitle:
                              Text(
                            '${p['seats']} seat(s)',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

if (widget.isDriver &&
    (widget.ride['status'] == 'open' ||
     widget.ride['status'] == 'full')) ...[

  const SizedBox(height: 24),

  ElevatedButton.icon(
    onPressed: () async {
      await _api.completeRide(
        widget.ride['id'],
      );

      if (!mounted) return;

      Navigator.pop(context);
    },
    icon: const Icon(Icons.check_circle),
    label: const Text('Complete Ride'),
  ),

  const SizedBox(height: 12),

  ElevatedButton.icon(
    onPressed: () async {
      await _api.cancelRide(
        widget.ride['id'],
      );

      if (!mounted) return;

      Navigator.pop(context);
    },
    icon: const Icon(Icons.cancel),
    label: const Text('Cancel Ride'),
  ),
],

if (!widget.isDriver &&
    (widget.ride['status'] == 'open' ||
     widget.ride['status'] == 'full')) ...[

  const SizedBox(height: 24),

  ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
    ),
    onPressed: () async {
      await _api.cancelBooking(
        widget.ride['id'],
      );

      if (!mounted) return;

      Navigator.pop(context);
    },
    icon: const Icon(Icons.cancel),
    label: const Text('Cancel Booking'),
  ),
],
            ],
          ),
        ),
      ),
    );
  }
}
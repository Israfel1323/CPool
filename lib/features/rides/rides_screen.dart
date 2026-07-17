import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../shell/main_shell.dart';
import 'ride_details_screen.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  final ApiClient _api = ApiClient();
late Future<List<dynamic>> _createdRidesFuture;
late Future<List<dynamic>> _bookedRidesFuture;
late Future<List<dynamic>> _historyFuture;

 @override
void initState() {
  super.initState();

  _createdRidesFuture =
      _api.myCreatedRides();

  _bookedRidesFuture =
      _api.myBookedRides();
      _historyFuture =
    _api.myRideHistory();
}

Future<void> _refresh() async {
  setState(() {
    _createdRidesFuture =
        _api.myCreatedRides();

    _bookedRidesFuture =
        _api.myBookedRides();
        _historyFuture =
    _api.myRideHistory();
  });
}
Widget _ridesList(
  Future<List<dynamic>> future, {
  required bool isDriver,
}) {
  return RefreshIndicator(
    onRefresh: _refresh,
    child: FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
            ),
          );
        }

        final rides = snapshot.data ?? [];

        if (rides.isEmpty) {
          return const Center(
            child: Text(
              'No rides found',
            ),
          );
        }

        return ListView.builder(
          itemCount: rides.length,
          itemBuilder: (context, index) {
            final ride = rides[index];

            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: ListTile(
onTap: () {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => RideDetailsScreen(
        ride: ride,
        isDriver: isDriver,
      ),
    ),
  );
},
                leading: const Icon(
                  Icons.directions_car,
                ),
                title: Text(
  '${ride['from_address'].toString().split(',').first} → '
  '${ride['to_address'].toString().split(',').first}',
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
                subtitle: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
  'Departure: ${DateFormat(
    'dd MMM yyyy • hh:mm a',
  ).format(
    DateTime.parse(
      ride['departure_at'],
    ).toLocal(),
  )}',
),
Text(
  ride['pool_type'] == 'bikepool'
      ? '🏍 Bikepool'
      : '🚗 Carpool',
),
                    Text(
                      'Driver: ${ride['driver_name']}',
                    ),
                    Text(
                      'Seats: ${ride['seats_available']}/${ride['seats_total']}',
                    ),
                    Text(
                      '₹${(ride['cost_per_seat_paise'] ?? 0) ~/ 100} per seat',
                    ),
                    Text(
                      'Status: ${ride['status']}',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
  @override
  Widget build(BuildContext context) {
   return Scaffold(
  appBar: const CPoolAppBar(
    title: 'My Rides',
  ),
  body: DefaultTabController(
    length: 3,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: 'Created'),
            Tab(text: 'Booked'),
            Tab(text: 'History'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _ridesList(
                _createdRidesFuture,
                isDriver: true,
              ),
              _ridesList(
                _bookedRidesFuture,
                isDriver: false,
              ),
              _ridesList(
                _historyFuture,
                isDriver: true,
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
}
}
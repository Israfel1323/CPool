import 'package:flutter/material.dart';

class SearchFilters extends StatelessWidget {
  const SearchFilters({
    super.key,
    required this.womenOnly,
    required this.bikeRide,
    required this.onWomenOnlyChanged,
    required this.onBikeRideChanged,
  });

  final bool womenOnly;
  final bool bikeRide;

  final ValueChanged<bool> onWomenOnlyChanged;
  final ValueChanged<bool> onBikeRideChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filters',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),

        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Women Only'),
                secondary: const Icon(Icons.woman_rounded),
                value: womenOnly,
                onChanged: onWomenOnlyChanged,
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Bike Ride'),
                secondary: const Icon(Icons.two_wheeler_rounded),
                value: bikeRide,
                onChanged: onBikeRideChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
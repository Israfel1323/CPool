import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_client.dart';

class TripSafetyShareScreen extends StatefulWidget {
  final String shareToken;

  const TripSafetyShareScreen({super.key, required this.shareToken});

  @override
  State<TripSafetyShareScreen> createState() => _TripSafetyShareScreenState();
}

class _TripSafetyShareScreenState extends State<TripSafetyShareScreen> {
  final ApiClient _api = ApiClient();
  final MapController _mapController = MapController();

  Timer? _refreshTimer;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _session;

  @override
  void initState() {
    super.initState();

    _loadSharedTrip();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadSharedTrip(),
    );
  }

  Future<void> _loadSharedTrip() async {
    try {
      final session = await _api.getSharedTripSafety(widget.shareToken);

      if (!mounted) return;

      setState(() {
        _session = session;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load this shared trip.';
        _loading = false;
      });
    }
  }

  String _text(dynamic value) {
    if (value == null) return 'Not available';

    final text = value.toString().trim();

    if (text.isEmpty) return 'Not available';

    return text;
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Not available';

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) {
      return value.toString();
    }

    final local = parsed.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year • $hour:$minute $period';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Safety'), centerTitle: true),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'Trip safety link unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });

                  _loadSharedTrip();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final session = _session;

    if (session == null || session.isEmpty) {
      return const Center(
        child: Text('Trip safety information is unavailable.'),
      );
    }

    final status = _text(session['status']).toUpperCase();
    final displayName = _text(session['display_name']);
    final fromAddress = _text(session['from_address']);
    final toAddress = _text(session['to_address']);
    final departureAt = _formatDate(session['departure_at']);

    final latitude = session['latest_latitude'];
    final longitude = session['latest_longitude'];

    final hasLocation = latitude != null && longitude != null;

    return RefreshIndicator(
      onRefresh: _loadSharedTrip,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildProtectionCard(context, status),
          const SizedBox(height: 24),

          const Text(
            'Trip details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          _buildInfoCard(
            context,
            icon: Icons.person_outline,
            title: 'Traveller',
            value: displayName,
          ),

          const SizedBox(height: 12),

          _buildInfoCard(
            context,
            icon: Icons.trip_origin,
            title: 'From',
            value: fromAddress,
          ),

          const SizedBox(height: 12),

          _buildInfoCard(
            context,
            icon: Icons.location_on_outlined,
            title: 'To',
            value: toAddress,
          ),

          const SizedBox(height: 12),

          _buildInfoCard(
            context,
            icon: Icons.schedule,
            title: 'Departure',
            value: departureAt,
          ),

          const SizedBox(height: 24),

          const Text(
            'Live location',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          _buildLocationCard(
            context,
            hasLocation: hasLocation,
            latitude: latitude,
            longitude: longitude,
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              'Shared securely by CPool Trip Safety',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProtectionCard(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;

    final isActive = status == 'ACTIVE';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield, size: 38, color: colorScheme.primary),
          ),
          const SizedBox(height: 18),
          const Text(
            'Trip Safety',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isActive
                ? 'This trip is currently protected.'
                : 'This trip safety session has ended.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.green.withValues(alpha: 0.15)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.green : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _recenterMap(double latitude, double longitude) {
    _mapController.move(
      LatLng(latitude, longitude),
      _mapController.camera.zoom,
    );
  }

  Widget _buildLocationCard(
    BuildContext context, {
    required bool hasLocation,
    required dynamic latitude,
    required dynamic longitude,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!hasLocation) {
      return Container(
        height: 260,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 48, color: colorScheme.primary),
            const SizedBox(height: 14),
            const Text(
              'Waiting for live location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'The traveller has not shared a location update yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final lat = double.tryParse(latitude.toString());
    final lng = double.tryParse(longitude.toString());

    if (lat == null || lng == null) {
      return Container(
        height: 260,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'Live location is temporarily unavailable.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final position = LatLng(lat, lng);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        _mapController.move(position, _mapController.camera.zoom);
      } catch (_) {
        // Map may not be mounted yet.
      }
    });
    return Container(
      height: 320,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: position, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cpool.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: position,
                    width: 60,
                    height: 60,
                    child: Icon(
                      Icons.location_on,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              color: Theme.of(context).colorScheme.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _recenterMap(lat, lng),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.my_location),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Traveller location',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                  const SizedBox(width: 5),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

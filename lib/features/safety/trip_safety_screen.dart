import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_client.dart';

class TripSafetyScreen extends StatefulWidget {
  final String commuteId;

  const TripSafetyScreen({super.key, required this.commuteId});

  @override
  State<TripSafetyScreen> createState() => _TripSafetyScreenState();
}

class _TripSafetyScreenState extends State<TripSafetyScreen> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  bool _sharing = false;
  Map<String, dynamic>? _session;

  StreamSubscription<Position>? _positionSubscription;
  bool _locationSharing = false;
  bool _locationPermissionDenied = false;
  DateTime? _lastLocationSentAt;

  @override
  void initState() {
    super.initState();
    _loadSafetySession();
  }

  Future<void> _loadSafetySession() async {
    try {
      final session = await _api.getTripSafetySession(widget.commuteId);

      if (!mounted) return;

      setState(() {
        _session = session;
        _loading = false;
      });

      final status = (session['status'] ?? '').toString().toLowerCase();

      if (status == 'active') {
        await _startLocationSharing();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load trip safety: $e')));
    }
  }

  Future<void> _startLocationSharing() async {
    if (_positionSubscription != null) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _locationPermissionDenied = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enable location services to share your live location.',
            ),
          ),
        );

        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _locationPermissionDenied = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required for Trip Safety.'),
          ),
        );

        return;
      }

      if (!mounted) return;

      setState(() {
        _locationPermissionDenied = false;
        _locationSharing = true;
      });

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      );

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (position) {
              _sendLocationUpdate(position);
            },
            onError: (error) {
              debugPrint('Trip Safety location stream error: $error');
            },
          );

      try {
        final currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings,
        );

        await _sendLocationUpdate(currentPosition);
      } catch (e) {
        debugPrint('Initial Trip Safety location error: $e');
      }
    } catch (e) {
      debugPrint('Unable to start Trip Safety location: $e');

      if (!mounted) return;

      setState(() {
        _locationSharing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start live location: $e')),
      );
    }
  }

  Future<void> _sendLocationUpdate(Position position) async {
    final now = DateTime.now();

    if (_lastLocationSentAt != null &&
        now.difference(_lastLocationSentAt!) < const Duration(seconds: 10)) {
      return;
    }

    final status = (_session?['status'] ?? '').toString().toLowerCase();

    if (status != 'active') {
      return;
    }

    try {
      final updatedSession = await _api.updateTripSafetyLocation(
        commuteId: widget.commuteId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      _lastLocationSentAt = now;

      if (!mounted) return;

      setState(() {
        _session = {...?_session, ...updatedSession};
      });
    } catch (e) {
      debugPrint('Trip Safety location update failed: $e');
    }
  }

  Future<void> _stopLocationSharing() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    if (!mounted) return;

    setState(() {
      _locationSharing = false;
    });
  }

  Future<void> _shareTrip() async {
    if (_sharing) return;

    setState(() {
      _sharing = true;
    });

    try {
      final apiShareLink = await _api.getTripSafetyShareLink(widget.commuteId);

      if (!mounted) return;

      final apiUri = Uri.tryParse(apiShareLink);

      if (apiUri == null || apiUri.pathSegments.isEmpty) {
        throw Exception('Invalid trip safety link.');
      }

      // On Android/iOS, Uri.base can be a file:// URI. Its origin must
      // never be used for a web share link. The backend already returns the
      // complete HTTP(S) share URL, so use it directly.
      final publicShareLink = apiShareLink;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.share_outlined),
                SizedBox(width: 10),
                Expanded(child: Text('Share your trip')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send this secure link to a trusted person so they can follow your trip.',
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    publicShareLink,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: publicShareLink));

                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trip link copied!')),
                  );
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy link'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to create trip link: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
        });
      }
    }
  }

  Future<void> _triggerSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.emergency_outlined),
              SizedBox(width: 10),
              Text('Emergency Help'),
            ],
          ),
          content: const Text(
            'Are you sure you want to send an SOS alert? '
            'Your emergency contacts will be notified that you may need help.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.emergency),
              label: const Text('Send SOS'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _api.triggerSosAlert(commuteId: widget.commuteId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SOS alert activated.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to activate SOS. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Safety')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadSafetySession,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.shield_rounded,
                              size: 34,
                              color: primary,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            'Your trip is protected',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Your Trip Safety session is active while this ride is in progress.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Safety Session',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.circle,
                              title: 'Status',
                              value: (_session?['status'] ?? 'unknown')
                                  .toString()
                                  .toUpperCase(),
                            ),

                            const Divider(height: 28),

                            _InfoRow(
                              icon: Icons.verified_user_outlined,
                              title: 'Secure session',
                              value: 'Active',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'What this will do',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Card(
                      child: Column(
                        children: [
                          InkWell(
                            onTap: _sharing ? null : _shareTrip,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.share_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Share your trip',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Let a trusted person follow your trip safely.',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_sharing)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                          _SafetyFeatureTile(
                            icon: Icons.location_on_outlined,
                            title: 'Live location',
                            subtitle:
                                'Your location can be updated during the ride.',
                          ),
                          _SafetyFeatureTile(
                            icon: Icons.emergency_outlined,
                            title: 'Emergency help',
                            subtitle:
                                'Send an SOS alert to your emergency contacts.',
                            onTap: _triggerSos,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 21, color: primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your emergency contacts are managed from your Profile. '
                              'You can add up to two trusted contacts.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SafetyFeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SafetyFeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      onTap: onTap,
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
    );
  }
}

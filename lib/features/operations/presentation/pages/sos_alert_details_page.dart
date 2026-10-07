import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/app_page_header.dart';
import '../../models/sos_alert.dart';
import '../../services/operations_service.dart';

class SosAlertDetailsPage extends StatefulWidget {
  const SosAlertDetailsPage({super.key, required this.alertId});

  final String alertId;

  @override
  State<SosAlertDetailsPage> createState() => _SosAlertDetailsPageState();
}

class _SosAlertDetailsPageState extends State<SosAlertDetailsPage> {
  final OperationsService _service = OperationsService();
  final MapController _mapController = MapController();

  Timer? _refreshTimer;

  SosAlert? _alert;
  bool _loading = true;
  bool _resolving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _loadAlert();

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_alert?.isActive == true) {
        _loadAlert(silent: true);
      }
    });
  }

  Future<void> _loadAlert({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final alert = await _service.getSosAlert(widget.alertId);

      if (!mounted) return;

      setState(() {
        _alert = alert;
        _loading = false;
        _error = null;
      });

      _moveMapToLocation(alert);
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _loading = false;
          _error = 'Unable to load this SOS alert.';
        });
      }
    }
  }

  void _moveMapToLocation(SosAlert alert) {
    final latitude = alert.latestLatitude ?? alert.latitude;
    final longitude = alert.latestLongitude ?? alert.longitude;

    if (latitude == null || longitude == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        _mapController.move(
          LatLng(latitude, longitude),
          _mapController.camera.zoom,
        );
      } catch (_) {
        // Map may not be mounted yet.
      }
    });
  }

  Future<void> _resolveAlert() async {
    final alert = _alert;

    if (alert == null || !alert.isActive || _resolving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Resolve SOS alert?'),
          content: const Text(
            'Confirm that this emergency alert has been reviewed '
            'and no further action is required.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Resolve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _resolving = true;
    });

    try {
      final resolvedAlert = await _service.resolveSosAlert(alert.id);

      if (!mounted) return;

      setState(() {
        _alert = resolvedAlert;
        _resolving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS alert resolved successfully.')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _resolving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to resolve SOS alert. Please try again.'),
        ),
      );
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not available';

    final local = value.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year • $hour:$minute $period';
  }

  String _formatCoordinate(double? value) {
    if (value == null) return 'Not available';
    return value.toStringAsFixed(6);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: _buildBody(context)));
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadAlert);
    }

    final alert = _alert;

    if (alert == null) {
      return const Center(child: Text('SOS alert information is unavailable.'));
    }

    return RefreshIndicator(
      onRefresh: _loadAlert,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          AppPageHeader(
            title: 'SOS Incident',
            showBackButton: true,
            subtitle: 'Emergency alert details and live trip location.',
            trailing: IconButton(
              tooltip: 'Refresh',
              onPressed: () => _loadAlert(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),

          const SizedBox(height: 8),

          _buildStatusCard(context, alert),

          const SizedBox(height: 20),

          _buildPersonCard(context, alert),

          const SizedBox(height: 20),

          _buildTripCard(context, alert),

          const SizedBox(height: 20),

          _buildLocationSection(context, alert),

          if (alert.message != null && alert.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildMessageCard(context, alert),
          ],

          const SizedBox(height: 20),

          _buildSessionCard(context, alert),

          if (alert.isActive) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _resolving ? null : _resolveAlert,
                icon: _resolving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(_resolving ? 'Resolving...' : 'Resolve Alert'),
              ),
            ),
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, SosAlert alert) {
    final theme = Theme.of(context);
    final isActive = alert.isActive;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.error.withValues(alpha: 0.55)
              : theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.error.withValues(alpha: 0.12)
                  : theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive
                  ? Icons.emergency_rounded
                  : Icons.check_circle_outline_rounded,
              size: 32,
              color: isActive
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'Active SOS Alert' : 'Resolved SOS Alert',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Triggered ${_formatDate(alert.createdAt)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonCard(BuildContext context, SosAlert alert) {
    return _SectionCard(
      title: 'Person',
      icon: Icons.person_outline_rounded,
      children: [
        _DetailRow(label: 'Name', value: alert.displayName),
        _DetailRow(
          label: 'Phone',
          value: alert.userPhone?.trim().isNotEmpty == true
              ? alert.userPhone!
              : 'Not available',
        ),
        _DetailRow(
          label: 'Email',
          value: alert.userEmail?.trim().isNotEmpty == true
              ? alert.userEmail!
              : 'Not available',
        ),
      ],
    );
  }

  Widget _buildTripCard(BuildContext context, SosAlert alert) {
    return _SectionCard(
      title: 'Trip',
      icon: Icons.route_rounded,
      children: [
        _DetailRow(label: 'From', value: alert.fromAddress ?? 'Not available'),
        _DetailRow(label: 'To', value: alert.toAddress ?? 'Not available'),
        _DetailRow(label: 'Departure', value: _formatDate(alert.departureAt)),
        _DetailRow(
          label: 'Commute status',
          value: alert.commuteStatus ?? 'Not available',
        ),
      ],
    );
  }

  Widget _buildLocationSection(BuildContext context, SosAlert alert) {
    final latitude = alert.latestLatitude ?? alert.latitude;
    final longitude = alert.latestLongitude ?? alert.longitude;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Location',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _buildMap(
          context,
          alert: alert,
          latitude: latitude,
          longitude: longitude,
        ),
      ],
    );
  }

  Widget _buildMap(
    BuildContext context, {
    required SosAlert alert,
    required double? latitude,
    required double? longitude,
  }) {
    final theme = Theme.of(context);

    if (latitude == null || longitude == null) {
      return Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Live location is not available for this alert.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final position = LatLng(latitude, longitude);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 340,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: position, initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.cpool.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: position,
                        width: 60,
                        height: 60,
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 50,
                          color: theme.colorScheme.error,
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
                  color: theme.colorScheme.surface,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      _mapController.move(position, _mapController.camera.zoom);
                    },
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Current traveller location',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (alert.isActive) ...[
                        const Icon(
                          Icons.circle,
                          color: Colors.greenAccent,
                          size: 10,
                        ),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        _DetailRow(label: 'Latitude', value: _formatCoordinate(latitude)),

        _DetailRow(label: 'Longitude', value: _formatCoordinate(longitude)),

        _DetailRow(
          label: 'Last location update',
          value: _formatDate(alert.lastLocationUpdateAt),
        ),
      ],
    );
  }

  Widget _buildMessageCard(BuildContext context, SosAlert alert) {
    return _SectionCard(
      title: 'SOS Message',
      icon: Icons.message_outlined,
      children: [
        Text(alert.message!, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  Widget _buildSessionCard(BuildContext context, SosAlert alert) {
    return _SectionCard(
      title: 'Safety Session',
      icon: Icons.shield_outlined,
      children: [
        _DetailRow(
          label: 'Session started',
          value: _formatDate(alert.sessionStartedAt),
        ),
        _DetailRow(
          label: 'Session ended',
          value: _formatDate(alert.sessionEndedAt),
        ),
        _DetailRow(
          label: 'Session expires',
          value: _formatDate(alert.sessionExpiresAt),
        ),
        _DetailRow(
          label: 'Alert resolved',
          value: _formatDate(alert.resolvedAt),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 52),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

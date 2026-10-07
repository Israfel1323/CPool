import 'package:flutter/material.dart';

import '../../../../core/widgets/app_page_header.dart';
import '../../models/sos_alert.dart';
import '../../services/operations_service.dart';
import 'sos_alert_details_page.dart';

class SosAlertsPage extends StatefulWidget {
  const SosAlertsPage({super.key});

  @override
  State<SosAlertsPage> createState() => _SosAlertsPageState();
}

class _SosAlertsPageState extends State<SosAlertsPage> {
  final OperationsService _service = OperationsService();

  List<SosAlert> _alerts = [];
  bool _loading = true;
  String? _error;
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final alerts = await _service.getSosAlerts(status: _status);

      if (!mounted) return;

      setState(() {
        _alerts = alerts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Unable to load SOS alerts.';
      });
    }
  }

  Future<void> _resolveAlert(SosAlert alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Resolve SOS alert?'),
          content: const Text(
            'This will mark the SOS alert as resolved. '
            'Only do this after the incident has been reviewed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Resolve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final resolvedAlert = await _service.resolveSosAlert(alert.id);

      if (!mounted) return;

      setState(() {
        if (_status == 'active') {
          _alerts.removeWhere((item) => item.id == alert.id);
        } else {
          final index = _alerts.indexWhere((item) => item.id == alert.id);

          if (index != -1) {
            _alerts[index] = resolvedAlert;
          }
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SOS alert resolved.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to resolve SOS alert.')),
      );
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Unknown time';

    final local = value.toLocal();

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAlerts,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              AppPageHeader(
                title: 'SOS Alerts',
                showBackButton: true,
                subtitle: 'Review active and resolved emergency alerts.',
                trailing: IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loadAlerts,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),

              const SizedBox(height: 8),

              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'active',
                    label: Text('Active'),
                    icon: Icon(Icons.warning_amber_rounded),
                  ),
                  ButtonSegment(
                    value: 'resolved',
                    label: Text('Resolved'),
                    icon: Icon(Icons.check_circle_outline_rounded),
                  ),
                  ButtonSegment(
                    value: 'all',
                    label: Text('All'),
                    icon: Icon(Icons.list_alt_rounded),
                  ),
                ],
                selected: {_status},
                onSelectionChanged: (selection) {
                  setState(() {
                    _status = selection.first;
                  });
                  _loadAlerts();
                },
              ),

              const SizedBox(height: 20),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorState(message: _error!, onRetry: _loadAlerts)
              else if (_alerts.isEmpty)
                const _EmptyState()
              else
                ..._alerts.map(
                  (alert) => _SosAlertCard(
                    alert: alert,
                    formattedDate: _formatDate(alert.createdAt),
                    onResolve: alert.isActive
                        ? () => _resolveAlert(alert)
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SosAlertDetailsPage(alertId: alert.id),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosAlertCard extends StatelessWidget {
  const _SosAlertCard({
    required this.alert,
    required this.formattedDate,
    this.onResolve,
    this.onTap,
  });

  final SosAlert alert;
  final String formattedDate;
  final VoidCallback? onResolve;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = alert.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.emergency_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      alert.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(label: Text(alert.status.toUpperCase())),
                ],
              ),

              const SizedBox(height: 14),

              _InfoRow(icon: Icons.access_time_rounded, label: formattedDate),

              if (alert.userPhone != null && alert.userPhone!.trim().isNotEmpty)
                _InfoRow(icon: Icons.phone_outlined, label: alert.userPhone!),

              if (alert.fromAddress != null || alert.toAddress != null)
                _InfoRow(
                  icon: Icons.route_rounded,
                  label:
                      '${alert.fromAddress ?? 'Unknown'} → '
                      '${alert.toAddress ?? 'Unknown'}',
                ),

              if (alert.latitude != null && alert.longitude != null)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label:
                      '${alert.latitude!.toStringAsFixed(6)}, '
                      '${alert.longitude!.toStringAsFixed(6)}',
                ),

              if (alert.message != null &&
                  alert.message!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Text(
                    alert.message!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],

              const SizedBox(height: 10),

              Row(
                children: [
                  const Spacer(),
                  Text(
                    'View details',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),

              if (onResolve != null) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onResolve,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Resolve Alert'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Column(
        children: [
          Icon(Icons.shield_outlined, size: 52),
          const SizedBox(height: 16),
          Text(
            'No SOS alerts',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'There are no alerts matching this filter.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

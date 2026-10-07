import 'package:flutter/material.dart';

import '../../../../../../core/api/api_client.dart';
import '../../../../../../core/widgets/app_page_header.dart';
import 'customer_support_ticket_page.dart';

class CustomerSupportDashboardPage extends StatefulWidget {
  const CustomerSupportDashboardPage({super.key});

  @override
  State<CustomerSupportDashboardPage> createState() =>
      _CustomerSupportDashboardPageState();
}

class _CustomerSupportDashboardPageState
    extends State<CustomerSupportDashboardPage> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  String _status = 'open';
  List<dynamic> _tickets = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _api.getOperationsSupportTickets(status: _status);

      final data = response['data'];
      final items = data is Map ? data['items'] : null;

      if (!mounted) return;

      setState(() {
        _tickets = items is List ? items : <dynamic>[];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load support tickets.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTickets,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              AppPageHeader(
                title: "Customer Support",
                subtitle: "Review and resolve customer support tickets.",
                showBackButton: true,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'open',
                    label: Text('Open'),
                    icon: Icon(Icons.inbox_rounded),
                  ),
                  ButtonSegment(
                    value: 'resolved',
                    label: Text('Resolved'),
                    icon: Icon(Icons.check_circle_outline_rounded),
                  ),
                ],
                selected: {_status},
                onSelectionChanged: (value) {
                  setState(() => _status = value.first);
                  _loadTickets();
                },
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorCard(message: _error!, onRetry: _loadTickets)
              else if (_tickets.isEmpty)
                const _EmptyCard()
              else
                ..._tickets.map(
                  (ticket) => _TicketCard(
                    ticket: Map<String, dynamic>.from(ticket as Map),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerSupportTicketPage(
                            ticketId: ticket['id'].toString(),
                          ),
                        ),
                      );
                      if (mounted) _loadTickets();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = ticket['status']?.toString() ?? 'open';
    final category = ticket['category']?.toString() ?? 'Support';
    final description = ticket['description']?.toString() ?? '';
    final userName = ticket['user_name']?.toString() ?? 'Customer';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(status.toUpperCase()),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Text(userName, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.support_agent_rounded, size: 42),
            const SizedBox(height: 12),
            Text(
              'No tickets here',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'New customer support tickets will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(message),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

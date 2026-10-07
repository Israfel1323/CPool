import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/app_page_header.dart';

class CustomerSupportTicketPage extends StatefulWidget {
  final String ticketId;

  const CustomerSupportTicketPage({super.key, required this.ticketId});

  @override
  State<CustomerSupportTicketPage> createState() =>
      _CustomerSupportTicketPageState();
}

class _CustomerSupportTicketPageState extends State<CustomerSupportTicketPage> {
  final ApiClient _api = ApiClient();
  final TextEditingController _replyController = TextEditingController();
  Timer? _pollTimer;
  bool _polling = false;

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _ticket;
  List<dynamic> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadTicket();

    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollTicket(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadTicket() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _api.getOperationsSupportTicket(widget.ticketId);
      final data = response['data'];

      if (!mounted) return;

      setState(() {
        _ticket = data is Map
            ? Map<String, dynamic>.from(data['ticket'] as Map)
            : null;
        _messages = data is Map && data['messages'] is List
            ? data['messages'] as List
            : <dynamic>[];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load this support ticket.';
      });
    }
  }

  Future<void> _pollTicket() async {
    if (_polling || !mounted) return;

    _polling = true;

    try {
      final response = await _api.getOperationsSupportTicket(widget.ticketId);

      if (!mounted) return;

      final data = response['data'];

      final newTicket = data is Map && data['ticket'] is Map
          ? Map<String, dynamic>.from(data['ticket'] as Map)
          : null;

      final newMessages = data is Map && data['messages'] is List
          ? data['messages'] as List
          : <dynamic>[];

      final oldStatus = _ticket?['status']?.toString();
      final newStatus = newTicket?['status']?.toString();

      final oldCount = _messages.length;
      final newCount = newMessages.length;

      final oldLastId = _messages.isNotEmpty
          ? (_messages.last as Map)['id']?.toString()
          : null;

      final newLastId = newMessages.isNotEmpty
          ? (newMessages.last as Map)['id']?.toString()
          : null;

      final changed =
          oldStatus != newStatus ||
          oldCount != newCount ||
          oldLastId != newLastId;

      if (!changed) return;

      setState(() {
        _ticket = newTicket;
        _messages = newMessages;
      });
    } catch (_) {
      // Silent polling failure.
    } finally {
      _polling = false;
    }
  }

  Future<void> _reply() async {
    final message = _replyController.text.trim();
    if (message.isEmpty || _submitting) return;

    setState(() => _submitting = true);

    try {
      await _api.replyToOperationsSupportTicket(
        widget.ticketId,
        message: message,
      );

      _replyController.clear();
      await _pollTicket();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to send reply.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resolve() async {
    if (_submitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve ticket?'),
        content: const Text('This will mark the support ticket as resolved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _submitting = true);

    try {
      await _api.resolveOperationsSupportTicket(widget.ticketId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ticket resolved.')));

      // Refresh the ticket separately.
      // A refresh failure should NOT make a successful
      // resolve operation look like it failed.
      try {
        await _loadTicket();
      } catch (_) {
        // Ignore refresh failure because the resolve succeeded.
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to resolve ticket.')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    final isOpen = ticket?['status'] == 'open';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            AppPageHeader(
              title: "Ticket Details",
              subtitle: ticket?['category']?.toString() ?? "Support ticket",
              showBackButton: true,
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(_error!),
                ),
              )
            else if (ticket != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket['category']?.toString() ?? 'Support',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Chip(
                            label: Text(
                              (ticket['status']?.toString() ?? 'open')
                                  .toUpperCase(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        ticket['description']?.toString() ?? '',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        ticket['user_name']?.toString() ?? 'Customer',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (ticket['user_email'] != null)
                        Text(
                          ticket['user_email'].toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Conversation',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_messages.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No replies yet.'),
                  ),
                )
              else
                ..._messages.map((message) {
                  final map = Map<String, dynamic>.from(message as Map);
                  final role = map['sender_role']?.toString() ?? '';
                  final isOperations = role == 'operations';

                  return Align(
                    alignment: isOperations
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              map['sender_name']?.toString() ??
                                  (isOperations ? 'Operations' : 'Customer'),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 5),
                            Text(map['message']?.toString() ?? ''),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              if (isOpen) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _replyController,
                  minLines: 3,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Reply',
                    hintText: 'Write a response to the customer...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _submitting ? null : _reply,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'Sending...' : 'Send Reply'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _resolve,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Resolve Ticket'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

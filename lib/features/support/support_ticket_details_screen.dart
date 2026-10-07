import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';

class SupportTicketDetailsScreen extends StatefulWidget {
  final String ticketId;

  const SupportTicketDetailsScreen({super.key, required this.ticketId});

  @override
  State<SupportTicketDetailsScreen> createState() =>
      _SupportTicketDetailsScreenState();
}

class _SupportTicketDetailsScreenState
    extends State<SupportTicketDetailsScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _replyController = TextEditingController();
  Timer? _pollTimer;
  bool _polling = false;

  bool _loading = true;
  bool _refreshing = false;
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

  Future<void> _pollTicket() async {
    if (_polling || !mounted) return;

    _polling = true;

    try {
      final result = await _api.getSupportTicket(widget.ticketId);

      if (!mounted) return;

      final ticketData = result['ticket'];
      final messagesData = result['messages'];

      final newTicket = ticketData is Map
          ? Map<String, dynamic>.from(ticketData)
          : null;

      final newMessages = messagesData is List ? messagesData : <dynamic>[];

      final oldStatus = _ticket?['status']?.toString();
      final newStatus = newTicket?['status']?.toString();

      final oldMessageCount = _messages.length;
      final newMessageCount = newMessages.length;

      final oldLastMessageId = _messages.isNotEmpty
          ? (_messages.last as Map)['id']?.toString()
          : null;

      final newLastMessageId = newMessages.isNotEmpty
          ? (newMessages.last as Map)['id']?.toString()
          : null;

      final changed =
          oldStatus != newStatus ||
          oldMessageCount != newMessageCount ||
          oldLastMessageId != newLastMessageId;

      if (!changed) return;

      setState(() {
        _ticket = newTicket;
        _messages = newMessages;
      });
    } catch (_) {
      // Silent failure during automatic polling.
    } finally {
      _polling = false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadTicket({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await _api.getSupportTicket(widget.ticketId);

      if (!mounted) return;

      final ticketData = result['ticket'];
      final messagesData = result['messages'];

      setState(() {
        _ticket = ticketData is Map
            ? Map<String, dynamic>.from(ticketData)
            : null;

        _messages = messagesData is List ? messagesData : <dynamic>[];

        _loading = false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _refreshing = false;
        _error = 'Unable to load this support ticket.';
      });
    }
  }

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();

    if (message.isEmpty || _submitting) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await _api.replyToSupportTicket(widget.ticketId, message: message);

      _replyController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reply sent successfully.')));

      await _pollTicket();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to send reply.')));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    final status = ticket?['status']?.toString() ?? 'open';
    final isResolved = status == 'resolved';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : () => _loadTicket(refresh: true),
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadTicket,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : ticket == null
          ? const Center(child: Text('Ticket not found.'))
          : RefreshIndicator(
              onRefresh: () => _loadTicket(refresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _buildTicketHeader(context, ticket, isResolved),
                  const SizedBox(height: 24),
                  Text(
                    'Conversation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_messages.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No messages in this ticket yet.'),
                      ),
                    )
                  else
                    ..._messages.map(
                      (raw) => _buildMessage(
                        context,
                        Map<String, dynamic>.from(raw as Map),
                      ),
                    ),
                  const SizedBox(height: 20),

                  if (isResolved)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This ticket has been resolved.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _buildReplyComposer(context),
                ],
              ),
            ),
    );
  }

  Widget _buildReplyComposer(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reply to Support',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _replyController,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Write a message to the support team...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _sendReply,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_submitting ? 'Sending...' : 'Send Reply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketHeader(
    BuildContext context,
    Map<String, dynamic> ticket,
    bool isResolved,
  ) {
    final category = ticket['category']?.toString() ?? 'Other';
    final description = ticket['description']?.toString() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isResolved ? 'RESOLVED' : 'OPEN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isResolved ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(description, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(BuildContext context, Map<String, dynamic> message) {
    final role = message['sender_role']?.toString() ?? 'user';

    final text = message['message']?.toString() ?? '';

    final isOperations = role == 'operations';

    return Align(
      alignment: isOperations ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOperations ? 'Support Team' : 'You',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(text),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';

class ChatScreen extends StatefulWidget {
  final String commuteId;
  final String participantId;
  final String participantName;

  const ChatScreen({
    super.key,
    required this.commuteId,
    required this.participantId,
    required this.participantName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _api = ApiClient();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  static const List<String> _quickMessages = [
    'Where are you?',
    'I am coming',
    'I am here',
    'Running a little late',
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();

    // Phase 1 chat uses lightweight polling instead of a
    // realtime provider. This can be replaced with realtime later.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadMessages(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading = true);
    }

    try {
      final raw = await _api.getChatMessages(
        widget.commuteId,
        widget.participantId,
      );

      if (!mounted) return;

      final messages = raw.cast<Map<String, dynamic>>();

      setState(() {
        _messages = messages;
        _loading = false;
      });

      await _api.markChatMessagesRead(widget.commuteId, widget.participantId);

      if (!silent) {
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() => _loading = false);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _send() async {
    final auth = context.read<AuthProvider>();

    if (!auth.isSignedIn) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
      return;
    }

    final body = _messageCtrl.text.trim();

    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      await _api.sendChatMessage(widget.commuteId, widget.participantId, body);

      _messageCtrl.clear();

      await _loadMessages();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _sendQuickMessage(String message) async {
    if (_sending) return;

    _messageCtrl.text = message;
    await _send();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;

      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isMyMessage(Map<String, dynamic> message) {
    final auth = context.read<AuthProvider>();
    return message['sender_id'] == auth.user?.id;
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return '';

    final local = date.toLocal();

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.accent.withValues(alpha: 0.12),
              child: Icon(Icons.person_rounded, size: 20, color: theme.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.participantName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quick messages
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: _quickMessages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final message = _quickMessages[index];

                  return ActionChip(
                    label: Text(message),
                    onPressed: _sending
                        ? null
                        : () => _sendQuickMessage(message),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Messages
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 46,
                              color: theme.accent.withValues(alpha: 0.55),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Start the conversation',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Send a quick message or type your own.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, index) {
                        final message = _messages[index];
                        final isMine = _isMyMessage(message);

                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: isMine ? theme.accent : theme.card,
                              borderRadius: BorderRadius.circular(14),
                              border: isMine
                                  ? null
                                  : Border.all(color: theme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: isMine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!isMine)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      message['sender_name'] as String? ??
                                          widget.participantName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                Text(
                                  message['body'] as String? ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: isMine ? Colors.white : null,
                                      ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _formatTime(message['created_at']),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: isMine
                                            ? Colors.white.withValues(
                                                alpha: 0.75,
                                              )
                                            : null,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Message composer
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: theme.card,
                border: Border(top: BorderSide(color: theme.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
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

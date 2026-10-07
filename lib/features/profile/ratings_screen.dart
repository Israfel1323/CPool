import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '/commutes/ratings',
      );

      if (!mounted) return;

      setState(() {
        _data = response.data ?? {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Unable to load your ratings.';
      });
    }
  }

  double? _ratingValue(Map<String, dynamic> reputation) {
    final value = reputation['rating'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  int _ratingCount(Map<String, dynamic> reputation) {
    final value = reputation['rating_count'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _reputationText() {
    final reputation = Map<String, dynamic>.from(_data?['reputation'] ?? {});

    final rating = _ratingValue(reputation);
    final count = _ratingCount(reputation);

    if (rating == null || count == 0) {
      return 'New';
    }

    return '⭐ ${rating.toStringAsFixed(1)} · $count '
        '${count == 1 ? 'rating' : 'ratings'}';
  }

  String _formatRole(String? role) {
    if (role == 'driver') {
      return 'You were a driver';
    }

    return 'You were a passenger';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) return '';

    final local = parsed.toLocal();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  String _routeText(Map<String, dynamic> item) {
    final from = item['from_address']?.toString().trim();
    final to = item['to_address']?.toString().trim();

    if (from != null && from.isNotEmpty && to != null && to.isNotEmpty) {
      return '$from → $to';
    }

    return 'Completed ride';
  }

  String _personName(Map<String, dynamic> item) {
    final name = item['person_name']?.toString().trim();

    if (name == null || name.isEmpty) {
      return item['person_role'] == 'driver' ? 'Driver' : 'Passenger';
    }

    return name;
  }

  String _personRoleText(Map<String, dynamic> item) {
    final role = item['person_role']?.toString().toLowerCase();

    if (role == 'driver') {
      return 'Driver';
    }

    if (role == 'passenger') {
      return 'Passenger';
    }

    return '';
  }

  Future<void> _ratePerson(Map<String, dynamic> person) async {
    final commuteId = person['commute_id']?.toString();
    final personId = person['person_id']?.toString();

    if (commuteId == null ||
        commuteId.isEmpty ||
        personId == null ||
        personId.isEmpty) {
      return;
    }

    int selectedRating = 0;
    bool submitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final personName = _personName(person);
            final personRole = _personRoleText(person);

            return AlertDialog(
              title: Text('Rate $personName', textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (personRole.isNotEmpty)
                    Text(
                      personRole,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'How was your experience?',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final star = index + 1;

                      return IconButton(
                        tooltip: '$star stars',
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        onPressed: submitting
                            ? null
                            : () {
                                setDialogState(() {
                                  selectedRating = star;
                                });
                              },
                        icon: Icon(
                          selectedRating >= star
                              ? Icons.star
                              : Icons.star_border,
                          size: 34,
                        ),
                      );
                    }),
                  ),
                  if (selectedRating > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$selectedRating/5',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Later'),
                ),
                FilledButton(
                  onPressed: selectedRating == 0 || submitting
                      ? null
                      : () async {
                          setDialogState(() {
                            submitting = true;
                          });

                          try {
                            await _api.submitRating(
                              commuteId: commuteId,
                              ratedId: personId,
                              score: selectedRating,
                            );

                            if (!dialogContext.mounted) return;

                            Navigator.of(dialogContext).pop(true);
                          } catch (e) {
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              submitting = false;
                            });

                            String message = 'Unable to submit rating.';

                            if (e is DioException) {
                              final data = e.response?.data;

                              if (data is Map) {
                                final serverError = data['error']
                                    ?.toString()
                                    .trim();

                                if (serverError != null &&
                                    serverError.isNotEmpty) {
                                  message = serverError;
                                } else {
                                  message =
                                      'Unable to submit rating '
                                      '(HTTP ${e.response?.statusCode ?? 'error'}).';
                                }
                              } else {
                                message =
                                    'Unable to submit rating '
                                    '(HTTP ${e.response?.statusCode ?? 'error'}).';
                              }
                            } else if (e.toString().trim().isNotEmpty) {
                              message = e.toString();
                            }

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      await _loadRatings();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Thank you!', textAlign: TextAlign.center),
            content: const Text(
              'Your rating helps keep the CPool community safe and reliable.',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ratings')),
      body: RefreshIndicator(
        onRefresh: _loadRatings,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              )
            : _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 100),
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: theme.accent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton(
                      onPressed: _loadRatings,
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              )
            : _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(CPoolThemeExtension theme) {
    final pending = List<dynamic>.from(_data?['pending'] ?? []);
    final history = List<dynamic>.from(_data?['history'] ?? []);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _buildReputationCard(theme),
        const SizedBox(height: 30),
        _buildSectionTitle('Ratings to Give'),
        const SizedBox(height: 10),
        if (pending.isEmpty)
          _buildEmptyCard(
            theme,
            icon: Icons.check_circle_outline_rounded,
            text: "You're all caught up! No pending ratings.",
          )
        else
          ...pending.map(
            (item) => _buildPendingCard(
              theme,
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        const SizedBox(height: 30),
        _buildSectionTitle('Rating History'),
        const SizedBox(height: 10),
        if (history.isEmpty)
          _buildEmptyCard(
            theme,
            icon: Icons.star_outline_rounded,
            text: 'You have not given any ratings yet.',
          )
        else
          ...history.map(
            (item) => _buildHistoryCard(
              theme,
              Map<String, dynamic>.from(item as Map),
            ),
          ),
      ],
    );
  }

  Widget _buildReputationCard(CPoolThemeExtension theme) {
    final reputation = Map<String, dynamic>.from(_data?['reputation'] ?? {});
    final rating = _ratingValue(reputation);
    final count = _ratingCount(reputation);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          Icon(Icons.star_rounded, size: 42, color: theme.accent),
          const SizedBox(height: 10),
          Text(
            'Your Reputation',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            rating == null || count == 0
                ? 'New'
                : '⭐ ${rating.toStringAsFixed(1)}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            count == 0
                ? 'No ratings yet'
                : '$count ${count == 1 ? 'rating' : 'ratings'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(
    CPoolThemeExtension theme,
    Map<String, dynamic> item,
  ) {
    final name = _personName(item);
    final personRole = _personRoleText(item);
    final myRole = _formatRole(item['my_role']?.toString().toLowerCase());
    final date = _formatDate(item['departure_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(url: item['avatar_url']?.toString(), theme: theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (personRole.isNotEmpty)
                      Text(
                        personRole,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => _ratePerson(item),
                child: const Text('Rate'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            myRole,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(_routeText(item), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(date, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    CPoolThemeExtension theme,
    Map<String, dynamic> item,
  ) {
    final name = _personName(item);
    final personRole = _personRoleText(item);
    final myRole = _formatRole(item['my_role']?.toString().toLowerCase());
    final date = _formatDate(item['created_at']);
    final score =
        (item['score'] as num?)?.toInt() ??
        int.tryParse(item['score']?.toString() ?? '') ??
        0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(url: item['avatar_url']?.toString(), theme: theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (personRole.isNotEmpty)
                      Text(
                        personRole,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
              Text(
                '⭐ $score/5',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            myRole,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(_routeText(item), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(date, style: Theme.of(context).textTheme.bodySmall),
          ],
          finalComment(item),
        ],
      ),
    );
  }

  Widget finalComment(Map<String, dynamic> item) {
    final comment = item['comment']?.toString().trim();

    if (comment == null || comment.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        '"$comment"',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _buildEmptyCard(
    CPoolThemeExtension theme, {
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.accent, size: 26),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.theme});

  final String? url;
  final CPoolThemeExtension theme;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();

    return CircleAvatar(
      radius: 24,
      backgroundColor: theme.accentMuted,
      backgroundImage: imageUrl != null && imageUrl.isNotEmpty
          ? NetworkImage(imageUrl)
          : null,
      child: imageUrl == null || imageUrl.isEmpty
          ? Icon(Icons.person_rounded, color: theme.accent)
          : null,
    );
  }
}

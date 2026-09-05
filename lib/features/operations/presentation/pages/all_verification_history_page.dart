import 'package:flutter/material.dart';

import '../../models/verification_request.dart';
import '../../services/operations_service.dart';
import '../widgets/verification_tile.dart';
import 'verification_details_page.dart';

class AllVerificationHistoryPage extends StatefulWidget {
  const AllVerificationHistoryPage({super.key});

  @override
  State<AllVerificationHistoryPage> createState() =>
      _AllVerificationHistoryPageState();
}

class _AllVerificationHistoryPageState
    extends State<AllVerificationHistoryPage> {
  final OperationsService _service = OperationsService();
  final TextEditingController _searchController = TextEditingController();

  List<VerificationRequest> _allRequests = [];
  List<VerificationRequest> _filteredRequests = [];

  String _historyFilter = 'all';

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final approved = await _service.getVerificationRequests(
        status: 'approved',
        limit: 100,
      );

      final rejected = await _service.getVerificationRequests(
        status: 'rejected',
        limit: 100,
      );

      final combined = [...approved, ...rejected]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;

      setState(() {
        _allRequests = combined;
        _filteredRequests = combined;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filterRequests(String value) {
    final query = value.trim().toLowerCase();

    setState(() {
      _filteredRequests = _allRequests.where((request) {
        final matchesType =
            _historyFilter == 'all' ||
            (_historyFilter == 'student' &&
                request.verificationType == 'student') ||
            (_historyFilter == 'driver' &&
                request.verificationType == 'driver');

        if (!matchesType) {
          return false;
        }

        if (query.isEmpty) {
          return true;
        }

        final name = request.fullName?.toLowerCase() ?? '';
        final email = request.email?.toLowerCase() ?? '';

        return name.contains(query) || email.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to History',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'All History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(
              'Approved and rejected verifications',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadHistory);
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          TextField(
            controller: _searchController,
            onChanged: _filterRequests,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _filterRequests('');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'all',
                label: Text('All'),
                icon: Icon(Icons.list_alt_rounded),
              ),
              ButtonSegment<String>(
                value: 'student',
                label: Text('Students'),
                icon: Icon(Icons.school_rounded),
              ),
              ButtonSegment<String>(
                value: 'driver',
                label: Text('Drivers'),
                icon: Icon(Icons.directions_car_rounded),
              ),
            ],
            selected: {_historyFilter},
            onSelectionChanged: (selection) {
              setState(() {
                _historyFilter = selection.first;
              });

              _filterRequests(_searchController.text);
            },
          ),

          const SizedBox(height: 20),

          if (_filteredRequests.isEmpty)
            _NoResultsState(hasSearch: _searchController.text.trim().isNotEmpty)
          else
            ..._filteredRequests.map(
              (request) => _HistoryTile(
                request: request,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          VerificationDetailsPage(verificationId: request.id),
                    ),
                  );

                  if (mounted) {
                    await _loadHistory();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.request, required this.onTap});

  final VerificationRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        VerificationTile(request: request, onTap: onTap),
        Positioned(
          top: 12,
          right: 12,
          child: _StatusBadge(status: request.status),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isApproved = status.toLowerCase() == 'approved';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isApproved
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isApproved ? 'VERIFIED' : 'REJECTED',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isApproved ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'No search results found'
                  : 'No verification history found',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Approved and rejected verification records will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 16),
            Text(
              'Unable to load verification history',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

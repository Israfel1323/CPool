import 'package:flutter/material.dart';

import 'all_verification_history_page.dart';
import 'approved_verification_history_page.dart';
import 'rejected_verification_history_page.dart';

class VerificationHistoryPage extends StatelessWidget {
  const VerificationHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to Verification',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Verification History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'View approved and rejected requests',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _HistoryOptionCard(
            icon: Icons.list_alt_rounded,
            title: 'All History',
            description: 'View all approved and rejected verifications.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AllVerificationHistoryPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _HistoryOptionCard(
            icon: Icons.verified_rounded,
            title: 'Verified History',
            description: 'View all approved verification requests.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ApprovedVerificationHistoryPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _HistoryOptionCard(
            icon: Icons.cancel_rounded,
            title: 'Rejected History',
            description: 'View all rejected verification requests.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RejectedVerificationHistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryOptionCard extends StatelessWidget {
  const _HistoryOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(description),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
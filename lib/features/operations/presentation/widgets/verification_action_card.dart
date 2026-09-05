import 'package:flutter/material.dart';

import '../../../../core/widgets/app_card.dart';

class VerificationActionCard extends StatelessWidget {
  const VerificationActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.pendingCount,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int pendingCount;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 34,
          ),

          const SizedBox(height: 16),

          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 8),

          Text(
            "$pendingCount Pending",
            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: 8),

          Text(description),

          const SizedBox(height: 20),

          const Row(
            children: [
              Spacer(),
              Text(
                "View Requests",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
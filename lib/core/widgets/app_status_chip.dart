import 'package:flutter/material.dart';

enum AppStatus {
  pending,
  approved,
  rejected,
}

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.status,
  });

  final AppStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case AppStatus.pending:
        color = Colors.orange;
        label = "Pending";
        break;

      case AppStatus.approved:
        color = Colors.green;
        label = "Approved";
        break;

      case AppStatus.rejected:
        color = Colors.red;
        label = "Rejected";
        break;
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
    );
  }
}
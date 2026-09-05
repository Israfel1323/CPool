import 'package:flutter/material.dart';

import '../../../../core/widgets/app_stat_card.dart';

class StatsGrid extends StatelessWidget {
  const StatsGrid({
    super.key,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  final int pending;
  final int approved;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppStatCard(
          title: "Pending",
          value: pending.toString(),
          icon: Icons.pending_actions_rounded,
        ),

        AppStatCard(
          title: "Approved",
          value: approved.toString(),
          icon: Icons.check_circle_rounded,
          color: Colors.green,
        ),

        AppStatCard(
          title: "Rejected",
          value: rejected.toString(),
          icon: Icons.cancel_rounded,
          color: Colors.red,
        ),
      ],
    );
  }
}
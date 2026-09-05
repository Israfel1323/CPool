import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class VerificationDonutChart extends StatelessWidget {
  const VerificationDonutChart({
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
    final theme = context.cpoolTheme;

    final total = pending + approved + rejected;

    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 6,
              centerSpaceRadius: 72,
              startDegreeOffset: -90,
              sections: [
                PieChartSectionData(
                  value: pending.toDouble(),
                  color: theme.accent,
                  radius: 24,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: approved.toDouble(),
                  color: Colors.green,
                  radius: 24,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: rejected.toDouble(),
                  color: Colors.red,
                  radius: 24,
                  showTitle: false,
                ),
              ],
            ),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "$total",
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Total Requests",
                style: TextStyle(
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_container.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../providers/operations_provider.dart';
import '../widgets/donut_chart.dart';
import '../widgets/stats_grid.dart';
import '../../models/dashboard_stats.dart';
import '../widgets/verification_action_card.dart';
import 'driver_requests_page.dart';
import 'student_requests_page.dart';
import '../widgets/verification_history_card.dart';
import 'verification_history_page.dart';

class VerificationDashboardPage extends StatefulWidget {
  const VerificationDashboardPage({super.key});

  @override
  State<VerificationDashboardPage> createState() =>
      _VerificationDashboardPageState();
}

class _VerificationDashboardPageState extends State<VerificationDashboardPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OperationsProvider>().loadDashboard();
    });
  }

  Future<void> _refresh() async {
    await context.read<OperationsProvider>().loadDashboard();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        tooltip: 'Back to Operations',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Verification Dashboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(
            'Review driver & student verification requests',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OperationsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.stats == null) {
          return Scaffold(
            appBar: _buildAppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.error != null && provider.stats == null) {
          return Scaffold(
            appBar: _buildAppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    "Unable to load dashboard",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
          );
        }

        final stats = provider.stats!;

        return Scaffold(
          appBar: _buildAppBar(),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ResponsiveContainer(
              child: ResponsiveLayout(
                mobile: _MobileDashboard(stats: stats),
                tablet: _DesktopDashboard(stats: stats),
                desktop: _DesktopDashboard(stats: stats),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileDashboard extends StatelessWidget {
  const _MobileDashboard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        StatsGrid(
          pending: stats.pendingVerifications,
          approved: stats.approvedVerifications,
          rejected: stats.rejectedVerifications,
        ),

        const SizedBox(height: 28),

        VerificationActionCard(
          icon: Icons.directions_car_rounded,
          title: "Driver Requests",
          pendingCount: stats.pendingDrivers,
          description: "Review all pending driver verification requests.",
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DriverRequestsPage()),
            );
          },
        ),

        const SizedBox(height: 20),

        const SizedBox(height: 20),

        VerificationHistoryCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const VerificationHistoryPage(),
              ),
            );
          },
        ),

        const SizedBox(height: 28),

        VerificationDonutChart(
          pending: stats.pendingVerifications,
          approved: stats.approvedVerifications,
          rejected: stats.rejectedVerifications,
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

class _DesktopDashboard extends StatelessWidget {
  const _DesktopDashboard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        StatsGrid(
          pending: stats.pendingVerifications,
          approved: stats.approvedVerifications,
          rejected: stats.rejectedVerifications,
        ),

        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: VerificationActionCard(
                icon: Icons.directions_car_rounded,
                title: "Driver Requests",
                pendingCount: stats.pendingDrivers,
                description: "Review all pending driver verification requests.",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DriverRequestsPage(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 20),

            Expanded(
              child: VerificationActionCard(
                icon: Icons.school_rounded,
                title: "Student Requests",
                pendingCount: stats.pendingStudents,
                description:
                    "Review all pending student verification requests.",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StudentRequestsPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        VerificationHistoryCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const VerificationHistoryPage(),
              ),
            );
          },
        ),

        const SizedBox(height: 32),

        VerificationDonutChart(
          pending: stats.pendingVerifications,
          approved: stats.approvedVerifications,
          rejected: stats.rejectedVerifications,
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_page_header.dart';
import '../widgets/operation_card.dart';
import 'verification_dashboard_page.dart';
import 'customer_support_dashboard_page.dart';
import 'sos_alerts_page.dart';

class OperationsHomePage extends StatelessWidget {
  const OperationsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const AppPageHeader(
                title: "Operations",
                subtitle: "Manage the CPool platform.",
              ),

              OperationCard(
                icon: Icons.verified_user_rounded,
                title: "Verification",
                subtitle: "Review student and driver verification requests.",
                badge: "Live",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VerificationDashboardPage(),
                    ),
                  );
                },
              ),

              OperationCard(
                icon: Icons.support_agent_rounded,
                title: "Customer Support",
                subtitle: "Handle support tickets.",
                badge: "Live",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerSupportDashboardPage(),
                    ),
                  );
                },
              ),

              OperationCard(
                icon: Icons.security_rounded,
                title: "Safety & Reports",
                subtitle: "Review SOS alerts and safety incidents.",
                
                badge: "Live",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SosAlertsPage()),
                  );
                },
              ),

              OperationCard(
                icon: Icons.analytics_rounded,
                title: "Analytics",
                subtitle: "Platform insights and statistics.",
                badge: "Soon",
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

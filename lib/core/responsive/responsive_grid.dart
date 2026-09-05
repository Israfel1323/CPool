import 'package:flutter/material.dart';

import 'responsive.dart';

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    int count = 1;

    if (Responsive.isDesktop(context)) {
      count = 3;
    } else if (Responsive.isTablet(context)) {
      count = 2;
    }

    return GridView.count(
      crossAxisCount: count,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.3,
      children: children,
    );
  }
}
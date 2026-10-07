import 'package:flutter/material.dart';

/// Legacy ThemeToggle retained for API compatibility, renders nothing since single light theme is used.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

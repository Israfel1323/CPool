import 'package:flutter/material.dart';

import '../../../core/design/app_radius.dart';
import '../../../core/design/app_shadow.dart';
import '../../../core/design/app_size.dart';
import '../../../core/design/app_spacing.dart';

class ActionCard extends StatefulWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconBackgroundColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconBackgroundColor;
  final VoidCallback? onTap;

  @override
  State<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.iconBackgroundColor ?? Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.large),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.large),

              splashFactory: InkRipple.splashFactory,

              overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.pressed)) {
                  return Colors.white.withOpacity(0.08);
                }

                if (states.contains(WidgetState.hovered)) {
                  return Colors.white.withOpacity(0.04);
                }

                return null;
              }),

              onTapDown: (_) {
                setState(() => _pressed = true);
              },

              onTapCancel: () {
                setState(() => _pressed = false);
              },

              onTapUp: (_) {
                setState(() => _pressed = false);
                widget.onTap?.call();
              },

              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent,
                      Color.lerp(accent, Colors.black, 0.28)!,
                    ],
                  ),
                  boxShadow: AppShadow.elevated,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius:
                            BorderRadius.circular(AppRadius.button),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        color: Colors.white,
                        size: AppSize.iconLg,
                      ),
                    ),

                    const SizedBox(width: AppSpacing.lg),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          Text(
                            widget.subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
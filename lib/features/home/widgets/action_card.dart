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
    this.prominent = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconBackgroundColor;
  final bool prominent;
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
    final theme = Theme.of(context);
    final foreground =
        widget.prominent ? Colors.white : theme.colorScheme.onSurface;
    final secondaryForeground = widget.prominent
        ? Colors.white.withValues(alpha: 0.78)
        : theme.colorScheme.onSurfaceVariant;

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
                  return widget.prominent
                      ? Colors.white.withValues(alpha: 0.08)
                      : accent.withValues(alpha: 0.08);
                }

                if (states.contains(WidgetState.hovered)) {
                  return widget.prominent
                      ? Colors.white.withValues(alpha: 0.04)
                      : accent.withValues(alpha: 0.04);
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
                  color: widget.prominent ? null : theme.colorScheme.surface,
                  gradient: widget.prominent
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent,
                            Color.lerp(accent, Colors.black, 0.22)!,
                          ],
                        )
                      : null,
                  border: widget.prominent
                      ? null
                      : Border.all(color: accent.withValues(alpha: 0.28)),
                  boxShadow: widget.prominent
                      ? AppShadow.elevated
                      : AppShadow.card,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: widget.prominent
                            ? Colors.white.withValues(alpha: 0.12)
                            : accent.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppRadius.button),
                        border: Border.all(
                          color: widget.prominent
                              ? Colors.white.withValues(alpha: 0.08)
                              : accent.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.prominent ? Colors.white : accent,
                        size: AppSize.iconMd,
                      ),
                    ),

                    const SizedBox(width: AppSpacing.lg),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: secondaryForeground,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: AppSpacing.sm),

                    Icon(
                      Icons.arrow_forward_rounded,
                      color: widget.prominent
                          ? Colors.white.withValues(alpha: 0.92)
                          : accent,
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

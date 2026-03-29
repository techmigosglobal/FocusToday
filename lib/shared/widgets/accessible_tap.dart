import 'package:flutter/material.dart';
import '../../app/theme/app_dimensions.dart';

/// Ensures minimum 48dp touch targets and proper semantic labels
/// for accessibility compliance (WCAG 2.1 AA).
class AccessibleTap extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool isButton;
  final double minSize;
  final VoidCallback? onLongPress;

  const AccessibleTap({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.isButton = true,
    this.minSize = AppDimensions.minTouchTarget,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: isButton,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusCard),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
          child: child,
        ),
      ),
    );
  }
}

/// Accessible icon button with proper semantics and minimum touch target.
class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Color? color;
  final double? size;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: IconButton(
        icon: Icon(icon, color: color, size: size ?? AppDimensions.iconMedium),
        onPressed: onPressed,
        tooltip: semanticLabel,
        constraints: const BoxConstraints(
          minWidth: AppDimensions.minTouchTarget,
          minHeight: AppDimensions.minTouchTarget,
        ),
      ),
    );
  }
}

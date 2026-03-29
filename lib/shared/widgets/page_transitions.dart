import 'package:flutter/material.dart';

/// Smooth slide-up + fade transition for page navigation.
/// Use instead of `MaterialPageRoute` for a premium feel.
///
/// Usage:
/// ```dart
/// Navigator.push(context, SmoothPageRoute(builder: (_) => NextScreen()));
/// ```
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  SmoothPageRoute({required this.builder})
    : super(
        pageBuilder: (ctx, anim, secondaryAnim) => builder(ctx),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (ctx, anim, secondaryAnim, child) {
          final fadeAnim = CurvedAnimation(parent: anim, curve: Curves.easeOut);
          final slideAnim = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: fadeAnim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.08),
                end: Offset.zero,
              ).animate(slideAnim),
              child: child,
            ),
          );
        },
      );
}

/// Slide-in from right transition — mimics iOS navigation push.
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  SlidePageRoute({required this.builder})
    : super(
        pageBuilder: (ctx, anim, secondaryAnim) => builder(ctx),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (ctx, anim, secondaryAnim, child) {
          final slideAnim = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(slideAnim),
            child: child,
          );
        },
      );
}

/// Scale + fade transition — use for modals or special screens.
class ScalePageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  ScalePageRoute({required this.builder})
    : super(
        pageBuilder: (ctx, anim, secondaryAnim) => builder(ctx),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        transitionsBuilder: (ctx, anim, secondaryAnim, child) {
          final scaleAnim = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutBack,
          );

          return FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(scaleAnim),
              child: child,
            ),
          );
        },
      );
}

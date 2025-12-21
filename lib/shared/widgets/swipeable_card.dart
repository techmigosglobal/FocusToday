import 'package:flutter/material.dart';

/// Swipeable Card Widget
/// Provides swipe-to-like and swipe-to-bookmark functionality
class SwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeRight; // Like action
  final VoidCallback onSwipeLeft; // Bookmark action
  final bool enableSwipe;

  const SwipeableCard({
    super.key,
    required this.child,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    this.enableSwipe = true,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  double _dragExtent = 0;
  late AnimationController _controller;
  late Animation<Offset> _moveAnimation;
  bool _dragUnderway = false;

  static const double _kSwipeThreshold = 100.0;
  static const double _kMinFlingVelocity = 700.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _moveAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    if (!widget.enableSwipe) return;
    _dragUnderway = true;
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.enableSwipe || !_dragUnderway) return;

    final delta = details.primaryDelta ?? 0;
    setState(() {
      _dragExtent += delta;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.enableSwipe || !_dragUnderway) return;

    _dragUnderway = false;
    final velocity = details.primaryVelocity ?? 0;

    // Determine if swipe was significant enough
    if (_dragExtent.abs() >= _kSwipeThreshold ||
        velocity.abs() >= _kMinFlingVelocity) {
      if (_dragExtent > 0) {
        // Swiped right - Like
        _animateSwipe(SwipeDirection.right);
        widget.onSwipeRight();
      } else {
        // Swiped left - Bookmark
        _animateSwipe(SwipeDirection.left);
        widget.onSwipeLeft();
      }
    } else {
      // Reset to center
      _resetPosition();
    }
  }

  void _animateSwipe(SwipeDirection direction) {
    final double targetOffset = direction == SwipeDirection.right ? 1.5 : -1.5;

    _moveAnimation = Tween<Offset>(
      begin: Offset(_dragExtent / context.size!.width, 0),
      end: Offset(targetOffset, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.reset();
    _controller.forward().then((_) {
      setState(() {
        _dragExtent = 0;
      });
      _controller.reset();
    });
  }

  void _resetPosition() {
    _moveAnimation = Tween<Offset>(
      begin: Offset(_dragExtent / context.size!.width, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.reset();
    _controller.forward().then((_) {
      setState(() {
        _dragExtent = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enableSwipe) {
      return widget.child;
    }

    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        children: [
          // Background indicators
          if (_dragExtent != 0) _buildSwipeIndicator(),

          // Main content with transform
          Transform.translate(
            offset: _controller.isAnimating
                ? Offset(_moveAnimation.value.dx * context.size!.width, 0)
                : Offset(_dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeIndicator() {
    final isRight = _dragExtent > 0;
    final opacity = (_dragExtent.abs() / _kSwipeThreshold).clamp(0.0, 1.0);

    return Positioned.fill(
      child: Container(
        alignment: isRight ? Alignment.centerLeft : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 50),
        color: isRight
            ? Colors.red.withValues(alpha: 0.1 * opacity)
            : Colors.blue.withValues(alpha: 0.1 * opacity),
        child: Icon(
          isRight ? Icons.favorite : Icons.bookmark,
          color: isRight
              ? Colors.red.withValues(alpha: opacity)
              : Colors.blue.withValues(alpha: opacity),
          size: 48 + (20 * opacity),
        ),
      ),
    );
  }
}

enum SwipeDirection { left, right }

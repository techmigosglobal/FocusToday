import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/connectivity_service.dart';
import '../../app/theme/app_colors.dart';

/// A banner that appears at the top of the screen when offline.
/// Wrap your Scaffold body with this widget.
class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  final ConnectivityService _connectivity = ConnectivityService();
  late StreamSubscription<bool> _sub;
  bool _isOffline = false;
  late AnimationController _anim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _isOffline = !_connectivity.isOnline;

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));

    if (_isOffline) _anim.value = 1.0;

    _sub = _connectivity.onConnectivityChanged.listen((online) {
      if (mounted) {
        setState(() => _isOffline = !online);
        if (_isOffline) {
          _anim.forward();
        } else {
          // Show "Back online" briefly before hiding
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_isOffline) _anim.reverse();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _slideAnim,
          builder: (context, child) {
            if (_anim.isDismissed) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: (_slideAnim.value + 1.0).clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Material(
            color: _isOffline ? AppColors.error : AppColors.secondary,
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isOffline ? Icons.wifi_off : Icons.wifi,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOffline ? 'No internet connection' : 'Back online',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

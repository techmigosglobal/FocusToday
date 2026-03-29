import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Global error handler — catches all uncaught Flutter and Dart errors.
/// In debug mode, errors are printed to console.
/// In release mode, errors are forwarded to Firebase Crashlytics.
class AppErrorHandler {
  AppErrorHandler._();

  static bool _initialized = false;

  /// Initialize global error handlers
  static void init() {
    if (_initialized) return;
    _initialized = true;

    // Flutter framework errors (widget build errors, rendering errors, etc.)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _reportError(details.exception, details.stack);
    };

    // Platform dispatcher errors (async errors not caught by zones)
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _reportError(error, stack);
      return true; // Handled — prevent crash
    };
  }

  /// Wrap app initialization with a guarded error zone for comprehensive error capture
  static void runGuarded(Future<void> Function() runner) {
    runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();
      init();
      await runner();
    }, (Object error, StackTrace stack) => _reportError(error, stack));
  }

  /// Report error to appropriate destination
  static void _reportError(Object error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('════════════════════════════════════════════');
      debugPrint('🔴 UNCAUGHT ERROR: $error');
      if (stack != null) {
        debugPrint('Stack trace:\n$stack');
      }
      debugPrint('════════════════════════════════════════════');
    } else {
      // Production: forward to Firebase Crashlytics
      FirebaseCrashlytics.instance.recordError(
        error,
        stack ?? StackTrace.current,
        fatal: true,
      );
    }
  }

  /// Manually report a non-fatal error (use in catch blocks)
  static void reportNonFatal(Object error, [StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('⚠️ Non-fatal error: $error');
    } else {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack ?? StackTrace.current,
        fatal: false,
      );
    }
  }
}

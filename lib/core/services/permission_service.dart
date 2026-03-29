import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized Permission Service
/// Handles all app permissions with user-friendly dialogs and graceful fallbacks
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request storage permission with rationale dialog
  /// Returns true if permission granted, false otherwise
  Future<bool> requestStoragePermission(BuildContext context) async {
    // Check current status
    final status = await _getStoragePermissionStatus();

    if (status.isGranted) {
      return true;
    }

    // Show rationale dialog before requesting
    if (context.mounted && _canShowMaterialDialogs(context)) {
      final shouldRequest = await _showPermissionRationaleDialog(
        context,
        title: 'Storage Permission Required',
        message:
            'Focus Today needs access to your photos and videos to:\n\n'
            '• Upload images and videos to create posts\n'
            '• Save media to your device\n'
            '• Access your camera to capture photos',
        icon: Icons.photo_library,
      );

      if (!shouldRequest) {
        return false;
      }
    }

    // Request permission
    final result = await _requestStoragePermission();

    // Handle denial
    if (!result && context.mounted && _canShowMaterialDialogs(context)) {
      await _showPermissionDeniedDialog(
        context,
        title: 'Storage Permission Denied',
        message:
            'You can enable storage permission in app settings to upload media.',
      );
    }

    return result;
  }

  /// Request notification permission with rationale dialog
  /// Returns true if permission granted, false otherwise
  Future<bool> requestNotificationPermission(BuildContext context) async {
    // Check current status
    final status = await Permission.notification.status;

    if (status.isGranted) {
      return true;
    }

    // Show rationale dialog
    if (context.mounted && _canShowMaterialDialogs(context)) {
      final shouldRequest = await _showPermissionRationaleDialog(
        context,
        title: 'Notification Permission',
        message:
            'Focus Today would like to send you notifications for:\n\n'
            '• New posts from sources you follow\n'
            '• Breaking news alerts\n'
            '• Comments and likes on your posts\n'
            '• Content approval updates',
        icon: Icons.notifications_outlined,
      );

      if (!shouldRequest) {
        return false;
      }
    }

    // Request permission
    final result = await Permission.notification.request();

    return result.isGranted;
  }

  /// Request camera permission
  Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (context.mounted && _canShowMaterialDialogs(context)) {
      final shouldRequest = await _showPermissionRationaleDialog(
        context,
        title: 'Camera Permission Required',
        message:
            'Focus Today needs camera access to capture photos and videos for your posts.',
        icon: Icons.camera_alt,
      );

      if (!shouldRequest) {
        return false;
      }
    }

    final result = await Permission.camera.request();

    if (!result.isGranted &&
        context.mounted &&
        _canShowMaterialDialogs(context)) {
      await _showPermissionDeniedDialog(
        context,
        title: 'Camera Permission Denied',
        message: 'You can enable camera permission in app settings.',
      );
    }

    return result.isGranted;
  }

  /// Check if storage permission is granted
  Future<bool> hasStoragePermission() async {
    final status = await _getStoragePermissionStatus();
    return status.isGranted;
  }

  /// Check if notification permission is granted
  Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Open app settings for manual permission grant
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Get appropriate storage permission based on Android version
  Future<PermissionStatus> _getStoragePermissionStatus() async {
    // Android 13+ uses granular media permissions
    if (await _isAndroid13OrHigher()) {
      final photos = await Permission.photos.status;
      final videos = await Permission.videos.status;

      // If both are granted, consider storage granted
      if (photos.isGranted && videos.isGranted) {
        return PermissionStatus.granted;
      }

      // Return photos status as primary
      return photos;
    } else {
      // Android 12 and below use storage permission
      return await Permission.storage.status;
    }
  }

  /// Request storage permission based on Android version
  Future<bool> _requestStoragePermission() async {
    if (await _isAndroid13OrHigher()) {
      // Request granular permissions for Android 13+
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.photos,
        Permission.videos,
      ].request();

      // Return true if at least photos permission is granted
      return statuses[Permission.photos]?.isGranted ?? false;
    } else {
      // Request storage permission for Android 12 and below
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  /// Check if Android version is 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      final androidInfo = await deviceInfo.androidInfo;
      // Android 13 = API level 33
      return androidInfo.version.sdkInt >= 33;
    } catch (e) {
      // Fallback to false for safety on unknown platforms
      return false;
    }
  }

  /// Show permission rationale dialog
  Future<bool> _showPermissionRationaleDialog(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  bool _canShowMaterialDialogs(BuildContext context) {
    return Localizations.of<MaterialLocalizations>(
          context,
          MaterialLocalizations,
        ) !=
        null;
  }

  /// Show permission denied dialog with option to go to settings
  Future<void> _showPermissionDeniedDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

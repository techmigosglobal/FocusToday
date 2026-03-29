import '../config/feature_flags.dart';

class ShareLinkService {
  ShareLinkService._();

  static const String _defaultBaseUrl = 'https://crii-focus-today.web.app';
  static const String _baseUrl = String.fromEnvironment(
    'CONTENT_SHARE_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static String postUrl(String postId) {
    final id = postId.trim();
    if (id.isEmpty) return _baseUrl;
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    if (!FeatureFlags.functionPreviewRouteEnabled) {
      return '$base/?postId=$id';
    }
    return '$base/p/$id';
  }
}

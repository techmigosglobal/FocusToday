import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_colors.dart';

/// Optimized network image with memory-conscious caching and error handling.
/// Automatically limits decoded image size for memory efficiency.
class OptimizedImage extends StatelessWidget {
  final String? imageUrl;
  final String? cacheBuster;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.cacheBuster,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildError();
    }

    final resolvedUrl = resolveUrl(imageUrl!, cacheBuster: cacheBuster);
    final safeWidth = _safeLayoutDimension(width);
    final safeHeight = _safeLayoutDimension(height);
    final safeMemCacheWidth = _safeCacheDimension(width, fallback: 800);
    final safeMemCacheHeight = _safeCacheDimension(height);

    final image = CachedNetworkImage(
      imageUrl: resolvedUrl,
      width: safeWidth,
      height: safeHeight,
      fit: fit,
      // Memory optimization: limit decoded image size
      memCacheWidth: safeMemCacheWidth,
      memCacheHeight: safeMemCacheHeight,
      maxWidthDiskCache: 1200,
      maxHeightDiskCache: 1200,
      placeholder: (_, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (_, url, error) => errorWidget ?? _buildError(),
      fadeInDuration: const Duration(milliseconds: 200),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.backgroundLight,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: width,
      height: height,
      color: AppColors.backgroundLight,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey[400],
          size: 32,
        ),
      ),
    );
  }

  static String resolveUrl(String rawUrl, {String? cacheBuster}) {
    final normalized = rawUrl.trim();
    if (normalized.isEmpty || cacheBuster == null || cacheBuster.isEmpty) {
      return normalized;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || (!uri.hasScheme && !normalized.startsWith('/'))) {
      return normalized;
    }
    final updatedQuery = Map<String, String>.from(uri.queryParameters)
      ..['cb'] = cacheBuster;
    return uri.replace(queryParameters: updatedQuery).toString();
  }

  static int? _safeCacheDimension(double? logicalPixels, {int? fallback}) {
    if (logicalPixels == null) return fallback;
    if (!logicalPixels.isFinite || logicalPixels <= 0) return fallback;
    final scaled = logicalPixels * 2;
    if (!scaled.isFinite || scaled <= 0) return fallback;
    return scaled.round().clamp(1, 4096);
  }

  static double? _safeLayoutDimension(double? logicalPixels) {
    if (logicalPixels == null) return null;
    if (!logicalPixels.isFinite || logicalPixels <= 0) return null;
    return logicalPixels;
  }
}

/// Optimized circular avatar with proper caching and fallback.
class OptimizedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;

  const OptimizedAvatar({
    super.key,
    this.imageUrl,
    this.radius = 24,
    this.fallbackIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback(context);
    }

    final safeRadius = radius.isFinite && radius > 0 ? radius : 24.0;
    final safeMemCacheWidth = (safeRadius * 4).round().clamp(1, 2048);
    final safeMaxDiskWidth = (safeRadius * 6).round().clamp(1, 4096);

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      memCacheWidth: safeMemCacheWidth,
      maxWidthDiskCache: safeMaxDiskWidth,
      imageBuilder: (_, imageProvider) =>
          CircleAvatar(radius: safeRadius, backgroundImage: imageProvider),
      placeholder: (_, url) => CircleAvatar(
        radius: safeRadius,
        backgroundColor: AppColors.backgroundLight,
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, url, error) => _buildFallback(context),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final safeRadius = radius.isFinite && radius > 0 ? radius : 24.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CircleAvatar(
      radius: safeRadius,
      backgroundColor: isDark
          ? AppColors.primaryOf(context).withValues(alpha: 0.28)
          : AppColors.primary.withValues(alpha: 0.1),
      child: Icon(
        fallbackIcon,
        size: safeRadius,
        color: isDark ? AppColors.onPrimaryOf(context) : AppColors.primary,
      ),
    );
  }
}

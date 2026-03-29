import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/media_thumbnail_service.dart';

/// Lightweight cached video frame thumbnail widget.
class VideoThumbnailView extends StatefulWidget {
  final String videoUrl;
  final BoxFit fit;
  final Widget fallback;

  const VideoThumbnailView({
    super.key,
    required this.videoUrl,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoThumbnailView> createState() => _VideoThumbnailViewState();
}

class _VideoThumbnailViewState extends State<VideoThumbnailView> {
  late Future<File?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _load();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _thumbnailFuture = _load();
    }
  }

  Future<File?> _load() {
    return MediaThumbnailService.getThumbnail(
      mediaUrl: widget.videoUrl,
      type: MediaThumbnailType.video,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return Image.file(
            file,
            fit: widget.fit,
            filterQuality: FilterQuality.medium,
          );
        }
        return widget.fallback;
      },
    );
  }
}

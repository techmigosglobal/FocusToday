import 'dart:async';

import 'package:flutter/material.dart';

enum ImageShapeType { square, portrait, landscape, unknown }

ImageShapeType classifyImageShapeFromAspectRatio(
  double aspectRatio, {
  double squareTolerance = 0.08,
}) {
  if (!aspectRatio.isFinite || aspectRatio <= 0) {
    return ImageShapeType.unknown;
  }
  if ((aspectRatio - 1.0).abs() <= squareTolerance) {
    return ImageShapeType.square;
  }
  return aspectRatio > 1.0 ? ImageShapeType.landscape : ImageShapeType.portrait;
}

Future<ImageShapeType> resolveImageShapeFromUrl(
  String imageUrl, {
  double squareTolerance = 0.08,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final trimmed = imageUrl.trim();
  if (trimmed.isEmpty) return ImageShapeType.unknown;

  final completer = Completer<ImageShapeType>();
  final provider = NetworkImage(trimmed);
  final stream = provider.resolve(const ImageConfiguration());
  late ImageStreamListener listener;

  listener = ImageStreamListener(
    (ImageInfo image, bool _) {
      final width = image.image.width.toDouble();
      final height = image.image.height.toDouble();
      final ratio = (height <= 0) ? double.nan : width / height;
      if (!completer.isCompleted) {
        completer.complete(
          classifyImageShapeFromAspectRatio(
            ratio,
            squareTolerance: squareTolerance,
          ),
        );
      }
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!completer.isCompleted) {
        completer.complete(ImageShapeType.unknown);
      }
      stream.removeListener(listener);
    },
  );

  stream.addListener(listener);
  try {
    return await completer.future.timeout(timeout);
  } on TimeoutException {
    stream.removeListener(listener);
    return ImageShapeType.unknown;
  }
}

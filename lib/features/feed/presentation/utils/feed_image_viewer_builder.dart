import 'package:flutter/material.dart';

import 'image_shape_type.dart';

Widget buildFeedImageViewer({
  required String mediaUrl,
  required ImageShapeType imageShape,
}) {
  final image = Image.network(
    mediaUrl,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => const Icon(
      Icons.broken_image_outlined,
      color: Colors.white54,
      size: 32,
    ),
  );
  if (imageShape == ImageShapeType.square) {
    return image;
  }
  return InteractiveViewer(minScale: 0.8, maxScale: 5.0, child: image);
}

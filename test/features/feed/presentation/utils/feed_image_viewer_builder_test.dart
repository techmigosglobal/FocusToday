import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_today/features/feed/presentation/utils/feed_image_viewer_builder.dart';
import 'package:focus_today/features/feed/presentation/utils/image_shape_type.dart';

void main() {
  testWidgets('square image viewer disables zoom', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildFeedImageViewer(
            mediaUrl: 'https://example.com/square.jpg',
            imageShape: ImageShapeType.square,
          ),
        ),
      ),
    );

    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('non-square image viewer keeps zoom', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildFeedImageViewer(
            mediaUrl: 'https://example.com/landscape.jpg',
            imageShape: ImageShapeType.landscape,
          ),
        ),
      ),
    );

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}

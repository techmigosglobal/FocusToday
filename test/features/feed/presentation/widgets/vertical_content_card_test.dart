import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_today/core/services/language_service.dart';
import 'package:focus_today/features/feed/presentation/utils/image_shape_type.dart';
import 'package:focus_today/features/feed/presentation/widgets/vertical_content_card.dart';
import 'package:focus_today/shared/models/post.dart';

Post _buildImagePost() {
  final now = DateTime.now();
  return Post(
    id: 'post_1',
    authorId: 'author_1',
    authorName: 'Reporter',
    caption: 'Test caption',
    mediaUrl: 'https://example.com/image.jpg',
    contentType: ContentType.image,
    category: 'news',
    createdAt: now,
    publishedAt: now,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('square image uses contain fit (no crop)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VerticalContentCard(
          post: _buildImagePost(),
          currentLanguage: AppLanguage.english,
          onLanguageToggle: () {},
          onLike: () {},
          onComment: () {},
          imageShapeOverride: ImageShapeType.square,
        ),
      ),
    );

    final imageWidget = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(imageWidget.fit, BoxFit.contain);
  });

  testWidgets('landscape image keeps cover fit', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VerticalContentCard(
          post: _buildImagePost(),
          currentLanguage: AppLanguage.english,
          onLanguageToggle: () {},
          onLike: () {},
          onComment: () {},
          imageShapeOverride: ImageShapeType.landscape,
        ),
      ),
    );

    final imageWidget = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(imageWidget.fit, BoxFit.cover);
  });
}

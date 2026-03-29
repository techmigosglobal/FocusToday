import 'package:flutter_test/flutter_test.dart';
import 'package:focus_today/shared/models/post.dart';

void main() {
  group('Post Model', () {
    test('should create Post from map', () {
      final map = {
        'id': 'test_id',
        'author_id': 'author_id',
        'author_name': 'Test Author',
        'caption': 'Test caption',
        'content_type': 'image',
        'category': 'News',
        'hashtags': 'test,news',
        'status': 'approved',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'published_at': DateTime.now().millisecondsSinceEpoch,
        'likes_count': 10,
        'bookmarks_count': 5,
        'shares_count': 2,
        'is_synced': 1,
        'edit_count': 0,
      };

      final post = Post.fromMap(map);

      expect(post.id, 'test_id');
      expect(post.authorId, 'author_id');
      expect(post.caption, 'Test caption');
      expect(post.contentType, ContentType.image);
      expect(post.category, 'News');
      expect(post.hashtags.length, 2);
      expect(post.status, PostStatus.approved);
      expect(post.likesCount, 10);
    });

    test('should parse delta fields from list payloads', () {
      final map = {
        'id': 'delta_list',
        'author_id': 'author_id',
        'author_name': 'Test Author',
        'caption': 'Caption',
        'caption_delta': [
          {'insert': 'Hello '},
          {
            'insert': 'World',
            'attributes': {'bold': true},
          },
          {'insert': '\n'},
        ],
        'article_content_delta': [
          {'insert': 'Body\n'},
        ],
        'content_type': 'article',
        'category': 'News',
        'status': 'approved',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'published_at': DateTime.now().millisecondsSinceEpoch,
      };

      final post = Post.fromMap(map);
      expect(post.captionDelta, isNotNull);
      expect(post.captionDelta!.length, 3);
      expect(post.articleContentDelta, isNotNull);
      expect(post.articleContentDelta!.length, 1);
    });

    test('should parse delta fields from json-string payloads', () {
      final map = {
        'id': 'delta_string',
        'author_id': 'author_id',
        'author_name': 'Test Author',
        'caption': 'Caption',
        'caption_delta': '[{"insert":"Hello"},{"insert":"\\n"}]',
        'article_content_delta': '{"ops":[{"insert":"Body\\n"}]}',
        'content_type': 'article',
        'category': 'News',
        'status': 'approved',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'published_at': DateTime.now().millisecondsSinceEpoch,
      };

      final post = Post.fromMap(map);
      expect(post.captionDelta, isNotNull);
      expect(post.captionDelta!.length, 2);
      expect(post.articleContentDelta, isNotNull);
      expect(post.articleContentDelta!.length, 1);
    });

    test('should ignore malformed delta strings safely', () {
      final map = {
        'id': 'delta_bad',
        'author_id': 'author_id',
        'author_name': 'Test Author',
        'caption': 'Caption',
        'caption_delta': '{this is not json}',
        'article_content_delta': 'not-json',
        'content_type': 'article',
        'category': 'News',
        'status': 'approved',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'published_at': DateTime.now().millisecondsSinceEpoch,
      };

      final post = Post.fromMap(map);
      expect(post.captionDelta, isNull);
      expect(post.articleContentDelta, isNull);
    });

    test(
      'should fallback to legacy media_type when content_type is missing',
      () {
        final map = {
          'id': 'legacy_media_type',
          'author_id': 'author_id',
          'author_name': 'Test Author',
          'caption': 'Caption',
          'media_type': 'video',
          'category': 'News',
          'status': 'approved',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'published_at': DateTime.now().millisecondsSinceEpoch,
        };

        final post = Post.fromMap(map);
        expect(post.contentType, ContentType.video);
      },
    );

    test('should convert Post to map', () {
      final post = Post(
        id: 'test_id',
        authorId: 'author_id',
        authorName: 'Test Author',
        caption: 'Test caption',
        contentType: ContentType.image,
        category: 'News',
        hashtags: ['test', 'news'],
        status: PostStatus.approved,
        createdAt: DateTime.now(),
        publishedAt: DateTime.now(),
        likesCount: 10,
        bookmarksCount: 5,
        sharesCount: 2,
      );

      final map = post.toMap();

      expect(map['id'], 'test_id');
      expect(map['author_id'], 'author_id');
      expect(map['caption'], 'Test caption');
      expect(map['content_type'], 'image');
      expect(map['category'], 'News');
      expect(map['hashtags'], 'test,news');
      expect(map['status'], 'approved');
      expect(map['likes_count'], 10);
    });

    test('should extract hashtags from caption', () {
      const caption = 'This is a #test post with #hashtags';
      final hashtags = Post.extractHashtags(caption);

      expect(hashtags.length, 2);
      expect(hashtags.contains('test'), true);
      expect(hashtags.contains('hashtags'), true);
    });

    test('should check if post is accessible for user', () {
      final post = Post(
        id: 'test_id',
        authorId: 'author_id',
        authorName: 'Test Author',
        caption: 'Test caption',
        category: 'News',
        createdAt: DateTime.now(),
        publishedAt: DateTime.now().subtract(const Duration(days: 8)),
      );

      // Admin should have access
      expect(post.isAccessibleFor(isAdmin: true, isReporter: false), true);

      // Regular user should also have access (no subscription gating)
      expect(post.isAccessibleFor(isAdmin: false, isReporter: false), true);

      // Public user with 8-day-old post should have access
      expect(post.isAccessibleFor(isAdmin: false, isReporter: false), true);
    });

    test('should copy post with new values', () {
      final original = Post(
        id: 'test_id',
        authorId: 'author_id',
        authorName: 'Test Author',
        caption: 'Original caption',
        category: 'News',
        createdAt: DateTime.now(),
        publishedAt: DateTime.now(),
        likesCount: 10,
      );

      final updated = original.copyWith(
        caption: 'Updated caption',
        likesCount: 15,
      );

      expect(updated.id, original.id);
      expect(updated.caption, 'Updated caption');
      expect(updated.likesCount, 15);
      expect(original.caption, 'Original caption'); // Original unchanged
    });
  });
}

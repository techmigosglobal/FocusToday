import 'dart:convert';

/// Content Type for posts
enum ContentType { image, video, pdf, article, story, poetry, none }

/// Extension for ContentType
extension ContentTypeExtension on ContentType {
  String toStr() {
    return toString().split('.').last;
  }

  static ContentType fromString(String? type) {
    if (type == null) return ContentType.none;
    switch (type) {
      case 'image':
        return ContentType.image;
      case 'video':
        return ContentType.video;
      case 'pdf':
        return ContentType.pdf;
      case 'article':
        return ContentType.article;
      case 'story':
        return ContentType.story;
      case 'poetry':
        return ContentType.poetry;
      case 'none':
        return ContentType.none;
      default:
        return ContentType.none;
    }
  }

  /// Get display name for content type
  String get displayName {
    switch (this) {
      case ContentType.image:
        return 'Image';
      case ContentType.video:
        return 'Video';
      case ContentType.pdf:
        return 'PDF Document';
      case ContentType.article:
        return 'Article';
      case ContentType.story:
        return 'Story';
      case ContentType.poetry:
        return 'Poetry';
      case ContentType.none:
        return 'Text';
    }
  }

  /// Check if content type requires media file
  bool get requiresMedia {
    return this == ContentType.image ||
        this == ContentType.video ||
        this == ContentType.pdf;
  }

  /// Check if content type is text-based
  bool get isTextBased {
    return this == ContentType.article ||
        this == ContentType.story ||
        this == ContentType.poetry ||
        this == ContentType.none;
  }
}

/// Post Status (for approval workflow)
enum PostStatus { pending, approved, rejected }

/// Extension for PostStatus
extension PostStatusExtension on PostStatus {
  String toStr() {
    return toString().split('.').last;
  }

  static PostStatus fromString(String status) {
    switch (status) {
      case 'pending':
        return PostStatus.pending;
      case 'approved':
        return PostStatus.approved;
      case 'rejected':
        return PostStatus.rejected;
      default:
        return PostStatus.approved;
    }
  }
}

/// Post Model
class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String caption;
  final String? captionTe; // Telugu translation
  final String? captionHi; // Hindi translation
  final List<dynamic>? captionDelta; // Rich text delta for caption
  final String? mediaUrl;
  final ContentType contentType;
  final String category;
  final List<String> hashtags;
  final PostStatus status;
  final DateTime createdAt;
  final DateTime publishedAt; // For content delay logic

  // Content-specific fields
  final String? pdfFilePath; // For PDF content
  final String? articleContent; // For article/story content
  final List<dynamic>? articleContentDelta; // Rich text delta for body content
  final List<String>? poemVerses; // For poetry content (list of stanzas/verses)
  final String? articleContentTe; // Telugu article/story translation
  final String? articleContentHi; // Hindi article/story translation
  final List<String>? poemVersesTe; // Telugu poetry translation
  final List<String>? poemVersesHi; // Hindi poetry translation

  // Engagement metrics
  final int likesCount;
  final int bookmarksCount;
  final int sharesCount;

  // User interaction state
  final bool isLikedByMe;
  final bool isBookmarkedByMe;

  // Offline sync
  final bool isSynced;
  final String? rejectionReason;

  // Edit tracking
  final int editCount;
  final DateTime? lastEditedAt;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.caption,
    this.captionTe,
    this.captionHi,
    this.captionDelta,
    this.mediaUrl,
    this.contentType = ContentType.none,
    required this.category,
    this.hashtags = const [],
    this.status = PostStatus.approved,
    required this.createdAt,
    required this.publishedAt,
    this.pdfFilePath,
    this.articleContent,
    this.articleContentDelta,
    this.poemVerses,
    this.articleContentTe,
    this.articleContentHi,
    this.poemVersesTe,
    this.poemVersesHi,
    this.likesCount = 0,
    this.bookmarksCount = 0,
    this.sharesCount = 0,
    this.isLikedByMe = false,
    this.isBookmarkedByMe = false,
    this.isSynced = true,
    this.rejectionReason,
    this.editCount = 0,
    this.lastEditedAt,
  });

  /// Get caption in the specified language
  String getLocalizedCaption(String languageCode) {
    switch (languageCode) {
      case 'te':
        return captionTe ?? caption;
      case 'hi':
        return captionHi ?? caption;
      default:
        return caption;
    }
  }

  /// Convert Post to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'caption': caption,
      'caption_te': captionTe,
      'caption_hi': captionHi,
      'caption_delta': captionDelta,
      'media_url': mediaUrl,
      'content_type': contentType.toStr(),
      'category': category,
      'hashtags': hashtags.join(','),
      'status': status.toStr(),
      'created_at': createdAt.millisecondsSinceEpoch,
      'published_at': publishedAt.millisecondsSinceEpoch,
      'pdf_file_path': pdfFilePath,
      'article_content': articleContent,
      'article_content_delta': articleContentDelta,
      'poem_verses': poemVerses?.join('||| VERSE_SEPARATOR |||'),
      'article_content_te': articleContentTe,
      'article_content_hi': articleContentHi,
      'poem_verses_te': poemVersesTe?.join('||| VERSE_SEPARATOR |||'),
      'poem_verses_hi': poemVersesHi?.join('||| VERSE_SEPARATOR |||'),
      'likes_count': likesCount,
      'bookmarks_count': bookmarksCount,
      'shares_count': sharesCount,
      'is_synced': isSynced,
      'rejection_reason': rejectionReason,
      'edit_count': editCount,
      'last_edited_at': lastEditedAt?.millisecondsSinceEpoch,
    };
  }

  /// Create Post from database Map
  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'],
      authorId: map['author_id'],
      authorName: map['author_name'],
      authorAvatar: map['author_avatar'],
      caption: map['caption'],
      captionTe: map['caption_te'],
      captionHi: map['caption_hi'],
      captionDelta: parseDeltaValue(map['caption_delta']),
      mediaUrl: map['media_url'],
      contentType: ContentTypeExtension.fromString(
        map['content_type'] ?? map['media_type'],
      ),
      category: map['category'],
      hashtags: map['hashtags'] != null && map['hashtags'].toString().isNotEmpty
          ? map['hashtags'].toString().split(',')
          : [],
      status: PostStatusExtension.fromString(map['status']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      publishedAt: DateTime.fromMillisecondsSinceEpoch(map['published_at']),
      pdfFilePath: map['pdf_file_path'],
      articleContent: map['article_content'],
      articleContentDelta: parseDeltaValue(map['article_content_delta']),
      poemVerses:
          map['poem_verses'] != null && map['poem_verses'].toString().isNotEmpty
          ? map['poem_verses'].toString().split('||| VERSE_SEPARATOR |||')
          : null,
      articleContentTe: map['article_content_te'],
      articleContentHi: map['article_content_hi'],
      poemVersesTe:
          map['poem_verses_te'] != null &&
              map['poem_verses_te'].toString().isNotEmpty
          ? map['poem_verses_te'].toString().split('||| VERSE_SEPARATOR |||')
          : null,
      poemVersesHi:
          map['poem_verses_hi'] != null &&
              map['poem_verses_hi'].toString().isNotEmpty
          ? map['poem_verses_hi'].toString().split('||| VERSE_SEPARATOR |||')
          : null,
      likesCount: map['likes_count'] ?? 0,
      bookmarksCount: map['bookmarks_count'] ?? 0,
      sharesCount: map['shares_count'] ?? 0,
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
      rejectionReason: map['rejection_reason'],
      editCount: map['edit_count'] ?? 0,
      lastEditedAt: map['last_edited_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_edited_at'])
          : null,
    );
  }

  /// Parse rich-text delta from list/json-string/map payloads.
  static List<dynamic>? parseDeltaValue(dynamic raw) {
    if (raw == null) return null;

    if (raw is List) {
      return List<dynamic>.from(raw);
    }

    if (raw is Map) {
      final ops = raw['ops'];
      if (ops is List) {
        return List<dynamic>.from(ops);
      }
      return null;
    }

    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      try {
        final decoded = jsonDecode(text);
        return parseDeltaValue(decoded);
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  /// Copy with method for updating post properties
  Post copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? caption,
    String? captionTe,
    String? captionHi,
    List<dynamic>? captionDelta,
    String? mediaUrl,
    ContentType? contentType,
    String? category,
    List<String>? hashtags,
    PostStatus? status,
    DateTime? createdAt,
    DateTime? publishedAt,
    String? pdfFilePath,
    String? articleContent,
    List<dynamic>? articleContentDelta,
    List<String>? poemVerses,
    String? articleContentTe,
    String? articleContentHi,
    List<String>? poemVersesTe,
    List<String>? poemVersesHi,
    int? likesCount,
    int? bookmarksCount,
    int? sharesCount,
    bool? isLikedByMe,
    bool? isBookmarkedByMe,
    bool? isSynced,
    String? rejectionReason,
    int? editCount,
    DateTime? lastEditedAt,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      caption: caption ?? this.caption,
      captionTe: captionTe ?? this.captionTe,
      captionHi: captionHi ?? this.captionHi,
      captionDelta: captionDelta ?? this.captionDelta,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      contentType: contentType ?? this.contentType,
      category: category ?? this.category,
      hashtags: hashtags ?? this.hashtags,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      publishedAt: publishedAt ?? this.publishedAt,
      pdfFilePath: pdfFilePath ?? this.pdfFilePath,
      articleContent: articleContent ?? this.articleContent,
      articleContentDelta: articleContentDelta ?? this.articleContentDelta,
      poemVerses: poemVerses ?? this.poemVerses,
      articleContentTe: articleContentTe ?? this.articleContentTe,
      articleContentHi: articleContentHi ?? this.articleContentHi,
      poemVersesTe: poemVersesTe ?? this.poemVersesTe,
      poemVersesHi: poemVersesHi ?? this.poemVersesHi,
      likesCount: likesCount ?? this.likesCount,
      bookmarksCount: bookmarksCount ?? this.bookmarksCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isBookmarkedByMe: isBookmarkedByMe ?? this.isBookmarkedByMe,
      isSynced: isSynced ?? this.isSynced,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      editCount: editCount ?? this.editCount,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
    );
  }

  /// Extract hashtags from caption
  static List<String> extractHashtags(String text) {
    final RegExp hashtagRegex = RegExp(r'#\w+');
    final matches = hashtagRegex.allMatches(text);
    return matches.map((m) => m.group(0)!.substring(1)).toList();
  }

  /// Check if post is accessible for a given user role
  bool isAccessibleFor({required bool isAdmin, required bool isReporter}) {
    // All users have access to all content (subscription removed)
    return true;
  }

  /// Get days until accessible for public users (always 0 now)
  int get daysUntilPublicAccess => 0;
}

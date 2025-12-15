import '../../../shared/models/post.dart';

/// Sample Post Data for Testing
/// This will be replaced with real data from backend/database later
class SamplePostData {
  static final List<Post> samplePosts = [
    Post(
      id: '1',
      authorId: 'author1',
      authorName: 'EagleTV News',
      authorAvatar: null,
      caption: '''Breaking News: Technology Revolution in India 🇮🇳

India is witnessing unprecedented growth in the technology sector. With millions of new developers joining the workforce every year, the nation is becoming a global tech powerhouse.

#Technology #India #Innovation''',
      mediaUrl: null,
      contentType: ContentType.none,
      category: 'News',
      hashtags: ['Technology', 'India', 'Innovation'],
      status: PostStatus.approved,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      likesCount: 1245,
      bookmarksCount: 342,
      sharesCount: 89,
    ),
    
    Post(
      id: '2',
      authorId: 'author2',
      authorName: 'Sports Reporter',
      authorAvatar: null,
      caption: '''Cricket World Cup 2024: India's Spectacular Victory! 🏏

In a thrilling match, Team India secured a commanding victory against their rivals. The captain's brilliant century led the team to an unforgettable win.

#Cricket #Sports #TeamIndia #WorldCup''',
      mediaUrl: null,
      contentType: ContentType.none,
      category: 'Sports',
      hashtags: ['Cricket', 'Sports', 'TeamIndia', 'WorldCup'],
      status: PostStatus.approved,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
      likesCount: 3421,
      bookmarksCount: 876,
      sharesCount: 234,
    ),
    
    Post(
      id: '3',
      authorId: 'author3',
      authorName: 'Entertainment Buzz',
      authorAvatar: null,
      caption: '''New Telugu Blockbuster Breaks Box Office Records! 🎬

The latest Telugu cinema release has taken the box office by storm, breaking all previous records in its opening weekend. Critics praise the outstanding performances.

#Telugu #Cinema #Entertainment #Tollywood''',
      mediaUrl: null,
      contentType: ContentType.none,
      category: 'Entertainment',
      hashtags: ['Telugu', 'Cinema', 'Entertainment', 'Tollywood'],
      status: PostStatus.approved,
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
      likesCount: 2156,
      bookmarksCount: 534,
      sharesCount: 167,
    ),
    
    Post(
      id: '4',
      authorId: 'author4',
      authorName: 'Health & Wellness',
      authorAvatar: null,
      caption: '''5 Simple Habits for a Healthier Lifestyle 💪

1. Drink 8 glasses of water daily
2. Get 7-8 hours of sleep
3. Exercise for 30 minutes
4. Eat fresh fruits & vegetables
5. Practice mindfulness

Start today for a better tomorrow!

#Health #Wellness #Lifestyle''',
      mediaUrl: null,
      contentType: ContentType.none,
      category: 'Health',
      hashtags: ['Health', 'Wellness', 'Lifestyle'],
      status: PostStatus.approved,
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      publishedAt: DateTime.now().subtract(const Duration(hours: 12)),
      likesCount: 892,
      bookmarksCount: 445,
      sharesCount: 78,
    ),
    
    Post(
      id: '5',
      authorId: 'author5',
      authorName: 'Tech Insider',
      authorAvatar: null,
      caption: '''AI Revolution: How Artificial Intelligence is Changing Our Lives 🤖

From smart assistants to self-driving cars, AI is transforming every aspect of our daily lives. Learn about the latest developments in this fascinating field.

#AI #Technology #Future #Innovation''',
      mediaUrl: null,
      contentType: ContentType.none,
      category: 'Technology',
      hashtags: ['AI', 'Technology', 'Future', 'Innovation'],
      status: PostStatus.approved,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      likesCount: 1678,
      bookmarksCount: 789,
      sharesCount: 234,
    ),
  ];
  
  /// Get posts (simulating API call)
  static Future<List<Post>> getPosts({int limit = 10}) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return samplePosts.take(limit).toList();
  }
  
  /// Get single post
  static Future<Post?> getPost(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return samplePosts.firstWhere((post) => post.id == id);
    } catch (e) {
      return null;
    }
  }
}

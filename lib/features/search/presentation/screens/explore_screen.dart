import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../data/repositories/search_repository.dart';
import 'search_screen.dart';

/// Explore Screen
/// Discover content through categories, trending posts, and popular hashtags
class ExploreScreen extends StatefulWidget {
  final User currentUser;

  const ExploreScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final SearchRepository _searchRepo = SearchRepository();
  
  List<Post> _trendingPosts = [];
  List<Map<String, dynamic>> _popularHashtags = [];
  Map<String, int> _categoryCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExploreData();
  }

  Future<void> _loadExploreData() async {
    setState(() => _isLoading = true);

    try {
      final trending = await _searchRepo.getTrendingPosts(limit: 5);
      final hashtags = await _searchRepo.getPopularHashtags(limit: 8);
      final categories = await _searchRepo.getAllCategoryCounts();

      setState(() {
        _trendingPosts = trending;
        _popularHashtags = hashtags;
        _categoryCounts = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading explore data: $e')),
        );
      }
    }
  }

  void _navigateToCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryPostsScreen(
          currentUser: widget.currentUser,
          category: category,
        ),
      ),
    );
  }

  void _navigateToHashtag(String hashtag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HashtagPostsScreen(
          currentUser: widget.currentUser,
          hashtag: hashtag,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchScreen(currentUser: widget.currentUser),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadExploreData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Categories Section
                  Text(
                    'Browse by Category',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildCategoriesGrid(),
                  const SizedBox(height: 24),

                  // Trending Hashtags
                  if (_popularHashtags.isNotEmpty) ...[
                    Text(
                      'Popular Hashtags',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildHashtagsSection(),
                    const SizedBox(height: 24),
                  ],

                  // Trending Posts
                  if (_trendingPosts.isNotEmpty) ...[
                    Text(
                      'Trending Posts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ..._trendingPosts.map((post) => _buildTrendingPostCard(post)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildCategoriesGrid() {
    final categories = [
      {'name': 'News', 'icon': Icons.newspaper, 'color': Colors.blue},
      {'name': 'Entertainment', 'icon': Icons.movie, 'color': Colors.purple},    {
'name': 'Sports', 'icon': Icons.sports_soccer, 'color': Colors.green},
      {'name': 'Politics', 'icon': Icons.how_to_vote, 'color': Colors.red},
      {'name': 'Technology', 'icon': Icons.computer, 'color': Colors.cyan},
      {'name': 'Health', 'icon': Icons.health_and_safety, 'color': Colors.pink},
      {'name': 'Business', 'icon': Icons.business, 'color': Colors.orange},
      {'name': 'Other', 'icon': Icons.category, 'color': Colors.grey},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final count = _categoryCounts[category['name']] ?? 0;

        return GestureDetector(
          onTap: () => _navigateToCategory(category['name'] as String),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: (category['color'] as Color).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category['icon'] as IconData,
                  size: 32,
                  color: category['color'] as Color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                category['name'] as String,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (count > 0)
                Text(
                  '$count',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHashtagsSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _popularHashtags.map((item) {
        final hashtag = item['hashtag'] as String;
        final count = item['count'] as int;

        return GestureDetector(
          onTap: () => _navigateToHashtag(hashtag),
          child: Chip(
            avatar: Icon(Icons.trending_up, size: 16, color: AppColors.primary),
            label: Text('#$hashtag ($count)'),
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            labelStyle: TextStyle(color: AppColors.primary),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTrendingPostCard(Post post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.trending_up, color: AppColors.primary),
        ),
        title: Text(
          post.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${post.authorName} • ${post.likesCount} likes',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        onTap: () {
          // Future: Navigate to post detail
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post detail coming soon!'),
              duration: Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }
}

// Category Posts Screen
class CategoryPostsScreen extends StatefulWidget {
  final User currentUser;
  final String category;

  const CategoryPostsScreen({
    super.key,
    required this.currentUser,
    required this.category,
  });

  @override
  State<CategoryPostsScreen> createState() => _CategoryPostsScreenState();
}

class _CategoryPostsScreenState extends State<CategoryPostsScreen> {
  final SearchRepository _searchRepo = SearchRepository();
  List<Post> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    try {
      final posts = await _searchRepo.getPostsByCategory(widget.category);
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading posts: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ))
          : _posts.isEmpty
              ? Center(
                  child: Text('No posts in this category'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(
                          post.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          post.authorName,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Post detail coming soon!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

// Hashtag Posts Screen
class HashtagPostsScreen extends StatefulWidget {
  final User currentUser;
  final String hashtag;

  const HashtagPostsScreen({
    super.key,
    required this.currentUser,
    required this.hashtag,
  });

  @override
  State<HashtagPostsScreen> createState() => _HashtagPostsScreenState();
}

class _HashtagPostsScreenState extends State<HashtagPostsScreen> {
  final SearchRepository _searchRepo = SearchRepository();
  List<Post> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    try {
      final posts = await _searchRepo.searchByHashtag(widget.hashtag);
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading posts: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('#${widget.hashtag}'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ))
          : _posts.isEmpty
              ? Center(
                  child: Text('No posts with this hashtag'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(
                          post.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${post.authorName} • ${post.category}',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Post detail coming soon!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

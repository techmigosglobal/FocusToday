import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../data/repositories/search_repository.dart';
import 'search_screen.dart';
import 'dart:ui';

/// Advanced Explore Screen
/// Modern, glassmorphic design discoverability hub
class ExploreScreen extends StatefulWidget {
  final User currentUser;

  const ExploreScreen({super.key, required this.currentUser});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final SearchRepository _searchRepo = SearchRepository();
  final ScrollController _scrollController = ScrollController();

  List<Post> _trendingPosts = [];
  List<Map<String, dynamic>> _popularHashtags = [];
  bool _isLoading = true;

  // Ticker controller
  late ScrollController _tickerController;
  Timer? _tickerTimer;
  double _tickerOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _tickerController = ScrollController();
    _loadExploreData();
    _startTicker();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tickerController.dispose();
    _tickerTimer?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_tickerController.hasClients) {
        _tickerOffset += 1.0;
        if (_tickerOffset >= _tickerController.position.maxScrollExtent) {
          _tickerOffset = 0.0;
          _tickerController.jumpTo(0.0);
        } else {
          _tickerController.jumpTo(_tickerOffset);
        }
      }
    });
  }

  Future<void> _loadExploreData() async {
    setState(() => _isLoading = true);
    try {
      final trending = await _searchRepo.getTrendingPosts(limit: 10);
      final hashtags = await _searchRepo.getPopularHashtags(limit: 10);

      if (mounted) {
        setState(() {
          _trendingPosts = trending;
          _popularHashtags = hashtags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Light grey background
      body: Stack(
        children: [
          // Background Gradient Ornaments
          Positioned(
            top: -100,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purple.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),

          // Main Content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Custom Glassmorphic App Bar
              SliverAppBar(
                expandedHeight: 120.0,
                floating: true,
                pinned: true,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: const Text(
                    'Explore',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  ),
                  background: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.black87),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SearchScreen(currentUser: widget.currentUser),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // Trending Ticker
              SliverToBoxAdapter(child: _buildTrendingTicker()),

              // Search Bar Placeholder (Interactive)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SearchScreen(currentUser: widget.currentUser),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Search for topics, people...',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Categories Section
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 100,
                      child: _isLoading
                          ? _buildShimmerCategories()
                          : _buildCategoriesList(),
                    ),
                  ],
                ),
              ),

              // Trending Hashtags
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.trending_up,
                            color: Colors.purple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Trending Now',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _isLoading
                          ? _buildShimmerHashtags()
                          : _buildHashtagsList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Featured Posts (Masonry-like Grid)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Featured Stories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),

              const SliverPadding(padding: EdgeInsets.only(top: 16)),

              _isLoading
                  ? SliverToBoxAdapter(child: _buildShimmerGrid())
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return _buildFeaturedPostCard(_trendingPosts[index]);
                        }, childCount: _trendingPosts.length),
                      ),
                    ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingTicker() {
    final trendingNews = [
      "Breaking: New AI model released by EagleTech!",
      "Sports: Regional finals start this weekend.",
      "Business: Stock market hits record high.",
      "Entertaiment: Upcoming blockbusters to watch.",
      "Politics: New policy changes announced today.",
    ];

    return Container(
      height: 35,
      color: AppColors.primary.withValues(alpha: 0.05),
      child: ListView.builder(
        controller: _tickerController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 100, // Large number for pseudo-looping
        itemBuilder: (context, index) {
          final text = trendingNews[index % trendingNews.length];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 20),
                const Text("•", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoriesList() {
    final categories = [
      {'name': 'News', 'icon': Icons.newspaper, 'color': 0xFF3B82F6},
      {'name': 'Sports', 'icon': Icons.sports_soccer, 'color': 0xFF10B981},
      {'name': 'Tech', 'icon': Icons.memory, 'color': 0xFF8B5CF6},
      {'name': 'Politics', 'icon': Icons.policy, 'color': 0xFFEF4444},
      {'name': 'Health', 'icon': Icons.favorite, 'color': 0xFFEC4899},
      {'name': 'Biz', 'icon': Icons.business, 'color': 0xFFF59E0B},
      {'name': 'Edu', 'icon': Icons.school, 'color': 0xFF6366F1},
    ];

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final name = cat['name'] as String;
        final color = Color(cat['color'] as int);

        return GestureDetector(
          onTap: () => _navigateToCategory(name),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      cat['icon'] as IconData,
                      color: color,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHashtagsList() {
    return Row(
      children: _popularHashtags.map((item) {
        final hashtag = item['hashtag'];
        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToHashtag(hashtag),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '#$hashtag',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeaturedPostCard(Post post) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image/Media Background
          if (post.mediaUrl != null && post.contentType == ContentType.image)
            Image.network(
              post.mediaUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.grey[200]),
            )
          else
            Container(
              color: const Color(0xFF5F5F5F),
              child: const Center(
                child: Icon(Icons.article, color: Colors.white54, size: 40),
              ),
            ),

          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  post.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.white24,
                      backgroundImage: post.authorAvatar != null
                          ? NetworkImage(post.authorAvatar!)
                          : null,
                      child: post.authorAvatar == null
                          ? const Icon(
                              Icons.person,
                              size: 10,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Ripple Effect
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Navigate to post details
              },
            ),
          ),
        ],
      ),
    );
  }

  // Navigation Methods
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

  // Shimmer Loaders
  Widget _buildShimmerCategories() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
              Container(height: 10, width: 40, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerHashtags() {
    return Row(
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(right: 8),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 80,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
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
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading posts: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category)),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _posts.isEmpty
          ? Center(child: Text('No posts in this category'))
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
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // View post details
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
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading posts: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.hashtag}')),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _posts.isEmpty
          ? Center(child: Text('No posts with this hashtag'))
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
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // View details
                    },
                  ),
                );
              },
            ),
    );
  }
}

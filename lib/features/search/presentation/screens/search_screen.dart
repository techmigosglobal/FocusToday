import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart' as models;
import '../../data/repositories/search_repository.dart';
import '../../../../core/services/search_history_service.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

/// Search Screen
/// Allows users to search for posts and users
class SearchScreen extends StatefulWidget {
  final models.User currentUser;

  const SearchScreen({super.key, required this.currentUser});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SearchRepository _searchRepo = SearchRepository();
  Timer? _debounce;

  List<Post> _postResults = [];
  List<models.User> _userResults = [];
  List<String> _searchHistory = [];
  bool _isLoading = false;
  String _selectedFilter = 'All'; // All, Posts, Users

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final historyService = await SearchHistoryService.init();
    setState(() {
      _searchHistory = historyService.getHistory();
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _postResults = [];
        _userResults = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save to history
      final historyService = await SearchHistoryService.init();
      await historyService.addToHistory(query);

      // Perform search based on filter
      if (_selectedFilter == 'All' || _selectedFilter == 'Posts') {
        final posts = await _searchRepo.searchPosts(query);
        if (mounted) {
          setState(() => _postResults = posts);
        }
      }

      if (_selectedFilter == 'All' || _selectedFilter == 'Users') {
        final List<models.User> users = await _searchRepo.searchUsers(query);
        if (mounted) {
          setState(() => _userResults = users);
        }
      }

      await _loadSearchHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearHistory() async {
    final historyService = await SearchHistoryService.init();
    await historyService.clearHistory();
    setState(() => _searchHistory = []);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.isNotEmpty;
    final hasResults = _postResults.isNotEmpty || _userResults.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search posts, users, hashtags...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: AppColors.textSecondary),
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (hasQuery)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _postResults = [];
                  _userResults = [];
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          if (hasQuery)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Posts'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Users'),
                ],
              ),
            ),

          // Search results or history
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  )
                : hasQuery
                ? hasResults
                      ? _buildSearchResults()
                      : _buildEmptyState()
                : _buildSearchHistory(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = label);
        _performSearch(_searchController.text);
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // Posts results
        if (_postResults.isNotEmpty &&
            (_selectedFilter == 'All' || _selectedFilter == 'Posts')) ...[
          if (_selectedFilter == 'All')
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Posts (${_postResults.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ..._postResults.map((post) => _buildPostTile(post)),
        ],

        // Users results
        if (_userResults.isNotEmpty &&
            (_selectedFilter == 'All' || _selectedFilter == 'Users')) ...[
          if (_selectedFilter == 'All')
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Users (${_userResults.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ..._userResults.map((user) => _buildUserTile(user)),
        ],
      ],
    );
  }

  Widget _buildPostTile(Post post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(post.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${post.authorName} • ${post.category}',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.textSecondary,
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

  Widget _buildUserTile(models.User user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: user.profilePicture != null
              ? ClipOval(
                  child: Image.network(
                    user.profilePicture!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.person, color: AppColors.background),
                  ),
                )
              : Icon(Icons.person, color: AppColors.background),
        ),
        title: Text(user.displayName),
        subtitle: Text(
          user.role.toStr().toUpperCase(),
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.textSecondary,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                currentUser: widget.currentUser,
                profileUser: user,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No search history',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(onPressed: _clearHistory, child: const Text('Clear')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchHistory.length,
            itemBuilder: (context, index) {
              final query = _searchHistory[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(query),
                onTap: () {
                  _searchController.text = query;
                  _performSearch(query);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

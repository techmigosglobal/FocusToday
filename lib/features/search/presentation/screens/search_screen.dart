import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/post_translation_service.dart';
import '../../../../core/services/search_history_service.dart';
import '../../../../core/services/ux_telemetry_service.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart' as models;
import '../../../../shared/widgets/page_transitions.dart';
import '../../../../main.dart';

import '../../../../shared/widgets/slice_surface.dart';
import '../../../feed/data/repositories/post_translation_repository.dart';
import '../../../feed/presentation/screens/post_detail_screen.dart';
import '../../../feed/presentation/screens/pdf_viewer_screen.dart';
import '../../../../shared/widgets/pdf_thumbnail.dart';
import '../../data/repositories/search_repository.dart';

/// Search Screen
/// Allows users to search for posts and users.
class SearchScreen extends StatefulWidget {
  final models.User currentUser;
  final String? initialQuery;

  const SearchScreen({super.key, required this.currentUser, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SearchRepository _searchRepo = SearchRepository();
  final UxTelemetryService _telemetry = UxTelemetryService.instance;
  Timer? _debounce;
  int _searchRequestId = 0;

  List<Post> _postResults = [];
  List<models.User> _userResults = [];
  List<Post> _allPosts = []; // unified discover feed
  bool _isLoading = false;
  bool _isDiscoverLoading = false;
  bool _isWarmingTranslationModels = false;
  String _selectedFilter = 'All'; // All, Posts, Users
  AppLanguage _currentLanguage = AppLanguage.english;
  LanguageService? _languageService;
  bool _isLanguageListenerAttached = false;
  final Map<String, LocalizedPostText> _localizedPostText = {};
  final Set<String> _translationInFlight = <String>{};
  Timer? _translationWarmDebounce;
  AppLocalizations get _l => AppLocalizations(_currentLanguage);

  // GAP-007: advanced filters
  String? _filterCategory;
  ContentType? _filterContentType;

  // Count of active advanced filters
  int get _activeFilterCount =>
      (_filterCategory != null ? 1 : 0) + (_filterContentType != null ? 1 : 0);

  // Available categories for filter picker
  static const _categories = [
    'politics',
    'sports',
    'technology',
    'health',
    'business',
    'entertainment',
    'science',
    'education',
    'crime',
    'environment',
  ];

  Color _tileIconBg() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppColors.primaryOf(context).withValues(alpha: 0.28)
        : AppColors.primary.withValues(alpha: 0.12);
  }

  Color _tileIconFg() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.onPrimaryOf(context) : AppColors.primary;
  }

  @override
  void initState() {
    super.initState();
    _initLanguage();
    _loadDiscoveryData();
    // GAP-005: pre-populate and execute from hashtag tap
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchController.text = widget.initialQuery!;
        _performSearch(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    if (_isLanguageListenerAttached && _languageService != null) {
      _languageService!.removeListener(_handleLanguageChange);
      _isLanguageListenerAttached = false;
    }
    _searchController.dispose();
    _debounce?.cancel();
    _translationWarmDebounce?.cancel();
    super.dispose();
  }

  Future<void> _initLanguage() async {
    final lang = FocusTodayApp.languageService ?? await LanguageService.init();
    FocusTodayApp.languageService ??= lang;
    _languageService = lang;
    if (!_isLanguageListenerAttached) {
      lang.addListener(_handleLanguageChange);
      _isLanguageListenerAttached = true;
    }
    if (!mounted) return;
    setState(() => _currentLanguage = lang.currentLanguage);
    _scheduleWarmLocalizedText();
    unawaited(_warmTranslationModels());
  }

  void _handleLanguageChange() {
    final languageService = _languageService;
    if (!mounted || languageService == null) return;
    final nextLanguage = languageService.currentLanguage;
    if (nextLanguage == _currentLanguage) return;
    setState(() => _currentLanguage = nextLanguage);
    _scheduleWarmLocalizedText();
    unawaited(_warmTranslationModels());
  }

  Future<void> _warmTranslationModels() async {
    final langCode = _currentLanguage.code;
    if (langCode == 'en') return;
    if (_isWarmingTranslationModels) return;
    if (mounted) setState(() => _isWarmingTranslationModels = true);
    try {
      await PostTranslationService.warmUpForLanguage(langCode);
    } finally {
      if (mounted) setState(() => _isWarmingTranslationModels = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final normalizedQuery = query.trim();
    final requestId = ++_searchRequestId;
    if (normalizedQuery.isEmpty) {
      setState(() {
        _postResults = [];
        _userResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      unawaited(
        _telemetry.track(
          eventName: 'search_performed',
          eventGroup: 'discovery',
          screen: 'search',
          user: widget.currentUser,
          metadata: {
            'query_length': normalizedQuery.length,
            'filter': _selectedFilter,
            'has_advanced_filters': _activeFilterCount > 0,
          },
        ),
      );

      final postFuture =
          (_selectedFilter == 'All' || _selectedFilter == 'Posts')
          ? (normalizedQuery.startsWith('#')
                ? _searchRepo.searchByHashtag(normalizedQuery)
                : _searchRepo.searchPosts(
                    normalizedQuery,
                    category: _filterCategory,
                    contentType: _filterContentType,
                  ))
          : Future.value(<Post>[]);

      final userFuture =
          (_selectedFilter == 'All' || _selectedFilter == 'Users')
          ? _searchRepo.searchUsers(normalizedQuery)
          : Future.value(<models.User>[]);

      final results = await Future.wait<dynamic>([postFuture, userFuture]);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _postResults = results[0] as List<Post>;
        _userResults = results[1] as List<models.User>;
      });
      _scheduleWarmLocalizedText();

      unawaited(_persistSearchQuery(normalizedQuery));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l.errorWithMessage('$e'))));
      }
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _persistSearchQuery(String query) async {
    final historyService = await SearchHistoryService.init();
    await historyService.addToHistory(query);
  }

  Future<void> _loadDiscoveryData() async {
    if (!mounted) return;
    setState(() => _isDiscoverLoading = true);
    try {
      final results = await Future.wait<List<Post>>([
        _searchRepo.getTrendingPosts(limit: 30),
        _searchRepo.getRecommendedPosts(widget.currentUser.id, limit: 30),
      ]);
      if (!mounted) return;
      final trending = results[0];
      final recommended = results[1];
      // Merge and deduplicate by post id
      final seen = <String>{};
      final merged = <Post>[];
      for (final p in [...trending, ...recommended]) {
        if (seen.add(p.id)) merged.add(p);
      }
      setState(() {
        _allPosts = merged;
      });
      _scheduleWarmLocalizedText();
    } catch (e) {
      debugPrint('[SearchScreen] discovery load error: $e');
    } finally {
      if (mounted) setState(() => _isDiscoverLoading = false);
    }
  }

  String _localizedKey(Post post, String languageCode) {
    return '${post.id}|$languageCode';
  }

  void _scheduleWarmLocalizedText({
    Duration delay = const Duration(milliseconds: 120),
  }) {
    _translationWarmDebounce?.cancel();
    _translationWarmDebounce = Timer(delay, () {
      if (!mounted) return;
      unawaited(_warmLocalizedTextForVisibleLists());
    });
  }

  Future<void> _warmLocalizedTextForVisibleLists() async {
    final langCode = _currentLanguage.code;
    if (langCode == 'en') return;

    final posts = <Post>[..._allPosts.take(24), ..._postResults.take(24)];
    if (posts.isEmpty) return;

    final dedup = <String, Post>{for (final post in posts) post.id: post};
    final pending = <String, Future<LocalizedPostText>>{};
    for (final post in dedup.values) {
      final key = _localizedKey(post, langCode);
      if (_localizedPostText.containsKey(key) ||
          _translationInFlight.contains(key)) {
        continue;
      }
      _translationInFlight.add(key);
      pending[key] = PostTranslationRepository.getLocalizedText(
        post: post,
        targetLanguageCode: langCode,
      );
    }
    if (pending.isEmpty) return;

    final resolved = await Future.wait(
      pending.entries.map((entry) async {
        try {
          final value = await entry.value;
          return MapEntry(entry.key, value);
        } catch (_) {
          return null;
        }
      }),
    );

    if (!mounted) return;
    final updates = <String, LocalizedPostText>{};
    for (final entry in resolved) {
      if (entry != null) updates[entry.key] = entry.value;
    }
    if (updates.isNotEmpty) {
      setState(() => _localizedPostText.addAll(updates));
    } else if (mounted) {
      setState(() {});
    }
    _translationInFlight.removeAll(pending.keys);
  }

  String _displayCaption(Post post) {
    if (_currentLanguage == AppLanguage.english) return post.caption;
    final localized =
        _localizedPostText[_localizedKey(post, _currentLanguage.code)];
    return localized?.caption.trim().isNotEmpty == true
        ? localized!.caption
        : post.caption;
  }

  bool get _isTranslatingText =>
      _isWarmingTranslationModels || _translationInFlight.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.isNotEmpty;
    final hasResults = _postResults.isNotEmpty || _userResults.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SliceBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _buildSearchHeader(hasQuery),
              ),
              const SizedBox(height: 12),
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
                    : _buildSearchHome(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // (Stats row removed — discover now shows the unified post feed)

  // GAP-007: Show filter bottom sheet for category + content type
  Future<void> _showFiltersSheet() async {
    String? tempCategory = _filterCategory;
    ContentType? tempContentType = _filterContentType;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
                top: 16,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondaryOf(
                          context,
                        ).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        _l.filterResults,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheet(() {
                            tempCategory = null;
                            tempContentType = null;
                          });
                        },
                        child: Text(_l.clear),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _l.category,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _categories.map((cat) {
                      final sel = tempCategory == cat;
                      return FilterChip(
                        label: Text(
                          _l.getCategoryName(cat),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? AppColors.onPrimaryOf(context)
                                : AppColors.textPrimaryOf(context),
                          ),
                        ),
                        selected: sel,
                        selectedColor: AppColors.primaryOf(context),
                        checkmarkColor: AppColors.onPrimaryOf(context),
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.08,
                        ),
                        showCheckmark: false,
                        side: BorderSide.none,
                        onSelected: (_) =>
                            setSheet(() => tempCategory = sel ? null : cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _l.contentTypeLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final ct in [
                        ContentType.article,
                        ContentType.video,
                        ContentType.image,
                      ])
                        FilterChip(
                          label: Text(
                            ct.name[0].toUpperCase() + ct.name.substring(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tempContentType == ct
                                  ? AppColors.onPrimaryOf(context)
                                  : AppColors.textPrimaryOf(context),
                            ),
                          ),
                          selected: tempContentType == ct,
                          selectedColor: AppColors.primaryOf(context),
                          checkmarkColor: AppColors.onPrimaryOf(context),
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.08,
                          ),
                          showCheckmark: false,
                          side: BorderSide.none,
                          onSelected: (_) => setSheet(
                            () => tempContentType = tempContentType == ct
                                ? null
                                : ct,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        setState(() {
                          _filterCategory = tempCategory;
                          _filterContentType = tempContentType;
                        });
                        if (_searchController.text.isNotEmpty) {
                          _performSearch(_searchController.text);
                        }
                      },
                      child: Text(
                        _l.applyFilters,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchHeader(bool hasQuery) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header title row
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _l.discover,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryOf(context),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      _l.discoverSubtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryOf(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_currentLanguage != AppLanguage.english &&
                        _isTranslatingText) ...[
                      const SizedBox(height: 4),
                      Text(
                        _l.translating,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.travel_explore_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceTier2Of(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.dividerOf(context)),
          ),
          child: _buildSearchInput(hasQuery),
        ),
      ],
    );
  }

  Widget _buildSearchInput(bool hasQuery) {
    return Semantics(
      textField: true,
      label: _l.searchFieldSemantics,
      child: TextField(
        controller: _searchController,
        autofocus: false,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: _l.searchHint,
          hintStyle: TextStyle(color: AppColors.textSecondaryOf(context)),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: _l.filters,
                    onPressed: _showFiltersSheet,
                  ),
                  if (_activeFilterCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$_activeFilterCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (hasQuery)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
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
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 24),
      children: [
        if (_postResults.isNotEmpty &&
            (_selectedFilter == 'All' || _selectedFilter == 'Posts')) ...[
          if (_selectedFilter == 'All')
            _buildSectionHeader(_l.postsCount(_postResults.length)),
          ..._postResults.map((post) => _buildPostTile(post)),
        ],
        if (_userResults.isNotEmpty &&
            (_selectedFilter == 'All' || _selectedFilter == 'Users')) ...[
          if (_selectedFilter == 'All')
            _buildSectionHeader(_l.usersCount(_userResults.length)),
          ..._userResults.map((user) => _buildUserTile(user)),
        ],
      ],
    );
  }

  Widget _buildPostTile(Post post) {
    final mediaUrl = post.mediaUrl;
    final isPdf =
        post.contentType == ContentType.pdf ||
        post.pdfFilePath != null ||
        (mediaUrl != null && mediaUrl.toLowerCase().contains('.pdf'));

    return SliceCard(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      onTap: () {
        if (isPdf) {
          Navigator.push(
            context,
            SmoothPageRoute(
              builder: (_) => PdfViewerScreen(
                post: post,
                currentLanguage: _currentLanguage,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            SmoothPageRoute(
              builder: (_) => PostDetailScreen(
                post: post,
                currentUser: widget.currentUser,
                currentLanguage: _currentLanguage,
              ),
            ),
          );
        }
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _tileIconBg(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.article_rounded, color: _tileIconFg()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayCaption(post),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${post.authorName} • ${_l.getCategoryName(post.category)}',
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.textSecondaryOf(context),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(models.User user) {
    return SliceCard(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      onTap: () {
        final query = user.displayName.trim();
        if (query.isEmpty) return;
        _searchController.text = query;
        setState(() => _selectedFilter = 'Posts');
        unawaited(
          _telemetry.track(
            eventName: 'discover_user_to_posts',
            eventGroup: 'discovery',
            screen: 'search',
            user: widget.currentUser,
            metadata: {'target_user_id': user.id},
          ),
        );
        _performSearch(query);
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: user.profilePicture != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user.profilePicture!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      memCacheWidth: 88,
                      errorWidget: (_, _, _) =>
                          const Icon(Icons.person, color: Colors.white),
                    ),
                  )
                : const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _localizedRoleLabel(user.role),
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _l.tapToDiscoverPosts,
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(
                      context,
                    ).withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.search_rounded, size: 14, color: _tileIconFg()),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SliceCard(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 52,
              color: AppColors.textSecondaryOf(context).withValues(alpha: 0.45),
            ),
            const SizedBox(height: 10),
            Text(
              _l.noResultsFound,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _l.tryDifferentKeywords,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHome() {
    if (_isDiscoverLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    final posts = _allPosts;

    return RefreshIndicator(
      onRefresh: _loadDiscoveryData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
        children: [
          // Post count badge
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _l.postsCount(posts.length),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
          ),

          if (posts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 48,
                      color: AppColors.textSecondaryOf(
                        context,
                      ).withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _l.noPostsYet,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Horizontal news-list: alternating thumbnail left / right
            ...List.generate(posts.length, (index) {
              return _buildNewsListCard(
                posts[index],
                mediaOnLeft: index.isEven,
              );
            }),
        ],
      ),
    );
  }

  /// Horizontal news-list card: thumbnail on one side, content on the other.
  Widget _buildNewsListCard(Post post, {required bool mediaOnLeft}) {
    final timeAgo = _getTimeAgo(post.createdAt);
    final hasMedia = post.mediaUrl != null && post.mediaUrl!.isNotEmpty;
    final isPdf =
        post.contentType == ContentType.pdf || post.pdfFilePath != null;
    final isVideo = post.contentType == ContentType.video;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 1.35);
    final cardHeight = (120.0 * textScale).clamp(120.0, 170.0);

    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(mediaOnLeft ? 16 : 0),
        bottomLeft: Radius.circular(mediaOnLeft ? 16 : 0),
        topRight: Radius.circular(mediaOnLeft ? 0 : 16),
        bottomRight: Radius.circular(mediaOnLeft ? 0 : 16),
      ),
      child: Container(
        width: 120,
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.07),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isPdf)
              PdfThumbnail(
                pdfUrl: post.pdfFilePath ?? post.mediaUrl ?? '',
                width: 120,
                height: double.infinity,
                fit: BoxFit.contain,
                label: '',
              )
            else if (hasMedia)
              CachedNetworkImage(
                imageUrl: post.mediaUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 240,
                fadeInDuration: const Duration(milliseconds: 200),
                errorWidget: (_, _, _) =>
                    _buildMediaIcon(_getContentTypeIcon(post.contentType)),
              )
            else
              _buildMediaIcon(_getContentTypeIcon(post.contentType)),
            // Video play icon overlay
            if (isVideo)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.overlaySoftOf(context),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final content = Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                post.category.toUpperCase(),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _displayCaption(post),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.3,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 11,
                  color: AppColors.textMutedOf(context),
                ),
                const SizedBox(width: 3),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMutedOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '•',
                  style: TextStyle(
                    color: AppColors.textMutedOf(context),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    post.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return SliceCard(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      padding: EdgeInsets.zero,
      onTap: () {
        if (isPdf) {
          Navigator.push(
            context,
            SmoothPageRoute(
              builder: (_) => PdfViewerScreen(
                post: post,
                currentLanguage: _currentLanguage,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            SmoothPageRoute(
              builder: (_) => PostDetailScreen(
                post: post,
                currentUser: widget.currentUser,
                currentLanguage: _currentLanguage,
              ),
            ),
          );
        }
      },
      child: SizedBox(
        height: cardHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: mediaOnLeft ? [thumbnail, content] : [content, thumbnail],
        ),
      ),
    );
  }

  Widget _buildMediaIcon(IconData icon) {
    return Center(
      child: Icon(
        icon,
        size: 32,
        color: AppColors.primary.withValues(alpha: 0.35),
      ),
    );
  }

  IconData _getContentTypeIcon(ContentType type) {
    switch (type) {
      case ContentType.article:
        return Icons.article_rounded;
      case ContentType.video:
        return Icons.play_circle_filled_rounded;
      case ContentType.image:
        return Icons.image_rounded;
      case ContentType.poetry:
        return Icons.music_note_rounded;
      case ContentType.story:
        return Icons.auto_stories_rounded;
      case ContentType.pdf:
        return Icons.picture_as_pdf_rounded;
      case ContentType.none:
        return Icons.article_rounded;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 7) return '${(diff.inDays / 7).floor()}w';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  String _localizedRoleLabel(models.UserRole role) {
    switch (role) {
      case models.UserRole.superAdmin:
        return _l.superAdminLabel.toUpperCase();
      case models.UserRole.admin:
        return _l.admin.toUpperCase();
      case models.UserRole.reporter:
        return _l.reporter.toUpperCase();
      case models.UserRole.publicUser:
        return _l.publicUser.toUpperCase();
    }
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _tileIconBg(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: _tileIconFg()),
            ),
            const SizedBox(width: 10),
          ] else ...[
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

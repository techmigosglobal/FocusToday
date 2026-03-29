import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/post_translation_service.dart';
import '../../../../core/services/post_sync_service.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/slice_surface.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../../shared/widgets/video_thumbnail_view.dart';
import '../../../../shared/widgets/pdf_thumbnail.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/post_translation_repository.dart';
import 'edit_post_screen.dart';
import 'pdf_viewer_screen.dart';
import 'video_player_screen.dart';
import '../../../../main.dart';

enum _PostFilter { all, pending, approved, rejected }

class AllPostsScreen extends StatefulWidget {
  final User currentUser;

  const AllPostsScreen({super.key, required this.currentUser});

  @override
  State<AllPostsScreen> createState() => _AllPostsScreenState();
}

class _AllPostsScreenState extends State<AllPostsScreen> {
  final PostRepository _postRepo = PostRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Post> _pendingPosts = [];
  List<Post> _approvedPosts = [];
  List<Post> _rejectedPosts = [];
  _PostFilter _activeFilter = _PostFilter.all;
  bool _isLoading = true;
  bool _isMutating = false;
  final Set<String> _expandedPostIds = {};
  AppLanguage _currentLanguage = AppLanguage.english;
  LanguageService? _languageService;
  bool _isLanguageListenerAttached = false;
  StreamSubscription<PostSyncEvent>? _postSyncSubscription;
  Timer? _refreshDebounce;
  Timer? _translationWarmDebounce;
  final Map<String, LocalizedPostText> _localizedPostText = {};
  final Set<String> _translationInFlight = <String>{};
  bool _isWarmingTranslationModels = false;

  @override
  void initState() {
    super.initState();
    _listenToPostSync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLanguage();
      _loadAllPosts();
    });
  }

  @override
  void dispose() {
    if (_isLanguageListenerAttached && _languageService != null) {
      _languageService!.removeListener(_handleLanguageChange);
      _isLanguageListenerAttached = false;
    }
    _postSyncSubscription?.cancel();
    _refreshDebounce?.cancel();
    _translationWarmDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToPostSync() {
    _postSyncSubscription = PostSyncService.stream.listen((_) {
      if (!mounted) return;
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
        if (mounted) _loadAllPosts();
      });
    });
  }

  Future<void> _initLanguage() async {
    final lang = FocusTodayApp.languageService ?? await LanguageService.init();
    FocusTodayApp.languageService ??= lang;
    _languageService = lang;
    if (!_isLanguageListenerAttached) {
      lang.addListener(_handleLanguageChange);
      _isLanguageListenerAttached = true;
    }
    if (mounted) setState(() => _currentLanguage = lang.currentLanguage);
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

  Future<void> _loadAllPosts() async {
    final l = AppLocalizations(_currentLanguage);
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _postRepo.getPostsByStatus(PostStatus.pending),
        _postRepo.getPostsByStatus(PostStatus.approved),
        _postRepo.getPostsByStatus(PostStatus.rejected),
      ]);

      if (!mounted) return;
      setState(() {
        _pendingPosts = List<Post>.from(results[0]);
        _approvedPosts = List<Post>.from(results[1]);
        _rejectedPosts = List<Post>.from(results[2]);
        _isLoading = false;
      });
      _scheduleWarmLocalizedText();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l.errorLoadingPosts}: $e')));
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
      unawaited(_warmLocalizedTextForVisiblePosts());
    });
  }

  Future<void> _warmLocalizedTextForVisiblePosts() async {
    final langCode = _currentLanguage.code;
    if (langCode == 'en') return;

    final posts = _filteredPosts.take(24).toList(growable: false);
    if (posts.isEmpty) return;

    final pending = <String, Future<LocalizedPostText>>{};
    for (final post in posts) {
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
    } else {
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

  String _displayBodyPreview(Post post, String fallback) {
    if (_currentLanguage == AppLanguage.english) return fallback;
    final localized =
        _localizedPostText[_localizedKey(post, _currentLanguage.code)];
    return localized?.snippet.trim().isNotEmpty == true
        ? localized!.snippet
        : fallback;
  }

  bool get _isTranslatingText =>
      _isWarmingTranslationModels || _translationInFlight.isNotEmpty;

  List<Post> get _filteredPosts {
    List<Post> source;
    switch (_activeFilter) {
      case _PostFilter.pending:
        source = _pendingPosts;
        break;
      case _PostFilter.approved:
        source = _approvedPosts;
        break;
      case _PostFilter.rejected:
        source = _rejectedPosts;
        break;
      case _PostFilter.all:
        source = [..._pendingPosts, ..._approvedPosts, ..._rejectedPosts];
        break;
    }

    source.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return source;
    return source.where((post) {
      return post.caption.toLowerCase().contains(query) ||
          post.authorName.toLowerCase().contains(query) ||
          post.category.toLowerCase().contains(query);
    }).toList();
  }

  bool get _canModerate => widget.currentUser.canModerate;
  bool get _hasModuleAccess => widget.currentUser.canModerate;

  Future<void> _approvePost(Post post) async {
    await _updatePostStatus(post: post, status: PostStatus.approved);
  }

  Future<void> _rejectPost(Post post) async {
    final l = AppLocalizations(_currentLanguage);
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.rejectPost),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l.rejectionReasonLabel,
            hintText: l.enterReason,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l.reject),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _updatePostStatus(
      post: post,
      status: PostStatus.rejected,
      rejectionReason: reasonController.text.trim(),
    );
  }

  Future<void> _updatePostStatus({
    required Post post,
    required PostStatus status,
    String? rejectionReason,
  }) async {
    final l = AppLocalizations(_currentLanguage);
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      final normalizedReason = rejectionReason?.trim() ?? '';
      final effectiveRejectionReason = status == PostStatus.rejected
          ? (normalizedReason.isNotEmpty ? normalizedReason : l.policyViolation)
          : rejectionReason;

      await _postRepo.updatePostStatus(
        postId: post.id,
        status: status,
        rejectionReason: effectiveRejectionReason,
        authorId: post.authorId,
      );

      final updated = post.copyWith(
        status: status,
        rejectionReason: status == PostStatus.rejected
            ? effectiveRejectionReason
            : post.rejectionReason,
      );

      setState(() {
        _pendingPosts.removeWhere((p) => p.id == post.id);
        _approvedPosts.removeWhere((p) => p.id == post.id);
        _rejectedPosts.removeWhere((p) => p.id == post.id);
        if (status == PostStatus.pending) _pendingPosts.insert(0, updated);
        if (status == PostStatus.approved) _approvedPosts.insert(0, updated);
        if (status == PostStatus.rejected) _rejectedPosts.insert(0, updated);
      });

      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == PostStatus.approved
                  ? l.postApprovedSuccess
                  : status == PostStatus.rejected
                  ? l.postRejectedSuccess
                  : l.postUpdated,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l.statusUpdateFailed}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _editPost(Post post) async {
    final updated = await Navigator.of(context).push<bool>(
      SmoothPageRoute(
        builder: (_) =>
            EditPostScreen(post: post, currentUser: widget.currentUser),
      ),
    );
    if (updated == true) {
      await _loadAllPosts();
    }
  }

  Future<void> _deletePost(Post post) async {
    final l = AppLocalizations(_currentLanguage);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deletePostTitle),
        content: Text(l.deletePostMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || _isMutating) return;

    setState(() => _isMutating = true);
    try {
      await _postRepo.deletePost(post.id, authorId: post.authorId);
      setState(() {
        _pendingPosts.removeWhere((p) => p.id == post.id);
        _approvedPosts.removeWhere((p) => p.id == post.id);
        _rejectedPosts.removeWhere((p) => p.id == post.id);
      });
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.deleteConfirmation)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l.deleteFailed}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  void _openMedia(Post post) {
    final mediaUrl = post.mediaUrl?.trim();
    final isPdf =
        post.contentType == ContentType.pdf ||
        (post.pdfFilePath?.trim().isNotEmpty ?? false) ||
        (mediaUrl != null && mediaUrl.toLowerCase().contains('.pdf'));
    final isVideo = post.contentType == ContentType.video;
    final isImage = post.contentType == ContentType.image;

    if (isVideo && mediaUrl != null && mediaUrl.isNotEmpty) {
      Navigator.of(
        context,
      ).push(SmoothPageRoute(builder: (_) => VideoPlayerScreen(post: post)));
      return;
    }

    if (isPdf) {
      Navigator.of(context).push(
        SmoothPageRoute(
          builder: (_) =>
              PdfViewerScreen(post: post, currentLanguage: _currentLanguage),
        ),
      );
      return;
    }

    if (isImage && mediaUrl != null && mediaUrl.isNotEmpty) {
      Navigator.of(context).push(
        SmoothPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Image.network(mediaUrl, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    }
  }

  void _toggleExpanded(Post post) {
    setState(() {
      if (_expandedPostIds.contains(post.id)) {
        _expandedPostIds.remove(post.id);
      } else {
        _expandedPostIds.add(post.id);
      }
    });
  }

  String _postBody(Post post) {
    if (post.articleContent != null && post.articleContent!.trim().isNotEmpty) {
      return post.articleContent!.trim();
    }
    if (post.poemVerses != null && post.poemVerses!.isNotEmpty) {
      return post.poemVerses!.join('\n').trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(_currentLanguage);
    final posts = _filteredPosts;

    if (!_hasModuleAccess) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SliceBackground(
          child: SafeArea(
            child: Center(
              child: SliceCard(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 52,
                      color: AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      localizations.adminAccessRequired,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      localizations.allPostsQueueModerationOnly,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SliceBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAllPosts,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                    children: [
                      SliceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.dashboard_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        localizations.allPosts,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        localizations.visibleItems(
                                          posts.length,
                                        ),
                                        style: TextStyle(
                                          color: AppColors.textSecondaryOf(
                                            context,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (_currentLanguage !=
                                              AppLanguage.english &&
                                          _isTranslatingText)
                                        Text(
                                          'Translating...',
                                          style: TextStyle(
                                            color: AppColors.textSecondaryOf(
                                              context,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryCards(),
                            const SizedBox(height: 12),
                            _buildFilterRow(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (posts.isEmpty)
                        _buildEmptyState(localizations)
                      else
                        ...posts.map(_buildPostTile),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final l = AppLocalizations(_currentLanguage);
    return Row(
      children: [
        Expanded(
          child: SliceStatChip(
            label: l.pending,
            value: _pendingPosts.length.toString(),
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliceStatChip(
            label: l.approved,
            value: _approvedPosts.length.toString(),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliceStatChip(
            label: l.rejected,
            value: _rejectedPosts.length.toString(),
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    final l = AppLocalizations(_currentLanguage);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filterChip(l.all, _PostFilter.all),
        _filterChip(l.pending, _PostFilter.pending),
        _filterChip(l.approved, _PostFilter.approved),
        _filterChip(l.rejected, _PostFilter.rejected),
      ],
    );
  }

  Widget _filterChip(String label, _PostFilter filter) {
    final selected = _activeFilter == filter;
    return SlicePill(
      label: label,
      selected: selected,
      onTap: () {
        setState(() => _activeFilter = filter);
        _scheduleWarmLocalizedText();
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final title = hasQuery ? l.noResults : l.noPostsHere;
    final subtitle = hasQuery
        ? l.tryDifferentSearchTermOrClearFilters
        : _activeFilter == _PostFilter.pending
        ? l.newSubmissionsWillAppearHere
        : _activeFilter == _PostFilter.approved
        ? l.approvedPostsWillAppearHere
        : _activeFilter == _PostFilter.rejected
        ? l.rejectedPostsWillAppearHere
        : l.postsWillAppear;
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Center(
        child: SliceCard(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_rounded,
                size: 44,
                color: AppColors.textSecondaryOf(
                  context,
                ).withValues(alpha: 0.6),
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondaryOf(context)),
              ),
              if (hasQuery || _activeFilter != _PostFilter.all) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _activeFilter = _PostFilter.all;
                    });
                  },
                  child: Text(l.clearSearchAndFilters),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostTile(Post post) {
    final l = AppLocalizations(_currentLanguage);
    final isExpanded = _expandedPostIds.contains(post.id);
    final body = _postBody(post);
    final fallbackPreview = body.isNotEmpty ? body : post.caption;
    final previewText = _displayBodyPreview(post, fallbackPreview);

    return SliceCard(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openMedia(post),
            child: _buildThumb(post),
          ),
          const SizedBox(height: 12),
          Text(
            _displayCaption(post),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            '${post.authorName} • ${post.category}',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [_statusChip(post.status), _typeChip(post.contentType)],
          ),
          const SizedBox(height: 10),
          Text(
            previewText,
            maxLines: isExpanded ? null : 4,
            overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimaryOf(context),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (body.isNotEmpty && body.length > 180) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => _toggleExpanded(post),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(isExpanded ? l.showLess : l.showFullContent),
            ),
          ],
          if (_canModerate) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isMutating ? null : () => _editPost(post),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: Text(l.edit),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isMutating ? null : () => _deletePost(post),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: Text(l.delete),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_canModerate && post.status == PostStatus.pending) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isMutating ? null : () => _approvePost(post),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(l.approve),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isMutating ? null : () => _rejectPost(post),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(l.reject),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThumb(Post post) {
    final mediaUrl = post.mediaUrl?.trim();
    final pdfUrl = (post.pdfFilePath?.trim().isNotEmpty ?? false)
        ? post.pdfFilePath!.trim()
        : mediaUrl;
    final isPdf =
        post.contentType == ContentType.pdf ||
        (post.pdfFilePath?.trim().isNotEmpty ?? false) ||
        (mediaUrl != null && mediaUrl.toLowerCase().contains('.pdf'));

    if (post.contentType == ContentType.image &&
        mediaUrl != null &&
        mediaUrl.isNotEmpty) {
      return _withMediaTypeBadge(
        post,
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: mediaUrl,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            placeholder: (_, _) => _thumbPlaceholder(post),
            errorWidget: (_, _, _) => _thumbPlaceholder(post),
          ),
        ),
      );
    }

    if (post.contentType == ContentType.video &&
        mediaUrl != null &&
        mediaUrl.isNotEmpty) {
      return _withMediaTypeBadge(
        post,
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: double.infinity,
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoThumbnailView(
                  videoUrl: mediaUrl,
                  fallback: _thumbPlaceholder(post),
                  fit: BoxFit.cover,
                ),
                Container(color: Colors.black.withValues(alpha: 0.24)),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isPdf && pdfUrl != null && pdfUrl.isNotEmpty) {
      return _withMediaTypeBadge(
        post,
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: double.infinity,
            height: 220,
            child: PdfThumbnail(
              pdfUrl: pdfUrl,
              width: double.infinity,
              height: 220,
              fit: BoxFit.contain,
              label: '',
            ),
          ),
        ),
      );
    }

    return _thumbPlaceholder(post);
  }

  Widget _withMediaTypeBadge(Post post, Widget child) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              post.contentType.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbPlaceholder(Post post) {
    IconData icon;
    switch (post.contentType) {
      case ContentType.video:
        icon = Icons.play_circle_outline_rounded;
        break;
      case ContentType.pdf:
        icon = Icons.picture_as_pdf_rounded;
        break;
      case ContentType.article:
      case ContentType.story:
      case ContentType.poetry:
      case ContentType.none:
      case ContentType.image:
        icon = Icons.article_outlined;
        break;
    }
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 48),
          const SizedBox(height: 8),
          Text(
            post.contentType.displayName,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(PostStatus status) {
    late final Color color;
    late final String label;
    switch (status) {
      case PostStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case PostStatus.approved:
        color = Colors.green;
        label = 'Approved';
        break;
      case PostStatus.rejected:
        color = Colors.red;
        label = 'Rejected';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _typeChip(ContentType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.displayName,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

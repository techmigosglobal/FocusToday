import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../feed/data/repositories/post_repository.dart';
import '../../../feed/presentation/screens/edit_post_screen.dart';
import '../../../feed/presentation/screens/post_detail_screen.dart';
import '../../../feed/presentation/screens/video_player_screen.dart';
import 'audit_timeline_screen.dart';

/// Moderation Screen
/// Card-based layout with quick actions for approve/edit/reject
class ModerationScreen extends StatefulWidget {
  final User currentUser;

  const ModerationScreen({super.key, required this.currentUser});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen>
    with SingleTickerProviderStateMixin {
  final PostRepository _postRepo = PostRepository();
  late TabController _tabController;
  AppLocalizations get _l => AppLocalizations(
    AppLanguage.fromCode(widget.currentUser.preferredLanguage),
  );

  List<Post> _pendingPosts = [];
  List<Post> _approvedPosts = [];
  List<Post> _rejectedPosts = [];
  bool _isLoading = true;
  bool get _hasModuleAccess => widget.currentUser.canModerate;

  // ── Bulk selection (GAP-011) ─────────────────────────────────────────────
  final Set<String> _selectedIds = {};
  bool _selectMode = false;

  void _enterSelectMode(String postId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectMode = true;
      _selectedIds.add(postId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String postId) {
    setState(() {
      if (_selectedIds.contains(postId)) {
        _selectedIds.remove(postId);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(postId);
      }
    });
  }

  Future<void> _bulkApprove() async {
    if (_selectedIds.isEmpty) return;
    final ids = Set<String>.from(_selectedIds);
    _exitSelectMode();
    final posts = _pendingPosts.where((p) => ids.contains(p.id)).toList();
    await Future.wait(
      posts.map(
        (p) => _postRepo.updatePostStatus(
          postId: p.id,
          status: PostStatus.approved,
          authorId: p.authorId,
        ),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${posts.length} ${_l.postApproved}'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      _loadAllPosts();
    }
  }

  Future<void> _bulkReject() async {
    if (_selectedIds.isEmpty) return;
    await _showBulkRejectSheet();
  }

  Future<void> _showBulkRejectSheet() async {
    final reasonController = TextEditingController();
    String? selectedCategory;
    final violationCategories = [
      'Spam',
      'Misinformation',
      'Hate Speech',
      'Adult Content',
      'Violence',
      'Off Topic',
    ];

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cancel_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    '${_l.bulkReject} (${_selectedIds.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _l.violationCategory,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: violationCategories.map((cat) {
                  final selected = selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    selectedColor: Colors.red.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      color: selected ? Colors.red : null,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                    onSelected: (_) =>
                        setSheetState(() => selectedCategory = cat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text(
                _l.additionalReasonOptional,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: _l.enterReason,
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(_l.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_l.rejectAll),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    final ids = Set<String>.from(_selectedIds);
    _exitSelectMode();
    final posts = _pendingPosts.where((p) => ids.contains(p.id)).toList();
    final reason = [
      if (selectedCategory != null) selectedCategory!,
      if (reasonController.text.trim().isNotEmpty) reasonController.text.trim(),
    ].join(' – ');
    await Future.wait(
      posts.map(
        (p) => _postRepo.updatePostStatus(
          postId: p.id,
          status: PostStatus.rejected,
          rejectionReason: reason.isNotEmpty ? reason : _l.policyViolation,
          authorId: p.authorId,
        ),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${posts.length} ${_l.rejected}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      _loadAllPosts();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllPosts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllPosts() async {
    setState(() => _isLoading = true);

    try {
      // Fetch all three statuses in parallel for faster loading
      final results = await Future.wait([
        _postRepo.getPostsByStatus(PostStatus.pending),
        _postRepo.getPostsByStatus(PostStatus.approved),
        _postRepo.getPostsByStatus(PostStatus.rejected),
      ]);

      if (mounted) {
        setState(() {
          _pendingPosts = List<Post>.from(results[0]);
          _approvedPosts = List<Post>.from(results[1]);
          _rejectedPosts = List<Post>.from(results[2]);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_l.errorLoadingPosts}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approvePost(Post post) async {
    try {
      await _postRepo.updatePostStatus(
        postId: post.id,
        status: PostStatus.approved,
        authorId: post.authorId,
      );

      HapticFeedback.mediumImpact();

      setState(() {
        _pendingPosts.removeWhere((p) => p.id == post.id);
        _approvedPosts.insert(0, post.copyWith(status: PostStatus.approved));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(_l.postApprovedSuccess),
              ],
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_l.errorLabel}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectPost(Post post) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(_l.rejectPost),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_l.provideReason),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _l.enterReason,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _l.cancel,
              style: TextStyle(color: AppColors.textSecondaryOf(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(_l.reject, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final normalizedReason = reasonController.text.trim();
      await _postRepo.updatePostStatus(
        postId: post.id,
        status: PostStatus.rejected,
        rejectionReason: normalizedReason,
        authorId: post.authorId,
      );

      HapticFeedback.mediumImpact();

      setState(() {
        _pendingPosts.removeWhere((p) => p.id == post.id);
        _rejectedPosts.insert(
          0,
          post.copyWith(
            status: PostStatus.rejected,
            rejectionReason: normalizedReason.isNotEmpty
                ? normalizedReason
                : 'Policy violation',
          ),
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.close, color: Colors.white),
                const SizedBox(width: 8),
                Text(_l.postRejectedSuccess),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_l.errorLabel}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openPost(Post post) {
    if (post.contentType == ContentType.video) {
      Navigator.of(
        context,
      ).push(SmoothPageRoute(builder: (_) => VideoPlayerScreen(post: post)));
      return;
    }

    Navigator.of(context).push(
      SmoothPageRoute(
        builder: (_) => PostDetailScreen(
          post: post,
          currentUser: widget.currentUser,
          currentLanguage: AppLanguage.fromCode(
            widget.currentUser.preferredLanguage,
          ),
        ),
      ),
    );
  }

  Future<void> _editPost(Post post) async {
    final result = await Navigator.push(
      context,
      SmoothPageRoute(
        builder: (_) =>
            EditPostScreen(post: post, currentUser: widget.currentUser),
      ),
    );

    if (result == true) {
      _loadAllPosts();
    }
  }

  /// Show audit timeline for a specific post
  void _showAuditTimeline(Post post) {
    Navigator.push(
      context,
      SmoothPageRoute(builder: (_) => AuditTimelineScreen(postId: post.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasModuleAccess) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(_l.moderation),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 56,
                  color: AppColors.textSecondaryOf(context),
                ),
                const SizedBox(height: 12),
                Text(
                  _l.moderationAccessRequired,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _l.onlyAdminRolesCanModerate,
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: _selectMode
            ? Text(_l.selectedCount(_selectedIds.length))
            : Text(_l.moderation),
        leading: _selectMode
            ? IconButton(
                onPressed: _exitSelectMode,
                icon: const Icon(Icons.close),
              )
            : null,
        centerTitle: true,
        actions: _selectMode
            ? [
                TextButton(
                  onPressed: () => setState(() {
                    final currentPosts = _tabController.index == 0
                        ? _pendingPosts
                        : _tabController.index == 1
                        ? _approvedPosts
                        : _rejectedPosts;
                    _selectedIds
                      ..clear()
                      ..addAll(currentPosts.map((p) => p.id));
                  }),
                  child: Text(_l.selectAllLabel),
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryOf(context),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_empty, size: 18),
                  const SizedBox(width: 4),
                  Text(_l.pendingCount(_pendingPosts.length)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 4),
                  Text(_l.approvedCount(_approvedPosts.length)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cancel_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text(_l.rejectedCount(_rejectedPosts.length)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildPostList(_pendingPosts, showActions: true),
                  _buildPostList(_approvedPosts),
                  _buildPostList(_rejectedPosts),
                ],
              ),
      ),
    );
  }

  Widget _buildPostList(List<Post> posts, {bool showActions = false}) {
    if (posts.isEmpty && !_isLoading) {
      return _buildEmptyState(
        title: _tabController.index == 0
            ? _l.noPendingPosts
            : _tabController.index == 1
            ? _l.noApprovedPosts
            : _l.noRejectedPosts,
        subtitle: _tabController.index == 0
            ? _l.newSubmissionsWillAppearHere
            : _tabController.index == 1
            ? _l.approvedPostsWillAppearHere
            : _l.rejectedPostsWillAppearHere,
      );
    }

    final listView = RefreshIndicator(
      onRefresh: _loadAllPosts,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: _selectMode ? 96 : 16,
        ),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return _buildPostCard(post, showActions: showActions);
        },
      ),
    );

    if (!_selectMode || !showActions) return listView;

    // Floating bulk action bar when in select mode on the Pending tab
    return Stack(
      children: [
        listView,
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    _l.selectedCount(_selectedIds.length),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _selectedIds.isEmpty ? null : _bulkApprove,
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: Text(_l.approve),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _selectedIds.isEmpty ? null : _bulkReject,
                    icon: const Icon(Icons.cancel, size: 16),
                    label: Text(_l.reject),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return EmptyStateWidget(
      icon: Icons.inbox_rounded,
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _buildPostCard(Post post, {bool showActions = false}) {
    final isSelected = _selectedIds.contains(post.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _selectMode
            ? () => _toggleSelect(post.id)
            : () => _openPost(post),
        onLongPress: (showActions && !_selectMode)
            ? () => _enterSelectMode(post.id)
            : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview Image/Gradient
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getCategoryColor(post.category),
                          _getCategoryColor(
                            post.category,
                          ).withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (post.mediaUrl != null &&
                            post.mediaUrl!.isNotEmpty &&
                            post.contentType == ContentType.image)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: post.mediaUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 480,
                              fadeInDuration: const Duration(milliseconds: 150),
                              errorWidget: (_, _, _) => Center(
                                child: Icon(
                                  _getContentTypeIcon(post.contentType),
                                  size: 48,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          )
                        else
                          Center(
                            child: Icon(
                              _getContentTypeIcon(post.contentType),
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        if (post.contentType == ContentType.video)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                size: 42,
                                color: Colors.white,
                              ),
                            ),
                          ),

                        // Category badge
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              post.category.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),

                        // Content type badge
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getContentTypeIcon(post.contentType),
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.2,
                              ),
                              child: Text(
                                post.authorName.isNotEmpty
                                    ? post.authorName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.authorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    _getTimeAgo(post.createdAt),
                                    style: TextStyle(
                                      color: AppColors.textSecondaryOf(context),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Caption
                        Text(
                          post.caption,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Actions
                        if (showActions) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.check_circle,
                                  label: _l.approve,
                                  color: AppColors.secondary,
                                  onTap: () => _approvePost(post),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.edit,
                                  label: _l.edit,
                                  color: AppColors.primary,
                                  onTap: () => _editPost(post),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.cancel,
                                  label: _l.reject,
                                  color: Colors.red,
                                  onTap: () => _rejectPost(post),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.history,
                                  label: _l.auditHistory,
                                  color: Colors.blueGrey,
                                  onTap: () => _showAuditTimeline(post),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Selection checkbox overlay
              if (_selectMode)
                Positioned(
                  top: 10,
                  right: 10,
                  child: AnimatedScale(
                    scale: _selectMode ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _selectedIds.contains(post.id)
                            ? AppColors.primary
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: _selectedIds.contains(post.id)
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'news':
        return AppColors.primary;
      case 'articles':
        return const Color(0xFF2196F3);
      case 'stories':
        return const Color(0xFF9C27B0);
      case 'poetry':
        return const Color(0xFFE91E63);
      case 'others':
        return const Color(0xFF607D8B);
      default:
        return AppColors.secondary;
    }
  }

  IconData _getContentTypeIcon(ContentType type) {
    switch (type) {
      case ContentType.image:
        return Icons.image;
      case ContentType.video:
        return Icons.videocam;
      case ContentType.article:
        return Icons.article;
      case ContentType.story:
        return Icons.auto_stories;
      case ContentType.poetry:
        return Icons.format_quote;
      case ContentType.pdf:
        return Icons.picture_as_pdf;
      default:
        return Icons.text_fields;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return _l.justNow;
    } else if (difference.inHours < 1) {
      return _l.minutesAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return _l.hoursAgo(difference.inHours);
    } else {
      return _l.daysAgo(difference.inDays);
    }
  }
}

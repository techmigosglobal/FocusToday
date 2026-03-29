import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../data/repositories/post_repository.dart';
import 'post_detail_screen.dart';

/// Reporter screen to view own pending posts.
class PendingPostsScreen extends StatefulWidget {
  final User currentUser;

  const PendingPostsScreen({super.key, required this.currentUser});

  @override
  State<PendingPostsScreen> createState() => _PendingPostsScreenState();
}

class _PendingPostsScreenState extends State<PendingPostsScreen> {
  final PostRepository _postRepo = PostRepository();
  List<Post> _pendingPosts = [];
  bool _isLoading = true;

  AppLocalizations get _l => AppLocalizations(
    AppLanguage.fromCode(widget.currentUser.preferredLanguage),
  );

  @override
  void initState() {
    super.initState();
    _loadPendingPosts();
  }

  Future<void> _loadPendingPosts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final posts = await _postRepo.getPostsByAuthor(
        widget.currentUser.id,
        status: PostStatus.pending,
      );
      if (!mounted) return;
      setState(() {
        _pendingPosts = posts;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(_l.pendingPosts),
        backgroundColor: AppColors.surfaceOf(context),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pendingPosts.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadPendingPosts,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pendingPosts.length,
                  itemBuilder: (context, index) =>
                      _buildPostCard(_pendingPosts[index]),
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.hourglass_top_rounded,
      title: _l.noPendingPosts,
      subtitle: _l.newSubmissionsWillAppearHere,
    );
  }

  Widget _buildPostCard(Post post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          SmoothPageRoute(
            builder: (_) => PostDetailScreen(
              post: post,
              currentUser: widget.currentUser,
              currentLanguage: AppLanguage.fromCode(
                widget.currentUser.preferredLanguage,
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_l.pending} • ${post.category}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/models/comment.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../data/repositories/comment_repository.dart';

/// Comments Bottom Sheet
/// Glassmorphic slide-up comments view with smooth animations
class CommentsBottomSheet extends StatefulWidget {
  final Post post;
  final User currentUser;
  final VoidCallback? onClose;
  final AppLanguage currentLanguage;

  const CommentsBottomSheet({
    super.key,
    required this.post,
    required this.currentUser,
    this.onClose,
    required this.currentLanguage,
  });

  static Future<void> show(
    BuildContext context,
    Post post,
    User currentUser,
    AppLanguage currentLanguage,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundOf(context).withValues(alpha: 0),
      barrierColor: AppColors.overlayStrongOf(context),
      builder: (context) => CommentsBottomSheet(
        post: post,
        currentUser: currentUser,
        currentLanguage: currentLanguage,
      ),
    );
  }

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  final CommentRepository _commentRepo = CommentRepository();
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  Comment? _replyingTo;
  final Map<String, List<Comment>> _replies = {};
  final Map<String, bool> _showingReplies = {};
  final Map<String, bool> _loadingReplies = {};

  Color _iconChipBg() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppColors.primaryOf(context).withValues(alpha: 0.28)
        : AppColors.primary.withValues(alpha: 0.1);
  }

  Color _iconChipFg() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.onPrimaryOf(context) : AppColors.primary;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _commentRepo.getComments(widget.post.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      if (_replyingTo != null) {
        final parentId = _replyingTo!.id;
        final newReply = await _commentRepo.addReply(
          postId: widget.post.id,
          commentId: parentId,
          authorId: widget.currentUser.id,
          authorName: widget.currentUser.displayName,
          authorAvatar: widget.currentUser.profilePicture,
          content: text,
        );
        if (mounted) {
          setState(() {
            _replies[parentId] = [...(_replies[parentId] ?? []), newReply];
            _showingReplies[parentId] = true;

            // Update parent comment reply count locally
            final parentIndex = _comments.indexWhere((c) => c.id == parentId);
            if (parentIndex != -1) {
              _comments[parentIndex] = _comments[parentIndex].copyWith(
                replyCount: _comments[parentIndex].replyCount + 1,
              );
            }

            _replyingTo = null;
            _commentController.clear();
            _isSending = false;
          });
        }
      } else {
        final newComment = await _commentRepo.addComment(
          postId: widget.post.id,
          authorId: widget.currentUser.id,
          authorName: widget.currentUser.displayName,
          authorAvatar: widget.currentUser.profilePicture,
          content: text,
        );
        if (mounted) {
          setState(() {
            _comments.insert(0, newComment);
            _commentController.clear();
            _isSending = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleReplies(String commentId) async {
    if (_showingReplies[commentId] == true) {
      setState(() => _showingReplies[commentId] = false);
      return;
    }

    if (_replies.containsKey(commentId)) {
      setState(() => _showingReplies[commentId] = true);
      return;
    }

    setState(() => _loadingReplies[commentId] = true);
    try {
      final replies = await _commentRepo.getReplies(widget.post.id, commentId);
      if (mounted) {
        setState(() {
          _replies[commentId] = replies;
          _showingReplies[commentId] = true;
          _loadingReplies[commentId] = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingReplies[commentId] = false);
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _slideAnimation.value) * 200),
          child: Opacity(
            opacity: _slideAnimation.value,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              margin: EdgeInsets.only(bottom: bottomPadding),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(
                        context,
                      ).withValues(alpha: 0.95),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.overlaySoftOf(context),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(child: _buildCommentsList()),
                        _buildInputBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.dividerOf(context), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.textSecondaryOf(context).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.chat_bubble_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations(widget.currentLanguage).comments,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _iconChipBg(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_comments.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _iconChipFg(),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: AppColors.textSecondaryOf(context).withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations(widget.currentLanguage).noCommentsYet,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations(widget.currentLanguage).beFirstToComment,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryOf(
                  context,
                ).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        return _buildCommentItem(comment, index);
      },
    );
  }

  Widget _buildCommentItem(Comment comment, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: _iconChipBg(),
              child: Text(
                comment.authorName[0].toUpperCase(),
                style: TextStyle(
                  color: _iconChipFg(),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(comment.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimaryOf(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _replyingTo = comment;
                            _focusNode.requestFocus();
                          });
                        },
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                      if (comment.replyCount > 0) ...[
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _toggleReplies(comment.id),
                          child: Text(
                            _showingReplies[comment.id] == true
                                ? 'Hide replies'
                                : 'View ${comment.replyCount} replies',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_loadingReplies[comment.id] == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (_showingReplies[comment.id] == true &&
                      _replies.containsKey(comment.id))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: _replies[comment.id]!.map((reply) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Text(
                                    reply.authorName[0].toUpperCase(),
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            reply.authorName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _timeAgo(reply.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondaryOf(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        reply.content,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textPrimaryOf(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(
          top: BorderSide(color: AppColors.dividerOf(context), width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_replyingTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Row(
                  children: [
                    Text(
                      'Replying to ${_replyingTo!.authorName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() => _replyingTo = null);
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTier2Of(context),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: AppLocalizations(
                          widget.currentLanguage,
                        ).writeCommentHint,
                        hintStyle: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(fontSize: 14),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Send button with animation
                GestureDetector(
                  onTap: _sendComment,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isSending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.onPrimaryOf(context),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: AppColors.onPrimaryOf(context),
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

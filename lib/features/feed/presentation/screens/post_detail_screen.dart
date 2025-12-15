import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/category_badge_widget.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../widgets/post_options_bottom_sheet.dart';

/// Post Detail Screen
/// Full post view with all details and interactions
class PostDetailScreen extends StatefulWidget {
  final Post post;
  final User currentUser;
  final AppLanguage currentLanguage;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.currentUser,
    required this.currentLanguage,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late bool _isLiked;
  late bool _isBookmarked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByMe;
    _isBookmarked = widget.post.isBookmarkedByMe;
    _likesCount = widget.post.likesCount;
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    // Future: Persist to database
  }

  void _toggleBookmark() {
    setState(() {
      _isBookmarked = !_isBookmarked;
    });
    // Future: Persist to database
  }

  String _getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(widget.post.createdAt);
    final localizations = AppLocalizations(widget.currentLanguage);

    if (difference.inMinutes < 1) {
      return localizations.justNow;
    } else if (difference.inHours < 1) {
      return localizations.minutesAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return localizations.hoursAgo(difference.inHours);
    } else {
      return localizations.daysAgo(difference.inDays);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(widget.currentLanguage);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.getCategoryName(widget.post.category)),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => PostOptionsBottomSheet(
                  post: widget.post,
                  currentUser: widget.currentUser,
                  currentLanguage: widget.currentLanguage,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Section
            if (widget.post.contentType != ContentType.none && widget.post.mediaUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: widget.post.contentType == ContentType.image
                    ? Image.network(
                        widget.post.mediaUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildPlaceholder(),
                      )
                    : Container(
                        color: Colors.black87,
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      ),
              )
            else
              _buildPlaceholder(),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge
                  CategoryBadgeWidget(
                    category: localizations.getCategoryName(widget.post.category),
                  ),
                  const SizedBox(height: 16),

                  // Headline
                  Text(
                    widget.post.caption,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Author Info
                  InkWell(
                    onTap: () {
                      // Navigate to author profile
                      // Navigator.push(...);
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary,
                          radius: 20,
                          child: widget.post.authorAvatar != null
                              ? ClipOval(
                                  child: Image.network(
                                    widget.post.authorAvatar!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
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
                                widget.post.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _getTimeAgo(),
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons Row
                  Row(
                    children: [
                      _buildActionButton(
                        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                        label: '$_likesCount',
                        color: _isLiked ? Colors.red : AppColors.textSecondary,
                        onTap: _toggleLike,
                      ),
                      const SizedBox(width: 24),
                      _buildActionButton(
                        icon: Icons.comment_outlined,
                        label: '0',
                        color: AppColors.textSecondary,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Comments coming soon!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 24),
                      _buildActionButton(
                        icon: _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        label: localizations.bookmarks,
                        color: _isBookmarked ? AppColors.primary : AppColors.textSecondary,
                        onTap: _toggleBookmark,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share),
                        color: AppColors.textSecondary,
                        onPressed: () {
                          Share.share('Check out this post: ${widget.post.caption}');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Divider(),
                  const SizedBox(height: 16),

                  // Hashtags
                  if (widget.post.hashtags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.post.hashtags.map((tag) {
                        return Chip(
                          label: Text('#$tag'),
                          labelStyle: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Engagement Stats
                  Text(
                    '${widget.post.likesCount} likes • ${widget.post.sharesCount} shares • ${widget.post.bookmarksCount} bookmarks',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
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

  Widget _buildPlaceholder() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.3),
              AppColors.secondary.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: const Center(
          child: Icon(Icons.article, size: 80, color: Colors.white70),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

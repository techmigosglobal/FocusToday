import 'package:flutter/material.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/widgets/category_badge_widget.dart';
import '../../../../shared/widgets/pdf_viewer_widget.dart';
import '../../../../shared/widgets/article_viewer_widget.dart';
import '../../../../shared/widgets/poetry_viewer_widget.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import 'post_options_bottom_sheet.dart';
import '../../../../shared/models/user.dart';

/// Vertical Content Card
/// Full-screen card inspired by Way2News style
class VerticalContentCard extends StatelessWidget {
  final Post post;
  final AppLanguage currentLanguage;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final bool isLiked;

  const VerticalContentCard({
    super.key,
    required this.post,
    required this.currentLanguage,
    required this.onLike,
    required this.onComment,
    this.isLiked = false,
  });

  String _getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(post.createdAt);

    final localizations = AppLocalizations(currentLanguage);

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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final mediaHeight = screenHeight * (isTablet ? 0.5 : 0.6);
    final localizations = AppLocalizations(currentLanguage);
    final displayCaption = post.getLocalizedCaption(currentLanguage.code);

    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          // Media Section (60% of screen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mediaHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media image/video/pdf/article/poetry
                if (post.contentType == ContentType.image &&
                    post.mediaUrl != null)
                  // If the mediaUrl is a local file path, use Image.file; otherwise assume network URL
                  Builder(
                    builder: (context) {
                      // Added Builder to allow return of a widget
                      final isLocal =
                          post.mediaUrl!.startsWith('/') ||
                          post.mediaUrl!.startsWith('file://');
                      if (isLocal) {
                        return Image.file(
                          File(post.mediaUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildPlaceholderMedia(),
                        );
                      } else {
                        return Image.network(
                          post.mediaUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildPlaceholderMedia(),
                        );
                      }
                    },
                  )
                else if (post.contentType == ContentType.video &&
                    post.mediaUrl != null)
                  Container(
                    color: Colors.black87,
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (post.contentType == ContentType.pdf &&
                    post.pdfFilePath != null)
                  PDFPreviewWidget(
                    pdfPath: post.pdfFilePath!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PDFViewerWidget(
                            pdfPath: post.pdfFilePath!,
                            showFullScreen: true,
                          ),
                        ),
                      );
                    },
                  )
                else if ((post.contentType == ContentType.article ||
                        post.contentType == ContentType.story) &&
                    post.articleContent != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArticleViewerWidget(
                            content: post.articleContent!,
                            title: post.caption,
                          ),
                        ),
                      );
                    },
                    child: ArticleViewerWidget(
                      content: post.articleContent!,
                      title: post.caption,
                      isPreview: true,
                    ),
                  )
                else if (post.contentType == ContentType.poetry &&
                    post.poemVerses != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PoetryViewerWidget(
                            verses: post.poemVerses!,
                            title: post.caption,
                          ),
                        ),
                      );
                    },
                    child: PoetryViewerWidget(
                      verses: post.poemVerses!,
                      title: post.caption,
                      isPreview: true,
                    ),
                  )
                else
                  _buildPlaceholderMedia(),

                // Gradient overlay for readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                      stops: const [0.0, 0.3, 1.0],
                    ),
                  ),
                ),

                // Category badge (top-left)
                Positioned(
                  top: 16,
                  left: 16,
                  child: CategoryBadgeWidget(
                    category: localizations.getCategoryName(post.category),
                  ),
                ),
              ],
            ),
          ),

          // Content Section (40% of screen)
          Positioned(
            top: mediaHeight,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Headline
                  Text(
                    displayCaption,
                    style: TextStyle(
                      fontSize: isTablet ? 28 : 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: Colors.black87,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Summary (if exists in caption)
                  if (displayCaption.length > 100) ...[
                    Text(
                      _extractSummary(),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 8),

                  const Spacer(),

                  // Source and actions row
                  Row(
                    children: [
                      // Source and time
                      Expanded(
                        child: Text(
                          '${post.authorName} • ${_getTimeAgo()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Action icons
                      _buildActionIcon(
                        Icons.favorite,
                        post.likesCount,
                        isLiked ? Colors.red : AppColors.textSecondary,
                        onLike,
                      ),
                      const SizedBox(width: 16),
                      _buildActionIcon(
                        Icons.comment,
                        0, // commentsCount not in model yet
                        AppColors.textSecondary,
                        onComment,
                      ),
                      const SizedBox(width: 16),
                      _buildActionIcon(
                        Icons.share,
                        0,
                        AppColors.textSecondary,
                        () =>
                            Share.share('Check out this post: $displayCaption'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (_) => PostOptionsBottomSheet(
                              post: post,
                              currentUser: User(
                                id: post.authorId,
                                phoneNumber: '',
                                displayName: post.authorName,
                                role: UserRole.publicUser,
                                createdAt: DateTime.now(),
                              ),
                              currentLanguage: currentLanguage,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderMedia() {
    return Container(
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
    );
  }

  Widget _buildActionIcon(
    IconData icon,
    int count,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _extractSummary() {
    // Simple summary extraction - first 150 chars
    if (post.caption.length <= 150) return post.caption;

    final summary = post.caption.substring(0, 150);
    final lastSpace = summary.lastIndexOf(' ');

    return lastSpace > 0
        ? '${summary.substring(0, lastSpace)}...'
        : '$summary...';
  }
}

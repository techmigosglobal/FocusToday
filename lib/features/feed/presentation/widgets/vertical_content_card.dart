import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/widgets/video_player_widget.dart';
import '../../../../shared/widgets/pdf_viewer_widget.dart';
import '../../../../shared/widgets/article_viewer_widget.dart';
import '../../../../shared/widgets/poetry_viewer_widget.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import 'post_options_bottom_sheet.dart';
import '../../../../shared/models/user.dart';

/// Vertical Content Card
/// Full-screen card inspired by Way2News style with modern glassmorphism
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
    final mediaHeight = screenHeight * (isTablet ? 0.5 : 0.55);
    final localizations = AppLocalizations(currentLanguage);
    final displayCaption = post.getLocalizedCaption(currentLanguage.code);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFF8F9FA), const Color(0xFFFFFFFF)],
        ),
      ),
      child: Stack(
        children: [
          // Media Section (55% of screen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mediaHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media content
                _buildMediaContent(context, displayCaption),

                // Elegant gradient overlay with stronger bottom protect
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(
                          alpha: 0.3,
                        ), // Darker top for icons
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.05), // Mid transparent
                        Colors.black.withValues(
                          alpha: 0.6,
                        ), // Darker bottom for fade
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),

                // Category badge (top-left) with simplified design
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      localizations
                          .getCategoryName(post.category)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),

                // Content type indicator (top-right)
                if (post.contentType != ContentType.none &&
                    post.contentType != ContentType.image)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: _buildContentTypeIndicator(),
                  ),
              ],
            ),
          ),

          // Content Section with elevated card effect
          Positioned(
            top: mediaHeight - 32, // More overlap
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.12,
                    ), // Deeper shadow
                    blurRadius: 24,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Headline with improved typography
                    Text(
                      displayCaption,
                      style: TextStyle(
                        fontSize: isTablet ? 26 : 22,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: const Color(0xFF1A1A2E),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),

                    // Summary with interactive Read More
                    if (displayCaption.length > 80) ...[
                      GestureDetector(
                        onTap: () {
                          // Open Article Viewer for full text
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArticleViewerWidget(
                                content: post.articleContent ?? post.caption,
                                title: post.caption,
                                imageUrl: post.mediaUrl,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _extractSummary(),
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: const Color(0xFF4B5563),
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              localizations.readMore,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          post.caption,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ),

                    const Spacer(),

                    // Author info and actions row
                    _buildBottomSection(context, displayCaption, localizations),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(BuildContext context, String displayCaption) {
    if (post.contentType == ContentType.image && post.mediaUrl != null) {
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
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingMedia();
          },
          errorBuilder: (_, _, _) => _buildPlaceholderMedia(),
        );
      }
    } else if (post.contentType == ContentType.video && post.mediaUrl != null) {
      return VideoPreviewWidget(
        videoUrl: post.mediaUrl!,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  title: Text(
                    displayCaption.length > 30
                        ? '${displayCaption.substring(0, 30)}...'
                        : displayCaption,
                  ),
                ),
                body: VideoPlayerWidget(
                  videoUrl: post.mediaUrl!,
                  showControls: true,
                  autoPlay: true,
                ),
              ),
            ),
          );
        },
      );
    } else if (post.contentType == ContentType.pdf &&
        post.pdfFilePath != null) {
      return PDFPreviewWidget(
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
      );
    } else if ((post.contentType == ContentType.article ||
            post.contentType == ContentType.story) &&
        post.articleContent != null) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArticleViewerWidget(
                content: post.articleContent!,
                title: post.caption,
                imageUrl: post.mediaUrl,
              ),
            ),
          );
        },
        child: ArticleViewerWidget(
          content: post.articleContent!,
          title: post.caption,
          isPreview: true,
          imageUrl: post.mediaUrl,
        ),
      );
    } else if (post.contentType == ContentType.poetry &&
        post.poemVerses != null) {
      return GestureDetector(
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
      );
    } else {
      return _buildPlaceholderMedia();
    }
  }

  Widget _buildContentTypeIndicator() {
    IconData icon;
    String label;
    Color bgColor;

    switch (post.contentType) {
      case ContentType.video:
        icon = Icons.play_circle_filled;
        label = 'VIDEO';
        bgColor = Colors.red;
        break;
      case ContentType.pdf:
        icon = Icons.picture_as_pdf;
        label = 'PDF';
        bgColor = Colors.orange;
        break;
      case ContentType.article:
      case ContentType.story:
        icon = Icons.article;
        label = 'READ';
        bgColor = Colors.blue;
        break;
      case ContentType.poetry:
        icon = Icons.format_quote;
        label = 'POETRY';
        bgColor = Colors.purple;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMedia() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFE8E8E8), const Color(0xFFF5F5F5)],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
        ),
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
            const Color(0xFF6366F1).withValues(alpha: 0.15),
            const Color(0xFF8B5CF6).withValues(alpha: 0.15),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: const Color(0xFF6366F1).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'News Article',
              style: TextStyle(
                color: const Color(0xFF6366F1).withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(
    BuildContext context,
    String displayCaption,
    AppLocalizations localizations,
  ) {
    return Column(
      children: [
        // Divider
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                const Color(0xFFE5E7EB),
                Colors.transparent,
              ],
            ),
          ),
        ),

        Row(
          children: [
            // Author avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  post.authorName.isNotEmpty
                      ? post.authorName[0].toUpperCase()
                      : 'E',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Source and time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.authorName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getTimeAgo(),
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons with modern styling
            _buildModernActionButton(
              icon: isLiked ? Icons.favorite : Icons.favorite_border,
              count: post.likesCount,
              color: isLiked
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF6B7280),
              onTap: onLike,
            ),
            const SizedBox(width: 8),
            _buildModernActionButton(
              icon: Icons.chat_bubble_outline,
              count: 0,
              color: const Color(0xFF6B7280),
              onTap: onComment,
            ),
            const SizedBox(width: 8),
            _buildModernActionButton(
              icon: Icons.share_outlined,
              count: 0,
              color: const Color(0xFF6B7280),
              onTap: () => Share.share('Check out this post: $displayCaption'),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz, color: Color(0xFF6B7280)),
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
    );
  }

  Widget _buildModernActionButton({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  _formatCount(count),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _extractSummary() {
    if (post.caption.length <= 120) return post.caption;

    final summary = post.caption.substring(0, 120);
    final lastSpace = summary.lastIndexOf(' ');

    return lastSpace > 0
        ? '${summary.substring(0, lastSpace)}...'
        : '$summary...';
  }
}

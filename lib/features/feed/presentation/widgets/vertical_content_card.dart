import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/share_link_service.dart';
import '../../../../core/services/post_translation_service.dart';

import '../../data/services/feed_video_controller_service.dart';
import '../../../../shared/models/post.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../utils/image_shape_type.dart';

import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/post_rich_text.dart';
import '../../../../shared/widgets/pdf_thumbnail.dart';

import '../../../../shared/widgets/video_thumbnail_view.dart';

/// Vertical Content Card — Premium TikTok/Shorts-Style
/// Media fills 100% of the card; title + meta overlaid via gradient.
/// Bottom action bar is a fixed-height strip — zero overflow risk.
class VerticalContentCard extends StatefulWidget {
  final Post post;
  final User? currentUser;
  final AppLanguage currentLanguage;
  final VoidCallback onLanguageToggle;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback? onTap;
  final VoidCallback? onReadMore;
  final VoidCallback? onMediaTap;
  final VoidCallback? onBookmark;
  final VoidCallback? onBookmarkLongPress;
  final VoidCallback? onShare;
  final bool isLiked;
  final bool isBookmarked;
  final bool isVisible;
  final bool shouldPrepareVideo;
  final int likeCount;
  final int bookmarkCount;
  final int shareCount;
  final String? translatedCaption;
  final String? translatedSnippet;
  final int? postIndex;
  final int? totalPosts;
  final bool showPostCounter;
  final double flipProgress;
  final ImageShapeType? imageShapeOverride;

  const VerticalContentCard({
    super.key,
    required this.post,
    this.currentUser,
    required this.currentLanguage,
    required this.onLanguageToggle,
    required this.onLike,
    required this.onComment,
    this.onTap,
    this.onReadMore,
    this.onMediaTap,
    this.onBookmark,
    this.onBookmarkLongPress,
    this.onShare,
    this.isLiked = false,
    this.isBookmarked = false,
    this.isVisible = true,
    this.shouldPrepareVideo = true,
    this.likeCount = 0,
    this.bookmarkCount = 0,
    this.shareCount = 0,
    this.translatedCaption,
    this.translatedSnippet,
    this.postIndex,
    this.totalPosts,
    this.showPostCounter = true,
    this.flipProgress = 0.0,
    this.imageShapeOverride,
  });

  @override
  State<VerticalContentCard> createState() => _VerticalContentCardState();
}

class _VerticalContentCardState extends State<VerticalContentCard>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoInitFailed = false;
  bool _isVideoInitInFlight = false;
  bool _isMuted = true;
  bool _showHeartOverlay = false;
  ImageShapeType _resolvedImageShape = ImageShapeType.unknown;
  String? _resolvedImageShapeUrl;
  bool _isImageShapeResolveInFlight = false;
  late AnimationController _heartAnim;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.3,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_heartAnim);
    _heartAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showHeartOverlay = false);
      }
    });
    _initVideoIfNeeded();
    _resolveImageShapeIfNeeded();
  }

  @override
  void didUpdateWidget(VerticalContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.mediaUrl != widget.post.mediaUrl ||
        oldWidget.post.contentType != widget.post.contentType) {
      _videoController = null;
      _isVideoInitialized = false;
      _isVideoInitFailed = false;
      _isVideoInitInFlight = false;
      _isMuted = true;
      _resolvedImageShape = ImageShapeType.unknown;
      _resolvedImageShapeUrl = null;
      _isImageShapeResolveInFlight = false;
      _initVideoIfNeeded();
      _resolveImageShapeIfNeeded();
    }
    if (widget.shouldPrepareVideo != oldWidget.shouldPrepareVideo &&
        widget.shouldPrepareVideo) {
      _initVideoIfNeeded();
    }
    if (widget.isVisible != oldWidget.isVisible ||
        oldWidget.shouldPrepareVideo != widget.shouldPrepareVideo) {
      _syncPlaybackState();
    }
  }

  void _resolveImageShapeIfNeeded() {
    final mediaUrl = widget.post.mediaUrl?.trim();
    final isImage =
        widget.post.contentType == ContentType.image ||
        (mediaUrl != null && _isImageUrl(mediaUrl));
    if (!isImage || mediaUrl == null || mediaUrl.isEmpty) {
      return;
    }
    if (_isImageShapeResolveInFlight) return;
    if (_resolvedImageShapeUrl == mediaUrl &&
        _resolvedImageShape != ImageShapeType.unknown) {
      return;
    }

    _isImageShapeResolveInFlight = true;
    resolveImageShapeFromUrl(mediaUrl)
        .then((shape) {
          if (!mounted) return;
          final currentUrl = widget.post.mediaUrl?.trim();
          if (currentUrl != mediaUrl) return;
          setState(() {
            _resolvedImageShape = shape;
            _resolvedImageShapeUrl = mediaUrl;
          });
        })
        .whenComplete(() {
          _isImageShapeResolveInFlight = false;
        });
  }

  void _initVideoIfNeeded() {
    final mediaUrl = widget.post.mediaUrl?.trim();
    if (mediaUrl == null || mediaUrl.isEmpty) return;
    if (!widget.shouldPrepareVideo) return;
    if (_isVideoInitInFlight || _isVideoInitFailed) return;

    final isVideoType =
        widget.post.contentType == ContentType.video || _isVideoUrl(mediaUrl);
    if (!isVideoType) return;

    final controllerKey = FeedVideoControllerService.buildKey(
      postId: widget.post.id,
      mediaUrl: mediaUrl,
    );
    final cached = FeedVideoControllerService.instance.getController(
      controllerKey,
    );
    if (cached != null) {
      _videoController = cached;
      _isVideoInitialized = cached.value.isInitialized;
      _isVideoInitFailed = false;
      _syncPlaybackState();
      if (mounted) setState(() {});
      return;
    }

    _isVideoInitInFlight = true;
    FeedVideoControllerService.instance
        .acquire(key: controllerKey, uri: Uri.parse(mediaUrl))
        .then((controller) {
          if (!mounted) return;
          setState(() {
            _isVideoInitInFlight = false;
            _videoController = controller;
            _isVideoInitialized = controller?.value.isInitialized == true;
            _isVideoInitFailed = controller == null;
          });
          _syncPlaybackState();
        });
  }

  void _syncPlaybackState() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    controller.setVolume(_isMuted ? 0.0 : 1.0);
    if (widget.isVisible) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _videoController?.pause();
    _heartAnim.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoController?.setVolume(_isMuted ? 0.0 : 1.0);
    });
    HapticFeedback.lightImpact();
  }

  void _openPostDetail() {
    HapticFeedback.lightImpact();
    if (widget.onTap != null) {
      widget.onTap!.call();
    } else if (widget.onMediaTap != null) {
      widget.onMediaTap!.call();
    }
  }

  void _onDoubleTapLike() {
    if (!widget.isLiked) widget.onLike();
    HapticFeedback.heavyImpact();
    setState(() => _showHeartOverlay = true);
    _heartAnim.forward(from: 0);
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  bool _isVideoUrl(String url) {
    final l = url.toLowerCase();
    return l.endsWith('.mp4') ||
        l.endsWith('.mov') ||
        l.endsWith('.avi') ||
        l.endsWith('.mkv') ||
        l.contains('video') ||
        l.contains('watch');
  }

  bool _isImageUrl(String url) {
    final l = url.toLowerCase();
    return l.endsWith('.jpg') ||
        l.endsWith('.jpeg') ||
        l.endsWith('.png') ||
        l.endsWith('.gif') ||
        l.endsWith('.webp') ||
        l.contains('image') ||
        l.contains('img');
  }

  bool _isPdfUrl(String url) {
    final l = url.toLowerCase();
    return l.endsWith('.pdf') || l.contains('pdf');
  }

  Color _categoryColor() {
    switch (widget.post.category.toLowerCase()) {
      case 'technology':
        return const Color(0xFF2196F3);
      case 'business':
        return const Color(0xFF4CAF50);
      case 'sports':
        return const Color(0xFFFF9800);
      case 'politics':
        return const Color(0xFF9C27B0);
      case 'health':
        return const Color(0xFF00BCD4);
      case 'world':
        return const Color(0xFF607D8B);
      case 'news':
        return AppColors.primary;
      case 'articles':
        return const Color(0xFF3F51B5);
      case 'stories':
        return const Color(0xFF673AB7);
      case 'poetry':
        return const Color(0xFFFF5722);
      default:
        return AppColors.primary;
    }
  }

  IconData _categoryIcon() {
    switch (widget.post.category.toLowerCase()) {
      case 'technology':
        return Icons.computer;
      case 'business':
        return Icons.trending_up;
      case 'sports':
        return Icons.sports_cricket;
      case 'politics':
        return Icons.account_balance;
      case 'health':
        return Icons.health_and_safety;
      case 'world':
        return Icons.public;
      case 'news':
        return Icons.newspaper;
      default:
        return Icons.article;
    }
  }

  String get _resolvedCaption {
    final t = widget.translatedCaption?.trim() ?? '';
    if (t.isNotEmpty) return t;
    final lc = _languageCode();
    if (lc == 'te' || lc == 'hi') {
      final server = lc == 'te' ? widget.post.captionTe : widget.post.captionHi;
      if (PostTranslationService.shouldUseServerTranslation(
        sourceText: widget.post.caption,
        candidateText: server,
        targetLanguageCode: lc,
      )) {
        return server!.trim();
      }
    }
    return widget.post.caption;
  }

  List<dynamic>? get _captionDelta {
    final hasTranslatedCaption =
        (widget.translatedCaption?.trim().isNotEmpty ?? false);
    if (hasTranslatedCaption) return null;
    if (widget.currentLanguage != AppLanguage.english) return null;
    final localizedFromPost = widget.post.getLocalizedCaption('en').trim();
    if (localizedFromPost.isEmpty) return null;
    return widget.post.captionDelta;
  }

  String _languageCode() {
    switch (widget.currentLanguage) {
      case AppLanguage.telugu:
        return 'te';
      case AppLanguage.hindi:
        return 'hi';
      default:
        return 'en';
    }
  }

  String get _bodySnippet {
    final t = widget.translatedSnippet?.trim() ?? '';
    if (t.isNotEmpty) return t;
    final localizedFromPost = _localizedSnippetFromPost();
    if (localizedFromPost.isNotEmpty) return localizedFromPost;
    final art = widget.post.articleContent?.trim() ?? '';
    if (art.isNotEmpty) return art;
    final poem = widget.post.poemVerses?.join(' ') ?? '';
    if (poem.trim().isNotEmpty) return poem.trim();
    return '';
  }

  List<dynamic>? get _bodySnippetDelta {
    final hasTranslatedSnippet =
        (widget.translatedSnippet?.trim().isNotEmpty ?? false);
    if (hasTranslatedSnippet) return null;
    if (widget.currentLanguage != AppLanguage.english) return null;
    final localizedFromPost = _localizedSnippetFromPost();
    if (localizedFromPost.isNotEmpty) return null;
    return widget.post.articleContentDelta;
  }

  String _localizedSnippetFromPost() {
    final source = (widget.post.articleContent?.trim().isNotEmpty ?? false)
        ? widget.post.articleContent!.trim()
        : widget.post.poemVerses?.join('\n').trim() ?? '';
    if (source.isEmpty) return '';

    switch (widget.currentLanguage) {
      case AppLanguage.telugu:
        {
          final article = widget.post.articleContentTe?.trim() ?? '';
          if (PostTranslationService.shouldUseServerTranslation(
            sourceText: source,
            candidateText: article,
            targetLanguageCode: 'te',
          )) {
            return article;
          }
          final poem = widget.post.poemVersesTe?.join(' ').trim() ?? '';
          if (PostTranslationService.shouldUseServerTranslation(
            sourceText: source,
            candidateText: poem,
            targetLanguageCode: 'te',
          )) {
            return poem;
          }
          return '';
        }
      case AppLanguage.hindi:
        {
          final article = widget.post.articleContentHi?.trim() ?? '';
          if (PostTranslationService.shouldUseServerTranslation(
            sourceText: source,
            candidateText: article,
            targetLanguageCode: 'hi',
          )) {
            return article;
          }
          final poem = widget.post.poemVersesHi?.join(' ').trim() ?? '';
          if (PostTranslationService.shouldUseServerTranslation(
            sourceText: source,
            candidateText: poem,
            targetLanguageCode: 'hi',
          )) {
            return poem;
          }
          return '';
        }
      case AppLanguage.english:
        return '';
    }
  }

  String _timeAgo(DateTime dt, AppLocalizations localizations) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return localizations.justNow;
    if (diff.inMinutes < 60) return localizations.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return localizations.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return localizations.daysAgo(diff.inDays);
    if (diff.inDays < 30) {
      return localizations.weeksAgo((diff.inDays / 7).floor());
    }
    if (diff.inDays < 365) {
      return localizations.monthsAgo((diff.inDays / 30).floor());
    }
    return localizations.yearsAgo((diff.inDays / 365).floor());
  }

  Color _contentTypeColor() {
    switch (widget.post.contentType) {
      case ContentType.image:
        return AppColors.success;
      case ContentType.video:
        return AppColors.likeStrong;
      case ContentType.pdf:
        return AppColors.warning;
      case ContentType.article:
        return AppColors.infoOf(context);
      case ContentType.story:
        return AppColors.trustBlue;
      case ContentType.poetry:
        return AppColors.secondary;
      case ContentType.none:
        return AppColors.textSecondaryOf(context);
    }
  }

  String _contentTypeLabel(AppLocalizations localizations) {
    switch (widget.post.contentType) {
      case ContentType.image:
        return localizations.imageLabel.toUpperCase();
      case ContentType.video:
        return localizations.videoLabel.toUpperCase();
      case ContentType.pdf:
        return localizations.pdfLabel.toUpperCase();
      case ContentType.article:
        return localizations.articleLabel.toUpperCase();
      case ContentType.story:
        return localizations.storyLabel.toUpperCase();
      case ContentType.poetry:
        return localizations.poetryLabel.toUpperCase();
      case ContentType.none:
        return localizations.textLabel.toUpperCase();
    }
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor();
    final localizations = AppLocalizations(widget.currentLanguage);
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final overlayTop = (screenHeight * 0.50 - (widget.flipProgress.abs() * 14))
        .clamp(mediaQuery.padding.top + 92.0, screenHeight * 0.62)
        .toDouble();
    final overlayBottom = safeBottom + 8.0;
    final overlayHeight = (screenHeight - overlayTop - overlayBottom)
        .clamp(220.0, screenHeight)
        .toDouble();

    return GestureDetector(
      onTap: _openPostDetail,
      onDoubleTap: _onDoubleTapLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── full-bleed background ─────────────────────────────────────────
          _buildBackground(catColor),

          // ── continuous bottom gradient scrim (for readability) ────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.82),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  // Start the scrim a bit higher so long titles/snippets stay readable.
                  stops: const [0.0, 0.24, 0.46, 0.74, 1.0],
                ),
              ),
            ),
          ),

          // ── top badges row ────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 14,
            right: 14,
            child: Row(
              children: [
                // Category badge
                _pill(
                  label: localizations
                      .getCategoryName(widget.post.category)
                      .toUpperCase(),
                  icon: _categoryIcon(),
                  color: catColor,
                  filled: true,
                ),
                const SizedBox(width: 8),
                // Content type badge
                _pill(
                  label: _contentTypeLabel(localizations),
                  color: _contentTypeColor(),
                  filled: false,
                ),
                const Spacer(),
                // Post counter badge
                if (widget.showPostCounter &&
                    widget.postIndex != null &&
                    widget.totalPosts != null)
                  _pill(
                    label: '${widget.postIndex! + 1}/${widget.totalPosts}',
                    color: Colors.white,
                    filled: false,
                    textColor: Colors.white,
                  ),
              ],
            ),
          ),

          // ── video controls (mute + duration) ─────────────────────────────
          if (widget.post.contentType == ContentType.video &&
              _isVideoInitialized)
            _buildVideoControls(),

          // ── bottom text + author overlay ──────────────────────────────────
          Positioned(
            left: 0,
            right: 60, // Leave room for right action bar
            top: overlayTop,
            bottom: overlayBottom,
            child: _buildBottomOverlay(
              catColor,
              localizations,
              availableHeight: overlayHeight,
            ),
          ),

          // ── right action column ───────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 80,
            child: _buildRightActionBar(),
          ),

          // ── double-tap heart ──────────────────────────────────────────────
          if (_showHeartOverlay)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: ScaleTransition(
                    scale: _heartScale,
                    child: Icon(
                      Icons.favorite_rounded,
                      color: Colors.red.withValues(alpha: 0.92),
                      size: 110,
                      shadows: const [
                        Shadow(color: Colors.black38, blurRadius: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── background ────────────────────────────────────────────────────────────

  Widget _buildBackground(Color catColor) {
    final mediaUrl = widget.post.mediaUrl?.trim();
    final pdfPath = widget.post.pdfFilePath?.trim();
    final ct = widget.post.contentType;

    final isVideo =
        ct == ContentType.video || (mediaUrl != null && _isVideoUrl(mediaUrl));
    final isImage =
        ct == ContentType.image || (mediaUrl != null && _isImageUrl(mediaUrl));
    final isPdf =
        ct == ContentType.pdf ||
        pdfPath != null ||
        (mediaUrl != null && _isPdfUrl(mediaUrl));

    // ── video ──
    if (isVideo && mediaUrl != null) {
      if (_isVideoInitialized) {
        return Container(
          color: Colors.black,
          child: Center(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
        );
      }
      return _videoPlaceholder(isError: _isVideoInitFailed);
    }

    // ── image ──
    if (isImage && mediaUrl != null) {
      final imageShape = widget.imageShapeOverride ?? _resolvedImageShape;
      final shouldContain = imageShape == ImageShapeType.square;
      return Container(
        color: shouldContain
            ? AppColors.surfaceOf(context).withValues(alpha: 0.96)
            : Colors.transparent,
        child: CachedNetworkImage(
          imageUrl: mediaUrl,
          fit: shouldContain ? BoxFit.contain : BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: 900,
          fadeInDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          placeholder: (_, _) => _gradientPlaceholder(catColor),
          errorWidget: (_, _, _) => _gradientPlaceholder(catColor),
        ),
      );
    }

    // ── pdf ──
    if (isPdf) {
      final pdfUrl = pdfPath ?? mediaUrl;
      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: PdfThumbnail(
            pdfUrl: pdfUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            label: localizations(AppLocalizations(widget.currentLanguage)),
          ),
        );
      }
    }

    if (ct == ContentType.article) {
      return _articleTextBackground(catColor);
    }

    return _gradientPlaceholder(catColor);
  }

  String localizations(AppLocalizations l) => l.tapToReadPdf.toUpperCase();

  Widget _gradientPlaceholder(Color catColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            catColor.withValues(alpha: 0.85),
            catColor.withValues(alpha: 0.4),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _categoryIcon(),
          size: 96,
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
    );
  }

  Widget _articleTextBackground(Color catColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            catColor.withValues(alpha: 0.88),
            catColor.withValues(alpha: 0.50),
            Colors.black,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Opacity(
              opacity: 0.14,
              child: Image.asset(
                'Focus_Today_icon.png',
                width: 190,
                height: 190,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.newspaper_rounded,
                  size: 140,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoPlaceholder({bool isError = false}) {
    final url = widget.post.mediaUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          VideoThumbnailView(
            videoUrl: url,
            fallback: _gradientPlaceholder(_categoryColor()),
            fit: BoxFit.cover,
          )
        else
          _gradientPlaceholder(_categoryColor()),
        Container(color: Colors.black.withValues(alpha: 0.40)),
        Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Icon(
              isError ? Icons.error_outline_rounded : Icons.play_arrow_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
        ),
        if (!isError)
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 90,
                height: 90,
                child: CircularProgressIndicator(
                  color: Colors.white.withValues(alpha: 0.6),
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── bottom overlay ────────────────────────────────────────────────────────

  Widget _buildBottomOverlay(
    Color catColor,
    AppLocalizations localizations, {
    required double availableHeight,
  }) {
    final caption = _resolvedCaption;
    final captionDelta = _captionDelta;
    final snippet = _bodySnippet;
    final snippetDelta = _bodySnippetDelta;
    final hasSnippet = snippet.trim().isNotEmpty;

    return SizedBox(
      height: availableHeight,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── hashtags strip ─────────────────────────────────────────────────
          if (widget.post.hashtags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                height: 22,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: widget.post.hashtags.length.clamp(0, 6),
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final tag = widget.post.hashtags[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        tag.startsWith('#') ? tag : '#$tag',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 4),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── headline ───────────────────────────────────────────────
                  PostRichText(
                    caption,
                    delta: captionDelta,
                    maxLines: hasSnippet ? 9 : 12,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.22,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(height: 3),

                  // ── snippet preview ────────────────────────────────────────
                  if (hasSnippet)
                    Flexible(
                      child: PostRichText(
                        snippet,
                        delta: snippetDelta,
                        maxLines: 10,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.36,
                          shadows: const [
                            Shadow(color: Colors.black38, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── read more hint ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GestureDetector(
              onTap: widget.onReadMore ?? _openPostDetail,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      localizations.tapToReadFull,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),

          // ── author info bar ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.only(
              left: 14,
              right: 14,
              top: 1,
              bottom: 4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Author avatar
                CircleAvatar(
                  radius: 15,
                  backgroundColor: catColor.withValues(alpha: 0.2),
                  child: Text(
                    widget.post.authorName.isNotEmpty
                        ? widget.post.authorName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: catColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Name + time
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _timeAgo(widget.post.createdAt, localizations),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Category chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: catColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    localizations.getCategoryName(widget.post.category),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── right action bar ──────────────────────────────────────────────────────

  Widget _buildRightActionBar() {
    final localizations = AppLocalizations(widget.currentLanguage);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like
        _buildActionItem(
          icon: widget.isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: widget.isLiked ? AppColors.likeStrong : Colors.white,
          countText: _formatCount(widget.likeCount),
          semanticLabel: widget.isLiked
              ? '${localizations.like} ${localizations.delete}'
              : localizations.like,
          onTap: () {
            widget.onLike();
            HapticFeedback.mediumImpact();
          },
        ),
        const SizedBox(height: 18),

        // Comment
        _buildActionItem(
          icon: Icons.chat_bubble_outline_rounded,
          color: Colors.white,
          semanticLabel: localizations.comment,
          onTap: widget.onComment,
        ),
        const SizedBox(height: 18),

        // Bookmark
        _buildActionItem(
          icon: widget.isBookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          color: widget.isBookmarked ? AppColors.trustBlue : Colors.white,
          countText: _formatCount(widget.bookmarkCount),
          semanticLabel: widget.isBookmarked
              ? '${localizations.bookmarks} ${localizations.delete}'
              : localizations.bookmarks,
          onTap: () {
            widget.onBookmark?.call();
            HapticFeedback.mediumImpact();
          },
          onLongPress: () {
            widget.onBookmarkLongPress?.call();
            HapticFeedback.heavyImpact();
          },
        ),
        const SizedBox(height: 18),

        // Share
        _buildActionItem(
          icon: Icons.share_rounded,
          color: Colors.white,
          countText: _formatCount(widget.shareCount),
          semanticLabel: localizations.share,
          onTap: () {
            HapticFeedback.lightImpact();
            if (widget.onShare != null) {
              widget.onShare!.call();
              return;
            }
            final shareUrl = ShareLinkService.postUrl(widget.post.id);
            SharePlus.instance.share(
              ShareParams(
                text: 'Check out this: ${widget.post.caption}\n\n$shareUrl',
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color color,
    required String semanticLabel,
    required VoidCallback onTap,
    String? countText,
    VoidCallback? onLongPress,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    icon,
                    key: ValueKey('${icon.codePoint}_${color.toARGB32()}'),
                    color: color,
                    size: 24,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
            if (countText != null) ...[
              const SizedBox(height: 4),
              Text(
                countText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                ),
              ),
            ] else
              const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  String _formatCount(int value) {
    final safe = value < 0 ? 0 : value;
    if (safe >= 1000000) return '${(safe / 1000000).toStringAsFixed(1)}M';
    if (safe >= 1000) return '${(safe / 1000).toStringAsFixed(1)}K';
    return safe.toString();
  }

  // ── video controls ────────────────────────────────────────────────────────

  Widget _buildVideoControls() {
    final duration = _videoController?.value.duration ?? Duration.zero;
    final totalSeconds = duration.inSeconds;
    final mins = totalSeconds ~/ 60;
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    final durationLabel = totalSeconds > 0 ? '$mins:$secs' : null;

    return Stack(
      children: [
        if (durationLabel != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 50,
            left: 14,
            child: _glassLabel(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    durationLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 46,
          right: 14,
          child: GestureDetector(
            onTap: _toggleMute,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── shared small widgets ──────────────────────────────────────────────────

  Widget _pill({
    required String label,
    IconData? icon,
    required Color color,
    required bool filled,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.92)
            : Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: filled
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor ?? Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassLabel(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

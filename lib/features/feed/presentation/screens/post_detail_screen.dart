import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/post_translation_service.dart';
import '../../../../core/services/share_link_service.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/category_badge_widget.dart';
import '../../../../shared/widgets/markdown_text.dart';
import '../../../../shared/widgets/post_rich_text.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../../shared/widgets/pdf_thumbnail.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../widgets/post_options_bottom_sheet.dart';
import '../../data/repositories/post_repository.dart';
import 'video_player_screen.dart';
import 'pdf_viewer_screen.dart';
import 'article_reader_screen.dart';
import '../../../search/presentation/screens/search_screen.dart';

/// Optimized Post Detail / Read More Screen
/// Full immersive reading experience with hero media, scroll progress,
/// article content, author info, and engagement actions.
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

class _PostDetailScreenState extends State<PostDetailScreen>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late bool _isBookmarked;
  late int _likesCount;
  late int _bookmarksCount;
  late int _sharesCount;
  late ScrollController _scrollController;
  Future<String>? _translatedTitleFuture;
  Future<String>? _translatedContentFuture;
  double _scrollProgress = 0;
  bool _isImpressionTracked = false;

  // Aspect ratio of the media image (null while loading / not applicable).
  double? _imageAspectRatio;
  late AnimationController _likeAnimCtrl;
  late Animation<double> _likeScaleAnim;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByMe;
    _isBookmarked = widget.post.isBookmarkedByMe;
    _likesCount = widget.post.likesCount;
    _bookmarksCount = widget.post.bookmarksCount;
    _sharesCount = widget.post.sharesCount;
    _prepareTranslationFutures();
    _scrollController = ScrollController()..addListener(_updateScrollProgress);
    _likeAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _likeScaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _likeAnimCtrl, curve: Curves.elasticOut));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackImpression();
      _resolveImageAspectRatio();
    });
  }

  @override
  void didUpdateWidget(covariant PostDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLanguage != widget.currentLanguage ||
        oldWidget.post.id != widget.post.id ||
        oldWidget.post.caption != widget.post.caption ||
        oldWidget.post.articleContent != widget.post.articleContent ||
        oldWidget.post.poemVerses != widget.post.poemVerses) {
      _prepareTranslationFutures();
    }
  }

  @override
  void dispose() {
    _likeAnimCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollProgress() {
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      final next =
          (_scrollController.offset /
                  _scrollController.position.maxScrollExtent)
              .clamp(0.0, 1.0);
      if ((next - _scrollProgress).abs() < 0.01) return;
      setState(() => _scrollProgress = next);
    }
  }

  /// Asynchronously resolve the pixel dimensions of the hero image so the
  /// SliverAppBar can be sized to fit the image's natural aspect ratio.
  void _resolveImageAspectRatio() {
    final mediaUrl = widget.post.mediaUrl;
    final contentType = widget.post.contentType;
    final isImage =
        contentType == ContentType.image ||
        (mediaUrl != null && _isImageUrl(mediaUrl));
    if (!isImage || mediaUrl == null) return;

    final provider = CachedNetworkImageProvider(mediaUrl, maxWidth: 900);
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (h > 0 && w > 0 && mounted) {
          setState(() => _imageAspectRatio = w / h);
        }
        stream.removeListener(listener);
      },
      onError: (_, e) {
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  /// Compute how tall the hero SliverAppBar should be based on media type.
  double _computeHeroHeight(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final contentType = widget.post.contentType;
    final mediaUrl = widget.post.mediaUrl;

    final hasMedia = mediaUrl != null || widget.post.pdfFilePath != null;
    if (!hasMedia) return 180;

    final isVideo =
        contentType == ContentType.video ||
        (mediaUrl != null && _isVideoUrl(mediaUrl));
    final isPdf =
        contentType == ContentType.pdf ||
        widget.post.pdfFilePath != null ||
        (mediaUrl != null && _isPdfUrl(mediaUrl));
    final isImage =
        contentType == ContentType.image ||
        (mediaUrl != null && _isImageUrl(mediaUrl));

    if (isPdf) return 240;

    if (isImage) {
      final ar = _imageAspectRatio;
      if (ar != null && ar > 0) {
        return (screenW / ar).clamp(screenH * 0.30, screenH * 0.60);
      }
      return screenH * 0.42; // default while resolving
    }

    if (isVideo) return screenH * 0.42;

    return 300;
  }

  Future<void> _toggleLike() async {
    final previousLiked = _isLiked;
    final previousCount = _likesCount;
    setState(() {
      _isLiked = !_isLiked;
      _likesCount = (_likesCount + (_isLiked ? 1 : -1)).clamp(0, 1 << 30);
    });
    // Bounce animation on like
    _likeAnimCtrl.forward(from: 0);
    HapticFeedback.mediumImpact();
    final result = await PostRepository().toggleLike(
      widget.post.id,
      widget.currentUser.id,
    );
    if (!result.success && mounted) {
      setState(() {
        _isLiked = previousLiked;
        _likesCount = previousCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations(widget.currentLanguage).failedToUpdateLikeTryAgain,
          ),
        ),
      );
      return;
    }

    if (mounted && (result.isActive != null || result.count != null)) {
      setState(() {
        _isLiked = result.isActive ?? _isLiked;
        _likesCount = result.count ?? _likesCount;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final previousBookmarked = _isBookmarked;
    final previousCount = _bookmarksCount;
    setState(() {
      _isBookmarked = !_isBookmarked;
      _bookmarksCount = (_bookmarksCount + (_isBookmarked ? 1 : -1)).clamp(
        0,
        1 << 30,
      );
    });
    HapticFeedback.lightImpact();
    final result = await PostRepository().toggleBookmark(
      widget.post.id,
      widget.currentUser.id,
    );
    if (!result.success && mounted) {
      setState(() {
        _isBookmarked = previousBookmarked;
        _bookmarksCount = previousCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations(
              widget.currentLanguage,
            ).failedToUpdateBookmarkTryAgain,
          ),
        ),
      );
      return;
    }

    if (mounted && (result.isActive != null || result.count != null)) {
      setState(() {
        _isBookmarked = result.isActive ?? _isBookmarked;
        _bookmarksCount = result.count ?? _bookmarksCount;
      });
    }
  }

  Future<void> _sharePost() async {
    final localizations = AppLocalizations(widget.currentLanguage);
    final shareUrl = ShareLinkService.postUrl(widget.post.id);

    await SharePlus.instance.share(
      ShareParams(
        text:
            '${localizations.checkOutPost} ${widget.post.getLocalizedCaption(widget.currentLanguage.code)}\n\n$shareUrl',
      ),
    );

    if (!mounted) return;
    setState(() {
      _sharesCount += 1;
    });
    final result = await PostRepository().trackShare(
      widget.post.id,
      userId: widget.currentUser.id,
    );
    if (!result.success && mounted) {
      setState(() {
        _sharesCount = _sharesCount > 0 ? _sharesCount - 1 : 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations(widget.currentLanguage).failedToTrackShareTryAgain,
          ),
        ),
      );
      return;
    }

    if (mounted && result.count != null) {
      setState(() {
        _sharesCount = result.count!;
      });
    }
  }

  Future<void> _trackImpression() async {
    if (_isImpressionTracked) return;
    _isImpressionTracked = true;
    final result = await PostRepository().trackImpression(
      postId: widget.post.id,
      userId: widget.currentUser.id,
    );
    if (!result.success) {
      _isImpressionTracked = false;
    }
  }

  String _getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(widget.post.createdAt);
    final localizations = AppLocalizations(widget.currentLanguage);
    if (difference.inMinutes < 1) return localizations.justNow;
    if (difference.inHours < 1) {
      return localizations.minutesAgo(difference.inMinutes);
    }
    if (difference.inDays < 1) {
      return localizations.hoursAgo(difference.inHours);
    }
    return localizations.daysAgo(difference.inDays);
  }

  int get _readingTimeMinutes {
    final text = _sourceContent;
    final wordCount = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return (wordCount / 200).ceil().clamp(1, 999);
  }

  String get _sourceContent {
    if (widget.post.articleContent != null &&
        widget.post.articleContent!.trim().isNotEmpty) {
      return widget.post.articleContent!;
    }
    if (widget.post.poemVerses != null && widget.post.poemVerses!.isNotEmpty) {
      return widget.post.poemVerses!.join('\n\n');
    }
    return widget.post.caption;
  }

  void _prepareTranslationFutures() {
    _translatedTitleFuture = _buildTranslatedTitleFuture();
    _translatedContentFuture = _buildTranslatedContentFuture();
  }

  Future<String> _buildTranslatedTitleFuture() async {
    final targetCode = widget.currentLanguage.code;
    final serverTitle = _getServerTranslatedCaption(targetCode);
    if (PostTranslationService.shouldUseServerTranslation(
      sourceText: widget.post.caption,
      candidateText: serverTitle,
      targetLanguageCode: targetCode,
    )) {
      return serverTitle!.trim();
    }
    final sourceCode = PostTranslationService.detectLanguageCode(
      widget.post.caption,
    );
    if (sourceCode == targetCode) return widget.post.caption;
    final translated = await PostTranslationService.translate(
      text: widget.post.caption,
      sourceLanguageCode: sourceCode,
      targetLanguageCode: targetCode,
    );
    await _persistTitleIfMissing(targetCode, translated);
    return translated;
  }

  Future<String> _buildTranslatedContentFuture() async {
    final text = _sourceContent.trim();
    if (text.isEmpty) return text;
    final targetCode = widget.currentLanguage.code;
    final serverContent = _getServerTranslatedContent(targetCode);
    if (PostTranslationService.shouldUseServerTranslation(
      sourceText: text,
      candidateText: serverContent,
      targetLanguageCode: targetCode,
    )) {
      return serverContent!.trim();
    }
    final sourceCode = PostTranslationService.detectLanguageCode(text);
    if (sourceCode == targetCode) return text;
    final translated = await PostTranslationService.translate(
      text: text,
      sourceLanguageCode: sourceCode,
      targetLanguageCode: targetCode,
    );
    await _persistContentIfMissing(targetCode, translated);
    return translated;
  }

  String? _getServerTranslatedCaption(String targetCode) {
    if (targetCode == 'te') return widget.post.captionTe;
    if (targetCode == 'hi') return widget.post.captionHi;
    return null;
  }

  String? _getServerTranslatedContent(String targetCode) {
    if (targetCode == 'te') {
      final translatedArticle = widget.post.articleContentTe?.trim();
      if (translatedArticle != null && translatedArticle.isNotEmpty) {
        return translatedArticle;
      }
      final translatedPoem = widget.post.poemVersesTe;
      if (translatedPoem != null && translatedPoem.isNotEmpty) {
        return translatedPoem.join('\n\n');
      }
    }
    if (targetCode == 'hi') {
      final translatedArticle = widget.post.articleContentHi?.trim();
      if (translatedArticle != null && translatedArticle.isNotEmpty) {
        return translatedArticle;
      }
      final translatedPoem = widget.post.poemVersesHi;
      if (translatedPoem != null && translatedPoem.isNotEmpty) {
        return translatedPoem.join('\n\n');
      }
    }
    return null;
  }

  Future<void> _persistTitleIfMissing(
    String targetCode,
    String translated,
  ) async {
    final normalized = translated.trim();
    if (normalized.isEmpty) return;
    final update = <String, dynamic>{};
    if (targetCode == 'te' && (widget.post.captionTe?.trim().isEmpty ?? true)) {
      update['caption_te'] = normalized;
    } else if (targetCode == 'hi' &&
        (widget.post.captionHi?.trim().isEmpty ?? true)) {
      update['caption_hi'] = normalized;
    }
    if (update.isEmpty) return;
    update['translation_meta'] = {
      'provider': 'mlkit_on_device',
      'status': 'ready',
      'translated_at': FieldValue.serverTimestamp(),
    };
    update['updated_at'] = FieldValue.serverTimestamp();
    await FirestoreService.posts
        .doc(widget.post.id)
        .set(update, SetOptions(merge: true));
  }

  Future<void> _persistContentIfMissing(
    String targetCode,
    String translated,
  ) async {
    final normalized = translated.trim();
    if (normalized.isEmpty) return;
    final update = <String, dynamic>{};
    if (widget.post.articleContent != null &&
        widget.post.articleContent!.trim().isNotEmpty) {
      if (targetCode == 'te' &&
          (widget.post.articleContentTe?.trim().isEmpty ?? true)) {
        update['article_content_te'] = normalized;
      } else if (targetCode == 'hi' &&
          (widget.post.articleContentHi?.trim().isEmpty ?? true)) {
        update['article_content_hi'] = normalized;
      }
    } else if (widget.post.poemVerses != null &&
        widget.post.poemVerses!.isNotEmpty) {
      final verses = normalized
          .split('\n\n')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList(growable: false);
      if (verses.isNotEmpty) {
        if (targetCode == 'te' &&
            (widget.post.poemVersesTe == null ||
                widget.post.poemVersesTe!.isEmpty)) {
          update['poem_verses_te'] = verses;
        } else if (targetCode == 'hi' &&
            (widget.post.poemVersesHi == null ||
                widget.post.poemVersesHi!.isEmpty)) {
          update['poem_verses_hi'] = verses;
        }
      }
    }
    if (update.isEmpty) return;
    update['translation_meta'] = {
      'provider': 'mlkit_on_device',
      'status': 'ready',
      'translated_at': FieldValue.serverTimestamp(),
    };
    update['updated_at'] = FieldValue.serverTimestamp();
    await FirestoreService.posts
        .doc(widget.post.id)
        .set(update, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(widget.currentLanguage);
    final hasMedia =
        widget.post.mediaUrl != null || widget.post.pdfFilePath != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- Collapsing hero header ---
              SliverAppBar(
                expandedHeight: _computeHeroHeight(context),
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.primary,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: GestureDetector(
                    onTap: () => _openMediaViewer(),
                    child: _buildHeroMedia(hasMedia),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
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

              // --- Content body ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category + reading time row
                      Row(
                        children: [
                          CategoryBadgeWidget(
                            category: localizations.getCategoryName(
                              widget.post.category,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 13,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppLocalizations(
                                    widget.currentLanguage,
                                  ).minRead(_readingTimeMinutes),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Headline
                      FutureBuilder<String>(
                        future: _translatedTitleFuture,
                        builder: (context, snapshot) {
                          final translatedTitle = snapshot.data?.trim();
                          final hasTranslatedTitle =
                              translatedTitle != null &&
                              translatedTitle.isNotEmpty;
                          final title = hasTranslatedTitle
                              ? translatedTitle
                              : widget.post.getLocalizedCaption(
                                  widget.currentLanguage.code,
                                );
                          final useSourceDelta =
                              !hasTranslatedTitle &&
                              widget.currentLanguage == AppLanguage.english;
                          return PostRichText(
                            title,
                            delta: useSourceDelta
                                ? widget.post.captionDelta
                                : null,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Author row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.15,
                            ),
                            child: widget.post.authorAvatar != null
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: widget.post.authorAvatar!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 80,
                                      errorWidget: (_, _, _) => Text(
                                        widget.post.authorName[0].toUpperCase(),
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    widget.post.authorName[0].toUpperCase(),
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.post.authorName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: AppColors.textPrimaryOf(context),
                                  ),
                                ),
                                Text(
                                  _getTimeAgo(),
                                  style: TextStyle(
                                    color: AppColors.textSecondaryOf(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Divider
                      Divider(color: AppColors.dividerOf(context)),
                      const SizedBox(height: 16),

                      // Article / content body
                      FutureBuilder<String>(
                        future: _translatedContentFuture,
                        builder: (context, snapshot) {
                          final translated = snapshot.data?.trim();
                          final content =
                              translated != null && translated.isNotEmpty
                              ? translated
                              : _sourceContent;
                          final useSourceDelta =
                              (translated == null || translated.isEmpty) &&
                              widget.currentLanguage == AppLanguage.english;
                          return _buildArticleBody(
                            content,
                            delta: useSourceDelta
                                ? widget.post.articleContentDelta
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Hashtags — GAP-005: tappable chips → SearchScreen
                      if (widget.post.hashtags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.post.hashtags.map((tag) {
                            return ActionChip(
                              label: Text(
                                '#$tag',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.08,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide.none,
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Navigator.push(
                                  context,
                                  SmoothPageRoute(
                                    builder: (_) => SearchScreen(
                                      currentUser: widget.currentUser,
                                      initialQuery: '#$tag',
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Engagement stats
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondaryOf(
                            context,
                          ).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatChip(
                              Icons.favorite,
                              '$_likesCount',
                              AppLocalizations(widget.currentLanguage).likes,
                            ),
                            _buildStatChip(
                              Icons.share,
                              '$_sharesCount',
                              AppLocalizations(widget.currentLanguage).shares,
                            ),
                            _buildStatChip(
                              Icons.bookmark,
                              '$_bookmarksCount',
                              AppLocalizations(widget.currentLanguage).saved,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // End marker
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.auto_stories,
                                color: AppColors.textSecondaryOf(
                                  context,
                                ).withValues(alpha: 0.4),
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations(
                                  widget.currentLanguage,
                                ).endOfArticle,
                                style: TextStyle(
                                  color: AppColors.textSecondaryOf(
                                    context,
                                  ).withValues(alpha: 0.5),
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 80), // space for FAB
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- Reading progress bar at top ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: LinearProgressIndicator(
                value: _scrollProgress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                minHeight: 3,
              ),
            ),
          ),
        ],
      ),

      // --- Floating action bar ---
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          boxShadow: [
            BoxShadow(
              color: AppColors.overlaySoftOf(context).withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SafeArea(
          child: Row(
            children: [
              ScaleTransition(
                scale: _likeScaleAnim,
                child: _buildBottomAction(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '$_likesCount',
                  color: _isLiked
                      ? AppColors.likeStrong
                      : AppColors.textSecondaryOf(context),
                  onTap: _toggleLike,
                ),
              ),
              const SizedBox(width: 20),
              _buildBottomAction(
                icon: _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                label: _isBookmarked
                    ? AppLocalizations(widget.currentLanguage).saved
                    : AppLocalizations(widget.currentLanguage).save,
                color: _isBookmarked
                    ? AppColors.primary
                    : AppColors.textSecondaryOf(context),
                onTap: _toggleBookmark,
              ),
              const Spacer(),
              IconButton(
                onPressed: _sharePost,
                icon: Icon(
                  Icons.share_outlined,
                  color: AppColors.textSecondaryOf(context),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders full article / poetry / content
  Widget _buildArticleBody(String content, {List<dynamic>? delta}) {
    final isPoetry = widget.post.contentType == ContentType.poetry;

    if (isPoetry) {
      final verses = content
          .split(RegExp(r'\n{2,}'))
          .where((v) => v.trim().isNotEmpty)
          .toList();
      final poemVerses = verses.isEmpty ? <String>[content] : verses;
      return Column(
        children: poemVerses.map((verse) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Container(
              padding: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.infoOf(context).withValues(alpha: 0.6),
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                verse,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimaryOf(context),
                  height: 2.0,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }).toList(),
      );
    }

    if (delta != null && delta.isNotEmpty) {
      return PostRichText(
        content,
        delta: delta,
        style: TextStyle(
          fontSize: 16,
          color: AppColors.textPrimaryOf(context),
          height: 1.8,
        ),
      );
    }

    // Article / story content — split into paragraphs
    final paragraphs = content.split('\n\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((p) {
        if (p.trim().isEmpty) return const SizedBox.shrink();
        if (p.startsWith('#')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 20),
            child: MarkdownText(
              p.replaceAll('#', '').trim(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: MarkdownText(
            p.trim(),
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textPrimaryOf(context),
              height: 1.8,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeroPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Center(
        child: Icon(
          widget.post.contentType == ContentType.poetry
              ? Icons.format_quote_rounded
              : Icons.article_rounded,
          size: 64,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  /// Build the hero media area based on content type
  Widget _buildHeroMedia(bool hasMedia) {
    final mediaUrl = widget.post.mediaUrl;
    final pdfPath = widget.post.pdfFilePath;
    final contentType = widget.post.contentType;

    // If no media at all, show placeholder
    if (mediaUrl == null && pdfPath == null) {
      return _buildHeroPlaceholder();
    }

    // Check if it's a video based on content type or URL extension
    final isVideoType =
        contentType == ContentType.video ||
        (mediaUrl != null && _isVideoUrl(mediaUrl));

    // Check if it's a PDF based on content type or pdfFilePath or URL
    final isPdfType =
        contentType == ContentType.pdf ||
        pdfPath != null ||
        (mediaUrl != null && _isPdfUrl(mediaUrl));

    // Check if it's an image based on content type or URL extension
    final isImageType =
        contentType == ContentType.image ||
        (mediaUrl != null && _isImageUrl(mediaUrl));

    // Image / Video — show image thumbnail with scrim
    if ((isVideoType || isImageType) && mediaUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: mediaUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: 1080,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, _) => _buildHeroPlaceholder(),
            errorWidget: (_, _, _) => _buildHeroPlaceholder(),
          ),
          // Scrim gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
          // Play icon for video
          if (isVideoType)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      );
    }

    // PDF — show the actual first-page thumbnail
    if (isPdfType) {
      final pdfUrl = widget.post.pdfFilePath ?? mediaUrl;
      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        return PdfThumbnail(
          pdfUrl: pdfUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          label: AppLocalizations(widget.currentLanguage).tapToOpenPdf,
        );
      }
      // Fallback red placeholder if no URL
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE53935),
                  Color(0xFFC62828),
                  Color(0xFF8E0000),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppLocalizations(widget.currentLanguage).tapToOpenPdf,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return _buildHeroPlaceholder();
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.contains('video') ||
        lower.contains('watch');
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.contains('image') ||
        lower.contains('img');
  }

  bool _isPdfUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf') || lower.contains('pdf');
  }

  /// Opens the specific media viewer depending on content type
  void _openMediaViewer() {
    HapticFeedback.lightImpact();

    final mediaUrl = widget.post.mediaUrl;
    final pdfPath = widget.post.pdfFilePath;
    final contentType = widget.post.contentType;

    // Determine actual media type
    final isVideoType =
        contentType == ContentType.video ||
        (mediaUrl != null && _isVideoUrl(mediaUrl));
    final isPdfType =
        contentType == ContentType.pdf ||
        pdfPath != null ||
        (mediaUrl != null && _isPdfUrl(mediaUrl));
    final isImageType =
        contentType == ContentType.image ||
        (mediaUrl != null && _isImageUrl(mediaUrl));

    if (isVideoType && mediaUrl != null) {
      Navigator.push(
        context,
        SmoothPageRoute(builder: (_) => VideoPlayerScreen(post: widget.post)),
      );
      return;
    }

    if (isPdfType) {
      Navigator.push(
        context,
        SmoothPageRoute(
          builder: (_) => PdfViewerScreen(
            post: widget.post,
            currentLanguage: widget.currentLanguage,
          ),
        ),
      );
      return;
    }

    if (isImageType && mediaUrl != null) {
      // Full-screen image viewer
      Navigator.push(
        context,
        SmoothPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: mediaUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    // For article/story/poetry, open article reader
    if (contentType == ContentType.article ||
        contentType == ContentType.story ||
        contentType == ContentType.poetry ||
        contentType == ContentType.none) {
      Navigator.push(
        context,
        SmoothPageRoute(builder: (_) => ArticleReaderScreen(post: widget.post)),
      );
    }
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondaryOf(context)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
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
    );
  }
}

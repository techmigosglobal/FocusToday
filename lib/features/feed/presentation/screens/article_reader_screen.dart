import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/post_translation_service.dart';
import '../../../../core/services/share_link_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/markdown_text.dart';
import '../../../../shared/widgets/post_rich_text.dart';
import '../../data/repositories/post_repository.dart';
import '../../../../main.dart';

/// Article Reader Screen
/// Beautiful article/story/poetry reader with proper typography
class ArticleReaderScreen extends StatefulWidget {
  final Post post;

  const ArticleReaderScreen({super.key, required this.post});

  @override
  State<ArticleReaderScreen> createState() => _ArticleReaderScreenState();
}

class _ArticleReaderScreenState extends State<ArticleReaderScreen> {
  double _fontSize = 16;
  AppLanguage _currentLanguage = AppLanguage.english;
  LanguageService? _languageService;
  bool _isLanguageListenerAttached = false;
  late ScrollController _scrollController;
  double _scrollProgress = 0;
  Future<String>? _translatedTitleFuture;
  Future<String>? _translatedContentFuture;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updateScrollProgress);
    _loadLanguage();
  }

  @override
  void dispose() {
    if (_isLanguageListenerAttached && _languageService != null) {
      _languageService!.removeListener(_handleLanguageChange);
      _isLanguageListenerAttached = false;
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguage() async {
    final langService =
        FocusTodayApp.languageService ?? await LanguageService.init();
    FocusTodayApp.languageService ??= langService;
    _languageService = langService;
    if (!_isLanguageListenerAttached) {
      langService.addListener(_handleLanguageChange);
      _isLanguageListenerAttached = true;
    }
    if (!mounted) return;
    setState(() {
      _currentLanguage = langService.currentLanguage;
    });
    _prepareTranslationFutures();
  }

  void _handleLanguageChange() {
    final languageService = _languageService;
    if (!mounted || languageService == null) return;
    final nextLanguage = languageService.currentLanguage;
    if (nextLanguage == _currentLanguage) return;
    setState(() => _currentLanguage = nextLanguage);
    _prepareTranslationFutures();
  }

  void _updateScrollProgress() {
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      final next =
          _scrollController.offset / _scrollController.position.maxScrollExtent;
      if ((next - _scrollProgress).abs() < 0.01) return;
      setState(() => _scrollProgress = next);
    }
  }

  String get _content {
    switch (widget.post.contentType) {
      case ContentType.article:
      case ContentType.story:
        return widget.post.articleContent ?? widget.post.caption;
      case ContentType.poetry:
        return widget.post.poemVerses?.join('\n\n') ?? widget.post.caption;
      default:
        return widget.post.caption;
    }
  }

  void _prepareTranslationFutures() {
    _translatedTitleFuture = _buildTranslatedTitleFuture();
    _translatedContentFuture = _buildTranslatedContentFuture();
  }

  Future<String> _buildTranslatedTitleFuture() async {
    final targetCode = _currentLanguage.code;
    final serverTitle = _getServerTranslatedCaption(targetCode);
    if (PostTranslationService.shouldUseServerTranslation(
      sourceText: widget.post.caption,
      candidateText: serverTitle,
      targetLanguageCode: targetCode,
    )) {
      return serverTitle!.trim();
    }
    if (targetCode == 'en') return widget.post.caption;
    final translated = await PostTranslationService.translate(
      text: widget.post.caption,
      targetLanguageCode: targetCode,
    );
    await _persistTitleIfMissing(targetCode, translated);
    return translated;
  }

  Future<String> _buildTranslatedContentFuture() async {
    final source = _content.trim();
    if (source.isEmpty) return source;
    final targetCode = _currentLanguage.code;
    final serverContent = _getServerTranslatedContent(targetCode);
    if (PostTranslationService.shouldUseServerTranslation(
      sourceText: source,
      candidateText: serverContent,
      targetLanguageCode: targetCode,
    )) {
      return serverContent!.trim();
    }
    if (targetCode == 'en') return source;
    final translated = await PostTranslationService.translate(
      text: source,
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

  String _contentTypeLabel(AppLocalizations localizations) {
    switch (widget.post.contentType) {
      case ContentType.article:
        return localizations.articleLabel;
      case ContentType.story:
        return localizations.storyLabel;
      case ContentType.poetry:
        return localizations.poetryLabel;
      default:
        return localizations.read;
    }
  }

  int get _readingTimeMinutes {
    final wordCount = _content.split(' ').length;
    return (wordCount / 200).ceil(); // Average reading speed
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(_currentLanguage);
    final isPoetry = widget.post.contentType == ContentType.poetry;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.primary,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    _contentTypeLabel(localizations),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isPoetry
                            ? [Colors.pink.shade700, Colors.purple.shade800]
                            : [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.8),
                              ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isPoetry
                            ? Icons.format_quote_rounded
                            : Icons.article_rounded,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                actions: [
                  // Font size button
                  PopupMenuButton<double>(
                    icon: const Icon(Icons.text_fields),
                    onSelected: (size) {
                      setState(() => _fontSize = size);
                      HapticFeedback.selectionClick();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 14,
                        child: Text(localizations.small),
                      ),
                      PopupMenuItem(
                        value: 16,
                        child: Text(localizations.medium),
                      ),
                      PopupMenuItem(
                        value: 18,
                        child: Text(localizations.large),
                      ),
                      PopupMenuItem(
                        value: 20,
                        child: Text(localizations.extraLarge),
                      ),
                    ],
                  ),
                  // Share button
                  IconButton(
                    icon: const Icon(Icons.share_rounded),
                    onPressed: () async {
                      final shareUrl = ShareLinkService.postUrl(widget.post.id);
                      final localizations = AppLocalizations(_currentLanguage);
                      await SharePlus.instance.share(
                        ShareParams(
                          text:
                              '${localizations.checkOutPost} ${widget.post.getLocalizedCaption(_currentLanguage.code)}\n\n$shareUrl',
                        ),
                      );
                      // Track the share server-side
                      PostRepository().trackShare(
                        widget.post.id,
                        userId: '', // Auth user resolved server-side
                      );
                    },
                  ),
                ],
              ),

              // Article content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: isPoetry
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      // Title
                      FutureBuilder<String>(
                        future: _translatedTitleFuture,
                        builder: (context, snapshot) {
                          final translatedTitle = snapshot.data?.trim();
                          final hasTranslatedTitle =
                              translatedTitle != null &&
                              translatedTitle.isNotEmpty;
                          final title = hasTranslatedTitle
                              ? translatedTitle
                              : widget.post.caption;
                          final useSourceDelta =
                              !hasTranslatedTitle &&
                              _currentLanguage == AppLanguage.english;
                          return PostRichText(
                            title,
                            delta: useSourceDelta
                                ? widget.post.captionDelta
                                : null,
                            style: TextStyle(
                              fontSize: _fontSize + 8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                            textAlign: isPoetry
                                ? TextAlign.center
                                : TextAlign.start,
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Meta info
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.divider),
                            bottom: BorderSide(color: AppColors.divider),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Author
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                widget.post.authorName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
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
                                    widget.post.authorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    localizations.getCategoryName(
                                      widget.post.category,
                                    ),
                                    style: TextStyle(
                                      color: AppColors.textSecondaryOf(context),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Reading time
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 12,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    localizations.minRead(_readingTimeMinutes),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${localizations.source}: ${widget.post.authorName} • ${localizations.getCategoryName(widget.post.category)}',
                                style: TextStyle(
                                  color: AppColors.textSecondaryOf(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Content
                      FutureBuilder<String>(
                        future: _translatedContentFuture,
                        builder: (context, snapshot) {
                          final translated = snapshot.data?.trim();
                          final content =
                              (translated != null && translated.isNotEmpty)
                              ? translated
                              : _content;
                          final useSourceDelta =
                              (translated == null || translated.isEmpty) &&
                              _currentLanguage == AppLanguage.english;
                          if (isPoetry) {
                            return _buildPoetryContent(content);
                          }
                          return _buildArticleContent(
                            content,
                            delta: useSourceDelta
                                ? widget.post.articleContentDelta
                                : null,
                          );
                        },
                      ),

                      const SizedBox(height: 40),

                      // End indicator
                      Center(
                        child: Column(
                          children: [
                            const Icon(Icons.auto_stories, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              localizations.endOfContent(
                                _contentTypeLabel(localizations),
                              ),
                              style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Reading progress indicator
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _scrollProgress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleContent(String content, {List<dynamic>? delta}) {
    if (delta != null && delta.isNotEmpty) {
      return PostRichText(
        content,
        delta: delta,
        style: TextStyle(
          fontSize: _fontSize,
          color: AppColors.textPrimary,
          height: 1.8,
        ),
      );
    }

    // Split content into paragraphs
    final paragraphs = content.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        if (paragraph.trim().isEmpty) return const SizedBox.shrink();

        // Check if it's a heading (starts with #)
        if (paragraph.startsWith('#')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 24),
            child: MarkdownText(
              paragraph.replaceAll('#', '').trim(),
              style: TextStyle(
                fontSize: _fontSize + 4,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MarkdownText(
            paragraph.trim(),
            style: TextStyle(
              fontSize: _fontSize,
              color: AppColors.textPrimary,
              height: 1.8,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPoetryContent(String content) {
    final verses = content
        .split(RegExp(r'\n{2,}'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final renderVerses = verses.isEmpty ? <String>[content] : verses;

    return Column(
      children: renderVerses.map((verse) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.pink.shade200, width: 3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                verse,
                style: TextStyle(
                  fontSize: _fontSize + 2,
                  color: AppColors.textPrimary,
                  height: 2.0,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

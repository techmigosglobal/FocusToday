import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/models/post.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/post_translation_service.dart';

/// Data-layer cache for feed card localized text.
/// Keeps caption/snippet translation out of widget build methods.
class LocalizedPostText {
  final String caption;
  final String snippet;

  const LocalizedPostText({required this.caption, required this.snippet});
}

class PostTranslationRepository {
  PostTranslationRepository._();

  static const int _maxSnippetChars = 420;
  static const int _maxCacheEntries = 1200;

  static final Map<String, LocalizedPostText> _cache = {};
  static final Map<String, Future<LocalizedPostText>> _inFlight = {};
  static final Set<String> _persistInFlight = <String>{};

  static Future<LocalizedPostText> getLocalizedText({
    required Post post,
    required String targetLanguageCode,
  }) async {
    final key = _buildCacheKey(post, targetLanguageCode);
    final cached = _cache[key];
    if (cached != null) return cached;

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _buildLocalizedText(post, targetLanguageCode);
    _inFlight[key] = future;

    try {
      final value = await future;
      _cache[key] = value;
      _trimCache();
      return value;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<void> warmPosts({
    required Iterable<Post> posts,
    required String targetLanguageCode,
    int maxPosts = 4,
  }) async {
    var count = 0;
    for (final post in posts) {
      if (count >= maxPosts) break;
      await getLocalizedText(
        post: post,
        targetLanguageCode: targetLanguageCode,
      );
      count++;
    }
  }

  static void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  static String _buildCacheKey(Post post, String targetLanguageCode) {
    final snippet = _getRawSnippet(post).trim();
    return [
      post.id,
      targetLanguageCode.trim().toLowerCase(),
      post.caption.hashCode,
      post.captionTe?.hashCode ?? 0,
      post.captionHi?.hashCode ?? 0,
      snippet.hashCode,
    ].join('|');
  }

  static Future<LocalizedPostText> _buildLocalizedText(
    Post post,
    String targetLanguageCode,
  ) async {
    final target = targetLanguageCode.trim().toLowerCase();
    final caption = await _resolveCaption(post, target);
    final snippet = await _resolveSnippet(post, target);
    if (target != 'en') {
      unawaited(
        _persistMissingTranslations(
          post: post,
          targetCode: target,
          translatedCaption: caption,
          translatedSnippet: snippet,
        ),
      );
    }
    return LocalizedPostText(caption: caption, snippet: snippet);
  }

  static Future<String> _resolveCaption(Post post, String targetCode) async {
    if (targetCode == 'en') return post.caption;
    final serverTranslated = _serverCaption(post, targetCode);
    if (PostTranslationService.shouldUseServerTranslation(
      sourceText: post.caption,
      candidateText: serverTranslated,
      targetLanguageCode: targetCode,
    )) {
      return serverTranslated!.trim();
    }
    return PostTranslationService.translate(
      text: post.caption,
      targetLanguageCode: targetCode,
    );
  }

  static Future<String> _resolveSnippet(Post post, String targetCode) async {
    final rawSnippet = _getRawSnippet(post).trim();
    if (targetCode == 'en') return _clipSnippet(rawSnippet);
    final serverSnippet = _serverSnippet(post, targetCode);
    if (PostTranslationService.shouldUseServerTranslation(
      sourceText: rawSnippet,
      candidateText: serverSnippet,
      targetLanguageCode: targetCode,
    )) {
      return _clipSnippet(serverSnippet.trim());
    }
    if (rawSnippet.isEmpty) return '';
    final translated = await PostTranslationService.translate(
      text: rawSnippet,
      targetLanguageCode: targetCode,
    );
    return _clipSnippet(translated.trim());
  }

  static String _getRawSnippet(Post post) {
    if (post.articleContent != null && post.articleContent!.trim().isNotEmpty) {
      return post.articleContent!;
    }
    if (post.poemVerses != null && post.poemVerses!.isNotEmpty) {
      return post.poemVerses!.join('\n');
    }
    return '';
  }

  static String _clipSnippet(String text) {
    if (text.length <= _maxSnippetChars) return text;
    return '${text.substring(0, _maxSnippetChars).trimRight()}...';
  }

  static String? _serverCaption(Post post, String targetCode) {
    if (targetCode == 'te') return post.captionTe;
    if (targetCode == 'hi') return post.captionHi;
    return null;
  }

  static String _serverSnippet(Post post, String targetCode) {
    if (targetCode == 'te') {
      if (post.articleContentTe != null &&
          post.articleContentTe!.trim().isNotEmpty) {
        return post.articleContentTe!;
      }
      if (post.poemVersesTe != null && post.poemVersesTe!.isNotEmpty) {
        return post.poemVersesTe!.join('\n');
      }
    }
    if (targetCode == 'hi') {
      if (post.articleContentHi != null &&
          post.articleContentHi!.trim().isNotEmpty) {
        return post.articleContentHi!;
      }
      if (post.poemVersesHi != null && post.poemVersesHi!.isNotEmpty) {
        return post.poemVersesHi!.join('\n');
      }
    }
    return '';
  }

  static void _trimCache() {
    while (_cache.length > _maxCacheEntries) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
  }

  static Future<void> _persistMissingTranslations({
    required Post post,
    required String targetCode,
    required String translatedCaption,
    required String translatedSnippet,
  }) async {
    final inFlightKey = '${post.id}|$targetCode';
    if (_persistInFlight.contains(inFlightKey)) return;
    _persistInFlight.add(inFlightKey);

    try {
      final update = <String, dynamic>{};
      final normalizedCaption = translatedCaption.trim();
      final normalizedSnippet = translatedSnippet.trim();
      final sourceCaption = post.caption.trim();
      final sourceSnippet = _getRawSnippet(post).trim();

      if (targetCode == 'te') {
        final missingCaption = (post.captionTe?.trim().isEmpty ?? true);
        if (missingCaption &&
            normalizedCaption.isNotEmpty &&
            (normalizedCaption != sourceCaption ||
                PostTranslationService.detectLanguageCode(sourceCaption) ==
                    targetCode)) {
          update['caption_te'] = normalizedCaption;
        }

        if (post.articleContent != null && post.articleContent!.trim().isNotEmpty) {
          final missingArticle = (post.articleContentTe?.trim().isEmpty ?? true);
          if (missingArticle &&
              normalizedSnippet.isNotEmpty &&
              (normalizedSnippet != sourceSnippet ||
                  PostTranslationService.detectLanguageCode(sourceSnippet) ==
                      targetCode)) {
            update['article_content_te'] = normalizedSnippet;
          }
        } else if (post.poemVerses != null && post.poemVerses!.isNotEmpty) {
          final missingPoem = post.poemVersesTe == null || post.poemVersesTe!.isEmpty;
          if (missingPoem) {
            final translatedPoem = await _translatePoem(
              verses: post.poemVerses!,
              targetCode: targetCode,
            );
            if (translatedPoem.isNotEmpty) {
              update['poem_verses_te'] = translatedPoem;
            }
          }
        }
      } else if (targetCode == 'hi') {
        final missingCaption = (post.captionHi?.trim().isEmpty ?? true);
        if (missingCaption &&
            normalizedCaption.isNotEmpty &&
            (normalizedCaption != sourceCaption ||
                PostTranslationService.detectLanguageCode(sourceCaption) ==
                    targetCode)) {
          update['caption_hi'] = normalizedCaption;
        }

        if (post.articleContent != null && post.articleContent!.trim().isNotEmpty) {
          final missingArticle = (post.articleContentHi?.trim().isEmpty ?? true);
          if (missingArticle &&
              normalizedSnippet.isNotEmpty &&
              (normalizedSnippet != sourceSnippet ||
                  PostTranslationService.detectLanguageCode(sourceSnippet) ==
                      targetCode)) {
            update['article_content_hi'] = normalizedSnippet;
          }
        } else if (post.poemVerses != null && post.poemVerses!.isNotEmpty) {
          final missingPoem = post.poemVersesHi == null || post.poemVersesHi!.isEmpty;
          if (missingPoem) {
            final translatedPoem = await _translatePoem(
              verses: post.poemVerses!,
              targetCode: targetCode,
            );
            if (translatedPoem.isNotEmpty) {
              update['poem_verses_hi'] = translatedPoem;
            }
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
      await FirestoreService.posts.doc(post.id).set(update, SetOptions(merge: true));
    } catch (_) {
      // Best-effort persistence only.
    } finally {
      _persistInFlight.remove(inFlightKey);
    }
  }

  static Future<List<String>> _translatePoem({
    required List<String> verses,
    required String targetCode,
  }) async {
    final output = <String>[];
    for (final verse in verses) {
      final text = verse.trim();
      if (text.isEmpty) continue;
      final translated = await PostTranslationService.translate(
        text: text,
        targetLanguageCode: targetCode,
      );
      final normalized = translated.trim();
      if (normalized.isNotEmpty) output.add(normalized);
    }
    return output;
  }
}

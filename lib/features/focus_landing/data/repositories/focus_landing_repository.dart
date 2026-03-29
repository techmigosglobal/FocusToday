import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/services/cache_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/user.dart';
import '../models/focus_landing_content.dart';

class FocusLandingRepository {
  static const String _cacheKey = 'focus_landing_content';

  Future<FocusLandingContent> getContent({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = CacheService.get(
        _cacheKey,
        maxAge: const Duration(minutes: 1),
      );
      if (cached is Map) {
        return FocusLandingContent.fromJson(Map<String, dynamic>.from(cached));
      }
    }

    try {
      final doc = await FirestoreService.focusLandingConfig.get();
      final data = doc.data();
      if (data == null || data.isEmpty) {
        final defaults = FocusLandingContent.defaults();
        await CacheService.set(_cacheKey, defaults.toJson());
        return defaults;
      }

      final normalized = _normalizeDocData(data);
      final rawContent = FocusLandingContent.fromJson(normalized);
      final resolvedContent = await _resolveImageUrls(rawContent);
      final content = _syncLegacyUrlsFromCanonicalBlocks(resolvedContent);
      await CacheService.set(_cacheKey, content.toJson());
      return content;
    } catch (e) {
      debugPrint('[FocusLandingRepo] getContent error: $e');
      return FocusLandingContent.defaults();
    }
  }

  Future<bool> saveContent({
    required FocusLandingContent content,
    required User currentUser,
  }) async {
    if (!currentUser.canModerate) {
      debugPrint(
        '[FocusLandingRepo] saveContent denied for role=${currentUser.role.toStr()}',
      );
      return false;
    }

    try {
      final cacheSnapshot = _syncLegacyUrlsFromCanonicalBlocks(
        content.copyWith(updatedBy: currentUser.id, updatedAt: DateTime.now()),
      );
      await FirestoreService.focusLandingConfig.set({
        ...content.toJson(),
        'updated_by': currentUser.id,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await CacheService.set(_cacheKey, cacheSnapshot.toJson());
      return true;
    } catch (e) {
      debugPrint('[FocusLandingRepo] saveContent error: $e');
      return false;
    }
  }

  Future<UploadImageResult> uploadImage({
    required String filePath,
    required String userId,
    required String slot,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const UploadImageResult(
          url: null,
          errorMessage: 'Selected image file was not found.',
        );
      }
      final ext = file.path.split('.').last.toLowerCase();
      final path =
          'focus_landing/$userId/${slot}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await FirebaseStorage.instance.ref(path).putFile(file);
      final downloadUrl = await FirebaseStorage.instance
          .ref(path)
          .getDownloadURL();
      return UploadImageResult(url: downloadUrl, errorMessage: null);
    } on FirebaseException catch (e) {
      final message = switch (e.code) {
        'permission-denied' =>
          'Upload permission denied. Please check Storage rules and sign in again.',
        'unauthenticated' =>
          'Your session expired. Please log in again and retry.',
        'network-request-failed' => 'Network issue while uploading image.',
        'canceled' => 'Image upload was canceled.',
        _ => 'Image upload failed (${e.code}).',
      };
      debugPrint(
        '[FocusLandingRepo] uploadImage firebase error: ${e.code} ${e.message}',
      );
      return UploadImageResult(url: null, errorMessage: message);
    } catch (e) {
      debugPrint('[FocusLandingRepo] uploadImage error: $e');
      return const UploadImageResult(
        url: null,
        errorMessage: 'Image upload failed. Please try again.',
      );
    }
  }

  Future<void> invalidateCache() => CacheService.invalidate(_cacheKey);

  Future<FocusLandingContent> _resolveImageUrls(
    FocusLandingContent content,
  ) async {
    final hero = await _resolveStorageUrl(content.heroImageUrl);
    final secondary = await _resolveStorageUrl(content.secondaryImageUrl);
    final resolvedBlocks = await Future.wait(
      content.blocks.map((block) async {
        if (block.type != FocusLandingBlockType.image) return block;
        final resolved = await _resolveStorageUrl(block.imageUrl);
        if (resolved == block.imageUrl) return block;
        return block.copyWith(imageUrl: resolved);
      }),
    );
    if (hero == content.heroImageUrl &&
        secondary == content.secondaryImageUrl &&
        _blocksEqual(content.blocks, resolvedBlocks)) {
      return content;
    }
    return content.copyWith(
      heroImageUrl: hero,
      secondaryImageUrl: secondary,
      blocks: resolvedBlocks,
    );
  }

  FocusLandingContent _syncLegacyUrlsFromCanonicalBlocks(
    FocusLandingContent content,
  ) {
    final heroFromBlock = _imageUrlFromBlock(content.blocks, 'hero_image');
    final secondaryFromBlock = _imageUrlFromBlock(
      content.blocks,
      'secondary_image',
    );
    final nextHero = heroFromBlock.isNotEmpty
        ? heroFromBlock
        : content.heroImageUrl;
    final nextSecondary = secondaryFromBlock.isNotEmpty
        ? secondaryFromBlock
        : content.secondaryImageUrl;
    if (nextHero == content.heroImageUrl &&
        nextSecondary == content.secondaryImageUrl) {
      return content;
    }
    return content.copyWith(
      heroImageUrl: nextHero,
      secondaryImageUrl: nextSecondary,
    );
  }

  String _imageUrlFromBlock(List<FocusLandingBlock> blocks, String id) {
    for (final block in blocks) {
      if (block.id == id && block.type == FocusLandingBlockType.image) {
        return block.imageUrl.trim();
      }
    }
    return '';
  }

  Future<String> _resolveStorageUrl(String value) async {
    final raw = value.trim();
    if (raw.isEmpty) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    try {
      if (raw.startsWith('gs://')) {
        return await FirebaseStorage.instance.refFromURL(raw).getDownloadURL();
      }
      final normalizedPath = raw.startsWith('/') ? raw.substring(1) : raw;
      return await FirebaseStorage.instance
          .ref(normalizedPath)
          .getDownloadURL();
    } catch (_) {
      return raw;
    }
  }

  Map<String, dynamic> _normalizeDocData(Map<String, dynamic> data) {
    final normalized = <String, dynamic>{...data};
    final updatedAt = data['updated_at'];
    if (updatedAt is Timestamp) {
      normalized['updated_at'] = updatedAt.toDate().toIso8601String();
    }
    return normalized;
  }

  bool _blocksEqual(
    List<FocusLandingBlock> first,
    List<FocusLandingBlock> second,
  ) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      final a = first[i];
      final b = second[i];
      if (a.id != b.id ||
          a.type != b.type ||
          a.titleEn != b.titleEn ||
          a.titleTe != b.titleTe ||
          a.titleHi != b.titleHi ||
          a.bodyEn != b.bodyEn ||
          a.bodyTe != b.bodyTe ||
          a.bodyHi != b.bodyHi ||
          a.imageUrl != b.imageUrl) {
        return false;
      }
    }
    return true;
  }
}

class UploadImageResult {
  final String? url;
  final String? errorMessage;

  const UploadImageResult({required this.url, required this.errorMessage});
}

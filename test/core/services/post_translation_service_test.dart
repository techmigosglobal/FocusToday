import 'package:flutter_test/flutter_test.dart';
import 'package:focus_today/core/services/post_translation_service.dart';

void main() {
  group('PostTranslationService.detectLanguageCode', () {
    test('detects telugu', () {
      expect(PostTranslationService.detectLanguageCode('ఇది తెలుగు వార్త'), 'te');
    });

    test('detects hindi', () {
      expect(PostTranslationService.detectLanguageCode('यह हिंदी समाचार है'), 'hi');
    });

    test('defaults to english', () {
      expect(PostTranslationService.detectLanguageCode('This is English text'), 'en');
    });
  });

  group('PostTranslationService.shouldUseServerTranslation', () {
    test('returns false when candidate is empty', () {
      final value = PostTranslationService.shouldUseServerTranslation(
        sourceText: 'Hello world',
        candidateText: '',
        targetLanguageCode: 'te',
      );
      expect(value, isFalse);
    });

    test('returns false when candidate equals source for different language', () {
      final value = PostTranslationService.shouldUseServerTranslation(
        sourceText: 'Hello world',
        candidateText: 'Hello world',
        targetLanguageCode: 'hi',
      );
      expect(value, isFalse);
    });

    test('returns true when source already in target language', () {
      final value = PostTranslationService.shouldUseServerTranslation(
        sourceText: 'తెలుగు',
        candidateText: 'తెలుగు',
        targetLanguageCode: 'te',
      );
      expect(value, isTrue);
    });
  });
}

import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import {
  computePostSourceHash,
  translatePostContent,
} from './translation_service';

if (!admin.apps.length) {
  admin.initializeApp();
}

export const onPostWrittenTranslate = onDocumentWritten(
  {
    document: 'posts/{postId}',
    region: 'asia-south1',
  },
  async (event) => {
    if (!event.data?.after.exists) return;

    const afterRef = event.data.after.ref;
    const afterData = event.data.after.data() ?? {};

    const caption = String(afterData.caption ?? '').trim();
    if (caption.length === 0) return;

    const articleContentRaw = String(afterData.article_content ?? '').trim();
    const articleContent = articleContentRaw.length > 0 ? articleContentRaw : null;
    const poemVerses = Array.isArray(afterData.poem_verses)
      ? afterData.poem_verses
          .map((value: unknown) => String(value ?? '').trim())
          .filter((value: string) => value.length > 0)
      : null;

    const currentHash = String(
      ((afterData.translation_meta as Record<string, unknown> | undefined)
        ?.source_hash ?? ''),
    );
    const nextHash = computePostSourceHash({
      caption,
      articleContent,
      poemVerses,
    });
    const hasCoreTranslations =
      String(afterData.caption_te ?? '').trim().length > 0 &&
      String(afterData.caption_hi ?? '').trim().length > 0;

    if (currentHash === nextHash && hasCoreTranslations) {
      return;
    }

    const translated = await translatePostContent({
      caption,
      articleContent,
      poemVerses,
    });

    await afterRef.set(
      {
        caption: translated.caption,
        caption_te: translated.captionTe,
        caption_hi: translated.captionHi,
        article_content: translated.articleContent,
        article_content_te: translated.articleContentTe,
        article_content_hi: translated.articleContentHi,
        poem_verses: translated.poemVerses,
        poem_verses_te: translated.poemVersesTe,
        poem_verses_hi: translated.poemVersesHi,
        source_language: translated.sourceLanguage,
        translation_meta: {
          provider: 'google_translate_api_v2',
          source_language: translated.sourceLanguage,
          source_hash: nextHash,
          status: 'ready',
          translated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  },
);

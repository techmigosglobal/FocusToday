"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onPostWrittenTranslate = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const translation_service_1 = require("./translation_service");
if (!admin.apps.length) {
    admin.initializeApp();
}
exports.onPostWrittenTranslate = (0, firestore_1.onDocumentWritten)({
    document: 'posts/{postId}',
    region: 'asia-south1',
}, async (event) => {
    if (!event.data?.after.exists)
        return;
    const afterRef = event.data.after.ref;
    const afterData = event.data.after.data() ?? {};
    const caption = String(afterData.caption ?? '').trim();
    if (caption.length === 0)
        return;
    const articleContentRaw = String(afterData.article_content ?? '').trim();
    const articleContent = articleContentRaw.length > 0 ? articleContentRaw : null;
    const poemVerses = Array.isArray(afterData.poem_verses)
        ? afterData.poem_verses
            .map((value) => String(value ?? '').trim())
            .filter((value) => value.length > 0)
        : null;
    const currentHash = String((afterData.translation_meta
        ?.source_hash ?? ''));
    const nextHash = (0, translation_service_1.computePostSourceHash)({
        caption,
        articleContent,
        poemVerses,
    });
    const hasCoreTranslations = String(afterData.caption_te ?? '').trim().length > 0 &&
        String(afterData.caption_hi ?? '').trim().length > 0;
    if (currentHash === nextHash && hasCoreTranslations) {
        return;
    }
    const translated = await (0, translation_service_1.translatePostContent)({
        caption,
        articleContent,
        poemVerses,
    });
    await afterRef.set({
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
    }, { merge: true });
});

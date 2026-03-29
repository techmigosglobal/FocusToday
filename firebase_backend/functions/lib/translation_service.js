"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeLanguageCode = normalizeLanguageCode;
exports.detectLanguageCode = detectLanguageCode;
exports.computePostSourceHash = computePostSourceHash;
exports.translateTextWithGoogleApi = translateTextWithGoogleApi;
exports.translatePostContent = translatePostContent;
const SUPPORTED_CODES = new Set(['en', 'te', 'hi']);
const TELUGU_REGEX = /[\u0C00-\u0C7F]/;
const HINDI_REGEX = /[\u0900-\u097F]/;
function normalizeLanguageCode(code) {
    const value = String(code ?? '').trim().toLowerCase();
    if (!SUPPORTED_CODES.has(value))
        return 'en';
    return value;
}
function detectLanguageCode(text) {
    if (TELUGU_REGEX.test(text))
        return 'te';
    if (HINDI_REGEX.test(text))
        return 'hi';
    return 'en';
}
function computePostSourceHash(input) {
    const payload = JSON.stringify({
        c: input.caption.trim(),
        a: (input.articleContent ?? '').trim(),
        p: (input.poemVerses ?? []).map((v) => String(v ?? '').trim()),
    });
    let hash = 0;
    for (let i = 0; i < payload.length; i++) {
        hash = ((hash << 5) - hash + payload.charCodeAt(i)) | 0;
    }
    return String(hash);
}
async function translateTextWithGoogleApi({ text, targetLanguageCode, sourceLanguageCode, }) {
    const normalizedText = String(text ?? '').trim();
    if (normalizedText.length === 0)
        return '';
    const target = normalizeLanguageCode(targetLanguageCode);
    const source = sourceLanguageCode
        ? normalizeLanguageCode(sourceLanguageCode)
        : detectLanguageCode(normalizedText);
    // Cloud translation is disabled in ML Kit-only mode.
    if (source === target)
        return normalizedText;
    return normalizedText;
}
async function translateOptionalText(text, targetLanguageCode, sourceLanguageCode) {
    const normalized = String(text ?? '').trim();
    if (normalized.length === 0)
        return null;
    return translateTextWithGoogleApi({
        text: normalized,
        targetLanguageCode,
        sourceLanguageCode,
    });
}
async function translateOptionalList(values, targetLanguageCode, sourceLanguageCode) {
    if (!values || values.length === 0)
        return null;
    const translated = await Promise.all(values.map((value) => translateTextWithGoogleApi({
        text: String(value ?? ''),
        targetLanguageCode,
        sourceLanguageCode,
    })));
    const cleaned = translated.map((v) => v.trim()).filter((v) => v.length > 0);
    return cleaned.length > 0 ? cleaned : null;
}
async function translatePostContent(input) {
    const captionOriginal = String(input.caption ?? '').trim();
    const articleOriginal = String(input.articleContent ?? '').trim();
    const poemOriginal = Array.isArray(input.poemVerses)
        ? input.poemVerses.map((v) => String(v ?? '').trim()).filter((v) => v.length > 0)
        : [];
    const sourceLanguage = detectLanguageCode([captionOriginal, articleOriginal, poemOriginal.join('\n')].join('\n'));
    const captionEn = await translateTextWithGoogleApi({
        text: captionOriginal,
        sourceLanguageCode: sourceLanguage,
        targetLanguageCode: 'en',
    });
    const articleEn = await translateOptionalText(articleOriginal || null, 'en', sourceLanguage);
    const poemEn = await translateOptionalList(poemOriginal.length > 0 ? poemOriginal : null, 'en', sourceLanguage);
    const captionTe = await translateTextWithGoogleApi({
        text: captionEn,
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
    });
    const captionHi = await translateTextWithGoogleApi({
        text: captionEn,
        sourceLanguageCode: 'en',
        targetLanguageCode: 'hi',
    });
    const [articleTe, articleHi, poemTe, poemHi] = await Promise.all([
        translateOptionalText(articleEn, 'te', 'en'),
        translateOptionalText(articleEn, 'hi', 'en'),
        translateOptionalList(poemEn, 'te', 'en'),
        translateOptionalList(poemEn, 'hi', 'en'),
    ]);
    return {
        sourceLanguage,
        caption: captionEn,
        captionTe,
        captionHi,
        articleContent: articleEn,
        articleContentTe: articleTe,
        articleContentHi: articleHi,
        poemVerses: poemEn,
        poemVersesTe: poemTe,
        poemVersesHi: poemHi,
    };
}

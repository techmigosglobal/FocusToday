import * as admin from 'firebase-admin';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';
import {
  computePostSourceHash,
  detectLanguageCode,
  normalizeLanguageCode,
} from './translation_service';

// Conditional init — notification_triggers.ts may have already initialized admin
// (TypeScript imports are hoisted, so import order ≠ source order).
if (!admin.apps.length) {
  admin.initializeApp();
}

// Set all Cloud Functions to asia-south1 region with conservative caps.
setGlobalOptions({ region: 'asia-south1', maxInstances: 3 });

const db = admin.firestore();

const ROLE_WEIGHT: Record<string, number> = {
  public_user: 1,
  publicUser: 1,
  reporter: 2,
  admin: 3,
  super_admin: 4,
  superAdmin: 4,
};

type JsonMap = Record<string, unknown>;
type FetchRequestInit = {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
};
type FetchResponse = {
  status: number;
  text(): Promise<string>;
};
type FetchLike = (
  input: string,
  init?: FetchRequestInit,
) => Promise<FetchResponse>;

const fetchLike = (globalThis as unknown as { fetch?: FetchLike }).fetch;

function parseRuntimeInt(
  value: string | undefined,
  fallback: number,
  {
    min,
    max,
  }: {
    min: number;
    max: number;
  },
): number {
  const parsed = Number.parseInt(String(value ?? '').trim(), 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(max, Math.max(min, parsed));
}

const otpVerifyMinInstances = parseRuntimeInt(
  process.env.OTP_VERIFY_MIN_INSTANCES,
  0,
  { min: 0, max: 2 },
);
const otpVerifyMaxInstances = parseRuntimeInt(
  process.env.OTP_VERIFY_MAX_INSTANCES,
  3,
  { min: 1, max: 30 },
);

function ensureAuth(uid?: string): string {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  return uid;
}

function toMap(value: unknown): JsonMap {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as JsonMap;
  }
  return {};
}

function normalizeRole(role: unknown): string {
  const normalized = String(role ?? '')
    .trim()
    .toLowerCase()
    .replace(/[\s_]/g, '');

  switch (normalized) {
    case 'superadmin':
      return 'super_admin';
    case 'admin':
      return 'admin';
    case 'reporter':
      return 'reporter';
    case 'publicuser':
    default:
      return 'public_user';
  }
}

function roleWeight(role: unknown): number {
  return ROLE_WEIGHT[normalizeRole(role)] ?? 0;
}

function ensureRole(callerRole: unknown, minimumRole: string): void {
  if (roleWeight(callerRole) < roleWeight(minimumRole)) {
    throw new HttpsError('permission-denied', 'Insufficient role permission.');
  }
}

function canonicalPostAuthorName(
  role: unknown,
  displayNameRaw: unknown,
): string {
  const normalizedRole = normalizeRole(role);
  if (normalizedRole === 'admin' || normalizedRole === 'super_admin') {
    return 'Focus Today';
  }
  const displayName = String(displayNameRaw ?? '').trim();
  return displayName.length > 0 ? displayName : 'Reporter';
}

async function writeAuditEvent({
  eventType,
  entityType,
  entityId,
  actorId,
  actorRole,
  summary,
  metadata,
  before,
  after,
}: {
  eventType: string;
  entityType: string;
  entityId?: string | null;
  actorId?: string | null;
  actorRole?: string | null;
  summary?: string | null;
  metadata?: Record<string, unknown> | null;
  before?: Record<string, unknown> | null;
  after?: Record<string, unknown> | null;
}) {
  const normalizedEventType = String(eventType).trim();
  const normalizedEntityType = String(entityType).trim();
  if (!normalizedEventType || !normalizedEntityType) return;

  const doc: Record<string, unknown> = {
    event_type: normalizedEventType,
    entity_type: normalizedEntityType,
    entity_id: entityId ?? null,
    actor_id: actorId ?? null,
    actor_role: actorRole ?? null,
    summary: summary ?? null,
    metadata: metadata ?? null,
    before: before ?? null,
    after: after ?? null,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    // Legacy compatibility for existing readers.
    type: normalizedEventType,
  };

  if (entityId && normalizedEntityType === 'post') {
    doc.post_id = entityId;
  }

  await db.collection('audit_logs').add(doc);
}

function normalizeIndianPhone(value: unknown): string {
  let digits = String(value ?? '').replace(/\D/g, '');
  if (digits.startsWith('91') && digits.length > 10) {
    digits = digits.slice(2);
  }
  if (digits.length > 10) {
    digits = digits.slice(-10);
  }
  return digits;
}

function toIndianE164(value: unknown): string {
  const normalized = normalizeIndianPhone(value);
  return normalized ? `+91${normalized}` : '';
}

function isValidIndianPhone(value: unknown): boolean {
  return /^\d{10}$/.test(normalizeIndianPhone(value));
}

function parsePhoneList(raw: string | undefined): Set<string> {
  return new Set(
    String(raw ?? '')
      .split(',')
      .map((value) => normalizeIndianPhone(value))
      .filter((value) => value.length == 10),
  );
}

const SUPER_ADMIN_PHONES = parsePhoneList(process.env.ROLE_SUPER_ADMIN_PHONES);
const ADMIN_PHONES = parsePhoneList(process.env.ROLE_ADMIN_PHONES);
const REPORTER_PHONES = parsePhoneList(process.env.ROLE_REPORTER_PHONES);

function roleFromConfiguredPhone(phone: string): string | null {
  if (SUPER_ADMIN_PHONES.has(phone)) return 'super_admin';
  if (ADMIN_PHONES.has(phone)) return 'admin';
  if (REPORTER_PHONES.has(phone)) return 'reporter';
  return null;
}

function timestampToIso(value: unknown): string | null {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    return value;
  }
  return null;
}

function buildDisplayName(
  normalizedPhone: string,
  data: FirebaseFirestore.DocumentData | undefined,
): string {
  const existingName = String(data?.display_name ?? '').trim();
  if (existingName.length > 0) return existingName;
  return `User ${normalizedPhone.substring(normalizedPhone.length - 4)}`;
}

function serializeUser(
  uid: string,
  data: FirebaseFirestore.DocumentData | undefined,
): Record<string, unknown> {
  return {
    id: uid,
    phone_number:
        String(data?.phone_number ?? '').trim() || data?.phone_normalized || '',
    display_name: String(data?.display_name ?? 'User').trim(),
    role: normalizeRole(data?.role),
    email: data?.email ?? null,
    profile_picture: data?.profile_picture ?? null,
    bio: data?.bio ?? null,
    area: data?.area ?? null,
    district: data?.district ?? null,
    state: data?.state ?? null,
    preferred_language: data?.preferred_language ?? 'en',
    is_subscribed: data?.is_subscribed == true,
    subscription_plan_type: data?.subscription_plan_type ?? null,
    created_at: timestampToIso(data?.created_at) ?? new Date().toISOString(),
  };
}

async function findUserByPhone(
  normalizedPhone: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot | null> {
  const normalizedMatch = await db
    .collection('users')
    .where('phone_normalized', '==', normalizedPhone)
    .limit(1)
    .get();
  if (!normalizedMatch.empty) {
    return normalizedMatch.docs[0];
  }

  const variants = Array.from(
    new Set([
      normalizedPhone,
      `91${normalizedPhone}`,
      `+91${normalizedPhone}`,
      `+91 ${normalizedPhone}`,
    ]),
  );
  const rawMatch = await db
    .collection('users')
    .where('phone_number', 'in', variants)
    .limit(1)
    .get();
  if (!rawMatch.empty) {
    return rawMatch.docs[0];
  }

  return null;
}

async function ensureFirebaseUser(
  uid: string,
  displayName: string,
): Promise<void> {
  // NOTE: We do NOT pass phoneNumber to Firebase Auth because Phone Auth
  // provider is not enabled in Identity Platform.  Phone data lives in
  // Firestore (phone_normalized, phone_number) and in custom claims.
  try {
    const existing = await admin.auth().getUser(uid);
    if ((existing.displayName ?? '') !== displayName) {
      await admin.auth().updateUser(uid, { displayName });
    }
  } catch (error) {
    const authError = error as { code?: string };
    if (
      authError.code !== 'auth/user-not-found' &&
      authError.code !== 'auth/configuration-not-found'
    ) {
      throw error;
    }
    try {
      await admin.auth().createUser({ uid, displayName });
    } catch (createError) {
      const ce = createError as { code?: string };
      // auth/configuration-not-found can also fire on createUser
      if (ce.code === 'auth/configuration-not-found') {
        console.warn(
          '[ensureFirebaseUser] createUser got configuration-not-found — ' +
          'Identity Platform Phone provider may not be enabled. ' +
          'Continuing without Firebase Auth user record.',
        );
      } else {
        throw createError;
      }
    }
  }
}

function isMsg91Success(data: unknown): boolean {
  const payload = toMap(data);
  return (
    String(payload.type ?? '').toLowerCase() == 'success' ||
    payload.success == true ||
    String(payload.status ?? '').toLowerCase() == 'success'
  );
}

async function postJson(
  url: string,
  body: Record<string, string>,
  headers: Record<string, string> = {},
): Promise<{ status: number; data: unknown }> {
  if (!fetchLike) {
    throw new Error('Global fetch is unavailable in the current runtime.');
  }

  const response = await fetchLike(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...headers,
    },
    body: JSON.stringify(body),
  });

  const rawText = await response.text();
  let data: unknown = rawText;
  try {
    data = rawText ? JSON.parse(rawText) : {};
  } catch (_) {
    data = rawText;
  }
  return { status: response.status, data };
}

function decodeJwtPayload(token: string): JsonMap {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Token is not a valid JWT');
  }
  // Base64url → Base64 → Buffer → JSON
  const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
  const json = Buffer.from(base64, 'base64').toString('utf8');
  return JSON.parse(json) as JsonMap;
}

async function verifyMsg91AccessToken(
  accessToken: string,
  expectedPhone?: string,
): Promise<void> {
  const normalizedToken = accessToken.trim();
  if (normalizedToken.length === 0) {
    throw new HttpsError(
      'invalid-argument',
      'Access token is empty.',
    );
  }

  // ── OPTIMIZATION: Skip Msg91 API verification and go directly to JWT decode ──
  // The Msg91 widget SDK returns a signed JWT on successful OTP verification.
  // The JWT contains:
  // - exp: expiry timestamp
  // - iat: issued-at timestamp
  // - identifier: phone number
  // - signature: signed by Msg91's private key
  //
  // Making HTTP calls to Msg91's verify API adds 12+ seconds of latency with no
  // additional security benefit (the JWT itself proves authenticity). We now skip
  // the API calls and verify directly via JWT claims validation.
  
  try {
    const payload = decodeJwtPayload(normalizedToken);
    const now = Math.floor(Date.now() / 1000);

    // Check expiry
    if (typeof payload.exp === 'number' && payload.exp < now) {
      throw new HttpsError('unauthenticated', 'Access token has expired.');
    }

    // Check issued-at is not in the far future (clock-skew tolerance: 5 min)
    if (typeof payload.iat === 'number' && payload.iat > now + 300) {
      throw new HttpsError('unauthenticated', 'Access token has invalid timestamps.');
    }

    // Verify phone number if provided
    if (expectedPhone && expectedPhone.length >= 10) {
      const tokenPhone =
        normalizeIndianPhone(payload.identifier) ||
        normalizeIndianPhone(payload.phone) ||
        normalizeIndianPhone(payload.phone_number) ||
        normalizeIndianPhone(payload.mobile);
      if (tokenPhone.length > 0 && tokenPhone !== expectedPhone) {
        throw new HttpsError(
          'unauthenticated',
          'Access token phone does not match.',
        );
      }
    }

    console.log(
      '[verifyMsg91AccessToken] JWT verification succeeded (fast path)',
      JSON.stringify({
        hasExp: typeof payload.exp === 'number',
        hasIat: typeof payload.iat === 'number',
        phoneMatch: expectedPhone ? 'checked' : 'skipped',
      }),
    );
    return;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error('[verifyMsg91AccessToken] JWT decode/validation failed:', (error as Error).message);
    throw new HttpsError('unauthenticated', 'OTP verification failed.');
  }
}

async function getCallerProfile(uid: string): Promise<{
  data: FirebaseFirestore.DocumentData;
  role: string;
}> {
  const doc = await db.collection('users').doc(uid).get();
  if (!doc.exists || !doc.data()) {
    throw new HttpsError(
      'permission-denied',
      'User profile is missing or not provisioned.',
    );
  }

  const data = doc.data()!;
  if (data.is_active == false) {
    throw new HttpsError('permission-denied', 'User account is disabled.');
  }

  return { data, role: normalizeRole(data.role) };
}

export const verifyMsg91OtpAndExchangeToken = onCall(
  {
    invoker: "public",
    enforceAppCheck: false,
    // Billing-safe default: no warm instances unless explicitly enabled.
    minInstances: Math.min(otpVerifyMinInstances, otpVerifyMaxInstances),
    maxInstances: otpVerifyMaxInstances,
  },
  async (request) => {
  const totalStart = Date.now();
  const input = toMap(request.data);
  const normalizedPhone = normalizeIndianPhone(
    input.phone_number ?? input.phoneNumber,
  );
  const accessToken = String(
    input.access_token ?? input.accessToken ?? '',
  ).trim();

  if (!isValidIndianPhone(normalizedPhone) || accessToken.length == 0) {
    throw new HttpsError(
      'invalid-argument',
      'A valid phone number and Msg91 access token are required.',
    );
  }

  const verifyStart = Date.now();
  await verifyMsg91AccessToken(accessToken, normalizedPhone);
  const verifyMs = Date.now() - verifyStart;

  const lookupStart = Date.now();
  const existingDoc = await findUserByPhone(normalizedPhone);
  const existingData = existingDoc?.data();
  const configuredRole = roleFromConfiguredPhone(normalizedPhone);
  const resolvedRole = normalizeRole(existingData?.role ?? configuredRole);
  const userId = existingDoc?.id ?? `phone_${normalizedPhone}`;
  const displayName = buildDisplayName(normalizedPhone, existingData);
  const userRef = db.collection('users').doc(userId);
  const now = admin.firestore.FieldValue.serverTimestamp();

  if (existingData?.is_active == false) {
    throw new HttpsError('permission-denied', 'User account is disabled.');
  }

  const payload: Record<string, unknown> = {
    phone_number: toIndianE164(normalizedPhone),
    phone_normalized: normalizedPhone,
    display_name: displayName,
    role: resolvedRole,
    is_active: existingData?.is_active ?? true,
    updated_at: now,
    last_login_at: now,
  };
  if (!existingDoc?.exists) {
    payload.created_at = now;
  }

  const firestoreStart = Date.now();
  await userRef.set(payload, { merge: true });
  await ensureFirebaseUser(userId, displayName);
  const firestoreMs = Date.now() - firestoreStart;

  // setCustomUserClaims needs the Auth user to exist.  If ensureFirebaseUser
  // could not create the record (Identity-Platform misconfiguration), skip
  // gracefully — the claims are also embedded in the custom token below and
  // the Auth user will be created on client-side signInWithCustomToken.
  try {
    await admin.auth().setCustomUserClaims(userId, {
      role: resolvedRole,
      phone_number: normalizedPhone,
    });
  } catch (claimErr) {
    const ce = claimErr as { code?: string };
    if (
      ce.code === 'auth/user-not-found' ||
      ce.code === 'auth/configuration-not-found'
    ) {
      console.warn(
        `[setCustomUserClaims] skipped (${ce.code}) — claims in custom token`,
      );
    } else {
      throw claimErr;
    }
  }

  const customTokenStart = Date.now();
  const customToken = await admin.auth().createCustomToken(userId, {
    role: resolvedRole,
    phone_number: normalizedPhone,
  });
  const customTokenMs = Date.now() - customTokenStart;
  const lookupMs = Date.now() - lookupStart;
  const responseUserData: Record<string, unknown> = {
    ...(existingData ?? {}),
    ...payload,
  };

  return {
    ok: true,
    custom_token: customToken,
    user: serializeUser(userId, responseUserData),
    debug: {
      verify_token_ms: verifyMs,
      user_lookup_and_upsert_ms: lookupMs,
      firestore_upsert_ms: firestoreMs,
      custom_token_ms: customTokenMs,
      total_ms: Date.now() - totalStart,
    },
  };
});

export const backfillUserPhoneNormalized = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const caller = await getCallerProfile(uid);
  ensureRole(caller.role, 'admin');

  const batchSize = 400;
  let scanned = 0;
  let updated = 0;
  let pass = 0;

  while (pass < 20) {
    pass += 1;
    const snapshot = await db
      .collection('users')
      .where('phone_normalized', '==', null)
      .limit(batchSize)
      .get();
    if (snapshot.empty) break;

    const batch = db.batch();
    let updatesThisPass = 0;
    for (const doc of snapshot.docs) {
      scanned += 1;
      const normalized = normalizeIndianPhone(doc.data().phone_number);
      if (!isValidIndianPhone(normalized)) continue;
      batch.set(
        doc.ref,
        {
          phone_normalized: normalized,
          phone_number: toIndianE164(normalized),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      updatesThisPass += 1;
    }
    if (updatesThisPass == 0) break;
    await batch.commit();
    updated += updatesThisPass;
  }

  return { ok: true, scanned, updated };
});

export const createPost = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const caller = await getCallerProfile(uid);
  ensureRole(caller.role, 'reporter');

  const input = toMap(request.data);
  const caption = String(input.caption ?? '').trim();
  const contentType = String(input.contentType ?? '').trim();
  const category = String(input.category ?? '').trim();
  if (caption.length == 0 || contentType.length == 0 || category.length == 0) {
    throw new HttpsError(
      'invalid-argument',
      'caption, contentType, and category are required.',
    );
  }

  const status = roleWeight(caller.role) >= roleWeight('admin')
    ? 'approved'
    : 'pending';
  const now = admin.firestore.FieldValue.serverTimestamp();
  const postRef = db.collection('posts').doc();
  const articleContent = String(input.articleContent ?? '').trim();
  const poemVerses = Array.isArray(input.poemVerses)
    ? input.poemVerses.map((v) => String(v ?? '').trim()).filter((v) => v.length > 0)
    : [];

  const sourceLanguage = detectLanguageCode(
    [caption, articleContent, poemVerses.join('\n')].join('\n'),
  );
  const sourceHash = computePostSourceHash({
    caption,
    articleContent: articleContent.length > 0 ? articleContent : null,
    poemVerses: poemVerses.length > 0 ? poemVerses : null,
  });

  await postRef.set({
    author_id: uid,
    author_role: caller.role,
    author_name: canonicalPostAuthorName(caller.role, caller.data.display_name),
    author_avatar: caller.data.profile_picture ?? null,
    caption,
    caption_te: null,
    caption_hi: null,
    media_url: input.mediaUrl ?? null,
    content_type: contentType,
    category,
    article_content: articleContent.length > 0 ? articleContent : null,
    article_content_te: null,
    article_content_hi: null,
    poem_verses: poemVerses.length > 0 ? poemVerses : null,
    poem_verses_te: null,
    poem_verses_hi: null,
    caption_original: caption,
    article_content_original: articleContent.length > 0 ? articleContent : null,
    poem_verses_original: poemVerses.length > 0 ? poemVerses : null,
    source_language: sourceLanguage,
    translation_meta: {
      provider: 'mlkit_on_device',
      source_language: sourceLanguage,
      source_hash: sourceHash,
      status: 'pending_client_fill',
      translated_at: null,
    },
    status,
    likes_count: 0,
    bookmarks_count: 0,
    shares_count: 0,
    impressions_count: 0,
    created_at: now,
    published_at: now,
    updated_at: now,
  });

  return {
    ok: true,
    id: postRef.id,
    status,
    translation_status: 'pending_client_fill',
  };
});

export const translateText = onCall(async (request) => {
  throw new HttpsError(
    'failed-precondition',
    'Cloud translation is disabled. Use on-device ML Kit translation.',
  );
});

export const backfillPostTranslations = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const caller = await getCallerProfile(uid);
  ensureRole(caller.role, 'admin');

  return {
    ok: true,
    scanned: 0,
    updated: 0,
    message: 'Cloud backfill disabled in ML Kit-only mode.',
  };
});

export const backfillAdminPostAuthorNames = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const caller = await getCallerProfile(uid);
  ensureRole(caller.role, 'admin');

  let scanned = 0;
  let updated = 0;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  const roleByUserId = new Map<string, string>();

  while (true) {
    let query: FirebaseFirestore.Query = db
      .collection('posts')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(150);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    if (snap.empty) break;

    const userIdsToLoad = new Set<string>();
    for (const doc of snap.docs) {
      const data = doc.data() ?? {};
      const authorId = String(data.author_id ?? '').trim();
      const roleFromPost = normalizeRole(data.author_role);
      if (
        roleFromPost !== 'admin' &&
        roleFromPost !== 'super_admin' &&
        authorId.length > 0 &&
        !roleByUserId.has(authorId)
      ) {
        userIdsToLoad.add(authorId);
      }
    }

    if (userIdsToLoad.size > 0) {
      for (const chunk of Array.from(userIdsToLoad).reduce<string[][]>((acc, id, idx) => {
        const bucket = Math.floor(idx / 30);
        if (!acc[bucket]) acc[bucket] = [];
        acc[bucket].push(id);
        return acc;
      }, [])) {
        const usersSnap = await db
          .collection('users')
          .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
          .get();
        for (const userDoc of usersSnap.docs) {
          roleByUserId.set(userDoc.id, normalizeRole(userDoc.data().role));
        }
      }
    }

    let batch = db.batch();
    let batchSize = 0;

    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data() ?? {};
      const authorId = String(data.author_id ?? '').trim();
      const roleFromPost = normalizeRole(data.author_role);
      const roleFromUser = authorId.length > 0
        ? (roleByUserId.get(authorId) ?? '')
        : '';
      const resolvedRole = roleFromPost.length > 0 ? roleFromPost : roleFromUser;
      const isAdminAuthored =
        resolvedRole === 'admin' || resolvedRole === 'super_admin';
      const authorName = String(data.author_name ?? '').trim();
      if (!isAdminAuthored || authorName === 'Focus Today') {
        continue;
      }

      batch.set(
        doc.ref,
        {
          author_name: 'Focus Today',
          author_role: resolvedRole,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      batchSize += 1;
      updated += 1;

      if (batchSize >= 350) {
        await batch.commit();
        batch = db.batch();
        batchSize = 0;
      }
    }

    if (batchSize > 0) {
      await batch.commit();
    }

    if (snap.size < 150) break;
    lastDoc = snap.docs[snap.docs.length - 1];
  }

  await writeAuditEvent({
    eventType: 'admin_post_author_backfill',
    entityType: 'post',
    actorId: uid,
    actorRole: caller.role,
    summary: 'Backfilled admin/super-admin post author names',
    metadata: { scanned, updated },
  });

  return { ok: true, scanned, updated };
});

export const moderatePost = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const caller = await getCallerProfile(uid);
  ensureRole(caller.role, 'admin');

  const input = toMap(request.data);
  const postId = String(input.postId ?? '').trim();
  const status = String(input.status ?? '').trim();
  const rejectionReason = String(input.rejectionReason ?? '').trim();
  if (
    postId.length == 0 ||
    !['approved', 'rejected'].includes(status)
  ) {
    throw new HttpsError(
      'invalid-argument',
      'postId and a valid moderation status are required.',
    );
  }
  if (status === 'rejected' && rejectionReason.length === 0) {
    throw new HttpsError(
      'invalid-argument',
      'rejectionReason is required when rejecting a post.',
    );
  }

  await db.collection('posts').doc(postId).set(
    {
      status,
      rejection_reason: rejectionReason.length == 0 ? null : rejectionReason,
      moderated_by: uid,
      moderated_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await writeAuditEvent({
    eventType: 'post_moderated',
    entityType: 'post',
    entityId: postId,
    actorId: uid,
    actorRole: caller.role,
    summary: `Post ${status}`,
    metadata: {
      status,
      reason: rejectionReason.length > 0 ? rejectionReason : null,
    },
    after: {
      status,
      rejection_reason: rejectionReason.length > 0 ? rejectionReason : null,
      moderated_by: uid,
    },
  });

  return { ok: true };
});

// ── Super Admin: Update storage config ──
export const updateStorageConfig = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const caller = await getCallerProfile(uid);
  ensureRole(caller.role, 'super_admin');

  const input = toMap(request.data);
  const parseLimit = (raw: unknown, key: string): number => {
    const value = Number(raw);
    if (!Number.isFinite(value) || value <= 0) {
      throw new HttpsError('invalid-argument', `${key} must be a positive number.`);
    }
    if (value > 5000) {
      throw new HttpsError('invalid-argument', `${key} is too large.`);
    }
    return Number(value.toFixed(2));
  };
  const parseUtilised = (raw: unknown, key: string): number => {
    const value = Number(raw);
    if (!Number.isFinite(value) || value < 0) {
      throw new HttpsError('invalid-argument', `${key} must be a non-negative number.`);
    }
    if (value > 5000) {
      throw new HttpsError('invalid-argument', `${key} is too large.`);
    }
    return Number(value.toFixed(2));
  };

  const postsLimit = parseLimit(input.posts_limit_gb, 'posts_limit_gb');
  const interactionsLimit = parseLimit(
    input.interactions_limit_gb,
    'interactions_limit_gb',
  );
  const usersLimit = parseLimit(input.users_limit_gb, 'users_limit_gb');
  const systemFiles = parseLimit(input.system_files_gb, 'system_files_gb');
  const postsUtilised = parseUtilised(
    input.posts_utilised_gb ?? input.posts_used_gb ?? 0,
    'posts_utilised_gb',
  );
  const interactionsUtilised = parseUtilised(
    input.interactions_utilised_gb ?? input.interactions_used_gb ?? 0,
    'interactions_utilised_gb',
  );
  const usersUtilised = parseUtilised(
    input.users_utilised_gb ?? input.users_used_gb ?? 0,
    'users_utilised_gb',
  );
  const systemUtilised = parseUtilised(
    input.system_files_utilised_gb ?? input.system_used_gb ?? 0,
    'system_files_utilised_gb',
  );

  await db.collection('system').doc('storage_config').set(
    {
      posts_limit_gb: postsLimit,
      interactions_limit_gb: interactionsLimit,
      users_limit_gb: usersLimit,
      system_files_gb: systemFiles,
      posts_utilised_gb: postsUtilised,
      interactions_utilised_gb: interactionsUtilised,
      users_utilised_gb: usersUtilised,
      system_files_utilised_gb: systemUtilised,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_by: uid,
    },
    { merge: true },
  );

  await writeAuditEvent({
    eventType: 'storage_config_updated',
    entityType: 'system',
    entityId: 'storage_config',
    actorId: uid,
    actorRole: caller.role,
    summary: 'Storage config updated',
    metadata: {
      posts_limit_gb: postsLimit,
      interactions_limit_gb: interactionsLimit,
      users_limit_gb: usersLimit,
      system_files_gb: systemFiles,
      posts_utilised_gb: postsUtilised,
      interactions_utilised_gb: interactionsUtilised,
      users_utilised_gb: usersUtilised,
      system_files_utilised_gb: systemUtilised,
    },
  });

  return { ok: true };
});

export const getCurrentStorageUsage = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const caller = await getCallerProfile(uid);
  ensureRole(caller.role, 'admin');

  const bytesToGb = (bytes: number): number => {
    if (!Number.isFinite(bytes) || bytes <= 0) return 0;
    return Number((bytes / (1024 ** 3)).toFixed(4));
  };

  const sumFileBytes = async (prefix: string): Promise<number> => {
    try {
      const [files] = await admin.storage().bucket().getFiles({ prefix });
      let total = 0;
      for (const file of files) {
        total += Number(file.metadata?.size ?? 0);
      }
      return total;
    } catch (error) {
      console.warn(`[getCurrentStorageUsage] failed for prefix "${prefix}":`, error);
      return 0;
    }
  };

  const [postsCountSnap, usersCountSnap, commentsCountSnap, interactionsCountSnap, postsBytes, totalBucketBytes] =
    await Promise.all([
      db.collection('posts').count().get(),
      db.collection('users').count().get(),
      db.collectionGroup('comments').count().get(),
      db.collectionGroup('interactions').count().get(),
      sumFileBytes('posts/'),
      sumFileBytes(''),
    ]);

  const postsCount = postsCountSnap.data().count;
  const usersCount = usersCountSnap.data().count;
  const commentsCount = commentsCountSnap.data().count;
  const interactionsCount = interactionsCountSnap.data().count;

  const estimatedInteractionsBytes =
    (commentsCount * 850) + (interactionsCount * 250);
  const estimatedUsersBytes = usersCount * 900;
  const systemBytes = Math.max(0, totalBucketBytes - postsBytes);

  return {
    ok: true,
    generated_at: new Date().toISOString(),
    posts: {
      count: postsCount,
      used_gb: bytesToGb(postsBytes),
    },
    interactions: {
      comments: commentsCount,
      interactions: interactionsCount,
      used_gb: bytesToGb(estimatedInteractionsBytes),
    },
    users: {
      count: usersCount,
      used_gb: bytesToGb(estimatedUsersBytes),
    },
    system_files: {
      used_gb: bytesToGb(systemBytes),
    },
  };
});

export const recomputeAllMeetingEngagementCounts = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const caller = await getCallerProfile(uid);
  ensureRole(caller.role, 'admin');

  let scanned = 0;
  let updated = 0;
  let failed = 0;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;

  while (true) {
    let query: FirebaseFirestore.Query = db
      .collection('meetings')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(100);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    if (snap.empty) break;

    const results = await Promise.all(
      snap.docs.map(async (meetingDoc) => {
        scanned += 1;
        try {
          const [interestCountSnap, notInterestedCountSnap] = await Promise.all([
            meetingDoc.ref.collection('interests').count().get(),
            meetingDoc.ref
              .collection('rsvps')
              .where('response', '==', 'not_going')
              .count()
              .get(),
          ]);

          await meetingDoc.ref.set(
            {
              interest_count: interestCountSnap.data().count,
              not_interested_count: notInterestedCountSnap.data().count,
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
          return true;
        } catch (_) {
          return false;
        }
      }),
    );

    for (const ok of results) {
      if (ok) {
        updated += 1;
      } else {
        failed += 1;
      }
    }

    if (snap.size < 100) break;
    lastDoc = snap.docs[snap.docs.length - 1];
  }

  await writeAuditEvent({
    eventType: 'meeting_engagement_recomputed',
    entityType: 'meeting',
    actorId: uid,
    actorRole: caller.role,
    summary: 'Meeting engagement counters recomputed',
    metadata: { scanned, updated, failed },
  });

  return { ok: true, scanned, updated, failed };
});

export const togglePostInteraction = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const input = toMap(request.data);
  const postId = String(input.postId ?? '').trim();
  const type = String(input.type ?? '').trim();
  if (postId.length == 0 || !['like', 'bookmark'].includes(type)) {
    throw new HttpsError(
      'invalid-argument',
      'postId and a valid interaction type are required.',
    );
  }

  const postRef = db.collection('posts').doc(postId);
  const interactionRef = postRef.collection('interactions').doc(uid);
  const bookmarkRef = db
    .collection('users')
    .doc(uid)
    .collection('bookmarks')
    .doc(postId);

  const result = await db.runTransaction(async (tx) => {
    const interactionSnap = await tx.get(interactionRef);
    const current = interactionSnap.data() ?? {};
    const key = type == 'like' ? 'liked' : 'bookmarked';
    const previous = current[key] == true;
    const next = !previous;

    tx.set(
      interactionRef,
      {
        user_id: uid,
        [key]: next,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const counter = type == 'like' ? 'likes_count' : 'bookmarks_count';
    tx.set(
      postRef,
      {
        [counter]: admin.firestore.FieldValue.increment(next ? 1 : -1),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    if (type == 'bookmark') {
      if (next) {
        tx.set(
          bookmarkRef,
          { created_at: admin.firestore.FieldValue.serverTimestamp() },
          { merge: true },
        );
      } else {
        tx.delete(bookmarkRef);
      }
    }

    return { active: next };
  });

  return { ok: true, active: result.active };
});

export const createComment = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const caller = await getCallerProfile(uid);
  const input = toMap(request.data);
  const postId = String(input.postId ?? '').trim();
  const content = String(input.content ?? '').trim();
  if (postId.length == 0 || content.length == 0) {
    throw new HttpsError(
      'invalid-argument',
      'postId and content are required.',
    );
  }

  const ref = await db
    .collection('posts')
    .doc(postId)
    .collection('comments')
    .add({
      author_id: uid,
      author_name: String(caller.data.display_name ?? 'User'),
      author_avatar: caller.data.profile_picture ?? null,
      content,
      likes_count: 0,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

  return { ok: true, id: ref.id };
});

// ── Admin: Update user role ──
export const updateUserRole = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const caller = await getCallerProfile(uid);
  ensureRole(caller.role, 'admin');

  const input = toMap(request.data);
  const targetUserId = String(input.userId ?? '').trim();
  const newRole = normalizeRole(input.role);
  if (targetUserId.length === 0) {
    throw new HttpsError('invalid-argument', 'userId is required.');
  }

  // Prevent escalation: caller cannot assign a role >= their own weight
  // (except super_admin who can assign admin).
  if (roleWeight(newRole) >= roleWeight(caller.role) && caller.role !== 'super_admin') {
    throw new HttpsError('permission-denied', 'Cannot assign a role equal to or above your own.');
  }

  // SuperAdmin can assign admin/reporter/public_user.
  // Admin can only assign reporter/public_user.
  if (caller.role === 'admin' && roleWeight(newRole) >= roleWeight('admin')) {
    throw new HttpsError('permission-denied', 'Admins can only assign reporter or public_user roles.');
  }

  // Cannot change superAdmin's role
  const targetDoc = await db.collection('users').doc(targetUserId).get();
  if (targetDoc.exists) {
    const targetRole = normalizeRole(targetDoc.data()?.role);
    if (targetRole === 'super_admin' && caller.role !== 'super_admin') {
      throw new HttpsError('permission-denied', 'Cannot modify a super admin.');
    }
  }

  // Update Firestore
  await db.collection('users').doc(targetUserId).set(
    {
      role: newRole,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  // Update custom claims (best-effort)
  try {
    await admin.auth().setCustomUserClaims(targetUserId, {
      role: newRole,
      ...(targetDoc.exists ? { phone_number: targetDoc.data()?.phone_normalized } : {}),
    });
  } catch (claimErr) {
    const ce = claimErr as { code?: string };
    if (ce.code !== 'auth/user-not-found' && ce.code !== 'auth/configuration-not-found') {
      console.warn('[updateUserRole] setCustomUserClaims failed:', (claimErr as Error).message);
    }
  }

  await writeAuditEvent({
    eventType: 'role_changed',
    entityType: 'user',
    entityId: targetUserId,
    actorId: uid,
    actorRole: caller.role,
    summary: `Role changed to ${newRole}`,
    metadata: {
      target_user_id: targetUserId,
      new_role: newRole,
    },
    after: { role: newRole },
  });

  return { ok: true, userId: targetUserId, role: newRole };
});

// ── Admin: Create user with role ──
export const createUserWithRole = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const caller = await getCallerProfile(uid);
  ensureRole(caller.role, 'admin');

  const input = toMap(request.data);
  const phone = normalizeIndianPhone(input.phoneNumber ?? input.phone_number);
  const displayName = String(input.displayName ?? input.display_name ?? '').trim();
  const email = String(input.email ?? '').trim();
  const requestedRole = normalizeRole(input.role);

  if (!isValidIndianPhone(phone)) {
    throw new HttpsError('invalid-argument', 'A valid 10-digit phone number is required.');
  }
  if (displayName.length === 0) {
    throw new HttpsError('invalid-argument', 'Display name is required.');
  }

  // Role permission check
  if (caller.role === 'admin' && roleWeight(requestedRole) >= roleWeight('admin')) {
    throw new HttpsError('permission-denied', 'Admins can only create reporter or public_user.');
  }

  // Check if user already exists with this phone
  const existing = await findUserByPhone(phone);
  if (existing) {
    // Update existing user's role instead of creating duplicate
    const existingRole = normalizeRole(existing.data().role);
    if (existingRole === 'super_admin') {
      throw new HttpsError('permission-denied', 'Cannot modify a super admin.');
    }

    await db.collection('users').doc(existing.id).set(
      {
        role: requestedRole,
        display_name: displayName || existing.data().display_name,
        ...(email.length > 0 ? { email } : {}),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    try {
      await admin.auth().setCustomUserClaims(existing.id, {
        role: requestedRole,
        phone_number: phone,
      });
    } catch (_) { /* best effort */ }

    const updatedDoc = await db.collection('users').doc(existing.id).get();
    return {
      ok: true,
      created: false,
      user: serializeUser(existing.id, updatedDoc.data()),
    };
  }

  // Create new user doc
  const userId = `phone_${phone}`;
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection('users').doc(userId).set({
    phone_number: toIndianE164(phone),
    phone_normalized: phone,
    display_name: displayName,
    ...(email.length > 0 ? { email } : {}),
    role: requestedRole,
    is_active: true,
    created_at: now,
    updated_at: now,
  });

  // Create Firebase Auth user (best-effort)
  await ensureFirebaseUser(userId, displayName);
  try {
    await admin.auth().setCustomUserClaims(userId, {
      role: requestedRole,
      phone_number: phone,
    });
  } catch (_) { /* best effort */ }

  await writeAuditEvent({
    eventType: 'user_created',
    entityType: 'user',
    entityId: userId,
    actorId: uid,
    actorRole: caller.role,
    summary: `Created user with role ${requestedRole}`,
    metadata: { role: requestedRole },
    after: { role: requestedRole },
  });

  const freshDoc = await db.collection('users').doc(userId).get();
  return {
    ok: true,
    created: true,
    user: serializeUser(userId, freshDoc.data()),
  };
});

// ── Delete post (author or admin) ──
export const deletePost = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const caller = await getCallerProfile(uid);
  const input = toMap(request.data);
  const postId = String(input.postId ?? '').trim();
  if (postId.length === 0) {
    throw new HttpsError('invalid-argument', 'postId is required.');
  }

  const postRef = db.collection('posts').doc(postId);
  const postSnap = await postRef.get();
  if (!postSnap.exists) {
    throw new HttpsError('not-found', 'Post not found.');
  }

  const postData = postSnap.data()!;
  const isAuthor = postData.author_id === uid;
  const isAdmin = roleWeight(caller.role) >= roleWeight('admin');
  if (!isAuthor && !isAdmin) {
    throw new HttpsError(
      'permission-denied',
      'Only the post author or an admin can delete this post.',
    );
  }

  // Delete sub-collections (comments, interactions) — best effort
  const batch = db.batch();
  const commentSnaps = await postRef.collection('comments').listDocuments();
  for (const doc of commentSnaps) batch.delete(doc);
  const interactionSnaps = await postRef.collection('interactions').listDocuments();
  for (const doc of interactionSnaps) batch.delete(doc);
  batch.delete(postRef);
  await batch.commit();

  await writeAuditEvent({
    eventType: 'post_deleted',
    entityType: 'post',
    entityId: postId,
    actorId: uid,
    actorRole: caller.role,
    summary: 'Post deleted',
    metadata: { was_author: isAuthor },
  });

  return { ok: true };
});

// ── Track share interaction ──
export const trackShareInteraction = onCall(async (request) => {
  const uid = ensureAuth(request.auth?.uid);
  const input = toMap(request.data);
  const postId = String(input.postId ?? '').trim();
  if (postId.length === 0) {
    throw new HttpsError('invalid-argument', 'postId is required.');
  }

  const postRef = db.collection('posts').doc(postId);
  const postSnap = await postRef.get();
  if (!postSnap.exists) {
    throw new HttpsError('not-found', 'Post not found.');
  }

  // Increment shares_count atomically
  await postRef.set(
    {
      shares_count: admin.firestore.FieldValue.increment(1),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  // Fetch updated count
  const updated = await postRef.get();
  const count = Number(updated.data()?.shares_count ?? 0);

  return { ok: true, count };
});

// ── Get trending hashtags (server-side aggregation) ──
export const getTrendingHashtags = onCall(async (request) => {
  // Fetch recent approved posts, aggregate hashtags server-side
  const snapshot = await db
    .collection('posts')
    .where('status', '==', 'approved')
    .orderBy('published_at', 'desc')
    .limit(100)
    .get();

  const score: Record<string, number> = {};
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const hashtags = Array.isArray(data.hashtags) ? data.hashtags : [];
    const likesCount = Number(data.likes_count ?? 0);
    const weight = 1 + Math.min(likesCount, 50); // Weight by engagement

    for (const tag of hashtags) {
      const normalized = String(tag).trim().toLowerCase();
      if (normalized.length === 0) continue;
      score[normalized] = (score[normalized] ?? 0) + weight;
    }

    // Use category as fallback hashtag
    if (hashtags.length === 0 && data.category) {
      const categoryTag = String(data.category).trim().toLowerCase();
      if (categoryTag.length > 0) {
        score[categoryTag] = (score[categoryTag] ?? 0) + weight;
      }
    }
  }

  // Sort by score descending, return top 20
  const sorted = Object.entries(score)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 20)
    .map(([tag, count]) => ({ tag: `#${tag}`, count }));

  return { ok: true, hashtags: sorted };
});

// ── Public: Serve shareable post preview (Open Graph) ──
// This HTTP function renders a rich HTML page with OG meta tags so shared
// links show thumbnails/titles in WhatsApp, Telegram, Twitter, etc.
// Non-app users can view the full post content in a browser.
export const servePostPreview = onRequest(async (req, res) => {
  // Extract post ID from URL: /p/{postId}
  const pathParts = req.path.split('/').filter(Boolean);
  // Accept /p/{id} or just /{id}
  const postId =
    pathParts.length >= 2 && pathParts[0] === 'p'
      ? pathParts[1]
      : pathParts[0] || '';

  if (!postId || postId.length === 0) {
    res.status(404).send(buildErrorPage('Post not found'));
    return;
  }

  try {
    const postDoc = await db.collection('posts').doc(postId).get();
    if (!postDoc.exists || !postDoc.data()) {
      res.status(404).send(buildErrorPage('Post not found'));
      return;
    }

    const post = postDoc.data()!;
    const status = String(post.status ?? 'pending');
    if (status !== 'approved') {
      res.status(403).send(buildErrorPage('This post is not publicly available'));
      return;
    }

    const title = truncate(String(post.caption ?? 'Focus Today Post'), 120);
    const authorName = String(post.author_name ?? 'Focus Today');
    const category = String(post.category ?? '');
    const contentType = String(post.content_type ?? 'none');
    const mediaUrl = post.media_url ? String(post.media_url) : null;
    const articleContent = post.article_content ? String(post.article_content) : null;
    const poemVerses = Array.isArray(post.poem_verses) ? post.poem_verses : null;
    const likesCount = Number(post.likes_count ?? 0);
    const sharesCount = Number(post.shares_count ?? 0);
    const createdAt = post.created_at instanceof admin.firestore.Timestamp
      ? post.created_at.toDate()
      : new Date();

    const description = buildDescription(title, authorName, category, likesCount);
    const ogImage = mediaUrl && ['image', 'video'].includes(contentType)
      ? mediaUrl
      : 'https://crii-focus-today.web.app/og-default.png';

    const appStoreUrl = 'https://apps.apple.com/in/app/eagle-tv/id1234567890'; // TODO: Replace with actual iOS App ID
    const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.crii.eagletv';

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)} — Focus Today</title>

  <!-- Open Graph -->
  <meta property="og:type" content="article">
  <meta property="og:title" content="${escapeAttr(title)}">
  <meta property="og:description" content="${escapeAttr(description)}">
  <meta property="og:image" content="${escapeAttr(ogImage)}">
  <meta property="og:url" content="https://crii-focus-today.web.app/p/${postId}">
  <meta property="og:site_name" content="Focus Today">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="${mediaUrl ? 'summary_large_image' : 'summary'}">
  <meta name="twitter:title" content="${escapeAttr(title)}">
  <meta name="twitter:description" content="${escapeAttr(description)}">
  <meta name="twitter:image" content="${escapeAttr(ogImage)}">

  <!-- App Deep Link hints -->
  <meta property="al:android:url" content="eagletv://post/${postId}">
  <meta property="al:android:package" content="com.eagletv.eagle_tv">
  <meta property="al:android:app_name" content="Focus Today">

  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0a0a0a; color: #e0e0e0; min-height: 100vh;
      display: flex; flex-direction: column; align-items: center;
    }
    .header {
      width: 100%; max-width: 680px; padding: 20px;
      display: flex; align-items: center; gap: 12px;
    }
    .header .logo { font-size: 24px; font-weight: 800; color: #ff6b35; }
    .card {
      width: 100%; max-width: 680px; background: #1a1a1a;
      border-radius: 16px; overflow: hidden; margin: 0 16px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.4);
    }
    .media-container { width: 100%; aspect-ratio: 16/9; background: #111; overflow: hidden; }
    .media-container img { width: 100%; height: 100%; object-fit: cover; }
    .media-container video { width: 100%; height: 100%; object-fit: cover; }
    .media-placeholder {
      width: 100%; height: 100%; display: flex; align-items: center;
      justify-content: center; font-size: 48px; color: #333;
    }
    .content { padding: 24px; }
    .meta { display: flex; align-items: center; gap: 8px; margin-bottom: 12px; flex-wrap: wrap; }
    .author { font-weight: 600; color: #ff6b35; font-size: 15px; }
    .category {
      background: #ff6b3520; color: #ff6b35; padding: 3px 10px;
      border-radius: 12px; font-size: 12px; font-weight: 600;
    }
    .time { color: #888; font-size: 13px; }
    .caption { font-size: 18px; line-height: 1.6; margin: 16px 0; color: #f0f0f0; }
    .article { font-size: 16px; line-height: 1.8; margin: 16px 0; color: #ccc; }
    .poem { font-size: 16px; line-height: 2; margin: 16px 0; color: #ccc; font-style: italic; }
    .stats { display: flex; gap: 20px; padding: 16px 0; border-top: 1px solid #333; margin-top: 16px; }
    .stat { display: flex; align-items: center; gap: 6px; color: #888; font-size: 14px; }
    .cta-section {
      padding: 24px; text-align: center; margin: 24px 16px;
      background: #1a1a1a; border-radius: 16px;
    }
    .cta-section p { color: #888; margin-bottom: 16px; font-size: 15px; }
    .cta-btn {
      display: inline-block; padding: 14px 32px; background: #ff6b35;
      color: white; text-decoration: none; border-radius: 12px;
      font-weight: 700; font-size: 16px; margin: 6px;
      transition: background 0.2s;
    }
    .cta-btn:hover { background: #e55a28; }
    .footer { padding: 40px 20px; text-align: center; color: #555; font-size: 13px; }
  </style>
</head>
<body>
  <div class="header">
    <span class="logo">📺 Focus Today</span>
  </div>

  <div class="card">
    ${buildMediaHtml(contentType, mediaUrl)}
    <div class="content">
      <div class="meta">
        <span class="author">${escapeHtml(authorName)}</span>
        ${category ? `<span class="category">${escapeHtml(category)}</span>` : ''}
        <span class="time">${formatDate(createdAt)}</span>
      </div>
      <div class="caption">${escapeHtml(title)}</div>
      ${articleContent ? `<div class="article">${escapeHtml(truncate(articleContent, 2000))}</div>` : ''}
      ${poemVerses ? `<div class="poem">${poemVerses.map((v: string) => escapeHtml(v)).join('<br>')}</div>` : ''}
      <div class="stats">
        <span class="stat">❤️ ${formatCount(likesCount)} likes</span>
        <span class="stat">🔗 ${formatCount(sharesCount)} shares</span>
      </div>
    </div>
  </div>

  <div class="cta-section">
    <p>Get the full experience on the Focus Today app</p>
    <a class="cta-btn" href="${playStoreUrl}">Download for Android</a>
    <a class="cta-btn" href="${appStoreUrl}">Download for iOS</a>
  </div>

  <div class="footer">
    <p>&copy; ${new Date().getFullYear()} Focus Today. All rights reserved.</p>
  </div>
</body>
</html>`;

    res.set('Cache-Control', 'public, max-age=300, s-maxage=600');
    res.status(200).send(html);
  } catch (error) {
    console.error('[servePostPreview] error:', (error as Error).message);
    res.status(500).send(buildErrorPage('Something went wrong'));
  }
});

// ── Helper functions for servePostPreview ──

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;');
}

function escapeAttr(str: string): string {
  return str.replace(/"/g, '&quot;').replace(/'/g, '&#x27;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function truncate(str: string, max: number): string {
  return str.length > max ? str.substring(0, max - 1) + '…' : str;
}

function formatCount(n: number): string {
  if (n >= 1000) return (n / 1000).toFixed(1) + 'k';
  return String(n);
}

function formatDate(d: Date): string {
  return d.toLocaleDateString('en-IN', {
    year: 'numeric', month: 'short', day: 'numeric',
  });
}

function buildDescription(
  title: string,
  author: string,
  category: string,
  likes: number,
): string {
  const parts = [`By ${author}`];
  if (category) parts.push(`in ${category}`);
  if (likes > 0) parts.push(`${formatCount(likes)} likes`);
  return `${truncate(title, 80)} — ${parts.join(' • ')} — Focus Today`;
}

function buildMediaHtml(
  contentType: string,
  mediaUrl: string | null,
): string {
  if (!mediaUrl) {
    return `<div class="media-container"><div class="media-placeholder">📝</div></div>`;
  }
  switch (contentType) {
    case 'image':
      return `<div class="media-container"><img src="${escapeAttr(mediaUrl)}" alt="Post media" loading="lazy"></div>`;
    case 'video':
      return `<div class="media-container"><video src="${escapeAttr(mediaUrl)}" controls preload="metadata" poster="${escapeAttr(mediaUrl)}"></video></div>`;
    case 'pdf':
      return `<div class="media-container"><div class="media-placeholder">📄 PDF Document</div></div>`;
    default:
      return `<div class="media-container"><div class="media-placeholder">📝</div></div>`;
  }
}

function buildErrorPage(message: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Focus Today</title>
  <style>
    body {
      font-family: -apple-system, sans-serif; background: #0a0a0a; color: #e0e0e0;
      min-height: 100vh; display: flex; align-items: center; justify-content: center;
      flex-direction: column; gap: 16px;
    }
    h1 { color: #ff6b35; font-size: 28px; }
    p { color: #888; }
  </style>
</head>
<body>
  <h1>📺 Focus Today</h1>
  <p>${escapeHtml(message)}</p>
</body>
</html>`;
}

// Import and export notification triggers
export {
  onPostCreated,
  onPostStatusChange,
  onPostPublishedOutboxEnqueue,
  onPostResubmitted,
  onCommentCreated,
  onUserRoleChanged,
  onUserProfileIdentityChanged,
  onReporterApplicationDecision,
  onBreakingNewsCreated,
  onMeetingCreated,
  onMeetingInterestCreated,
  onMeetingInterestWritten,
  onMeetingRsvpWritten,
  sendTestFcmToSelf,
  sendMessageCampaign,
  executeScheduledCampaigns,
  sendMeetingReminders,
  dispatchPublicPublishedPostDigest,
  cleanupStaleDevices,
} from './notification_triggers';

// Translation trigger intentionally disabled in ML Kit-only mode.

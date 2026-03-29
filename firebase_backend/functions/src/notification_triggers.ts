import * as admin from 'firebase-admin';
import {
  onDocumentUpdated,
  onDocumentCreated,
  onDocumentWritten,
} from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const DEFAULT_FCM_CHANNEL_ID = 'focus_today_high_importance';

function normalizeRole(value: unknown): string {
  const normalized = String(value ?? '')
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

function normalizeRoleTopicSuffix(value: unknown): string {
  return normalizeRole(value);
}

function normalizeOptionalString(value: unknown): string | null {
  const normalized = String(value ?? '').trim();
  return normalized.length > 0 ? normalized : null;
}

const CAMPAIGN_MAX_TITLE_LENGTH = 120;
const CAMPAIGN_MAX_BODY_LENGTH = 1000;
const CAMPAIGN_ALLOWED_TYPES = new Set(['all', 'broadcast', 'role', 'topic']);
const CAMPAIGN_ALLOWED_ROLES = new Set([
  'public_user',
  'reporter',
  'admin',
  'super_admin',
]);
const CAMPAIGN_ALLOWED_TOPICS = new Set([
  'new_content',
  'breaking_news',
  'role_public_user',
  'role_reporter',
  'role_admin',
  'role_super_admin',
]);

function toRequestMap(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function sanitizeTitle(raw: unknown, fallback: string): string {
  const title = String(raw ?? fallback).trim() || fallback;
  if (title.length > CAMPAIGN_MAX_TITLE_LENGTH) {
    throw new HttpsError(
      'invalid-argument',
      `Title must be <= ${CAMPAIGN_MAX_TITLE_LENGTH} characters`,
    );
  }
  return title;
}

function sanitizeBody(raw: unknown, fallback = ''): string {
  const body = String(raw ?? fallback).trim();
  if (body.length === 0) {
    throw new HttpsError('invalid-argument', 'Message body is required');
  }
  if (body.length > CAMPAIGN_MAX_BODY_LENGTH) {
    throw new HttpsError(
      'invalid-argument',
      `Body must be <= ${CAMPAIGN_MAX_BODY_LENGTH} characters`,
    );
  }
  return body;
}

function normalizeCampaignType(raw: unknown): 'all' | 'broadcast' | 'role' | 'topic' {
  const normalized = String(raw ?? 'all').trim().toLowerCase();
  if (!CAMPAIGN_ALLOWED_TYPES.has(normalized)) {
    throw new HttpsError(
      'invalid-argument',
      "targeting.type must be one of: 'all', 'broadcast', 'role', 'topic'",
    );
  }
  return normalized as 'all' | 'broadcast' | 'role' | 'topic';
}

function normalizeCampaignRole(raw: unknown): string {
  const normalized = normalizeRoleTopicSuffix(raw);
  if (!CAMPAIGN_ALLOWED_ROLES.has(normalized)) {
    throw new HttpsError(
      'invalid-argument',
      "targeting.value for role must be one of: public_user, reporter, admin, super_admin",
    );
  }
  return normalized;
}

function normalizeCampaignTopic(raw: unknown): string {
  const topic = String(raw ?? 'new_content').trim() || 'new_content';
  if (!CAMPAIGN_ALLOWED_TOPICS.has(topic)) {
    throw new HttpsError(
      'invalid-argument',
      `targeting.value for topic must be one of: ${Array.from(CAMPAIGN_ALLOWED_TOPICS).join(', ')}`,
    );
  }
  return topic;
}

function buildCampaignResponse({
  type,
  value,
  deliveryMethod,
  topic,
  targetUserCount,
  targetedCount,
  successCount,
  failureCount,
  invalidTokenCount,
  messageId,
}: {
  type: string;
  value?: string | null;
  deliveryMethod: 'tokens' | 'topic';
  topic?: string | null;
  targetUserCount?: number;
  targetedCount?: number;
  successCount?: number;
  failureCount?: number;
  invalidTokenCount?: number;
  messageId?: string | null;
}) {
  return {
    ok: true,
    success: true,
    message: 'Campaign sent successfully',
    targeting: {
      type,
      value: value ?? null,
    },
    delivery: {
      method: deliveryMethod,
      topic: topic ?? null,
      target_user_count: targetUserCount ?? 0,
      target_count: targetedCount ?? 0,
      success_count: successCount ?? 0,
      failure_count: failureCount ?? 0,
      invalid_token_count: invalidTokenCount ?? 0,
      message_id: messageId ?? null,
    },
    // Backward-compatible fields expected by existing client code.
    messageCount: successCount ?? (deliveryMethod === 'topic' ? 1 : 0),
    delivery_method: deliveryMethod,
    topic: topic ?? null,
    target_user_count: targetUserCount ?? 0,
    target_count: targetedCount ?? 0,
    success_count: successCount ?? 0,
    failure_count: failureCount ?? 0,
  };
}

function canonicalAuthorName(role: unknown, displayName: unknown): string {
  const normalizedRole = normalizeRole(role);
  if (normalizedRole === 'admin' || normalizedRole === 'super_admin') {
    return 'Focus Today';
  }
  const trimmed = String(displayName ?? '').trim();
  return trimmed.length > 0 ? trimmed : 'User';
}

async function syncTopLevelAuthorFields({
  collection,
  userId,
  authorName,
  authorAvatar,
}: {
  collection: string;
  userId: string;
  authorName: string;
  authorAvatar: string | null;
}) {
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;

  while (true) {
    let query: FirebaseFirestore.Query = db
      .collection(collection)
      .where('author_id', '==', userId)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(400);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    let updates = 0;

    for (const doc of snap.docs) {
      const data = doc.data() ?? {};
      const currentName = String(data.author_name ?? '').trim();
      const currentAvatar = normalizeOptionalString(data.author_avatar);
      if (currentName === authorName && currentAvatar === authorAvatar) {
        continue;
      }

      batch.update(doc.ref, {
        author_name: authorName,
        author_avatar: authorAvatar,
      });
      updates++;
    }

    if (updates > 0) {
      await batch.commit();
    }

    if (snap.size < 400) break;
    lastDoc = snap.docs[snap.docs.length - 1];
  }
}

async function syncCollectionGroupAuthorFields({
  collectionId,
  userId,
  authorName,
  authorAvatar,
}: {
  collectionId: string;
  userId: string;
  authorName: string;
  authorAvatar: string | null;
}) {
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;

  while (true) {
    let query: FirebaseFirestore.Query = db
      .collectionGroup(collectionId)
      .where('author_id', '==', userId)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(400);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    let updates = 0;

    for (const doc of snap.docs) {
      const data = doc.data() ?? {};
      const currentName = String(data.author_name ?? '').trim();
      const currentAvatar = normalizeOptionalString(data.author_avatar);
      if (currentName === authorName && currentAvatar === authorAvatar) {
        continue;
      }

      batch.update(doc.ref, {
        author_name: authorName,
        author_avatar: authorAvatar,
      });
      updates++;
    }

    if (updates > 0) {
      await batch.commit();
    }

    if (snap.size < 400) break;
    lastDoc = snap.docs[snap.docs.length - 1];
  }
}

function actionDataJson(data?: Record<string, string>): string | null {
  if (!data || Object.keys(data).length === 0) return null;
  return JSON.stringify(data);
}

const PUBLIC_PUBLISHED_OUTBOX_PATH =
  'notification_outbox/public_published_posts/items';

function publicPublishedOutboxCollection() {
  return db.collection(PUBLIC_PUBLISHED_OUTBOX_PATH);
}

function buildFiveMinuteWindowKey(date: Date): string {
  const windowStartMs = Math.floor(date.getTime() / (5 * 60 * 1000)) * 5 * 60 * 1000;
  return new Date(windowStartMs).toISOString();
}

async function createInAppNotification({
  userId,
  title,
  body,
  type,
  data,
}: {
  userId: string;
  title: string;
  body: string;
  type: string;
  data?: Record<string, string>;
}) {
  if (!userId) return;

  await db.collection('notifications').add({
    user_id: userId,
    title,
    body,
    type,
    is_read: false,
    action_data: actionDataJson(data),
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function createInAppNotificationsForUsers({
  userIds,
  title,
  body,
  type,
  data,
}: {
  userIds: string[];
  title: string;
  body: string;
  type: string;
  data?: Record<string, string>;
}) {
  if (userIds.length === 0) return;

  const uniqueUserIds = Array.from(new Set(userIds.filter((id) => id.length > 0)));
  if (uniqueUserIds.length === 0) return;

  const now = admin.firestore.FieldValue.serverTimestamp();
  let batch = db.batch();
  let batchSize = 0;

  for (const userId of uniqueUserIds) {
    const ref = db.collection('notifications').doc();
    batch.set(ref, {
      user_id: userId,
      title,
      body,
      type,
      is_read: false,
      action_data: actionDataJson(data),
      created_at: now,
    });
    batchSize++;

    if (batchSize >= 400) {
      await batch.commit();
      batch = db.batch();
      batchSize = 0;
    }
  }

  if (batchSize > 0) {
    await batch.commit();
  }
}

async function getAllUserIds(): Promise<string[]> {
  const userIds: string[] = [];
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;

  while (true) {
    let query: FirebaseFirestore.Query = db
      .collection('users')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(500);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      userIds.push(doc.id);
    }

    if (snap.size < 500) break;
    lastDoc = snap.docs[snap.docs.length - 1];
  }

  return userIds;
}

async function getUserIdsByRoles(rawRoles: unknown[]): Promise<string[]> {
  const normalizedRoles = Array.from(
    new Set(
      rawRoles
        .map((role) => normalizeRole(role))
        .filter((role) => role.length > 0),
    ),
  );
  if (normalizedRoles.length === 0) return [];

  const queryRoles = Array.from(
    new Set(
      normalizedRoles.flatMap((role) => {
        switch (role) {
          case 'public_user':
            return ['public_user', 'publicUser'];
          case 'super_admin':
            return ['super_admin', 'superAdmin', 'superadmin'];
          case 'admin':
            return ['admin'];
          case 'reporter':
            return ['reporter'];
          default:
            return [role];
        }
      }),
    ),
  );

  const userIds: string[] = [];
  for (const roleChunk of chunkArray(queryRoles, 10)) {
    const snap = await db
      .collection('users')
      .where('role', 'in', roleChunk)
      .get();
    for (const doc of snap.docs) {
      userIds.push(doc.id);
    }
  }
  return Array.from(new Set(userIds));
}

function chunkArray<T>(arr: T[], chunkSize: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += chunkSize) {
    chunks.push(arr.slice(i, i + chunkSize));
  }
  return chunks;
}

function logDispatch(
  event: string,
  payload: Record<string, unknown>,
) {
  console.log(
    '[dispatch]',
    JSON.stringify({
      event,
      ...payload,
      ts: new Date().toISOString(),
    }),
  );
}

async function sendFCMToTokens({
  tokens,
  title,
  body,
  data,
}: {
  tokens: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<{
  targeted: number;
  success: number;
  failed: number;
  invalidTokens: string[];
}> {
  if (tokens.length === 0) {
    return { targeted: 0, success: 0, failed: 0, invalidTokens: [] };
  }

  const uniqueTokens = Array.from(new Set(tokens.filter((t) => t && t.length > 0)));
  if (uniqueTokens.length === 0) {
    return { targeted: 0, success: 0, failed: 0, invalidTokens: [] };
  }

  let success = 0;
  let failed = 0;
  const invalidTokenSet = new Set<string>();

  for (const tokenChunk of chunkArray(uniqueTokens, 500)) {
    const message: admin.messaging.MulticastMessage = {
      tokens: tokenChunk,
      notification: { title, body },
      data,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: DEFAULT_FCM_CHANNEL_ID,
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
        },
        payload: {
          aps: { sound: 'default' },
        },
      },
    };

    let response: admin.messaging.BatchResponse;
    try {
      response = await admin.messaging().sendEachForMulticast(message);
    } catch (error) {
      console.error('[sendFCMToTokens] Fatal batch error:', error);
      throw error;
    }

    console.log(
      `[sendFCMToTokens] Batch sent: ${response.successCount}/${response.responses.length}`,
    );
    success += response.successCount;
    failed += response.failureCount;

    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const error = resp.error;
        if (
          error?.code === 'messaging/invalid-registration-token' ||
          error?.code === 'messaging/registration-token-not-registered'
        ) {
          const invalidToken = tokenChunk[idx];
          if (invalidToken) invalidTokenSet.add(invalidToken);
        }
      }
    });
  }

  const invalidTokens = Array.from(invalidTokenSet);
  if (invalidTokens.length > 0) {
    console.log(
      `[sendFCMToTokens] Found ${invalidTokens.length} invalid tokens to cleanup`,
    );
  }

  console.log(
    `[sendFCMToTokens] Total sent: ${success}/${uniqueTokens.length}, failed: ${failed}`,
  );
  return {
    targeted: uniqueTokens.length,
    success,
    failed,
    invalidTokens,
  };
}

async function getUserTokens(uid: string): Promise<string[]> {
  const tokens = new Set<string>();

  try {
    const devicesActiveSnap = await db
      .collection('users')
      .doc(uid)
      .collection('devices')
      .where('active', '==', true)
      .get();

    for (const doc of devicesActiveSnap.docs) {
      const token = doc.data()?.fcm_token;
      if (token) tokens.add(token);
    }

    // Legacy fallback: older device docs may not have `active: true`.
    if (tokens.size === 0) {
      const devicesSnap = await db
        .collection('users')
        .doc(uid)
        .collection('devices')
        .limit(100)
        .get();
      for (const doc of devicesSnap.docs) {
        const data = doc.data() ?? {};
        if (data.active == false) continue;
        const token = data.fcm_token;
        if (token) tokens.add(token);
      }
    }

    if (tokens.size === 0) {
      const userDoc = await db.collection('users').doc(uid).get();
      const legacyToken = userDoc.data()?.fcm_token;
      if (legacyToken) tokens.add(legacyToken);
    }
  } catch (error) {
    console.error('[getUserTokens] Error:', error);
  }

  return Array.from(tokens);
}

async function getTokensForUserIds(userIds: string[]): Promise<string[]> {
  if (userIds.length === 0) return [];
  const tokenSet = new Set<string>();
  for (const userId of userIds) {
    const tokens = await getUserTokens(userId);
    for (const finalToken of tokens) {
      tokenSet.add(finalToken);
    }
  }
  return Array.from(tokenSet);
}

async function getAdminUserIds(): Promise<string[]> {
  return getUserIdsByRoles(['admin', 'super_admin']);
}

async function sendFCMToTopic({
  topic,
  title,
  body,
  data,
}: {
  topic: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<{ topic: string; messageId: string }> {
  try {
    const message: admin.messaging.Message = {
      notification: { title, body },
      data,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: DEFAULT_FCM_CHANNEL_ID,
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
        },
        payload: {
          aps: { sound: 'default' },
        },
      },
      topic,
    };

    const messageId = await admin.messaging().send(message);
    console.log(`[sendFCMToTopic] Sent to topic '${topic}': ${messageId}`);
    return { topic, messageId };
  } catch (error) {
    console.error(`[sendFCMToTopic] Error sending to topic '${topic}':`, error);
    throw error;
  }
}

export const onPostCreated = onDocumentCreated('posts/{postId}', async (event: any) => {
  const post = event.data.data();
  const postId = event.params.postId;

  if (post.status !== 'pending') return;

  const adminIds = await getAdminUserIds();
  if (adminIds.length === 0) return;

  const allTokens: string[] = [];
  for (const adminId of adminIds) {
    const tokens = await getUserTokens(adminId);
    allTokens.push(...tokens);
  }

  const body = `"${post.caption?.substring(0, 50) || 'New post'}" by ${post.author_name || 'Unknown'} is awaiting approval`;
  const data = {
    type: 'new_post_pending',
    post_id: postId,
  };

  logDispatch('onPostCreated.trigger', {
    postId,
    status: post.status,
    adminAudienceCount: adminIds.length,
    tokenCount: allTokens.length,
  });

  const delivery = await sendFCMToTokens({
    tokens: allTokens,
    title: '📝 New Post Pending Review',
    body,
    data,
  });
  await createInAppNotificationsForUsers({
    userIds: adminIds,
    title: 'New post pending review',
    body,
    type: 'new_post_pending',
    data,
  });
  logDispatch('onPostCreated.delivery', {
    postId,
    adminAudienceCount: adminIds.length,
    tokenCount: allTokens.length,
    successCount: delivery.success,
    failureCount: delivery.failed,
    invalidTokenCount: delivery.invalidTokens.length,
  });
});

export const onPostStatusChange = onDocumentUpdated(
  'posts/{postId}',
  async (event: any) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const postId = event.params.postId;

    const beforeStatus = before.status;
    const afterStatus = after.status;

    if (
      beforeStatus === afterStatus ||
      !['approved', 'rejected'].includes(afterStatus)
    ) {
      return;
    }

    const authorId = after.author_id;
    if (!authorId) return;

    const authorTokens = await getUserTokens(authorId);
    const postTitle = after.caption?.substring(0, 50) || 'Your post';
    const data = {
      type: `post_${afterStatus}`,
      post_id: postId,
    };

    let body: string;
    if (afterStatus === 'approved') {
      body = `"${postTitle}" has been approved and is now live`;
    } else {
      const rejectionReason = after.rejection_reason || 'Please review and resubmit';
      body = `"${postTitle}" was rejected: ${rejectionReason}`;
    }

    logDispatch('onPostStatusChange.trigger', {
      postId,
      fromStatus: beforeStatus,
      toStatus: afterStatus,
      authorId,
      tokenCount: authorTokens.length,
    });

    const delivery = await sendFCMToTokens({
      tokens: authorTokens,
      title: afterStatus === 'approved' ? '✅ Post Approved!' : '❌ Post Requires Changes',
      body,
      data,
    });
    await createInAppNotification({
      userId: authorId,
      title: afterStatus === 'approved' ? 'Post approved' : 'Post rejected',
      body,
      type: `post_${afterStatus}`,
      data,
    });
    logDispatch('onPostStatusChange.delivery', {
      postId,
      authorId,
      tokenCount: authorTokens.length,
      successCount: delivery.success,
      failureCount: delivery.failed,
      invalidTokenCount: delivery.invalidTokens.length,
    });
  },
);

export const onPostPublishedOutboxEnqueue = onDocumentWritten(
  'posts/{postId}',
  async (event: any) => {
    const before = event.data.before?.data() ?? null;
    const after = event.data.after?.data() ?? null;
    const postId = String(event.params.postId ?? '').trim();
    if (!after || !postId) return;

    const beforeStatus = String(before?.status ?? '').trim().toLowerCase();
    const afterStatus = String(after.status ?? '').trim().toLowerCase();
    if (afterStatus !== 'approved' || beforeStatus === 'approved') {
      return;
    }

    const now = new Date();
    const windowKey = buildFiveMinuteWindowKey(now);
    await publicPublishedOutboxCollection().doc(postId).set(
      {
        post_id: postId,
        status: 'approved',
        author_id: String(after.author_id ?? ''),
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        sent: false,
        sent_at: null,
        window_key: windowKey,
      },
      { merge: true },
    );
  },
);

export const onPostResubmitted = onDocumentWritten('posts/{postId}', async (event: any) => {
  const before = event.data.before?.data();
  const after = event.data.after?.data();

  if (!before || !after) return;

  const beforeStatus = before.status;
  const afterStatus = after.status;
  const postId = event.params.postId;

  if (beforeStatus !== 'rejected' || afterStatus !== 'pending') return;

  const adminIds = await getAdminUserIds();
  if (adminIds.length === 0) return;

  const allTokens: string[] = [];
  for (const adminId of adminIds) {
    const tokens = await getUserTokens(adminId);
    allTokens.push(...tokens);
  }

  const body = `"${after.caption?.substring(0, 50) || 'Post'}" has been edited and resubmitted`;
  const data = {
    type: 'post_resubmitted',
    post_id: postId,
  };

  await sendFCMToTokens({
    tokens: allTokens,
    title: '🔄 Post Resubmitted for Review',
    body,
    data,
  });
  await createInAppNotificationsForUsers({
    userIds: adminIds,
    title: 'Post resubmitted',
    body,
    type: 'post_resubmitted',
    data,
  });
});

export const onCommentCreated = onDocumentCreated(
  'posts/{postId}/comments/{commentId}',
  async (event: any) => {
    const comment = event.data.data();
    const postId = event.params.postId;
    const commentId = event.params.commentId;

    const postSnap = await db.collection('posts').doc(postId).get();
    if (!postSnap.exists) return;

    const post = postSnap.data()!;
    const authorId = post.author_id;
    const commenterId = comment.author_id;

    if (authorId === commenterId) return;

    const authorTokens = await getUserTokens(authorId);
    const commenterName = comment.author_name || 'Someone';
    const postTitle = post.caption?.substring(0, 40) || 'your post';

    const body = `${commenterName} commented on "${postTitle}"`;
    const data = {
      type: 'comment',
      post_id: postId,
      comment_id: commentId,
    };

    await sendFCMToTokens({
      tokens: authorTokens,
      title: '💬 New Comment',
      body,
      data,
    });
    await createInAppNotification({
      userId: authorId,
      title: 'New comment',
      body,
      type: 'comment',
      data,
    });
  },
);

function formatDateInIst(date: Date): string {
  const istDate = new Date(date.getTime() + 330 * 60 * 1000);
  const year = istDate.getUTCFullYear();
  const month = String(istDate.getUTCMonth() + 1).padStart(2, '0');
  const day = String(istDate.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function parseMeetingStartUtcMs(meetingDate: unknown, meetingTime: unknown): number | null {
  const dateRaw = String(meetingDate ?? '').trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateRaw)) return null;

  const [yearRaw, monthRaw, dayRaw] = dateRaw.split('-');
  const year = Number.parseInt(yearRaw, 10);
  const month = Number.parseInt(monthRaw, 10);
  const day = Number.parseInt(dayRaw, 10);
  if (
    !Number.isFinite(year) ||
    !Number.isFinite(month) ||
    !Number.isFinite(day)
  ) {
    return null;
  }

  const timeRaw = String(meetingTime ?? '00:00:00').trim();
  const timeParts = timeRaw.split(':');
  const hour = Number.parseInt(timeParts[0] ?? '0', 10);
  const minute = Number.parseInt(timeParts[1] ?? '0', 10);
  if (
    !Number.isFinite(hour) ||
    !Number.isFinite(minute) ||
    hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59
  ) {
    return null;
  }

  // Meetings are authored in India-local time. Convert IST (UTC+05:30) to UTC.
  const utcMs = Date.UTC(year, month - 1, day, hour, minute) - (330 * 60 * 1000);
  return Number.isFinite(utcMs) ? utcMs : null;
}

async function getMeetingReminderAudienceUserIds(
  meetingRef: FirebaseFirestore.DocumentReference,
): Promise<string[]> {
  const [interestSnap, rsvpSnap] = await Promise.all([
    meetingRef.collection('interests').limit(1000).get(),
    meetingRef
      .collection('rsvps')
      .where('response', 'in', ['going', 'maybe'])
      .limit(1000)
      .get(),
  ]);

  const userIds = new Set<string>();
  for (const doc of interestSnap.docs) {
    if (doc.id) userIds.add(doc.id);
  }
  for (const doc of rsvpSnap.docs) {
    if (doc.id) userIds.add(doc.id);
  }
  return Array.from(userIds);
}

async function syncMeetingEngagementCounts(meetingId: string): Promise<void> {
  const normalizedMeetingId = String(meetingId).trim();
  if (!normalizedMeetingId) return;

  try {
    const meetingRef = db.collection('meetings').doc(normalizedMeetingId);
    const meetingDoc = await meetingRef.get();
    if (!meetingDoc.exists) {
      logDispatch('meeting_engagement_sync.skipped', {
        meetingId: normalizedMeetingId,
        reason: 'meeting_not_found',
      });
      return;
    }

    const [interestCountSnap, notInterestedCountSnap] = await Promise.all([
      meetingRef.collection('interests').count().get(),
      meetingRef
        .collection('rsvps')
        .where('response', '==', 'not_going')
        .count()
        .get(),
    ]);

    const interestCount = interestCountSnap.data().count;
    const notInterestedCount = notInterestedCountSnap.data().count;
    await meetingRef.set(
      {
        interest_count: interestCount,
        not_interested_count: notInterestedCount,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    logDispatch('meeting_engagement_sync.success', {
      meetingId: normalizedMeetingId,
      interestCount,
      notInterestedCount,
    });
  } catch (error) {
    logDispatch('meeting_engagement_sync.failure', {
      meetingId: normalizedMeetingId,
      error: (error as Error).message,
    });
  }
}

export const onUserRoleChanged = onDocumentWritten('users/{userId}', async (event: any) => {
  const before = event.data.before?.data();
  const after = event.data.after?.data();

  if (!before || !after) return;

  const beforeRole = normalizeRole(before.role);
  const afterRole = normalizeRole(after.role);
  const userId = event.params.userId;

  if (beforeRole === afterRole) return;

  const userTokens = await getUserTokens(userId);

  const body = `Your role has been changed from ${beforeRole} to ${afterRole}`;
  const data = {
    type: 'role_changed',
    old_role: beforeRole,
    new_role: afterRole,
  };

  await sendFCMToTokens({
    tokens: userTokens,
    title: '🎯 Role Updated',
    body,
    data,
  });
  await createInAppNotification({
    userId,
    title: 'Role updated',
    body,
    type: 'role_changed',
    data,
  });
});

export const onUserProfileIdentityChanged = onDocumentUpdated(
  'users/{userId}',
  async (event: any) => {
    const before = event.data.before?.data() ?? {};
    const after = event.data.after?.data() ?? {};
    const userId = String(event.params.userId ?? '').trim();
    if (!userId) return;

    const beforeName = canonicalAuthorName(before.role, before.display_name);
    const afterName = canonicalAuthorName(after.role, after.display_name);
    const beforeAvatar = normalizeOptionalString(before.profile_picture);
    const afterAvatar = normalizeOptionalString(after.profile_picture);

    if (beforeName === afterName && beforeAvatar === afterAvatar) {
      return;
    }

    await Promise.all([
      syncTopLevelAuthorFields({
        collection: 'posts',
        userId,
        authorName: afterName,
        authorAvatar: afterAvatar,
      }),
      syncTopLevelAuthorFields({
        collection: 'reports',
        userId,
        authorName: afterName,
        authorAvatar: afterAvatar,
      }),
      syncCollectionGroupAuthorFields({
        collectionId: 'comments',
        userId,
        authorName: afterName,
        authorAvatar: afterAvatar,
      }),
      syncCollectionGroupAuthorFields({
        collectionId: 'replies',
        userId,
        authorName: afterName,
        authorAvatar: afterAvatar,
      }),
    ]);
  },
);

export const onReporterApplicationDecision = onDocumentUpdated(
  'reporter_applications/{applicationId}',
  async (event: any) => {
    const before = event.data.before?.data() ?? {};
    const after = event.data.after?.data() ?? {};

    const beforeStatus = String(before.status ?? '');
    const afterStatus = String(after.status ?? '');
    if (beforeStatus === afterStatus) return;
    if (!['approved', 'rejected'].includes(afterStatus)) return;

    const applicantId = String(after.applicant_id ?? '').trim();
    if (!applicantId) return;

    const userTokens = await getUserTokens(applicantId);
    const type =
      afterStatus === 'approved'
        ? 'reporter_application_approved'
        : 'reporter_application_rejected';

    const body =
      afterStatus === 'approved'
        ? 'Your reporter application has been approved.'
        : `Your reporter application was rejected${after.rejection_reason ? `: ${String(after.rejection_reason)}` : '.'}`;

    const data = {
      type,
      application_id: event.params.applicationId,
    };

    await sendFCMToTokens({
      tokens: userTokens,
      title: afterStatus === 'approved' ? '🎉 Reporter Application Approved' : 'Reporter Application Update',
      body,
      data,
    });
    await createInAppNotification({
      userId: applicantId,
      title: afterStatus === 'approved' ? 'Application approved' : 'Application rejected',
      body,
      type,
      data,
    });
  },
);

export const onBreakingNewsCreated = onDocumentCreated(
  'breaking_news/{newsId}',
  async (event: any) => {
    const news = event.data.data() ?? {};
    const newsId = event.params.newsId;
    if (news.is_active === false) return;

    const title = String(news.title ?? 'Breaking News');
    const body = String(
      news.subtitle ?? 'Tap to read the latest breaking update.',
    );
    const audience = news.audience && typeof news.audience === 'object'
      ? news.audience
      : { type: 'all' };
    const audienceType = String(audience.type ?? 'all').trim().toLowerCase();
    const audienceRoles = Array.isArray(audience.roles) ? audience.roles : [];
    const audienceUserIds = Array.isArray(audience.user_ids)
      ? audience.user_ids.map((id: unknown) => String(id)).filter(Boolean)
      : [];
    const delayMinutes = Math.max(
      0,
      Number(news.notify_delay_minutes ?? 0) || 0,
    );

    const data = {
      type: 'breaking_news',
      news_id: newsId,
    };

    if (delayMinutes > 0) {
      const scheduledAt = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + delayMinutes * 60 * 1000),
      );
      const scheduledTargeting =
        audienceType === 'users'
          ? { type: 'users', value: audienceUserIds }
          : audienceType === 'roles'
          ? { type: 'roles', value: audienceRoles }
          : { type: 'all' };
      await db.collection('fcm_campaigns').add({
        title,
        body,
        targeting: scheduledTargeting,
        status: 'scheduled',
        scheduled_at: scheduledAt,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        kind: 'breaking_news',
        data,
      });
      return;
    }

    let recipientUserIds: string[] = [];
    if (audienceType === 'users' && audienceUserIds.length > 0) {
      recipientUserIds = Array.from(new Set(audienceUserIds));
      const tokens = await getTokensForUserIds(recipientUserIds);
      await sendFCMToTokens({ tokens, title, body, data });
    } else if (audienceType === 'roles' && audienceRoles.length > 0) {
      recipientUserIds = await getUserIdsByRoles(audienceRoles);
      const tokens = await getTokensForUserIds(recipientUserIds);
      await sendFCMToTokens({ tokens, title, body, data });
    } else {
      recipientUserIds = await getAllUserIds();
      const tokens = await getTokensForUserIds(recipientUserIds);
      if (tokens.length > 0) {
        await sendFCMToTokens({ tokens, title, body, data });
      } else {
        await sendFCMToTopic({ topic: 'new_content', title, body, data });
      }
    }

    await createInAppNotificationsForUsers({
      userIds: recipientUserIds,
      title,
      body,
      type: 'breaking_news',
      data,
    });
  },
);

export const onMeetingInterestCreated = onDocumentCreated(
  'meetings/{meetingId}/interests/{userId}',
  async (event: any) => {
    const meetingId = String(event.params.meetingId ?? '');
    const userId = String(event.params.userId ?? '');
    if (!meetingId || !userId) return;
    const dedupeId = String(event.id ?? '').trim();
    if (dedupeId.length > 0) {
      const dedupeRef = db.collection('trigger_event_dedupe').doc(`meeting_interest_${dedupeId}`);
      const dedupeDoc = await dedupeRef.get();
      if (dedupeDoc.exists) return;
      await dedupeRef.set({
        type: 'meeting_interest',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const [meetingDoc, userDoc, adminUserIds] = await Promise.all([
      db.collection('meetings').doc(meetingId).get(),
      db.collection('users').doc(userId).get(),
      getAdminUserIds(),
    ]);

    const meetingData = meetingDoc.data() ?? {};
    const userData = userDoc.data() ?? {};
    const meetingTitle = String(meetingData.title ?? 'Meeting').trim();
    const meetingDate = String(meetingData.meeting_date ?? '').trim();
    const userRole = normalizeRole(userData.role ?? 'public_user');
    const userName = String(
      userData.display_name ?? 'A user',
    ).trim();
    const userPhone = String(userData.phone_number ?? '').trim();
    const userDistrict = String(userData.district ?? '').trim();
    const userState = String(userData.state ?? '').trim();
    const userLocation = [userDistrict, userState]
      .filter((value) => value.length > 0)
      .join(', ');

    const title = 'Meeting interest update';
    const bodyParts: string[] = [
      `${userName} (${userRole}) is interested in "${meetingTitle}"`,
    ];
    if (meetingDate.length > 0) {
      bodyParts.push(`on ${meetingDate}`);
    }
    if (userLocation.length > 0) {
      bodyParts.push(`from ${userLocation}`);
    }
    if (userPhone.length > 0) {
      bodyParts.push(`Phone: ${userPhone}`);
    }
    const body = `${bodyParts.join(' ')}.`;
    const data = {
      type: 'meeting_interest',
      meeting_id: meetingId,
      meeting_title: meetingTitle,
      meeting_date: meetingDate,
      user_id: userId,
      user_name: userName,
      user_phone: userPhone,
      user_district: userDistrict,
      user_state: userState,
      user_role: userRole,
    };

    const adminTokens = await getTokensForUserIds(adminUserIds);
    logDispatch('onMeetingInterestCreated.trigger', {
      meetingId,
      actorUserId: userId,
      adminAudienceCount: adminUserIds.length,
      tokenCount: adminTokens.length,
    });

    let topicDeliveries: Array<{ topic: string; messageId: string }> = [];
    if (adminTokens.length > 0) {
      await sendFCMToTokens({ tokens: adminTokens, title, body, data });
    } else {
      topicDeliveries = await Promise.all([
        sendFCMToTopic({ topic: 'role_admin', title, body, data }),
        sendFCMToTopic({ topic: 'role_super_admin', title, body, data }),
      ]);
    }
    await createInAppNotificationsForUsers({
      userIds: adminUserIds,
      title,
      body,
      type: 'meeting_interest',
      data,
    });

    logDispatch('onMeetingInterestCreated.delivery', {
      meetingId,
      actorUserId: userId,
      adminAudienceCount: adminUserIds.length,
      tokenCount: adminTokens.length,
      topics: topicDeliveries.map((item) => item.topic),
      messageIds: topicDeliveries.map((item) => item.messageId),
    });
  },
);

export const onMeetingInterestWritten = onDocumentWritten(
  'meetings/{meetingId}/interests/{userId}',
  async (event: any) => {
    const meetingId = String(event.params.meetingId ?? '').trim();
    if (!meetingId) return;
    await syncMeetingEngagementCounts(meetingId);
  },
);

export const onMeetingRsvpWritten = onDocumentWritten(
  'meetings/{meetingId}/rsvps/{userId}',
  async (event: any) => {
    const meetingId = String(event.params.meetingId ?? '').trim();
    if (!meetingId) return;
    await syncMeetingEngagementCounts(meetingId);
  },
);

export const onMeetingCreated = onDocumentCreated('meetings/{meetingId}', async (event: any) => {
  const meeting = event.data.data() ?? {};
  const meetingId = event.params.meetingId;

  const title = String(meeting.title ?? meeting.topic ?? 'New Meeting Scheduled');
  const body = String(
    meeting.description ?? meeting.agenda ?? 'A new meeting is available. Check details.',
  );

  const data = {
    type: 'meeting_created',
    meeting_id: meetingId,
  };

  const allUserIds = await getAllUserIds();
  const allTokens = await getTokensForUserIds(allUserIds);
  logDispatch('onMeetingCreated.trigger', {
    meetingId,
    audienceCount: allUserIds.length,
    tokenCount: allTokens.length,
  });

  let topicDelivery: { topic: string; messageId: string } | null = null;
  let directDelivery:
    | { targeted: number; success: number; failed: number; invalidTokens: string[] }
    | null = null;
  if (allTokens.length > 0) {
    directDelivery = await sendFCMToTokens({
      tokens: allTokens,
      title,
      body,
      data,
    });
  } else {
    topicDelivery = await sendFCMToTopic({
      topic: 'new_content',
      title,
      body,
      data,
    });
  }

  await createInAppNotificationsForUsers({
    userIds: allUserIds,
    title,
    body,
    type: 'meeting_created',
    data,
  });
  logDispatch('onMeetingCreated.delivery', {
    meetingId,
    audienceCount: allUserIds.length,
    tokenCount: allTokens.length,
    topic: topicDelivery?.topic,
    messageId: topicDelivery?.messageId,
    successCount: directDelivery?.success,
    failureCount: directDelivery?.failed,
    invalidTokenCount: directDelivery?.invalidTokens.length,
  });
});

export const sendTestFcmToSelf = onCall(async (request) => {
  try {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const userDoc = await db.collection('users').doc(uid).get();
    const userRole = normalizeRole(userDoc.data()?.role || 'public_user');
    if (!['admin', 'super_admin'].includes(userRole)) {
      throw new HttpsError(
        'permission-denied',
        'Only admin or super admin can run test push verification',
      );
    }

    const payload = toRequestMap(request.data);
    const title = sanitizeTitle(payload.title, 'Focus Today Test Push');
    const body = sanitizeBody(
      payload.body,
      'This is a manual FCM delivery verification message.',
    );
    const data = {
      type: 'fcm_test',
      source: 'sendTestFcmToSelf',
    };

    const tokens = await getUserTokens(uid);
    const delivery = await sendFCMToTokens({
      tokens,
      title,
      body,
      data,
    });

    logDispatch('sendTestFcmToSelf.delivery', {
      uid,
      tokenCount: tokens.length,
      successCount: delivery.success,
      failureCount: delivery.failed,
      invalidTokenCount: delivery.invalidTokens.length,
    });

    return {
      ok: true,
      message: 'Test push processed',
      targeted: delivery.targeted,
      success_count: delivery.success,
      failure_count: delivery.failed,
      invalid_token_count: delivery.invalidTokens.length,
      // Backward-compatible response fields.
      success: delivery.success,
      failed: delivery.failed,
      invalidTokens: delivery.invalidTokens,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    console.error('[sendTestFcmToSelf] Unexpected error:', error);
    throw new HttpsError('internal', 'Failed to process test push');
  }
});

export const sendMessageCampaign = onCall(async (request) => {
  try {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const userDoc = await db.collection('users').doc(uid).get();
    const userRole = normalizeRole(userDoc.data()?.role || 'public_user');

    if (!['admin', 'super_admin'].includes(userRole)) {
      throw new HttpsError('permission-denied', 'Admin access required');
    }

    const requestData = toRequestMap(request.data);
    const title = sanitizeTitle(requestData.title, 'Message from Focus Today');
    const body = sanitizeBody(requestData.body);

    const rawTargeting = toRequestMap(
      requestData.targeting ??
          {
            type: requestData.targetType ?? 'all',
            value: requestData.targetValue,
          },
    );
    const targetingType = normalizeCampaignType(rawTargeting.type);

    switch (targetingType) {
    case 'role': {
      const normalizedRole = normalizeCampaignRole(rawTargeting.value);
      const topic = `role_${normalizedRole}`;
      const userIds = await getUserIdsByRoles([normalizedRole]);
      const tokens = await getTokensForUserIds(userIds);
      let topicMessageId: string | null = null;
      let delivery:
        | { targeted: number; success: number; failed: number; invalidTokens: string[] }
        | null = null;

      if (tokens.length > 0) {
        delivery = await sendFCMToTokens({
          tokens,
          title,
          body,
          data: { type: 'campaign', targeting_role: normalizedRole },
        });
      } else {
        const topicDelivery = await sendFCMToTopic({
          topic,
          title,
          body,
          data: { type: 'campaign', targeting_role: normalizedRole },
        });
        topicMessageId = topicDelivery.messageId;
      }

      await db.collection('fcm_campaigns').add({
        title,
        body,
        targeting: { type: 'role', value: normalizedRole },
        status: 'sent',
        sent_at: admin.firestore.FieldValue.serverTimestamp(),
        created_by: uid,
        delivery_method: delivery ? 'tokens' : 'topic',
        topic: delivery ? null : topic,
        target_user_count: userIds.length,
        target_count: delivery?.targeted ?? 0,
        success_count: delivery?.success ?? 0,
        failure_count: delivery?.failed ?? 0,
        invalid_token_count: delivery?.invalidTokens.length ?? 0,
        message_id: topicMessageId,
      });

      return buildCampaignResponse({
        type: 'role',
        value: normalizedRole,
        deliveryMethod: delivery ? 'tokens' : 'topic',
        topic: delivery ? null : topic,
        targetUserCount: userIds.length,
        targetedCount: delivery?.targeted ?? 0,
        successCount: delivery?.success ?? 0,
        failureCount: delivery?.failed ?? 0,
        invalidTokenCount: delivery?.invalidTokens.length ?? 0,
        messageId: topicMessageId,
      });
    }

    case 'all':
    case 'broadcast': {
      const userIds = await getAllUserIds();
      const tokens = await getTokensForUserIds(userIds);
      let topicMessageId: string | null = null;
      let delivery:
        | { targeted: number; success: number; failed: number; invalidTokens: string[] }
        | null = null;

      if (tokens.length > 0) {
        delivery = await sendFCMToTokens({
          tokens,
          title,
          body,
          data: { type: 'campaign', targeting_type: 'broadcast' },
        });
      } else {
        const topicDelivery = await sendFCMToTopic({
          topic: 'new_content',
          title,
          body,
          data: { type: 'campaign', targeting_type: 'broadcast' },
        });
        topicMessageId = topicDelivery.messageId;
      }

      await db.collection('fcm_campaigns').add({
        title,
        body,
        targeting: { type: 'all' },
        status: 'sent',
        sent_at: admin.firestore.FieldValue.serverTimestamp(),
        created_by: uid,
        delivery_method: delivery ? 'tokens' : 'topic',
        topic: delivery ? null : 'new_content',
        target_user_count: userIds.length,
        target_count: delivery?.targeted ?? 0,
        success_count: delivery?.success ?? 0,
        failure_count: delivery?.failed ?? 0,
        invalid_token_count: delivery?.invalidTokens.length ?? 0,
        message_id: topicMessageId,
      });

      return buildCampaignResponse({
        type: 'all',
        value: null,
        deliveryMethod: delivery ? 'tokens' : 'topic',
        topic: delivery ? null : 'new_content',
        targetUserCount: userIds.length,
        targetedCount: delivery?.targeted ?? 0,
        successCount: delivery?.success ?? 0,
        failureCount: delivery?.failed ?? 0,
        invalidTokenCount: delivery?.invalidTokens.length ?? 0,
        messageId: topicMessageId,
      });
    }

    case 'topic':
    default: {
      const topic = normalizeCampaignTopic(rawTargeting.value);
      await sendFCMToTopic({
        topic,
        title,
        body,
        data: { type: 'campaign', targeting_topic: topic },
      });

      await db.collection('fcm_campaigns').add({
        title,
        body,
        targeting: { type: 'topic', value: topic },
        status: 'sent',
        sent_at: admin.firestore.FieldValue.serverTimestamp(),
        created_by: uid,
        delivery_method: 'topic',
        topic,
      });

      return buildCampaignResponse({
        type: 'topic',
        value: topic,
        deliveryMethod: 'topic',
        topic,
        targetUserCount: 0,
        targetedCount: 0,
        successCount: 1,
      });
    }
    }
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    console.error('[sendMessageCampaign] Unexpected error:', error);
    throw new HttpsError('internal', 'Failed to send campaign');
  }
});

export const executeScheduledCampaigns = onSchedule(
  'every 1 minutes',
  async () => {
    const now = admin.firestore.Timestamp.now();

    const campaignsSnap = await db
      .collection('fcm_campaigns')
      .where('status', '==', 'scheduled')
      .where('scheduled_at', '<=', now)
      .limit(10)
      .get();

    if (campaignsSnap.empty) return;

    for (const campaignDoc of campaignsSnap.docs) {
      const campaign = campaignDoc.data();
      const campaignId = campaignDoc.id;

      try {
        await db.runTransaction(async (transaction) => {
          const ref = db.collection('fcm_campaigns').doc(campaignId);
          const doc = await transaction.get(ref);

          if (doc.data()?.status !== 'scheduled') {
            throw new Error('Campaign already processed');
          }

          transaction.update(ref, { status: 'sending' });
        });

        const title = campaign.title || 'Message from Focus Today';
        const body = campaign.body || '';
        const targeting = campaign.targeting || { type: 'all' };
        const kind = String(campaign.kind || '').trim().toLowerCase();
        const campaignData =
          campaign.data && typeof campaign.data === 'object'
            ? Object.fromEntries(
                Object.entries(campaign.data as Record<string, unknown>).map(
                  ([key, value]) => [key, String(value ?? '')],
                ),
              )
            : { type: 'campaign' };

        switch (targeting.type) {
          case 'role': {
            const normalizedRole = normalizeRoleTopicSuffix(targeting.value);
            const topic = `role_${normalizedRole}`;
            await sendFCMToTopic({ topic, title, body, data: campaignData });

            await db.collection('fcm_campaigns').doc(campaignId).update({
              status: 'sent',
              sent_at: admin.firestore.FieldValue.serverTimestamp(),
              delivery_method: 'topic',
              topic,
            });
            break;
          }

          case 'roles': {
            const roles = Array.isArray(targeting.value)
              ? targeting.value
              : [targeting.value];
            const userIds = await getUserIdsByRoles(roles);
            const tokens = await getTokensForUserIds(userIds);
            const delivery = await sendFCMToTokens({
              tokens,
              title,
              body,
              data: campaignData,
            });

            if (kind === 'breaking_news') {
              await createInAppNotificationsForUsers({
                userIds,
                title,
                body,
                type: 'breaking_news',
                data: campaignData,
              });
            }

            await db.collection('fcm_campaigns').doc(campaignId).update({
              status: 'sent',
              sent_at: admin.firestore.FieldValue.serverTimestamp(),
              delivery_method: 'tokens',
              target_user_count: userIds.length,
              target_count: delivery.targeted,
              success_count: delivery.success,
              failure_count: delivery.failed,
              invalid_token_count: delivery.invalidTokens.length,
            });
            break;
          }

          case 'users': {
            const userIds = Array.isArray(targeting.value)
              ? targeting.value.map((id: unknown) => String(id)).filter(Boolean)
              : [];
            const tokens = await getTokensForUserIds(userIds);
            const delivery = await sendFCMToTokens({
              tokens,
              title,
              body,
              data: campaignData,
            });

            if (kind === 'breaking_news') {
              await createInAppNotificationsForUsers({
                userIds,
                title,
                body,
                type: 'breaking_news',
                data: campaignData,
              });
            }

            await db.collection('fcm_campaigns').doc(campaignId).update({
              status: 'sent',
              sent_at: admin.firestore.FieldValue.serverTimestamp(),
              delivery_method: 'tokens',
              target_user_count: userIds.length,
              target_count: delivery.targeted,
              success_count: delivery.success,
              failure_count: delivery.failed,
              invalid_token_count: delivery.invalidTokens.length,
            });
            break;
          }

          case 'all':
          case 'broadcast': {
            const allUserIds = await getAllUserIds();
            const tokens = await getTokensForUserIds(allUserIds);
            let delivery:
              | { targeted: number; success: number; failed: number; invalidTokens: string[] }
              | null = null;
            let topicMessageId: string | null = null;

            if (tokens.length > 0) {
              delivery = await sendFCMToTokens({
                tokens,
                title,
                body,
                data: campaignData,
              });
            } else {
              const topicDelivery = await sendFCMToTopic({
                topic: 'new_content',
                title,
                body,
                data: campaignData,
              });
              topicMessageId = topicDelivery.messageId;
            }

            if (kind === 'breaking_news') {
              await createInAppNotificationsForUsers({
                userIds: allUserIds,
                title,
                body,
                type: 'breaking_news',
                data: campaignData,
              });
            }

            await db.collection('fcm_campaigns').doc(campaignId).update({
              status: 'sent',
              sent_at: admin.firestore.FieldValue.serverTimestamp(),
              delivery_method: delivery ? 'tokens' : 'topic',
              topic: delivery ? null : 'new_content',
              target_user_count: allUserIds.length,
              target_count: delivery?.targeted ?? 0,
              success_count: delivery?.success ?? 0,
              failure_count: delivery?.failed ?? 0,
              invalid_token_count: delivery?.invalidTokens.length ?? 0,
              message_id: topicMessageId,
            });
            break;
          }

          case 'topic':
          default: {
            const topic = targeting.value || 'new_content';
            await sendFCMToTopic({ topic, title, body, data: campaignData });

            await db.collection('fcm_campaigns').doc(campaignId).update({
              status: 'sent',
              sent_at: admin.firestore.FieldValue.serverTimestamp(),
              delivery_method: 'topic',
              topic,
            });
            break;
          }
        }
      } catch (error) {
        await db.collection('fcm_campaigns').doc(campaignId).update({
          status: 'failed',
          error_message: (error as Error).message,
        });
      }
    }
  },
);

export const sendMeetingReminders = onSchedule(
  'every 5 minutes',
  async () => {
    const now = Date.now();
    const todayIst = formatDateInIst(new Date(now));
    const meetingsSnap = await db
      .collection('meetings')
      .where('status', '==', 'upcoming')
      .where('meeting_date', '>=', todayIst)
      .limit(300)
      .get();

    if (meetingsSnap.empty) return;

    for (const meetingDoc of meetingsSnap.docs) {
      const meeting = meetingDoc.data() ?? {};
      const startMs = parseMeetingStartUtcMs(
        meeting.meeting_date,
        meeting.meeting_time,
      );
      if (startMs == null) continue;

      const minutesUntilStart = (startMs - now) / 60000;
      if (minutesUntilStart < 0 || minutesUntilStart > 30) {
        continue;
      }

      const dedupeKey = `${meetingDoc.id}_${startMs}`;
      const dispatchRef = db.collection('meeting_reminder_dispatches').doc(dedupeKey);
      try {
        await dispatchRef.create({
          meeting_id: meetingDoc.id,
          scheduled_start_ms_utc: startMs,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        // Already dispatched by a previous scheduler run.
        continue;
      }

      const recipientUserIds = await getMeetingReminderAudienceUserIds(meetingDoc.ref);
      if (recipientUserIds.length === 0) continue;

      const title = `Reminder: ${String(meeting.title ?? 'Meeting')}`;
      const body = 'Starts soon. Tap to check meeting details and attendance.';
      const data = {
        type: 'meeting_reminder',
        meeting_id: meetingDoc.id,
      };

      const tokens = await getTokensForUserIds(recipientUserIds);
      logDispatch('sendMeetingReminders.trigger', {
        meetingId: meetingDoc.id,
        scheduledStartMsUtc: startMs,
        minutesUntilStart,
        audienceCount: recipientUserIds.length,
        tokenCount: tokens.length,
      });

      const [delivery] = await Promise.all([
        sendFCMToTokens({ tokens, title, body, data }),
        createInAppNotificationsForUsers({
          userIds: recipientUserIds,
          title,
          body,
          type: 'meeting_reminder',
          data,
        }),
      ]);
      logDispatch('sendMeetingReminders.delivery', {
        meetingId: meetingDoc.id,
        audienceCount: recipientUserIds.length,
        tokenCount: tokens.length,
        successCount: delivery.success,
        failureCount: delivery.failed,
        invalidTokenCount: delivery.invalidTokens.length,
      });
    }
  },
);

export const dispatchPublicPublishedPostDigest = onSchedule(
  'every 5 minutes',
  async () => {
    const now = admin.firestore.Timestamp.now();
    const outboxSnap = await publicPublishedOutboxCollection()
      .where('sent', '==', false)
      .orderBy('created_at', 'desc')
      .limit(200)
      .get();

    if (outboxSnap.empty) return;

    const docsToSend = outboxSnap.docs.filter((doc) => {
      const createdAt = doc.data().created_at;
      if (createdAt instanceof admin.firestore.Timestamp) {
        return createdAt.toMillis() <= now.toMillis();
      }
      return true;
    });
    if (docsToSend.length === 0) return;

    const latest = docsToSend[0].data();
    const latestPostId = String(latest.post_id ?? docsToSend[0].id);
    const count = docsToSend.length;
    const title = count === 1 ? 'New post published' : `${count} new posts published`;
    const body =
      count === 1
        ? 'A fresh update is now live in your feed.'
        : `${count} fresh updates are now live in your feed.`;

    const data = {
      type: 'post_published_digest',
      count: String(count),
      post_id: latestPostId,
    };

    const publicUserIds = await getUserIdsByRoles(['public_user', 'reporter']);
    const publicTokens = await getTokensForUserIds(publicUserIds);
    if (publicTokens.length > 0) {
      await sendFCMToTokens({
        tokens: publicTokens,
        title,
        body,
        data,
      });
    } else {
      await sendFCMToTopic({
        topic: 'role_public_user',
        title,
        body,
        data,
      });
    }

    const batch = db.batch();
    for (const doc of docsToSend) {
      batch.set(
        doc.ref,
        {
          sent: true,
          sent_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    await batch.commit();
  },
);

export const cleanupStaleDevices = onSchedule(
  'every 24 hours',
  async () => {
    const now = new Date();
    const thresholdDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    let totalCleaned = 0;
    const usersSnap = await db.collection('users').limit(1000).get();

    for (const userDoc of usersSnap.docs) {
      const userId = userDoc.id;

      try {
        const devicesSnap = await db
          .collection('users')
          .doc(userId)
          .collection('devices')
          .where('last_active_at', '<=', admin.firestore.Timestamp.fromDate(thresholdDate))
          .get();

        if (devicesSnap.empty) continue;

        const batch = db.batch();
        for (const deviceDoc of devicesSnap.docs) {
          batch.delete(deviceDoc.ref);
          totalCleaned++;
        }

        await batch.commit();
      } catch (error) {
        console.error(
          `[cleanupStaleDevices] Error cleaning devices for user ${userId}:`,
          (error as Error).message,
        );
      }
    }

    console.log(
      `[cleanupStaleDevices] Cleanup complete. Total devices removed: ${totalCleaned}`,
    );
  },
);

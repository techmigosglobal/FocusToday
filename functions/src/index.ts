import * as admin from "firebase-admin";
import {
  onDocumentWritten,
  onDocumentCreated,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";

// ─── Init ──────────────────────────────────────────────────────────────────
admin.initializeApp();
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

const db = admin.firestore();
const messaging = admin.messaging();

// ─── Helpers ───────────────────────────────────────────────────────────────

/** Get the FCM token stored on a user document */
async function getUserFcmToken(userId: string): Promise<string | null> {
  const doc = await db.collection("users").doc(userId).get();
  return doc.data()?.fcm_token ?? null;
}

/** Send a notification to a single user via their FCM token */
async function sendToUser(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  const token = await getUserFcmToken(userId);
  if (!token) return;
  await messaging.send({
    token,
    notification: { title, body },
    data,
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default", badge: 1 } } },
  });
}

/** Send to all users with a specific role (batches of 500) */
async function sendToRole(
  role: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  const snap = await db
    .collection("users")
    .where("role", "==", role)
    .where("fcm_token", "!=", null)
    .get();

  const tokens: string[] = snap.docs
    .map((d) => (d.data().fcm_token as string) ?? "")
    .filter(Boolean);

  await sendToTokensBatch(tokens, title, body, data);
}

/** Batch-send to a list of FCM tokens (500 per batch) */
async function sendToTokensBatch(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  for (let i = 0; i < tokens.length; i += 500) {
    const batch = tokens.slice(i, i + 500);
    await messaging.sendEachForMulticast({
      tokens: batch,
      notification: { title, body },
      data,
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
  }
}

/** Write an in-app notification document */
async function createNotification(
  userId: string,
  type: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  await db.collection("notifications").add({
    user_id: userId,
    type,
    title,
    body,
    data,
    read: false,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ─── GAP-001: Post Status Change ──────────────────────────────────────────
/**
 * Fires when a post document is updated.
 * Sends FCM + in-app notification to the author when status changes to
 * 'approved' or 'rejected'.
 */
export const onPostStatusChange = onDocumentWritten(
  "posts/{postId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) return;

    const prevStatus = before.status as string | undefined;
    const newStatus = after.status as string | undefined;

    // Only fire when status actually changes
    if (prevStatus === newStatus) return;
    if (!["approved", "rejected"].includes(newStatus ?? "")) return;

    const authorId = after.author_id as string | undefined;
    if (!authorId) return;

    const postTitle = (after.caption as string | undefined)?.slice(0, 60) ?? "Your post";

    if (newStatus === "approved") {
      const title = "Post Approved ✅";
      const body = `"${postTitle}" has been approved and is now live.`;
      await sendToUser(authorId, title, body, {
        type: "post_approved",
        post_id: event.params.postId,
      });
      await createNotification(authorId, "post_approved", title, body, {
        post_id: event.params.postId,
      });
    } else if (newStatus === "rejected") {
      const reason = (after.rejection_reason as string | undefined) ?? "See guidelines";
      const title = "Post Rejected ❌";
      const body = `"${postTitle}" was rejected. Reason: ${reason}`;
      await sendToUser(authorId, title, body, {
        type: "post_rejected",
        post_id: event.params.postId,
      });
      await createNotification(authorId, "post_rejected", title, body, {
        post_id: event.params.postId,
        reason,
      });
    }

    // Write audit log
    await db.collection("audit_logs").add({
      type: `post_${newStatus}`,
      actor_id: after.moderated_by ?? "system",
      target_id: event.params.postId,
      meta: { prev_status: prevStatus, new_status: newStatus },
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

// ─── GAP-001: Breaking News Broadcast ────────────────────────────────────
/**
 * Fires when a breaking_news document is created.
 * Broadcasts FCM to `breaking_news` topic and writes in-app notifications
 * for all users.
 */
export const onBreakingNewsCreated = onDocumentCreated(
  "breaking_news/{id}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const headline = (data.headline as string) ?? "Breaking News";
    const summary = (data.summary as string) ?? "";

    // Broadcast via topic (users must subscribe to 'breaking_news' topic on app side)
    await messaging.send({
      topic: "breaking_news",
      notification: { title: `🔴 BREAKING: ${headline}`, body: summary },
      data: {
        type: "breaking_news",
        news_id: event.params.id,
      },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
  }
);

// ─── GAP-001 / GAP-008: Emergency Alert (Geofenced) ──────────────────────
/**
 * Fires when an alert document is created.
 * If the alert has area/district/state targeting, only users in that
 * location receive the notification. Otherwise broadcast to all.
 */
export const onEmergencyAlertCreated = onDocumentCreated(
  "alerts/{alertId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const title = `🚨 ${(data.title as string) ?? "Emergency Alert"}`;
    const body = (data.description as string) ?? "";
    const alertData = {
      type: "emergency_alert",
      alert_id: event.params.alertId,
      severity: (data.severity as string) ?? "medium",
    };

    const targetArea = data.area as string | undefined;
    const targetDistrict = data.district as string | undefined;
    const targetState = data.state as string | undefined;

    let usersQuery: admin.firestore.Query = db
      .collection("users")
      .where("fcm_token", "!=", null);

    // Apply geo-filters if provided
    if (targetArea) {
      usersQuery = usersQuery.where("area", "==", targetArea);
    } else if (targetDistrict) {
      usersQuery = usersQuery.where("district", "==", targetDistrict);
    } else if (targetState) {
      usersQuery = usersQuery.where("state", "==", targetState);
    }

    const snap = await usersQuery.get();
    const tokens: string[] = snap.docs
      .map((d) => (d.data().fcm_token as string) ?? "")
      .filter(Boolean);

    await sendToTokensBatch(tokens, title, body, alertData);
  }
);

// ─── GAP-001: Publish Scheduled Posts ────────────────────────────────────
/**
 * Runs every 5 minutes. Publishes posts where scheduled_at <= now and
 * status == 'scheduled'.
 */
export const publishScheduledPosts = onSchedule(
  { schedule: "every 5 minutes", timeZone: "Asia/Kolkata" },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const snap = await db
      .collection("posts")
      .where("status", "==", "scheduled")
      .where("scheduled_at", "<=", now)
      .limit(50)
      .get();

    const batch = db.batch();
    snap.docs.forEach((doc) => {
      batch.update(doc.ref, {
        status: "approved",
        published_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    if (!snap.empty) {
      await batch.commit();
      console.log(`[ScheduledPosts] Published ${snap.size} post(s)`);
    }
  }
);

// ─── GAP-001: Meeting Reminders ───────────────────────────────────────────
/**
 * Runs every 60 minutes. Sends FCM reminders for meetings starting within
 * the next 24 hours that have not yet had a reminder sent.
 */
export const sendMeetingReminders = onSchedule(
  { schedule: "every 60 minutes", timeZone: "Asia/Kolkata" },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const in24h = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 24 * 60 * 60 * 1000)
    );

    const snap = await db
      .collection("meetings")
      .where("start_time", ">=", now)
      .where("start_time", "<=", in24h)
      .where("reminder_sent", "==", false)
      .limit(50)
      .get();

    for (const doc of snap.docs) {
      const meeting = doc.data();
      const title = "📅 Meeting Reminder";
      const body = `"${meeting.title}" starts in less than 24 hours.`;
      const data = { type: "meeting_reminder", meeting_id: doc.id };

      // Notify all reporters and admins
      for (const role of ["reporter", "admin", "superAdmin", "super_admin"]) {
        await sendToRole(role, title, body, data);
      }

      // Mark reminder as sent
      await doc.ref.update({ reminder_sent: true });
    }
  }
);

// ─── GAP-003: Reporter Application Status ────────────────────────────────
/**
 * Fires when a reporter_applications document is updated.
 * Notifies the applicant when their application is approved or rejected.
 */
export const onReporterApplicationStatus = onDocumentWritten(
  "reporter_applications/{appId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const prevStatus = before.status as string | undefined;
    const newStatus = after.status as string | undefined;
    if (prevStatus === newStatus) return;

    const applicantId = after.applicant_id as string | undefined;
    if (!applicantId) return;

    if (newStatus === "approved") {
      // Promote user role to reporter
      await db.collection("users").doc(applicantId).update({
        role: "reporter",
        role_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      const title = "🎉 Application Approved!";
      const body = "Congratulations! You are now a Reporter on Focus Today.";
      await sendToUser(applicantId, title, body, {
        type: "reporter_application_approved",
      });
      await createNotification(
        applicantId,
        "reporter_application_approved",
        title,
        body
      );
    } else if (newStatus === "rejected") {
      const reason =
        (after.rejection_reason as string | undefined) ?? "Does not meet criteria";
      const title = "Application Update";
      const body = `Your reporter application was not approved. Reason: ${reason}`;
      await sendToUser(applicantId, title, body, {
        type: "reporter_application_rejected",
      });
      await createNotification(
        applicantId,
        "reporter_application_rejected",
        title,
        body
      );
    }
  }
);

// ─── GAP-014: Admin FCM Message Campaign ────────────────────────────────
/**
 * HTTPS Callable function.
 * Allows super_admin and admin to send a targeted FCM campaign by role or topic.
 *
 * Request payload:
 * {
 *   title: string,
 *   body: string,
 *   targetType: 'all' | 'role' | 'topic',
 *   targetValue?: string,  // role name or topic name
 * }
 */
export const sendMessageCampaign = onCall(
  { enforceAppCheck: false },
  async (request) => {
    // Auth check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const callerUid = request.auth.uid;
    const callerDoc = await db.collection("users").doc(callerUid).get();
    const callerRole = callerDoc.data()?.role as string | undefined;

    if (!callerRole || !["superAdmin", "super_admin", "admin"].includes(callerRole)) {
      throw new HttpsError("permission-denied", "Only admins can send campaigns");
    }

    const { title, body, targetType, targetValue } = request.data as {
      title: string;
      body: string;
      targetType: "all" | "role" | "topic";
      targetValue?: string;
    };

    if (!title || !body) {
      throw new HttpsError("invalid-argument", "title and body are required");
    }

    const campaignData: Record<string, string> = {
      type: "campaign",
      sent_by: callerUid,
    };

    let recipientCount = 0;

    if (targetType === "topic" && targetValue) {
      await messaging.send({
        topic: targetValue,
        notification: { title, body },
        data: campaignData,
        android: { priority: "high" },
      });
      recipientCount = -1; // unknown for topic
    } else {
      let query: admin.firestore.Query = db
        .collection("users")
        .where("fcm_token", "!=", null);

      if (targetType === "role" && targetValue) {
        query = query.where("role", "==", targetValue);
      }

      const snap = await query.get();
      const tokens = snap.docs
        .map((d) => (d.data().fcm_token as string) ?? "")
        .filter(Boolean);

      await sendToTokensBatch(tokens, title, body, campaignData);
      recipientCount = tokens.length;
    }

    // Log campaign in Firestore
    await db.collection("fcm_campaigns").add({
      title,
      body,
      target_type: targetType,
      target_value: targetValue ?? "all",
      sent_by: callerUid,
      recipient_count: recipientCount,
      sent_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, recipientCount };
  }
);

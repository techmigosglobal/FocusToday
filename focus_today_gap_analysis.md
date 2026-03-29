# Focus Today App — Revised Gap Analysis & Improvement Plan

> **Revised on:** 2026-03-18 | **Stack:** Flutter + Firebase (Firestore/Storage/Functions) + Riverpod
> **Changes applied from user review — all comments incorporated below.**

---

## 1. App Overview

| Item | Detail |
|---|---|
| **App name** | Focus Today (formerly "CRII") |
| **Auth method** | Phone OTP only (no email login needed) |
| **Roles** | `superAdmin` → `admin` → `reporter` → `publicUser` |
| **Feature modules** | 16 (`auth`, `feed`, `create_post`, `profile`, `moderation`, `workspace`, `emergency`, `notifications`, `search`, `settings`, `departments`, `meetings`, `comments`, `legal`, `enrollment` — dead code) |
| **Content types** | image, video, pdf, article, story, poetry |
| **Localization** | English / Telugu / Hindi |

---

## 2. Feature × Role Matrix (Updated)

> ~~Reports list~~ **removed** — not required per user decision.

| Feature | superAdmin | admin | reporter | publicUser |
|---|---|---|---|---|
| View feed | ✅ | ✅ | ✅ | ✅ |
| Feed category tabs | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** |
| Hashtag navigation | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** |
| Saved bookmark collections | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** |
| Create post | ✅ | ✅ | ✅ | ❌ |
| Draft posts (before submit) | ❌ **GAP** | — | ❌ **GAP** | — |
| Approve/Reject posts | ✅ | ✅ | ❌ | ❌ |
| Bulk moderation actions | ❌ **GAP** | ❌ **GAP** | — | — |
| Content policy violation tag | ❌ **GAP** | ❌ **GAP** | — | — |
| Moderation screen (linked) | ❌ **GAP** | ❌ **GAP** | — | — |
| User management | ✅ | ✅ | ❌ | ❌ |
| Analytics (admin) | ✅ | ✅ | ❌ | ❌ |
| Analytics (reporter) | ✅ | ✅ | ✅ | ❌ |
| Emergency alerts (create) | ✅ | ✅ | ❌ | ❌ (view) |
| Emergency alert push (FCM) | ❌ **GAP** | ❌ **GAP** | — | — |
| Emergency geofencing | ❌ **GAP** | ❌ **GAP** | — | — |
| Breaking news (send) | ✅ | ✅ | ❌ | ❌ |
| FCM push on post approval | ❌ **GAP** | — | ❌ **GAP** | — |
| FCM message campaigns | ❌ **GAP** | ❌ **GAP** | — | — |
| Meetings management | ✅ | ✅ | ❌ | ❌ |
| Meeting detail screen | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** |
| Meeting RSVP / attendance | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** |
| Meeting reminder (FCM) | ❌ **GAP** | ❌ **GAP** | — | — |
| Storage limits | ✅ (config) | ✅ (view) | ❌ | ❌ |
| Search (basic) | ✅ | ✅ | ✅ | ✅ |
| Search advanced filters | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** |
| Hashtag search landing | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** |
| Departments | ✅ | ✅ | ✅ | ✅ |
| Bookmarks | ✅ | ✅ | ✅ | ✅ |
| Comments (flat) | ✅ | ✅ | ✅ | ✅ |
| Comment replies (nested) | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** | ❌ **GAP** |
| Moderation queue (linked) | ❌ **GAP** | ❌ **GAP** | — | — |
| Audit timeline (linked) | ❌ **GAP** | ❌ **GAP** | — | — |
| Edit profile | ✅ | ✅ | ✅ | ✅ |
| View OTHER user's profile | ✅ | ✅ | ❌ **RESTRICT** | ❌ **RESTRICT** |
| publicUser → reporter application | ❌ **GAP** | — | — | ❌ **GAP** |
| Role upgrade approval | ❌ **GAP** | ❌ **GAP** | — | — |

---

## 3. Gap Detail — What to Implement

### 🔴 GAP-001: Cloud Functions — Empty (CRITICAL)
**All FCM triggers are missing.** [functions/src/index.ts](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/functions/src/index.ts) is a skeleton.

**Must implement:**
- Post approved → FCM to reporter's device
- Post rejected → FCM to reporter's device (with rejection reason)
- Emergency alert created → broadcast to all users via FCM topic
- Breaking news created → broadcast via FCM topic
- Meeting reminder → scheduled trigger N minutes before meeting start
- Scheduled post publishing (use `publishedAt` field, scan every 5 min)
- **Message campaigns** — admin-triggered FCM broadcasts with custom title/body to all users or role-specific groups

```typescript
// Post status change → notify reporter
onDocumentUpdated("posts/{postId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status === after.status) return;
  const authorToken = await getReporterFCMToken(after.author_id);
  await sendFCM(authorToken, {
    title: after.status === "approved" ? "Post Approved ✅" : "Post Rejected ❌",
    body: after.status === "rejected" ? after.rejection_reason : after.caption?.substring(0, 60),
  });
});

// Emergency alert → all users broadcast
onDocumentCreated("emergency_alerts/{alertId}", async (event) => {
  await getMessaging().sendEachForMulticast({
    topic: "all_users",
    notification: { title: "⚠️ Emergency Alert", body: event.data.data().description },
  });
});

// Breaking news → broadcast
onDocumentCreated("breaking_news/{newsId}", async (event) => {
  await getMessaging().sendEachForMulticast({
    topic: "all_users",
    notification: { title: "🔴 Breaking News", body: event.data.data().title },
  });
});

// Scheduled content publishing
onSchedule("every 5 minutes", async () => {
  const now = Timestamp.now();
  const posts = await db.collection("posts")
    .where("status", "==", "scheduled")
    .where("published_at", "<=", now)
    .get();
  posts.forEach(doc => doc.ref.update({ status: "approved" }));
});
```

---

### 🔴 GAP-002: Moderation Screen — Not Linked
[moderation_screen.dart](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/lib/features/moderation/presentation/screens/moderation_screen.dart) (3-tab pending/approved/rejected) is **never navigated to** from [WorkspaceScreen](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/lib/features/workspace/presentation/screens/workspace_screen.dart#18-277) or [SettingsScreen](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/lib/features/settings/presentation/screens/settings_screen.dart#31-39).

**Fix:** Add a dedicated "Moderation Queue" tile in [WorkspaceScreen](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/lib/features/workspace/presentation/screens/workspace_screen.dart#18-277) under Management section (admin only). Also link [audit_timeline_screen.dart](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/lib/features/moderation/presentation/screens/audit_timeline_screen.dart) which has no confirmed entry point.

---

### 🔴 GAP-003: publicUser → Reporter Upgrade Flow
The `enrollment` folder is dead code. Public users have zero path to become a reporter.

**Implement:**
1. **"Apply as Reporter"** button in [ProfileScreen](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/lib/features/profile/presentation/screens/profile_screen.dart#20-29) (for `publicUser` only)
2. Application form screen (name, reason, sample writing)
3. Admin notification (FCM + Firestore document in `reporter_applications`)
4. Admin review screen to approve/reject applications
5. On approval → Cloud Function updates user role to `reporter`

---

### 🔴 GAP-004: Profile — Restrict Other User Viewing
**Rule:** Only `superAdmin` and `admin` can view another user's full profile. `reporter` and `publicUser` must NOT navigate to other profiles.

**Fix:**
- Add role guard in any navigation that passes `profileUser` param to [ProfileScreen](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/lib/features/profile/presentation/screens/profile_screen.dart#20-29)
- Remove/disable author name tap from feed cards for non-admin roles
- Hardcode: [ProfileScreen](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/lib/features/profile/presentation/screens/profile_screen.dart#20-29) with `profileUser != null` only accepts navigation if `currentUser.canModerate == true`
- **No follower/following model** — confirm and remove any reference to it entirely

---

### 🟡 GAP-005: Feed — Category Tabs & Hashtag Navigation
**Implement:**
- Horizontal scrollable category tab bar on [FeedScreen](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/lib/features/feed/presentation/screens/feed_screen.dart#38-46): **All | News | Articles | Stories | Poetry | Videos | PDF**
- Selecting a tab filters `_posts` list by `post.category` or `post.contentType`
- Each hashtag chip on a post card becomes tappable → opens `SearchScreen` pre-filled with `#hashtag`
- Add **trending hashtags section** on `SearchScreen`

---

### 🟡 GAP-006: Saved Bookmark Collections
**Implement:**
- `BookmarkCollection` model: `{id, userId, name, postIds[]}`
- **Collections bottom sheet** when bookmarking — "Add to collection" + "New collection"
- [ProfileScreen](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/lib/features/profile/presentation/screens/profile_screen.dart#20-29) Bookmarks tab shows collection folders before flat list

---

### 🟡 GAP-007: Search — Advanced Filters
**Implement in `SearchScreen`:**
- Filter drawer/bottom sheet with: **Date range**, **Category**, **Content type**, **Author name**
- **Hashtag search** — tapping `#tag` in any post opens search pre-filtered
- Order results by: Newest / Most Liked / Most Viewed
- (Phase 3): Algolia integration for full-text body search

---

### 🟡 GAP-008: Emergency Alerts — Geofencing
**Implement:**
- `EmergencyAlert` model gains `targetArea`, `targetDistrict`, `targetState` fields
- **Admin create alert screen** adds location scope selector
- Cloud Function filters FCM recipients by matching their profile `area`/`district`/`state`
- Feed only shows alerts relevant to the current user's location

---

### 🟡 GAP-009: Notifications — In-App Categories + Bulk Actions
**Implement:**
- `NotificationsScreen` adds tab bar: **All | Posts | Emergency | Meetings | System**
- "Mark all as read" button
- Notification badge auto-clears visually on open
- FCM payload carries `notification_type` field used for routing and filtering

---

### 🟡 GAP-010: Meetings — Detail Screen + RSVP + Calendar
**Implement:**
- `MeetingDetailScreen` — title, description, date/time, location, attendee list
- RSVP buttons: **Going / Not Going / Maybe**
- `MeetingCalendarScreen` — monthly calendar view with meeting dots
- Cloud Function: scheduled reminder 30 min before meeting → FCM to all attendees

---

### 🟠 GAP-011: Moderation — Bulk Actions + Violation Tags
**Implement:**
- Long-press on post card → enter selection mode
- **Select All / Approve Selected / Reject Selected** action bar
- Rejection dialog gains **violation category picker**: Misinformation, Offensive Content, Copyright, Spam, Other
- Violation category stored in `rejectionReason` or a new `violationType` field

---

### 🟠 GAP-012: Comment Nested Replies
**Implement:**
- [Comment](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/lib/features/feed/presentation/screens/feed_screen.dart#862-870) model gains `parentId` field
- `CommentsBottomSheet` shows replies indented under parent
- "Reply" tap on a comment pre-fills text field with `@authorName`

---

### 🟠 GAP-013: Reporter Draft Posts
**Implement:**
- "Save Draft" button in `CreatePostScreen`
- Stored locally via `CacheService` (SQLite)
- "My Drafts" tile in reporter WorkspaceScreen
- Drafts screen lists unsent posts with "Continue editing" and "Delete" actions

---

### 🟠 GAP-014: FCM Message Campaigns (Admin)
**Implement in WorkspaceScreen (admin/superAdmin):**
- "Send Campaign" tile → Campaign compose screen
- Fields: Title, Body, Target (All / Reporters / Area), Schedule (Now / Later)
- Stored in Firestore `campaigns` collection
- Cloud Function reads campaign doc and sends FCM multicast

---

## 4. Items Removed / Confirmed Out of Scope

| Item | Decision |
|---|---|
| Reports list screen | ❌ **Removed** — not required |
| Email/password login | ❌ **Not needed** — Phone OTP only |
| Follower / following model | ❌ **Removed** — not required |
| Other user profile (reporter/publicUser) | ❌ **Restricted** — only admins can view |
| Reporter profile viewing another reporter | ❌ **Not allowed** |
| Audio content type | 🔜 Deferred to later |
| Subscription / paywall | 🔜 Deferred to later |

---

## 5. Prioritized Roadmap

### 🚀 Phase 1 — Critical Infrastructure

| # | Task | Effort |
|---|---|---|
| P1-1 | Cloud Functions: post approval/rejection FCM, emergency broadcast, breaking news push | 🔴 High |
| P1-2 | Cloud Functions: meeting reminder, scheduled post publishing | 🔴 High |
| P1-3 | Cloud Functions: FCM message campaigns for admins | 🟡 Medium |
| P1-4 | Link [ModerationScreen](file:///home/vinay/Downloads/CRII_Flutter_With_Backend_Firebase/lib/features/moderation/presentation/screens/moderation_screen.dart#16-24) + `AuditTimelineScreen` from WorkspaceScreen | 🟢 Low |
| P1-5 | Restrict other-user profile access to admin/superAdmin only | 🟢 Low |

### ⚡ Phase 2 — Feature Completion

| # | Task | Effort |
|---|---|---|
| P2-1 | Feed category tabs (News / Stories / Articles / Poetry / All) | 🟡 Medium |
| P2-2 | Hashtag → tap → search navigation | 🟢 Low |
| P2-3 | publicUser → reporter application flow (apply + admin review) | 🟡 Medium |
| P2-4 | Meeting detail screen + RSVP + calendar view | 🟡 Medium |
| P2-5 | Notification in-app categories + bulk mark read | 🟢 Low |
| P2-6 | Search advanced filters (date, category, content type) | 🟡 Medium |
| P2-7 | Bulk moderation (select + approve/reject) + violation tags | 🟡 Medium |
| P2-8 | Emergency geofencing (target by area/district) | 🔴 High |

### 🔧 Phase 3 — Polish

| # | Task | Effort |
|---|---|---|
| P3-1 | Saved bookmark collections (folders) | 🟡 Medium |
| P3-2 | Reporter draft posts (local save) | 🟡 Medium |
| P3-3 | Nested comment replies | 🟡 Medium |
| P3-4 | SuperAdmin dashboard (KPI cards) | 🟡 Medium |
| P3-5 | GoRouter named routes (deep link stability) | 🔴 High |
| P3-6 | Firestore offline persistence | 🟢 Low |
| P3-7 | `package_info_plus` for dynamic version display | 🟢 Low |
| P3-8 | Remove dead `enrollment` folder | 🟢 Low |

---

## 6. Updated Scorecard

| Category | Score | Notes |
|---|---|---|
| Auth & Onboarding | 8/10 | Phone OTP solid; no email needed |
| Content Feed | 6/10 | Flip works; missing category tabs & hashtag nav |
| Content Creation | 6/10 | 6 types; no draft mode for reporters |
| Moderation Workflow | 5/10 | UI exists but unreachable; bulk actions missing |
| User Roles & Permissions | 5/10 | publicUser upgrade path gone; profile restriction needed |
| Push Notifications (FCM) | 2/10 | FCM initialized; zero Cloud Function triggers deployed |
| Search & Discovery | 4/10 | Basic prefix search; no filters, no hashtag nav |
| Meetings | 4/10 | Management screen only; no detail/RSVP/calendar/reminder |
| Offline Support | 5/10 | Banner + queue; Firestore persistence not enabled |
| Backend (Cloud Functions) | 2/10 | Index.ts nearly empty — highest priority |
| Profile | 7/10 | 4-tab works; profile access restriction needed |
| Settings | 8/10 | Well structured; version hardcoded |
| Emergency / Alerts | 6/10 | UI complete; no push trigger; no geofencing |
| Comments | 5/10 | Flat only; no nested replies |

**Overall App Maturity: ~5.5/10** — Strong UI foundation but critical backend and workflow gaps must be resolved for production readiness.

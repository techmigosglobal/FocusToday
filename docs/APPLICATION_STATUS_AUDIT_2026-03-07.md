# Application Status Audit (2026-03-07)

## Executive Summary

The application is feature-rich and the Flutter app is already wired to Firebase for most day-to-day operations, but the Firebase backend is **not finished from a production-readiness perspective**.

Short version:

- The app now runs primarily on **Firestore + Firebase Storage + Firebase Messaging + anonymous Firebase Auth + MSG91 OTP**.
- Core content flows are implemented: posts, moderation, likes, bookmarks, shares, comments, profile updates, notifications, emergency alerts.
- The codebase also contains a **Firebase Functions workspace** and a **legacy NestJS backend**. Both build successfully, but the Flutter app is not currently calling the Firebase callable functions.
- The largest blockers are **security/authorization**, **incomplete Firestore rules coverage**, and **billing/plan assumptions for Storage/Functions**.

## Verification Performed

Commands run locally on this branch:

- `flutter analyze` -> passed, no issues found
- `flutter test` -> passed, 69 tests
- `npm --prefix firebase_backend/functions run build` -> passed
- `npm --prefix backend_nestjs run build` -> passed

## 1. Is the Firebase Backend Implementation Finished?

## Verdict

**No. It is partially implemented and functionally usable for some flows, but not complete or safe enough to treat as "finished".**

## What is already implemented in code

Evidence:

- Firebase app initialization and anonymous sign-in are active in `lib/main.dart:132-144`.
- Firestore collections are the app's primary data layer in `lib/core/services/firestore_service.dart:7-63`.
- Posts are created/read/updated/deleted directly in Firestore in `lib/features/feed/data/repositories/post_repository.dart:15-420`.
- Comments are stored in Firestore in `lib/features/comments/data/repositories/comment_repository.dart:7-97`.
- Profile images and post media upload to Firebase Storage in:
  - `lib/features/feed/data/repositories/post_repository.dart:225-255`
  - `lib/features/profile/data/repositories/profile_repository.dart`
- Notifications are read from Firestore in `lib/features/notifications/data/repositories/notification_repository.dart`.
- A Firebase Functions backend exists and compiles in `firebase_backend/functions/src/index.ts:29-195`.

## Why it is still not finished

### 1. The app does not use the Firebase callable functions

The Firebase Functions workspace exists, but there are no `FirebaseFunctions`, `HttpsCallable`, or `cloud_functions` usages under `lib/`.

Implication:

- Sensitive operations are happening from the client directly against Firestore instead of going through a hardened server layer.
- The functions backend is currently more of a scaffold than the active backend.

### 2. Authentication is not properly bound to real Firebase user identity

Current runtime behavior:

- App startup signs in anonymously if no Firebase user exists: `lib/main.dart:137-139`
- OTP is handled by MSG91, not Firebase phone auth
- Session state is then persisted locally and mirrored into Firestore by `AuthRepository`

Critical implementation details:

- `AuthRepository.verifyAndSaveSession()` looks up a user by phone number, but still assigns the session to the current anonymous Firebase UID instead of reusing the existing Firestore user document id: `lib/features/auth/data/repositories/auth_repository.dart:103-149`
- `AuthRepository._currentOrAnonymousUid()` always uses the anonymous Firebase account unless none exists: `lib/features/auth/data/repositories/auth_repository.dart:263-268`

Impact:

- Cross-device identity is not reliable
- Duplicate user records are possible
- Phone verification is not actually establishing a secure Firebase-authenticated phone identity

### 3. Role assignment is not secure

New users can self-select privileged roles from the UI:

- `UserRole.admin` is a normal signup option in `lib/features/auth/presentation/screens/role_selection_screen.dart:32-72`
- The selected role is written directly into the Firestore user document in `lib/features/auth/data/repositories/auth_repository.dart:245-259`

The rules then trust the role stored in that user document:

- `firebase_backend/firestore/firestore.rules:16-31`

Impact:

- A fresh anonymous user can create/update their own user document
- That same document controls `isAdminOrAbove()`
- This is a privilege-escalation vulnerability

### 4. Firestore rules cover only part of the collections the app uses

App uses these collections/documents:

- `users`, `posts`, `alerts`, `breaking_news`, `notifications`, `reports`, `meetings`, `donations`, `partners`, `system/*`, `audit_logs`, `users/{uid}/meeting_seen`

Defined in:

- `lib/core/services/firestore_service.dart:9-63`

But checked-in rules only define access for:

- `users`
- `users/{uid}/bookmarks`
- `posts`
- `posts/{postId}/comments`
- `posts/{postId}/interactions`
- `notifications`
- `alerts`
- `breaking_news`

Defined in:

- `firebase_backend/firestore/firestore.rules:28-69`

Missing rule coverage for:

- `reports`
- `meetings`
- `meetings/*/interests`
- `donations`
- `partners`
- `system/donation_config`
- `system/storage_config`
- `audit_logs`
- `users/{uid}/meeting_seen`

Impact:

- If the checked-in rules are what is deployed, these features will fail with permission errors even though the Flutter UI/repositories exist.

### 5. Firebase index coverage is incomplete for the current query set

The index file contains only 5 composite indexes:

- posts by status/published_at
- posts by author_id/created_at
- alerts
- breaking_news
- notifications unread query

File:

- `firebase_backend/firestore/firestore.indexes.json`

But current code uses more complex queries, for example:

- posts by `author_id + status + created_at`
- rejected posts by `author_id + status + updated_at`
- reports by `report_type + status + created_at`
- donations by `status + created_at`
- meetings by `status + meeting_date`

These likely need additional composite indexes for production.

## Bottom line

Feature migration is far along.

Production backend hardening is not.

I would describe the current status as:

- **Feature migration to Firebase:** mostly done
- **Production-grade backend/security:** not done

## 2. Role-Based Features and Functionalities

## Public User

Visible capabilities:

- Feed browsing and post detail
- Search screen in bottom navigation
- Like, bookmark, share, comment on posts
- Notifications
- Profile and profile editing
- Become partner
- Donation/support flow
- Emergency alerts
- Activity reports viewing
- Department linkages
- Meetings interest toggling through public meetings UI

Evidence:

- Bottom nav for non-moderators: `lib/shared/widgets/main_navigation_shell.dart:124-167`
- Public settings workspace: `lib/features/settings/presentation/screens/settings_screen.dart:398-460`
- Comments backend: `lib/features/comments/data/repositories/comment_repository.dart:7-97`

Notes:

- Public users currently have full feed access because `Post.isAccessibleFor()` always returns `true` in `lib/shared/models/post.dart`.

## Reporter

Reporter gets everything a public user gets, plus:

- Create post
- Submitted posts go through moderation flow
- Rejected posts list
- Edit and resubmit rejected posts
- Personal analytics

Evidence:

- Reporter workspace: `lib/features/settings/presentation/screens/settings_screen.dart:295-395`
- Reporter posts are created with pending/approved status decided by role in `lib/features/feed/presentation/screens/create_post_screen.dart`
- Resubmission flow: `lib/features/feed/presentation/screens/rejected_posts_screen.dart` and `lib/features/feed/presentation/screens/edit_resubmit_screen.dart`

## Admin

Admin gets moderator capabilities:

- All posts queue
- Approve/reject posts
- Edit/delete posts
- User management
- Analytics dashboard
- Emergency alerts
- Meetings management
- Reports workspace
- Storage limits screen (view-level admin access, edit only for super admin)

Evidence:

- Admin workspace: `lib/features/settings/presentation/screens/settings_screen.dart:198-292`
- Admin navigation swaps Search for All Posts queue: `lib/shared/widgets/main_navigation_shell.dart:124-167`
- Moderation logic exists in `lib/features/feed/presentation/screens/all_posts_screen.dart` and `lib/features/moderation/presentation/screens/moderation_screen.dart`

## Super Admin

Super admin effectively gets admin features plus elevated admin actions:

- Can edit storage configuration
- Can assign admin role in user management
- Can delete broader user types than admin

Evidence:

- Storage edit guard: `lib/features/moderation/presentation/screens/storage_limits_screen.dart:35-39`
- User management differentiates admin vs super admin in `lib/features/moderation/presentation/screens/user_management_screen.dart`

Note:

- There is no normal onboarding path for super admin in the visible auth UI. This role appears to require seeding/manual assignment.

## 3. Firebase No-Charge Limits Before Billing Starts

These limits are based on the current official Firebase and Google Cloud pricing docs as of **March 7, 2026**.

Important project-specific note first:

- This repo is configured to use the default Storage bucket `egaletv-57c7a.firebasestorage.app` in `lib/firebase_options.dart:25-39`.
- Firebase's Storage change notice says default `*.firebasestorage.app` buckets require the **Blaze** plan going forward; the key deadline called out in the official FAQ is **February 2, 2026**.

So for this project as currently configured:

- **Cloud Storage for Firebase:** treat Blaze as required
- **Cloud Functions for Firebase:** also effectively Blaze-only

That does **not** automatically mean you will be billed. It means billing is enabled, and charges start only if you exceed the relevant free usage where applicable.

## Firestore

On the Firebase pricing page, Cloud Firestore free usage on the Spark plan is listed as:

- 1 GiB stored
- 50K reads/day
- 20K writes/day
- 20K deletes/day
- 10 GiB/month outbound data transfer

Practical meaning for this app:

- Small to moderate MVP usage can remain free if reads/writes stay inside those limits.
- Feed-heavy apps usually hit **reads** first.

## Cloud Functions for Firebase

Cloud Functions requires Blaze for real use. Firebase's pricing page lists no-charge usage on Blaze up to:

- 2M invocations/month
- 400K GB-seconds/month
- 200K CPU-seconds/month
- 5 GB/month outbound networking

Practical meaning:

- You can be on Blaze and still pay $0 at low volume.
- Once you add scheduled functions, fan-out notifications, image/video processing, or moderation pipelines, cost risk increases.

## Cloud Storage for Firebase

For current default buckets, Firebase's Storage FAQ says Blaze is required.

The relevant Google Cloud Storage always-free usage (only in eligible regions) is:

- 5 GB-month storage
- 100 GB/month data transfer out from North America to all region destinations, excluding China and Australia
- 5,000 Class A operations/month
- 50,000 Class B operations/month

Important caveats:

- Always Free is region-dependent
- If your bucket region is not eligible, charges can begin earlier
- Media-heavy apps usually hit **storage size** and **download egress** first

## Authentication

Firebase pricing currently lists "Other Authentication services" as no-cost up to **50K MAUs**.

But:

- **Phone Auth** is billed per SMS sent in many cases
- This app currently uses **MSG91 OTP**, not Firebase Phone Auth

So your real OTP cost exposure is currently **MSG91**, not Firebase Auth SMS.

## Firebase Cloud Messaging

Firebase Cloud Messaging is listed as **no-cost**.

## Best billing interpretation for this project

If you keep the current architecture:

- Firestore can stay free for a while on Spark-scale usage
- Storage and Functions should be treated as **Blaze-required services**
- You may still owe **$0** on Blaze if usage stays inside free allowances
- Once media uploads/downloads grow, **Storage** is the most likely first billing trigger

## Official Sources

- Firebase pricing: https://firebase.google.com/pricing
- Firestore quotas/pricing docs: https://firebase.google.com/docs/firestore/quotas
- Functions quotas docs: https://firebase.google.com/docs/functions/quotas
- Storage changes FAQ: https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024
- Google Cloud Storage pricing / always free: https://cloud.google.com/storage/pricing

## 4. Pending Work, Issues, Gaps, Incompleteness

## Critical

### 1. Role escalation vulnerability

- Any new user can pick `Admin` in the UI: `lib/features/auth/presentation/screens/role_selection_screen.dart:32-72`
- That role is written directly to the user's Firestore document: `lib/features/auth/data/repositories/auth_repository.dart:245-259`
- Rules trust that document for admin authorization: `firebase_backend/firestore/firestore.rules:16-31`

This must be fixed before production.

### 2. Incomplete Firestore rules

Collections used by the app are broader than the rule set.

Likely broken areas if current rules are deployed:

- donations
- partner enrollment
- meetings and meeting interest
- meeting popup "seen" state
- activity reports
- storage config
- audit timeline

### 3. Identity model is not trustworthy

- Anonymous Firebase UID is being used as the effective account id
- OTP success does not create/link a real Firebase-authenticated phone account
- Existing phone users can end up on a new anonymous UID

## High

### 4. Firebase Functions are scaffolded but not actually integrated

The functions backend currently contains only:

- verify/provision user
- create post
- moderate post
- toggle interaction
- create comment

File:

- `firebase_backend/functions/src/index.ts:29-195`

But the app does not call them.

### 5. Email login is mock and not exposed

- Login selection screen is OTP-only: `lib/features/auth/presentation/screens/login_method_selection_screen.dart:8-117`
- Email login screen exists, but it is a mock role-assignment flow based on email text patterns: `lib/features/auth/presentation/screens/email_login_screen.dart:74-107`

### 6. Storage limits screen is not real Firebase billing enforcement

The screen is an internal dashboard/config UI using rough estimated GB math:

- `lib/features/moderation/presentation/screens/storage_limits_screen.dart:135-151`

It should not be treated as real Firebase usage or billing data.

## Medium

### 7. Some UX flows are still placeholders

- Bookmark tile tap says "Post detail coming soon": `lib/features/profile/presentation/widgets/bookmarks_grid_view.dart:71-80`
- Article reader share says "Share feature coming soon": `lib/features/feed/presentation/screens/article_reader_screen.dart:151-160`
- Privacy policy button is a no-op in login: `lib/features/auth/presentation/screens/login_method_selection_screen.dart:135-146`

### 8. Offline interaction sync is currently a compatibility no-op

- `lib/core/services/post_interaction_sync_service.dart`

So the offline-first story is weaker than the app branding suggests.

### 9. Scalability gaps remain

Examples:

- search/discovery is still largely client-filtered
- analytics screens aggregate by fetching large sets into the client
- user management pagination is client-sliced after over-fetching
- several missing indexes are likely to surface once data grows

## 5. Suggested Implementation Order

Recommended next sequence:

1. Lock down auth and roles first.
   - Remove admin self-selection from public signup
   - Move privileged role assignment to super admin only
   - Replace anonymous-auth identity with real Firebase Auth identity binding

2. Fix Firestore rules and indexes.
   - Add rules for every collection currently used
   - Add composite indexes for live query patterns

3. Decide the backend authority model.
   - Either fully commit to direct Firestore with strong rules
   - Or move sensitive writes to Cloud Functions and keep the client thinner

4. Fix billing-sensitive infrastructure.
   - Confirm bucket region
   - Move to Blaze knowingly
   - Add actual usage monitoring instead of estimated "storage limits"

5. Finish dormant/placeholder features.
   - Real email auth or remove it
   - Bookmark-to-detail navigation
   - Article share
   - Privacy policy link

## Final Assessment

If the question is "does the app have a lot implemented?" -> **yes**

If the question is "is the Firebase backend finished and ready for production billing-enabled launch?" -> **no**

The next implementation phase should focus on **security, authorization, rules, indexes, and identity integrity** before adding more features.

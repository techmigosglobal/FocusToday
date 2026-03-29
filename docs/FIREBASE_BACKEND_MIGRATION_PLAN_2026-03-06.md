# Firebase Backend Migration Plan (March 6, 2026)

## Goal
Replace cPanel/NestJS backend dependencies with Firebase-native architecture (Firestore + Cloud Functions + Storage + FCM), while preserving existing role workflows and avoiding performance regressions as usage scales.

## Target Architecture
- Auth: Firebase Auth (phone/email/custom token), App Check enabled.
- Database: Firestore with role-aware security rules.
- Media: Firebase Storage with deterministic paths (`users/{uid}/...`, `posts/{postId}/...`).
- Server Logic: Cloud Functions (callable + event-driven) for moderation, counters, analytics rollups, and notifications.
- Notifications: FCM topic + per-user notifications collection.
- Analytics: Aggregated counters in denormalized docs + optional BigQuery export for advanced BI.

## Data Model (Primary Collections)
- `users/{uid}`: profile, role, moderation flags, FCM token.
- `posts/{postId}`: content, status, engagement counters, moderation metadata.
- `posts/{postId}/comments/{commentId}`.
- `posts/{postId}/interactions/{uid}` for like/bookmark/impression state.
- `users/{uid}/bookmarks/{postId}`.
- `notifications/{notificationId}`.
- `alerts/{alertId}` and `breaking_news/{newsId}`.
- `reports/{reportId}` for content abuse reporting.

## Migration Phases
1. Foundation: Firestore rules/indexes, Cloud Functions skeleton, shared Firestore service in Flutter.
2. Content Core: Migrate posts/comments/interactions/bookmarks to Firestore + callable functions.
3. Role Modules: Migrate moderation/users/reports/analytics/meetings.
4. Realtime UX: Replace poll-based APIs with stream listeners and paginated cursors.
5. Decommission: Remove `ApiService` and old cPanel deployment scripts/docs from active pipeline.

## Performance Guardrails
- Use query pagination (`limit` + cursor), avoid full collection scans.
- Move all counter mutations to transactions/functions.
- Precompute hot metrics (trending, pending counts, reporter analytics) in materialized docs.
- Keep feed payload lightweight; lazy-load heavy media metadata.
- Add image/video caching policy and upload size limits by role.
- Configure composite indexes early for production query patterns.

## Immediate Work Completed In This Commit
- Added Firebase dependencies: `cloud_firestore`, `firebase_storage`, `cloud_functions`.
- Added Firestore shared service (`lib/core/services/firestore_service.dart`).
- Migrated comments repository to Firestore.
- Migrated feed alert/breaking-news reads to Firestore.
- Migrated FCM token sync from REST patch to Firestore user doc updates.
- Created `firebase_backend/` with Cloud Functions, Firestore rules, indexes.
- Removed runtime cPanel API service from Flutter app and migrated all `ApiService` call sites to Firebase-backed repositories/screens.
- Added Firestore-backed audit timeline and audit log events for moderation/admin operations.
- Verified Flutter static analysis and tests after migration.

## Remaining High-Priority Migrations
- `PostRepository` full migration from REST to Firestore/Functions.
- `NotificationRepository` migration to Firestore queries.
- `AuthRepository` migration from backend OTP verification to Firebase-authenticated flow.
- `UserRepository`, `ReportRepository`, `MeetingRepository`, `DonationRepository` migration.
- Remove old cPanel scripts from CI/CD release path.

## Deployment Status (March 6, 2026)
- `firestore.rules` and `firestore.indexes.json` deployed successfully to project `eagle-tv-crii`.
- Full `functions` deployment failed because the project must be upgraded to Blaze plan before enabling `cloudbuild.googleapis.com` and `artifactregistry.googleapis.com`.

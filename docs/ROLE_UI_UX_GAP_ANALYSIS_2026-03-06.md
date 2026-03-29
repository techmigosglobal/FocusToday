# Role Workflow and UI/UX Gap Analysis (March 6, 2026)

## Implementation Status (Updated March 6, 2026)
- Completed:
  - Firestore-backed moderation, reports, alerts, enrollment, notifications, and analytics data paths.
  - Audit timeline module added for SuperAdmin/Admin visibility.
  - Reporter analytics moved to Firestore-derived stats (approved/pending/rejected + engagement).
  - Breaking-news and emergency flows moved to Firestore with audit log events.
- Remaining non-blocking enhancements:
  - Advanced trust badges/provenance UI polish on all post cards.
  - SLA countdown widgets per pending/rejected post card.

## SuperAdmin
- Gaps:
  - No explicit global policy UI (storage quota, role policy, moderation SLA thresholds).
  - Limited audit trail visibility (who approved/rejected what and when).
- Improvements:
  - Add policy console screen with immutable audit log timeline.
  - Add emergency override actions with confirmation + reason capture.

## Admin
- Gaps:
  - Pending moderation load may scale poorly without queue prioritization.
  - Analytics and storage views still depend on API-driven endpoints.
- Improvements:
  - Moderation queue sorting by risk/recency/reporter reliability score.
  - Firestore-driven admin dashboard cards with cached rollups.

## Reporter
- Gaps:
  - Weak feedback loop on rejection reasons and edit guidance.
  - No explicit publishing SLA visibility.
- Improvements:
  - Structured rejection taxonomy and auto-suggest fixes on resubmit.
  - Reporter status center: pending age, average approval time, quality score.

## Public User
- Gaps:
  - Trust signals for news quality are minimal.
  - Explore/search personalization is still basic.
- Improvements:
  - Source trust badge, report outcome status, and post provenance.
  - Relevance tuning using language/region and interaction history.

## Cross-Role UX Gaps
- Alerts and breaking-news should be real-time streams, not periodic polling.
- Offline and retry states are inconsistent across modules.
- Empty/error states are not standardized for all role-specific screens.

## UI/UX Missing Elements to Implement
- Unified skeleton/loading states for all list screens.
- Role-aware tooltips and first-run walkthrough.
- Accessibility pass: larger tap targets, semantic labels, contrast checks.
- Performance pass: prefetch windows for media, incremental list render, on-demand heavy widgets.

## Workflow Risks To Resolve
- Counter integrity if client writes engagement metrics directly.
- Race conditions in moderation without transactional updates.
- Search latency when scaling if query strategy remains client-heavy.

## Recommended Next Implementation Batch
1. Complete `PostRepository` migration to Firestore + callable interaction functions.
2. Migrate moderation modules (users/reports/analytics) to role-secure Firestore queries.
3. Replace notification repository with Firestore stream + unread-count aggregate doc.
4. Add audit log collection + admin/superadmin timeline UI.

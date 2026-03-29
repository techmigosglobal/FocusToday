# Active Backend Map (Firebase-First)

## Active Deploy Targets

- Firebase project: `crii-focus-today`
- Firebase config root: [`firebase.json`](/Users/kgt/Desktop/CRII_Flutter_With_Backend_Firebase_18_March/CRII_Flutter_With_Backend_Firebase/firebase.json)
- Active Cloud Functions source: `firebase_backend/functions`
- Active Firestore rules/indexes:
  - `firebase_backend/firestore/firestore.rules`
  - `firebase_backend/firestore/firestore.indexes.json`
- Active Storage rules:
  - `firebase_backend/storage/storage.rules`

## Legacy / Non-Deploy Workspaces

- `functions/` is present in repo but **not used by current deploy config**.
- Treat `functions/` as legacy/reference unless `firebase.json` is intentionally changed.
- Legacy project `eagle-tv-crii` is retired from active deploy workflow.

## Reliability Notes

- Region is standardized to `asia-south1` for callable and trigger functions.
- Meeting images are stored in Firebase Storage under:
  - `meetings/{userId}/{fileName}`
- Meeting counters in Firestore are authoritative fields:
  - `interest_count`
  - `not_interested_count`

## Quick Verification Commands

```bash
firebase use
firebase functions:list --project crii-focus-today
npm --prefix firebase_backend/functions run build
firebase deploy --project crii-focus-today --only functions,firestore:rules,firestore:indexes,storage
```

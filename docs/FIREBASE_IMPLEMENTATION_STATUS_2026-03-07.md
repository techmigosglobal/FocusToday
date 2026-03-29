# Firebase Implementation Status - 2026-03-07

## Implemented

- Removed anonymous Firebase sign-in from app startup.
- Removed client-side dev-role, email-login, and role-selection auth flows.
- Kept authentication on Msg91 OTP only.
- Added Firebase callable auth exchange:
  - Msg91 access token is verified server-side in Cloud Functions.
  - Function provisions or resolves the Firestore user by phone number.
  - Function returns a Firebase custom token.
  - Flutter signs in with `FirebaseAuth.signInWithCustomToken(...)`.
- Moved role resolution to the backend:
  - Existing user documents are resolved by `phone_normalized`.
  - Bootstrap role mapping can be provided by function env vars.
  - Client no longer chooses its own role.
- Hardened Firestore rules:
  - Owners can no longer edit their own role or phone number.
  - Missing collections used by the app are now covered.
  - Post creation is restricted to reporter/admin/super-admin roles.
- Expanded Firestore indexes for live query patterns.
- Extended local caching and reduced repeated reads for:
  - users
  - profile stats
  - notifications
  - search users
  - meetings
  - donations
  - bookmarks
  - feed interaction hydration

## Deployment Status On 2026-03-07

Completed against Firebase project `eagle-tv-crii`:

- Firestore rules deployed from `firebase_backend/firestore/firestore.rules`
- Firestore indexes deployed from `firebase_backend/firestore/firestore.indexes.json`
- Cloud Functions deployed in `us-central1`
- Artifact Registry cleanup policy set to delete old function images after 30 days

Deployed callable functions:

- `verifyMsg91OtpAndExchangeToken`
- `createPost`
- `moderatePost`
- `togglePostInteraction`
- `createComment`

Functions environment was loaded from `firebase_backend/functions/.env.eagle-tv-crii` during deployment.

Still pending:

- Firebase Storage bucket initialization in the Firebase console
- Storage rules deployment after the bucket is created

Console step still required:

1. Open `https://console.firebase.google.com/project/eagle-tv-crii/storage`
2. Click `Get Started`
3. After that, run `firebase deploy --project eagle-tv-crii --only storage`

## Project Alignment On 2026-03-07

- Flutter app config was regenerated with FlutterFire for Firebase project `eagle-tv-crii`
- New Android app id: `1:645914739063:android:9b6413ee47e467ea1c6172`
- New iOS app id: `1:645914739063:ios:dfbce02aaa6d48b91c6172`
- Root Firebase CLI config now points to:
  - `firebase_backend/functions`
  - `firebase_backend/firestore/firestore.rules`
  - `firebase_backend/firestore/firestore.indexes.json`
- Storage rules were added at `firebase_backend/storage/storage.rules`
- A project-scoped functions env file was added at `firebase_backend/functions/.env.eagle-tv-crii`
- Demo bootstrap role mapping was seeded for first-run testing:
  - super admin: `9876543000`
  - admin: `9876543111`
  - reporter: `9876543222`

## Remaining Notes

- The legacy `backend_nestjs/` directory is no longer part of the active app path. Runtime auth/data flow is now Firebase-only.
- Old historical docs about cPanel/NestJS still exist in `docs/`; they can be pruned separately if you want a strict Firebase-only repository cleanup pass.
- `firebase deploy --only storage` currently fails with `Firebase Storage has not been set up on project 'eagle-tv-crii'`.

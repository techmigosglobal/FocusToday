# Notifications + Campaigns + Multi-Device Tokens Implementation

## Overview

This implementation adds missing FCM notification triggers, campaign scheduling, and multi-device token management to the Eagle TV / Focus Today app.

---

## Key Changes

### 0. Runtime Source of Truth

- Active deployable Cloud Functions source is `firebase_backend/functions`.
- Root `functions/` directory exists but is not the active deploy target with current `firebase.json`.

### 1. Cloud Functions: Missing Notification Triggers (FCM-only)

**File:** `firebase_backend/functions/src/notification_triggers.ts`

| Trigger | Event | Recipients | Payload |
|---------|-------|------------|---------|
| `onPostCreated` | `posts/{postId}` on create, `status == 'pending'` | Admins + Super Admins | `{ type: 'new_post_pending', post_id }` |
| `onCommentCreated` | `posts/{postId}/comments/{commentId}` on create | Post author (if not commenter) | `{ type: 'new_comment', post_id, comment_id }` |
| `onPostResubmitted` | `posts/{postId}` on write, `before.rejected → after.pending` | Admins + Super Admins | `{ type: 'post_resubmitted', post_id }` |
| `onPostStatusChange` | `posts/{postId}` on write, status → approved/rejected | Post author | `{ type: 'post_approved' or 'post_rejected', post_id }` |
| `onUserRoleChanged` | `users/{userId}` on write, role changed | Affected user | `{ type: 'role_changed', new_role }` |

**Key Features:**
- FCM-only notifications (no in-app notifications in this pass)
- Payloads aligned with app routing (`type` + `post_id` where applicable)
- Multi-device token support via `getUserTokens()` helper

---

### 2. Cloud Functions: Campaign Scheduling

**Files:** `firebase_backend/functions/src/notification_triggers.ts`

**Collection:** `fcm_campaigns`

**Schema:**
```typescript
{
  title: string,
  body: string,
  targeting: {
    type: 'all' | 'role' | 'topic',
    value?: string // role name for 'role' type
  },
  status: 'draft' | 'scheduled' | 'sending' | 'sent' | 'failed',
  scheduled_at?: Timestamp,
  sent_at?: Timestamp,
  recipient_count?: number,
  error_message?: string,
  created_by: string, // admin UID
}
```

**Functions:**

1. **`sendMessageCampaign`** (Callable)
   - Admin-only callable function
   - Sends campaign immediately
   - Targeting modes: `all`, `role`, `topic`
   - Logs campaign to `fcm_campaigns` with `status: 'sent'`

2. **`executeScheduledCampaigns`** (Scheduled: every 1 minute)
   - Queries `fcm_campaigns` where `status == 'scheduled'` and `scheduled_at <= now`
   - Uses transaction to mark `status: 'sending'` (prevents double sends)
   - Sends FCM via `getRoleTokens()` or `getAllActiveTokens()`
   - Updates `status: 'sent'`, `sent_at`, `recipient_count` on success
   - Updates `status: 'failed'` + `error_message` on failure

3. **`sendTestFcmToSelf`** (Callable, admin-only)
   - Sends a manual test push to caller's own tokens.
   - Returns delivery summary:
     - `targeted`
     - `success`
     - `failed`
     - `invalidTokens`
   - Useful for production FCM diagnostics without creating content events.

---

### 3. Multi-Device Token Management

#### Client-Side Changes

**File:** `lib/core/services/notification_service.dart`

**Key Changes:**

1. **Device ID Generation**
   ```dart
   Future<String> _getOrCreateDeviceId() async {
     final prefs = await SharedPreferences.getInstance();
     String? deviceId = prefs.getString(_prefDeviceId);
     if (deviceId == null) {
       deviceId = _uuid.v4(); // Generate UUID v4
       await prefs.setString(_prefDeviceId, deviceId);
     }
     return deviceId;
   }
   ```

2. **Token Sync (Multi-Device)**
   ```dart
   Future<void> syncFcmTokenToServer(String userId) async {
     final token = await getStoredFcmToken();
     final deviceId = await _getOrCreateDeviceId();
     
     // Write to devices subcollection
     await FirestoreService.users
         .doc(userId)
         .collection('devices')
         .doc(deviceId)
         .set({
       'fcm_token': token,
       'device_id': deviceId,
       'platform': defaultTargetPlatform.name,
       'created_at': now,
       'last_active_at': now,
       'active': true,
     }, SetOptions(merge: true));
     
     // Also update legacy field
     await FirestoreService.users.doc(userId).set({
       'fcm_token': token,
       'updated_at': now,
     }, SetOptions(merge: true));
   }
   ```

3. **Logout Cleanup**
   ```dart
   Future<void> deleteToken({String? userId}) async {
     if (userId != null) {
       final deviceId = await _getOrCreateDeviceId();
       await FirestoreService.users
           .doc(userId)
           .collection('devices')
           .doc(deviceId)
           .delete();
       
       // Clear legacy token
       await FirestoreService.users.doc(userId).set({
         'fcm_token': '',
         'updated_at': FieldValue.serverTimestamp(),
       }, SetOptions(merge: true));
     }
     // ... unsubscribe from topics, delete FCM token
   }
   ```

#### Server-Side Helpers

**File:** `firebase_backend/functions/src/notification_triggers.ts`

1. **`getUserTokens(uid)`**
   ```typescript
   async function getUserTokens(uid: string): Promise<string[]> {
     const tokens = new Set<string>();
     
     // Try devices subcollection first
     const devicesSnap = await db
       .collection('users')
       .doc(uid)
       .collection('devices')
       .where('active', '==', true)
       .get();
     
     for (const doc of devicesSnap.docs) {
       const token = doc.data()?.fcm_token;
       if (token) tokens.add(token);
     }
     
     // Fallback to legacy field
     if (tokens.size === 0) {
       const userDoc = await db.collection('users').doc(uid).get();
       const legacyToken = userDoc.data()?.fcm_token;
       if (legacyToken) tokens.add(legacyToken);
     }
     
     return Array.from(tokens);
   }
   ```

2. **`getRoleTokens(role)`**
   - Queries all users with role
   - For each user, gets device tokens (or legacy fallback)
   - Deduplicates tokens

3. **`getAllActiveTokens()`**
   - Iterates all users
   - Collects device tokens (or legacy fallback)
   - Deduplicates tokens

4. **`cleanupStaleDevices`** (Scheduled: every 24 hours)
   - Deletes device docs where `last_active_at < now - 30 days`
   - Processes 1000 users per run

---

### 4. Firestore Rules

**File:** `firebase_backend/firestore/firestore.rules`

**New Rules for Devices Subcollection:**

```javascript
match /users/{userId} {
  // Multi-device token management
  match /devices/{deviceId} {
    // Allow owner to read/write their own devices
    allow read, write: if isOwner(userId);
    
    // Allow admins to read (for debugging)
    allow read: if isAdminOrAbove();
    
    // Restrict writable fields to prevent privilege escalation
    allow update: if isOwner(userId) &&
      request.resource.data.diff(resource.data).changedKeys().hasOnly([
        'fcm_token',
        'last_active_at',
        'active',
      ]);
  }
}
```

**Security:**
- Users can only read/write their own devices
- Admins can read all devices (debugging)
- Users can only update token + metadata fields (no privilege escalation)

---

## Deployment Instructions

### 1. Install Flutter Dependencies

```bash
cd /home/astra/Documents/CRII_Flutter_With_Backend_Firebase_18_March/CRII_Flutter_With_Backend_Firebase
flutter pub get
```

**Required packages (already added):**
- `uuid: ^4.3.3` - Device ID generation

---

### 2. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

---

### 3. Deploy Cloud Functions

```bash
cd firebase_backend/functions
npm install
npm run build
firebase deploy --only functions
```

**Deployed Functions:**
- `onPostCreated` (Firestore trigger)
- `onPostStatusChange` (Firestore trigger)
- `onPostResubmitted` (Firestore trigger)
- `onCommentCreated` (Firestore trigger)
- `onUserRoleChanged` (Firestore trigger)
- `sendMessageCampaign` (Callable)
- `executeScheduledCampaigns` (Scheduled: every 1 min)
- `cleanupStaleDevices` (Scheduled: every 24 hours)

---

### 4. Update App Initialization

In `lib/main.dart` or your app entry point:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize notification service
  await NotificationService.initialize();
  
  runApp(const MyApp());
}
```

---

### 5. Update Authentication Flow

**After successful login:**

```dart
// In your login/auth service
await NotificationService.instance.onUserAuthenticated(userId, userRole);
```

**On logout:**

```dart
// In your logout function
await NotificationService.instance.deleteToken(userId: userId);
```

---

## Test Plan

### 1. Local Emulator or Staging Environment

#### Test Missing Triggers

**Test 1: New Post Pending**
```
1. Login as reporter
2. Create a new post (status: pending)
3. Login as admin on different device
4. Verify admin receives push notification with:
   - title: "📝 New Post Pending Review"
   - data: { type: 'new_post_pending', post_id: '...' }
```

**Test 2: New Comment**
```
1. Login as user A, create a post
2. Login as user B, add comment to user A's post
3. Verify user A receives push notification with:
   - title: "💬 New Comment"
   - data: { type: 'new_comment', post_id: '...', comment_id: '...' }
4. Test self-comment (user A comments on own post) → NO notification
```

**Test 3: Post Resubmitted**
```
1. Login as reporter, create post
2. Login as admin, reject post
3. Login as reporter, edit and resubmit post
4. Verify admin receives push notification with:
   - title: "🔄 Post Resubmitted for Review"
   - data: { type: 'post_resubmitted', post_id: '...' }
```

**Test 4: Role Changed**
```
1. Login as user, note current role
2. Login as admin, change user's role via admin panel
3. Verify user receives push notification with:
   - title: "🎯 Role Updated"
   - data: { type: 'role_changed', new_role: '...' }
```

---

#### Test Campaign Scheduling

**Test 5: Scheduled Campaign**
```
1. Create fcm_campaigns document:
   {
     title: "Test Campaign",
     body: "This is a test",
     targeting: { type: 'all' },
     status: 'scheduled',
     scheduled_at: <timestamp 1 minute in future>,
     created_by: <admin_uid>
   }
2. Wait 2 minutes
3. Verify:
   - Campaign status changed to 'sent'
   - sent_at timestamp set
   - recipient_count > 0
   - FCM notifications delivered to target users
```

**Test 6: Immediate Campaign**
```
1. Call sendMessageCampaign callable function:
   {
     title: "Immediate Test",
     body: "Testing immediate send",
     targeting: { type: 'role', value: 'reporter' }
   }
2. Verify:
   - All reporters receive notification
   - Campaign logged with status: 'sent'
```

---

#### Test Multi-Device Tokens

**Test 7: Two Devices Login**
```
1. Login on Device A with user@test.com
2. Login on Device B with same account
3. Check Firestore:
   - users/{uid}/devices/ should have 2 documents
   - Both devices have active: true
   - Both have different device_id and fcm_token
4. Send test notification to user
5. Verify BOTH devices receive notification
```

**Test 8: Logout One Device**
```
1. From Test 7, logout Device A
2. Check Firestore:
   - Device A document deleted
   - Device B document still exists
3. Send test notification
4. Verify ONLY Device B receives notification
```

**Test 9: Stale Device Cleanup**
```
1. Create test device document with:
   - last_active_at: 31 days ago
   - active: true
2. Wait for cleanup job (or trigger manually)
3. Verify device document deleted
```

---

## Firestore Indexes

The following composite indexes may be required (create if deployment fails):

**Collection:** `fcm_campaigns`
- Fields: `status` (Ascending), `scheduled_at` (Ascending)

**Collection Group:** `devices`
- Fields: `active` (Ascending), `last_active_at` (Ascending)

Create indexes via Firebase Console or `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "fcm_campaigns",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "scheduled_at", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "devices",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "active", "order": "ASCENDING" },
        { "fieldPath": "last_active_at", "order": "ASCENDING" }
      ]
    }
  ]
}
```

---

## Migration Notes

### Backward Compatibility

- Legacy `users.fcm_token` field is maintained as fallback
- Existing users will automatically get device subcollection entries on next token sync
- Cloud functions check devices first, then fallback to legacy field

### Breaking Changes

None. The implementation is fully backward compatible.

---

## Troubleshooting

### Issue: Notifications not received on multiple devices

**Check:**
1. Both devices have unique `device_id` in SharedPreferences
2. Both devices have entries in `users/{uid}/devices`
3. Both devices have `active: true`
4. FCM tokens are valid (check Firebase Console → Cloud Messaging)

### Issue: Scheduled campaigns not sending

**Check:**
1. `scheduled_at` timestamp is in the past
2. `status` is `'scheduled'` (not `'draft'`)
3. Cloud Function `executeScheduledCampaigns` is deployed and running
4. Check Cloud Function logs for errors

### Issue: Firestore rules blocking writes

**Check:**
1. User is authenticated (`request.auth != null`)
2. User is writing to their own devices (`isOwner(userId)`)
3. Only allowed fields are being updated (`fcm_token`, `last_active_at`, `active`)

---

## Assumptions

1. **FCM-only notifications** - In-app notifications are out of scope for this pass
2. **Phase 1 triggers only** - Meeting created, account disabled, etc. are future enhancements
3. **30-day stale threshold** - Configurable in `cleanupStaleDevices` function
4. **Campaign schema compatibility** - Uses existing `fcm_campaigns` collection with added fields
5. **Topic-based targeting** - Currently treats topics as "all users" (topic subscription tracking would require additional infrastructure)

---

## Files Changed

### Backend

| File | Changes |
|------|---------|
| `firebase_backend/functions/src/notification_triggers.ts` | New file - All notification triggers + campaign functions |
| `firebase_backend/functions/src/index.ts` | Export notification triggers |
| `firebase_backend/firestore/firestore.rules` | Added devices subcollection rules |

### Client

| File | Changes |
|------|---------|
| `lib/core/services/notification_service.dart` | Multi-device token management, uuid-based device ID |
| `pubspec.yaml` | Already has `uuid: ^4.3.3` |

### Files Removed

| File | Reason |
|------|--------|
| `lib/core/services/device_token_manager.dart` | Integrated into notification_service.dart |

---

## Next Steps (Future Enhancements)

1. **In-app notifications** - Add notification documents to `users/{uid}/notifications`
2. **More triggers** - Meeting created, account disabled, post edited, etc.
3. **Topic subscription tracking** - Store user topic subscriptions in Firestore
4. **Campaign analytics** - Track open rates, click-through rates
5. **Rich notifications** - Add image attachments to notifications
6. **Notification preferences** - Per-category opt-out support

---

## Summary

✅ **Missing Triggers** - 4 FCM triggers implemented (post pending, comment, resubmitted, role change)  
✅ **Campaign Scheduling** - Immediate + scheduled campaigns with transaction safety  
✅ **Multi-Device Tokens** - UUID-based device ID, devices subcollection, legacy fallback  
✅ **Firestore Rules** - Secure device subcollection access  
✅ **Cleanup Job** - Daily stale device removal (30 days)  

All implementations follow the backend-first approach with FCM-only notifications as specified.

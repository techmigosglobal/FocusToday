# CRII App Testing Checklist

## Scope

- Date: `2026-03-07`
- App: `CRII Flutter + Firebase backend`
- Auth model under test: `Msg91 OTP -> Firebase custom token`
- Role model under test: `role resolved by phone number`
- Roles to validate: `Public User`, `Reporter`, `Admin`, `Super Admin`
- Not in scope: `email login`, `anonymous login`, `NestJS backend`
- Important note: reports currently support `draft save` in the UI; a `publish` action is not currently exposed in the app

## Execution Sheet

| Item | Value |
| --- | --- |
| Build / APK / IPA | |
| Firebase project | `eagle-tv-crii` |
| Tester name | |
| Device name | |
| OS version | |
| Test date | |
| Network used | Wi-Fi / Mobile data |
| Result legend | Pass / Fail / Blocked / N/A |

## Required Test Accounts

Roles are now phone-number based. Each tester must know which phone number is mapped to which role before execution.

| Role | Test phone number | Expected landing experience | Ready |
| --- | --- | --- | --- |
| Public User | | Home + Search + Profile + Settings | |
| Reporter | | Home + Search + Profile + Settings; reporter workspace in Settings | |
| Admin | | Home + All Posts + Profile + Settings; admin workspace in Settings | |
| Super Admin | | Home + All Posts + Profile + Settings; super-admin controls in Settings | |
| Unmapped phone | | Should land as `Public User` | |

## Seed Data Checklist

Prepare these before feature execution.

| Data needed | Used in | Ready |
| --- | --- | --- |
| 1 approved image post | Feed, profile, bookmarks, search | |
| 1 approved video post | Feed, video playback, caching | |
| 1 approved PDF post | Feed, PDF viewer, caching | |
| 1 approved article post | Feed, article reader, search | |
| 1 approved story or poetry post | Feed, profile tabs | |
| 1 pending reporter post | Admin moderation tests | |
| 1 rejected reporter post with rejection reason | Reporter resubmission tests | |
| 1 active emergency alert | Feed banner, emergency module, notifications | |
| 1 upcoming meeting | Meetings list and interest toggle | |
| 1 daily report with `published` status | Public reports view | |
| 1 weekly or monthly report with `draft` status | Admin report visibility test | |
| 1 pending donation entry | Donation admin confirmation test | |
| 1 partner enrollment submission | Partner module verification | |
| 1 user created by admin | User-management and role-assignment verification | |

## A. Smoke And Install

| ID | Role | Scenario | Steps | Expected Result | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| APP-01 | Any | App launch | Install app; launch app from a cold start | Splash screen appears and app does not crash | | |
| APP-02 | Logged out | Login entry path | Wait for splash to finish on a logged-out device | App routes to login method screen | | |
| APP-03 | Logged out | OTP-only entry | Observe the login method screen | Only phone-number sign-in is shown; no email option; no dev role selector | | |
| APP-04 | Any | Language switch on login | Change language on login screen between English, Telugu, Hindi | UI labels update without crash | | |
| APP-05 | Any | App background / resume | Open app; send to background; resume | App returns cleanly without forced logout or blank screen | | |
| APP-06 | Any | App relaunch after successful login | Log in; close app completely; relaunch | Previous session is restored and app lands in authenticated shell | | |

## B. Authentication And Session

| ID | Role | Scenario | Steps | Expected Result | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| AUTH-01 | Any | Invalid phone validation | Enter fewer than 10 digits or invalid mobile number; tap `Send OTP` | Validation blocks submission and shows an error | | |
| AUTH-02 | Any | Valid phone OTP request | Enter a valid Indian mobile number; tap `Send OTP` | OTP request succeeds and OTP screen opens | | |
| AUTH-03 | Any | Invalid OTP validation | Enter fewer than 6 OTP digits; tap verify | Verification is blocked with a clear error | | |
| AUTH-04 | Any | Wrong OTP handling | Enter an incorrect 6-digit OTP | Error is shown; user stays on OTP screen | | |
| AUTH-05 | Any | OTP resend | Wait for resend countdown; tap resend | OTP resend succeeds or clear error is shown if provider blocks it | | |
| AUTH-06 | Public | Role resolution by phone | Log in using the mapped public-user phone number | User lands in public shell and profile badge shows `Public User` | | |
| AUTH-07 | Reporter | Role resolution by phone | Log in using the mapped reporter phone number | User lands in reporter shell and reporter workspace is visible | | |
| AUTH-08 | Admin | Role resolution by phone | Log in using the mapped admin phone number | User lands in admin shell with `All Posts` tab and admin workspace | | |
| AUTH-09 | Super Admin | Role resolution by phone | Log in using the mapped super-admin phone number | User lands in super-admin shell with editable storage config access | | |
| AUTH-10 | Unmapped | Default role fallback | Log in using an unmapped phone number | User is created or resolved as `Public User` | | |
| AUTH-11 | Any | Logout | Open Settings; tap `Logout`; confirm | Session is cleared and app returns to logged-out login flow | | |
| AUTH-12 | Any | No anonymous bypass | Fresh install; launch app without completing OTP flow | User must not enter authenticated shell without OTP verification | | |

## C. Public And Shared User Flows

| ID | Role | Scenario | Steps | Expected Result | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| PUB-01 | Public | Home feed load | Log in as public user; open Home | Approved posts load successfully | | |
| PUB-02 | Public | Feed refresh | Pull to refresh on Home | Feed refresh completes and list remains stable | | |
| PUB-03 | Public | Open post detail | Tap a post card from Home | Post detail screen opens with correct content | | |
| PUB-04 | Public | Like toggle | Like a post from feed or detail; remove like | Count and state update correctly | | |
| PUB-05 | Public | Bookmark toggle | Bookmark a post; unbookmark it later | Bookmark state updates immediately and is consistent in Profile bookmarks | | |
| PUB-06 | Public | Share action | Tap share on a post | Share sheet opens and share count does not regress | | |
| PUB-07 | Public | Add comment | Open comments on a post; submit a valid comment | Comment appears in the list immediately | | |
| PUB-08 | Public | Search by keyword | Search for a post caption keyword | Matching posts are returned | | |
| PUB-09 | Public | Search by hashtag | Search using a hashtag like `#news` | Matching hashtag results are returned | | |
| PUB-10 | Public | User search | Search for another user; open result | Profile screen for the selected user opens | | |
| PUB-11 | Public | Discovery content | Open Search with no query | Trending hashtags, trending posts, and recommended posts load | | |
| PUB-12 | Public | Search history | Perform searches; go back to Search home | Search history is visible and can be reused | | |
| PUB-13 | Public | Own profile tabs | Open Profile | Posts, Stories, Articles, and Bookmarks tabs load for own profile | | |
| PUB-14 | Public | Edit profile | Edit profile fields and save | Updated details persist after reopening Profile | | |
| PUB-15 | Public | Settings preferences | Change language, dark mode, autoplay, notification toggles | Preferences apply without crash and persist after reopening screen | | |
| PUB-16 | Public | Quiet hours | Enable quiet hours; set start and end times | Schedule saves and displays the selected time range | | |
| PUB-17 | Public | Legal pages | Open Privacy Policy, Terms of Service, Disclaimer | Each screen opens successfully | | |
| PUB-18 | Public | Emergency alerts list | Open Emergency Alerts | Active alerts load correctly with severity labels | | |
| PUB-19 | Public | Reports read-only view | Open Reports and switch Daily, Weekly, Monthly tabs | Public user sees only `published` reports | | |
| PUB-20 | Public | Departments module | Open Department Linkages | Departments screen opens without crash | | |
| PUB-21 | Public | Partner enrollment | Submit partner enrollment form with valid data | Submission succeeds and confirmation is shown | | |
| PUB-22 | Public | Donation submission | Open Support CRII; submit a donation intent / verification | Donation record is created and visible in donation history | | |
| PUB-23 | Public | Donation history | Reopen donation screen after prior submission | Previous donation history loads correctly | | |
| PUB-24 | Public | Meetings list | Open Meetings from notification or in-app entry if available | Upcoming meetings list loads | | |
| PUB-25 | Public | Meeting interest toggle | Tap `Interested?` on a meeting; tap again to revert | Interest state and interest count update correctly | | |

## D. Reporter Workflow

### Reporter Content-Type Coverage

Use the reporter phone number for all cases below. For each content type, create the post, confirm the expected pending state, then verify rendering after admin approval.

| ID | Content type | Steps | Expected Result | Result | Notes |
| --- | --- | --- | --- | --- | --- |
| REP-MEDIA-01 | Image | Create a reporter post with image media | Post submits successfully and enters `pending` state | | |
| REP-MEDIA-02 | Video | Create a reporter post with video media | Upload completes and post enters `pending` state | | |
| REP-MEDIA-03 | PDF | Create a reporter post with PDF media | Upload completes and post enters `pending` state | | |
| REP-MEDIA-04 | Article | Create a reporter post with article text content | Post submits successfully and enters `pending` state | | |
| REP-MEDIA-05 | Story | Create a reporter post with story content type | Post submits successfully and enters `pending` state | | |
| REP-MEDIA-06 | Poetry | Create a reporter post with poetry content type | Post submits successfully and enters `pending` state | | |

### Reporter Feature Checks

| ID | Role | Scenario | Steps | Expected Result | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| REP-01 | Reporter | Reporter workspace presence | Open Settings as reporter | `Create Post`, `Rejected Posts`, `My Analytics`, `Emergency Alerts`, `Reports`, `Become Partner`, `Support CRII`, `Department Linkages` are visible | | |
| REP-02 | Reporter | Post submission behavior | Submit any new reporter post | Success dialog says post is pending review; post is not immediately live in public feed | | |
| REP-03 | Reporter | Rejected posts list | Open `Rejected Posts` | Previously rejected posts load with rejection reason | | |
| REP-04 | Reporter | Edit and resubmit rejected post | Open a rejected post; edit; resubmit | Resubmission succeeds and post returns to pending review | | |
| REP-05 | Reporter | Reporter analytics | Open `My Analytics` | Analytics screen loads with counts for approved, pending, rejected content | | |
| REP-06 | Reporter | Notifications about moderation | After admin approval or rejection, open Notifications | Reporter receives the correct post-status notification | | |
| REP-07 | Reporter | Reports access | Open Reports | Reporter can read reports but cannot create drafts if not a moderator | | |
| REP-08 | Reporter | Access boundaries | Inspect nav and Settings | Reporter must not see `All Posts Queue`, `User Management`, or `Storage Limits` | | |

## E. Admin And Super Admin Workflow

| ID | Role | Scenario | Steps | Expected Result | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| ADM-01 | Admin | Admin shell layout | Log in as admin | Bottom navigation shows `Home`, `All Posts`, `Profile`, `Settings` | | |
| ADM-02 | Admin | Admin workspace presence | Open Settings as admin | `All Posts Queue`, `User Management`, `Analytics Dashboard`, `Storage Limits`, `Meetings`, `Emergency Alerts`, `Reports` are visible | | |
| ADM-03 | Admin | All-posts queue load | Open `All Posts Queue` | Pending, approved, and rejected posts load | | |
| ADM-04 | Admin | Post search and filters | Use search and filter chips in All Posts | Results update correctly by status and query | | |
| ADM-05 | Admin | Approve pending post | Approve a reporter pending post | Post moves to approved list; reporter gets notification; post appears in public feed | | |
| ADM-06 | Admin | Reject pending post | Reject a pending post with a rejection reason | Post moves to rejected list; reason is saved; reporter sees rejection info | | |
| ADM-07 | Admin | Edit existing post | Edit a post from All Posts | Changes save successfully and are reflected after reload | | |
| ADM-08 | Admin | Delete post | Delete a post from All Posts | Post is removed from the list and no longer appears in feed | | |
| ADM-09 | Admin | User-management load | Open User Management | User list loads with tab filters and search | | |
| ADM-10 | Admin | Admin can add reporter | Add a new reporter from User Management | User is created successfully and appears in the reporter list | | |
| ADM-11 | Admin | Admin role-change limits | Attempt role changes from User Management | Admin can change `Reporter` and `Public User`; admin cannot promote users to `Admin` or modify super admin users | | |
| ADM-12 | Admin | Admin delete-user limits | Try deleting a reporter or public user | Allowed users can be deleted; restricted users cannot be deleted | | |
| ADM-13 | Admin | Analytics dashboard | Open `Analytics Dashboard` | Dashboard loads counts for posts, users, and donations without crash | | |
| ADM-14 | Admin | Emergency alert creation | Create a new emergency alert | Alert saves successfully and becomes visible in emergency list / feed banner | | |
| ADM-15 | Admin | Meetings management create | Open Meetings; create a new meeting | Meeting is saved and appears in meetings management and public meetings list | | |
| ADM-16 | Admin | Meetings management update | Edit an existing meeting | Changes are reflected after refresh | | |
| ADM-17 | Admin | Meeting status actions | Mark meeting ongoing, completed, or cancelled | Status changes persist correctly | | |
| ADM-18 | Admin | Reports draft creation | Open Reports; create a report draft | Draft saves successfully and remains visible to moderators | | |
| ADM-19 | Admin | Donation pending queue | Open Donation admin section | Pending donations load correctly | | |
| ADM-20 | Admin | Donation confirmation | Mark a pending donation as success and another as failed | Donation status updates correctly and history reflects the new status | | |
| ADM-21 | Admin | Donation payment config | Update UPI/payment settings | Settings save successfully and reload correctly | | |
| ADM-22 | Admin | Storage limits read-only | Open Storage Limits as admin | Usage and config are visible, but save/edit capability is not available | | |
| SADM-01 | Super Admin | Add admin user | Add a new admin from User Management | Admin user is created successfully | | |
| SADM-02 | Super Admin | Change user role to admin | Promote a reporter or public user to admin | Role update succeeds and user appears under admin filter | | |
| SADM-03 | Super Admin | Storage limits edit | Open Storage Limits; modify values; save | New values save successfully and remain after reload | | |

## F. Notifications

| ID | Role | Scenario | Steps | Expected Result | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| NOTIF-01 | Any logged-in user | Notifications screen load | Open Notifications from the feed | Notification list loads and unread count is shown | | |
| NOTIF-02 | Any | Mark all as read | Tap `Mark all read` when unread items exist | All notifications become read | | |
| NOTIF-03 | Any | Delete a notification | Swipe a notification away | Notification is removed from the list | | |
| NOTIF-04 | Reporter | Post-status notification routing | Tap `post approved` or `post rejected` notification | App opens the relevant post or moderation-related destination correctly | | |
| NOTIF-05 | Admin | Pending-post notification routing | Tap `new_post_pending` or `post_resubmitted` notification | App routes to moderation / moderation screen correctly | | |
| NOTIF-06 | Any | Emergency notification routing | Tap an emergency-alert notification | App opens Emergency Alerts screen | | |
| NOTIF-07 | Any | Meeting notification routing | Tap a meeting-created notification | App opens Meetings list | | |
| NOTIF-08 | Any | Donation notification routing | Tap a donation-related notification | App opens Donation screen | | |

## G. Cache, Performance, And Offline-Resilience

Run these on a device with enough seed data to make repeated opens meaningful.

| ID | Role | Scenario | Steps | Expected Result | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| PERF-01 | Any | Feed warm reload | Open Home; let posts load; switch tabs; return to Home | Feed should reopen quickly with reduced loading delay | | |
| PERF-02 | Any | Search discovery warm reload | Open Search; wait for trending and recommended content; leave and return | Discovery content should return faster on second open | | |
| PERF-03 | Any | Profile warm reload | Open Profile; let counts and tabs load; leave and return | Profile data should appear faster on second open | | |
| PERF-04 | Any | Bookmark cache invalidation | Bookmark or unbookmark a post; reopen Profile bookmarks | Bookmark list updates correctly with no stale item | | |
| PERF-05 | Any | Meetings cache invalidation | Toggle meeting interest; refresh or reopen meetings | Updated interest state and count are shown correctly | | |
| PERF-06 | Any | Donation cache invalidation | Create or confirm a donation; reopen donation history | Donation list reflects the latest status | | |
| PERF-07 | Any | PDF cache | Open the same PDF post twice | Second open should be faster and PDF should render without re-downloading delays where possible | | |
| PERF-08 | Any | Video cache | Open the same video content twice | Second open should start faster and remain stable | | |
| PERF-09 | Any | Search history persistence | Perform searches; close and reopen app | Search history remains available | | |
| PERF-10 | Any | Temporary offline behavior | Load feed and profile once on network; disable network; reopen same screens | Previously loaded data should fail gracefully and any cached content should remain usable where available | | |
| PERF-11 | Any | Reconnect refresh | Re-enable network after offline test; pull to refresh | Latest data loads successfully and stale state clears | | |

## H. Access-Control Regression

These are UI-level checks to confirm the role model matches the intended phone-based permissions.

| ID | Role | Scenario | Steps | Expected Result | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| ACL-01 | Public | Public access restriction | Inspect Home, Search, Settings, and navigation | Public user cannot access Create Post, All Posts, User Management, Analytics, Meetings management, or Storage Limits | | |
| ACL-02 | Reporter | Reporter access restriction | Inspect nav and Settings | Reporter cannot access All Posts, User Management, Analytics Dashboard, or Storage Limits | | |
| ACL-03 | Admin | Admin storage restriction | Open Storage Limits as admin | Admin sees read-only usage; edit/save controls are unavailable | | |
| ACL-04 | Super Admin | Super-admin elevation | Open Storage Limits and User Management | Super admin can edit storage and manage admin assignments | | |
| ACL-05 | Admin-created user | New user sign-in | Add a reporter or admin; then sign in with that phone number | New user lands on the assigned role shell based on phone number | | |
| ACL-06 | Any | Role persistence | Log out and log back in using the same phone number | Same role is restored consistently | | |
| ACL-07 | Deleted user | Deleted-user regression | Delete a user; attempt sign-in again with same phone if part of test scope | Behavior is consistent with current backend rules and does not surface stale role data | | |
| ACL-08 | Any | No legacy auth surfaces | Inspect login, settings, and profile flows | No email-login or anonymous-login path is visible anywhere in the app | | |

## Known Current Constraints For Testers

- Roles must be verified using the phone number that is mapped for that role.
- Email login is intentionally removed and should be treated as absent by design.
- Anonymous auth is intentionally removed and should be treated as absent by design.
- Reports currently save as drafts in the UI. If testers need `publish` validation, that requires either seeded published documents or a future UI/API addition.
- Storage Limits screen is intentionally retained. Admin is view-only; Super Admin can save changes.

## Defect Log Template

| Defect ID | Test Case ID | Severity | Device | Role | Summary | Steps to reproduce | Actual result | Expected result | Screenshot / video |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | | |

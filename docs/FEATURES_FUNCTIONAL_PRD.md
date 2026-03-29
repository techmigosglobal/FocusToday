# Focus Today (CRII) - Functional Product Requirements Document

## 1. Product Definition

### 1.1 Product Name
Focus Today (CRII App)

### 1.2 Product Type
Role-based multilingual community news and civic coordination platform.

### 1.3 Primary Product Goal
Enable fast consumption, creation, moderation, and distribution of civic/community content with strong role controls, multilingual support, and real-time updates for critical information (breaking news, alerts, meetings).

---

## 2. User Roles and Access Model

### 2.1 Supported Roles
1. Super Admin
2. Admin
3. Reporter
4. Public User

### 2.2 Access Philosophy
1. All users can consume approved content.
2. Content creation is restricted to Super Admin, Admin, and Reporter.
3. Moderation and governance capabilities are restricted to Super Admin and Admin.
4. Public users are focused on consumption, interaction, and enrollment/application journeys.

---

## 3. Core Functional Journeys

### 3.1 First Launch and Entry
1. Splash experience with session restoration.
2. Automatic routing to:
   - Main app shell if session exists.
   - Login flow if no session exists.
3. Optional profile completion prompt when profile basics are incomplete.

### 3.2 Authentication Journey
1. OTP-based phone login flow.
2. Phone number validation before OTP request.
3. OTP verification with resend support.
4. Session creation and persistent login state.
5. Role-aware post-login destination.

### 3.3 Feed Consumption Journey
1. Vertical flip-style feed for approved posts.
2. Category-based filtering.
3. In-feed engagement actions:
   - Like
   - Comment
   - Bookmark
   - Share
4. Tap-through to full post detail.
5. Pull-to-refresh and background refresh behavior.

### 3.4 Content Creation Journey
1. 3-step post creation wizard.
2. Supported post types:
   - Image post
   - Video post
   - Text post
   - PDF post
3. Caption + category assignment.
4. Media selection and upload (where applicable).
5. Draft save and draft restore.
6. Role-based submission behavior:
   - Admin/Super Admin: direct approval/publish.
   - Reporter: pending review.

### 3.5 Moderation Journey
1. Pending queue review.
2. Actions on queued content:
   - Approve
   - Reject with reason
   - Edit before approval
3. Bulk moderation support (bulk approve/reject).
4. Access to approved and rejected tabs.
5. Audit timeline visibility for action history.

---

## 4. Functional Modules

## 4.1 Home Feed Module
1. Dynamic feed of approved content.
2. Auto-hide top bar behavior while reading.
3. In-feed banners:
   - Emergency alerts
   - Breaking news
4. Notification badge and quick access.
5. Reporter quick access to rejected posts.
6. Admin/Reporter quick access to workspace.
7. Pagination and continuous feed loading.

## 4.2 Post Interaction Module
1. Like/unlike with count updates.
2. Bookmark/unbookmark with count updates.
3. Long-press save to named bookmark collections.
4. Share with generated deep link per post.
5. Impression tracking and view capture.
6. Interaction continuity even during unstable network conditions.

## 4.3 Post Detail and Reader Module
1. Full post detail view with engagement controls.
2. Type-specific viewing:
   - Video viewer
   - PDF viewer
   - Article/text reader
3. Read-progress UX and immersive reading format.
4. Post options:
   - Copy link
   - Share
   - Report post
   - Hide post
   - Delete (owner/admin)
   - Block user (admin)

## 4.4 Comments Module
1. Bottom-sheet comment experience.
2. Add comment.
3. Reply to comment.
4. Expand/collapse replies.
5. Comment counts and relative timestamps.

## 4.5 Search and Discovery Module
1. Search across posts and users.
2. Debounced query execution.
3. Search filters:
   - All / Posts / Users
   - Category filter
   - Content-type filter
4. Hashtag-based search support.
5. Discovery blocks:
   - Trending hashtags
   - Trending posts
   - Recommended posts
6. Search history management:
   - Save history
   - Clear history

## 4.6 Notifications Module
1. Unified notifications inbox.
2. Category tabs:
   - All
   - Alerts
   - Approvals
   - Activity
3. Mark single as read.
4. Mark all as read.
5. Swipe-to-delete notification.
6. Action routing from notification type:
   - Post detail
   - Moderation queue
   - Emergency alerts
   - Meetings list

## 4.7 Profile Module
1. Role-stamped profile header with avatar/details.
2. Profile stats (posts, bookmarks).
3. Content tabs for own profile:
   - Posts
   - Articles
   - Stories
   - Bookmarks
4. Edit profile capability.
5. Profile restrictions:
   - Cross-profile viewing allowed for admins.
   - Restricted for non-admin roles.
6. Basic details form for public users:
   - Name
   - Area
   - District
   - State

## 4.8 Bookmark Collections Module
1. Create named bookmark collections.
2. Rename collection.
3. Delete collection.
4. View posts inside a collection.
5. Save posts into custom collections.

## 4.9 Settings and Preferences Module
1. Language selection (English, Telugu, Hindi).
2. Dark mode toggle.
3. Video autoplay toggle.
4. Notification preferences:
   - Push on/off
   - Grouped notifications
   - Quiet hours on/off
   - Quiet hours schedule
5. Access to role-specific workspace modules.
6. Legal pages access:
   - Privacy Policy
   - Terms of Use
   - Disclaimer
7. Logout flow.

## 4.10 Workspace Module (Role Command Center)
1. Admin workspace features:
   - All posts queue
   - Moderation
   - User management
   - Reporter applications review
   - Analytics
   - Storage limits
   - Meetings management
   - Audit timeline
   - Breaking news broadcast
   - FCM campaign sending
2. Reporter workspace features:
   - Create post
   - Rejected posts and resubmission
   - My analytics

## 4.11 Meetings Module
1. Public meetings list.
2. Meeting detail view.
3. Interest toggle for meetings.
4. RSVP support:
   - Going
   - Maybe
   - Not going
5. Admin meeting management:
   - Create
   - Edit
   - Delete
   - Status change (upcoming/ongoing/completed/cancelled)
   - Interested-users view
   - Display-window configuration

## 4.12 Emergency Alerts Module
1. Public-facing active alerts list.
2. Severity-based alert display.
3. Multilingual alert content support.
4. Admin-only alert creation:
   - Severity selection
   - Location targeting fields
   - Localized title/description fields

## 4.13 Reports Module
1. Report listing by period:
   - Daily
   - Weekly
   - Monthly
2. Report details with activity metrics.
3. Moderators can create reports.
4. PDF export and print support from report detail.

## 4.14 Enrollment and Reporter Application Module
1. Partner enrollment form:
   - Profile-linked prefill
   - Region/profession fields
2. Reporter application for public users:
   - Qualification and motivation capture
   - Pending submission protection (no duplicate pending)
3. Admin review of reporter applications:
   - Pending/Approved/Rejected tabs
   - Approve
   - Reject with reason

## 4.15 Department Linkages Module
1. Structured directory of emergency/public department contacts.
2. Coverage includes emergency, police, revenue, legal aid, and health/welfare blocks.

---

## 5. Status Lifecycles

### 5.1 Post Lifecycle
1. Created
2. Pending (Reporter-created)
3. Approved (Published)
4. Rejected (with reason)
5. Resubmitted after correction (Reporter flow)

### 5.2 Reporter Application Lifecycle
1. Submitted
2. Pending Review
3. Approved
4. Rejected (with optional reason)

### 5.3 Meeting Lifecycle
1. Upcoming
2. Ongoing
3. Completed
4. Cancelled

---

## 6. Role-Based Feature Matrix

| Capability | Super Admin/Admin | Reporter | Public User |
|---|---|---|---|
| View feed and details | Yes | Yes | Yes |
| Like, comment, bookmark, share | Yes | Yes | Yes |
| Create posts | Yes | Yes | No |
| Auto-publish own post | Yes | No | No |
| Access moderation tools | Yes | No | No |
| Manage users and roles | Yes | No | No |
| Review reporter applications | Yes | No | No |
| Create emergency alerts | Yes | No | No |
| Manage meetings | Yes | No | No |
| RSVP and interest in meetings | Yes | Yes | Yes |
| Create operational reports | Yes | No | No |
| View reports | Yes | Yes | Yes |
| Apply for reporter role | No | No | Yes |

---

## 7. Functional Requirements Summary

1. The app must provide multilingual operation across major workflows.
2. The app must enforce role-based access for creation, moderation, and governance.
3. The app must support both content consumption and operational coordination workflows.
4. The app must provide transparent status tracking for moderation-dependent workflows.
5. The app must support urgent communication channels through emergency and breaking-news systems.
6. The app must allow discoverability through search, hashtags, and recommendations.
7. The app must preserve user continuity through session restore, saved preferences, and draft support.

---

## 8. Product Scope Boundary (Functional)

### In Scope
1. Role-based news/community platform behavior defined in this document.
2. End-to-end content lifecycle from creation to moderation to consumption.
3. Civic coordination modules (alerts, meetings, reports, department linkages).

### Out of Scope
1. UI implementation details and visual design specifications.
2. Engineering architecture and infrastructure details.
3. Internal technical implementation decisions.


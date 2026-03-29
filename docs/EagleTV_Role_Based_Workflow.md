# EagleTV - Role-Based User Guide

## Demo Login Credentials

| Role | Phone Number | OTP | Display Name |
|------|--------------|-----|--------------|
| **Admin** | Ends with `111` (e.g., `9876543111`) | `123456` | Admin User |
| **Reporter** | Ends with `222` (e.g., `9876543222`) | `123456` | Reporter User |
| **Public User** | Any other (e.g., `9876543210`) | `123456` | Demo User |

---

## 1. Admin User Workflow

### Permissions
| Feature | Access |
|---------|--------|
| View Feed | ✅ Full |
| Create Posts | ✅ Posts auto-approved |
| Moderation Screen | ✅ Full access |
| Approve/Reject Posts | ✅ Yes |
| Edit Any Post | ✅ Yes |
| View Pending Count Badge | ✅ Yes |
| Settings | ✅ Full |
| Profile Management | ✅ Full |

### Content Upload Flow
```
Admin creates post → Post is AUTO-APPROVED → Appears immediately in feed
```

### Key Screens
1. **Feed Screen** - Shows moderation badge with pending count
2. **Create Post** - All content types available, auto-approved
3. **Moderation Screen** - Review pending posts from reporters/users
4. **Profile** - View own posts and bookmarks
5. **Settings** - Full app configuration

### Moderation Actions
- **Approve** - Post goes live to all users
- **Edit** - Modify caption, category, media before approval
- **Reject** - Post removed with optional reason

---

## 2. Reporter User Workflow

### Permissions
| Feature | Access |
|---------|--------|
| View Feed | ✅ Full |
| Create Posts | ✅ Posts go to moderation |
| Moderation Screen | ❌ No access |
| Approve/Reject Posts | ❌ No |
| Edit Own Pending Posts | ✅ Yes |
| Settings | ✅ Full |
| Profile Management | ✅ Full |

### Content Upload Flow
```
Reporter creates post → Post status = PENDING → Admin reviews → Approved/Rejected
```

### Key Screens
1. **Feed Screen** - View approved content only
2. **Create Post** - All content types available
3. **Profile** - View own posts (including pending status)
4. **Settings** - Full app configuration

### Post Types Available
- 📷 **Image** - Photo with caption
- 🎥 **Video** - Video with caption
- 📄 **PDF** - Document viewer
- 📝 **Article** - Long-form text content
- 📖 **Story** - Short story format
- ✍️ **Poetry** - Verses/stanzas format

---

## 3. Public User Workflow

### Permissions
| Feature | Access |
|---------|--------|
| View Feed | ✅ Full |
| Create Posts | ✅ Posts go to moderation |
| Moderation Screen | ❌ No access |
| Approve/Reject Posts | ❌ No |
| Like/Bookmark/Share | ✅ Yes |
| Comment | ✅ Yes |
| Settings | ✅ Full |
| Profile Management | ✅ Full |

### Content Upload Flow
```
User creates post → Post status = PENDING → Admin reviews → Approved/Rejected
```

### Key Screens
1. **Feed Screen** - Swipe through approved posts
2. **Create Post** - Submit content for review
3. **Explore** - Discover trending content
4. **Search** - Find posts and users
5. **Profile** - View own posts and bookmarks
6. **Settings** - App preferences

---

## Content Types & Upload Process

### Supported Content Types

| Type | Icon | Description | Media Required |
|------|------|-------------|----------------|
| Image | 📷 | Photo post | Yes - Image file |
| Video | 🎥 | Video post | Yes - Video file |
| PDF | 📄 | Document | Yes - PDF file |
| Article | 📝 | Long text | No - Text only |
| Story | 📖 | Short story | No - Text only |
| Poetry | ✍️ | Verses | No - Text only |

### Upload Steps (All Users)

1. **Tap Create (+)** button in bottom nav
2. **Select Content Type** from wizard
3. **Add Media** (if required) or **Write Content**
4. **Enter Caption** and select **Category**
5. **Preview** and **Submit**

### Post Status Flow

```
┌─────────────────────────────────────────────────────────┐
│                    POST CREATED                         │
└─────────────────────────────────────────────────────────┘
                          │
            ┌─────────────┴─────────────┐
            │                           │
      [Admin User]              [Reporter/Public]
            │                           │
            ▼                           ▼
    ┌───────────────┐          ┌───────────────┐
    │   APPROVED    │          │    PENDING    │
    │ (Auto-approve)│          │ (Wait review) │
    └───────────────┘          └───────────────┘
            │                           │
            ▼                 ┌─────────┴─────────┐
    ┌───────────────┐         │                   │
    │  LIVE IN FEED │    [Admin Approves]   [Admin Rejects]
    └───────────────┘         │                   │
                              ▼                   ▼
                      ┌───────────────┐   ┌───────────────┐
                      │   APPROVED    │   │   REJECTED    │
                      │ (Goes live)   │   │ (Not visible) │
                      └───────────────┘   └───────────────┘
```

---

## Feature Access Matrix

| Feature | Admin | Reporter | Public |
|---------|:-----:|:--------:|:------:|
| View Feed | ✅ | ✅ | ✅ |
| Like Posts | ✅ | ✅ | ✅ |
| Bookmark Posts | ✅ | ✅ | ✅ |
| Share Posts | ✅ | ✅ | ✅ |
| Comment | ✅ | ✅ | ✅ |
| Create Posts | ✅ | ✅ | ✅ |
| Auto-Approve Own Posts | ✅ | ❌ | ❌ |
| View Moderation | ✅ | ❌ | ❌ |
| Approve Posts | ✅ | ❌ | ❌ |
| Reject Posts | ✅ | ❌ | ❌ |
| Edit Any Post | ✅ | ❌ | ❌ |
| See Pending Badge | ✅ | ❌ | ❌ |
| Upload Images | ✅ | ✅ | ✅ |
| Upload Videos | ✅ | ✅ | ✅ |
| Upload PDFs | ✅ | ✅ | ✅ |
| Write Articles | ✅ | ✅ | ✅ |
| Write Stories | ✅ | ✅ | ✅ |
| Write Poetry | ✅ | ✅ | ✅ |
| Edit Profile | ✅ | ✅ | ✅ |
| Settings | ✅ | ✅ | ✅ |

---

## Navigation Structure

### Bottom Navigation (All Users)
1. **Home** - Main feed with flip animation
2. **Explore** - Discover trending content
3. **Create (+)** - Add new post
4. **Search** - Find content/users
5. **Profile** - User profile & settings

### Admin-Only Navigation
- **Moderation Icon** appears in Feed AppBar when logged as Admin
- Badge shows count of pending posts

---

## Testing Each Role

### Test Admin Flow
1. Login with phone ending `111`, OTP `123456`
2. Create a post → Verify it appears immediately
3. Check moderation icon in feed
4. Review pending posts (if any)

### Test Reporter Flow
1. Login with phone ending `222`, OTP `123456`
2. Create a post → Verify "Pending Review" status
3. Confirm no moderation access

### Test Public Flow
1. Login with any other phone, OTP `123456`
2. Browse feed, like/bookmark posts
3. Create a post → Verify pending status

---

---

## 🆕 Latest Updates & Improvements (December 2024)

### ✅ Demo Mode (No Backend Required)
The application now runs entirely locally without requiring any backend:
- Removed Supabase, database, and logger dependencies
- In-memory storage for posts, comments, bookmarks
- SharedPreferences for session management
- All repositories rewritten for demo mode

### ✅ PDF Viewing
- Sample PDF: `assets/sample.pdf` (Bank recruitment document)
- Built-in PDF viewer using Syncfusion Flutter PDF Viewer
- PDF posts display correctly in feed

### ✅ Video Playback  
- Working sample videos from Google Cloud Storage:
  - BigBuckBunny.mp4
  - ElephantsDream.mp4
- Auto-play with mute toggle on feed cards

### ✅ Content/Description Field Enhancement
- **NEW**: Content/Description field now shows for ALL post types
- Required for text-based posts (Article, Story, Poetry)
- Optional for media posts (Image, Video) - allows adding story/context
- Enhanced UX with descriptive labels

### ✅ Post Submission Flow Fixed
| User Role | Post Status | Success Message |
|-----------|-------------|-----------------|
| **Admin** | Auto-approved | "Post Published! - Your post is now live in the feed!" |
| **Reporter** | Pending | "Post Submitted! - pending review" |
| **Public** | Pending | "Post Submitted! - pending review" |

**Posts now correctly route to:**
- ✅ **Feed** immediately (if admin - auto-approved)
- ✅ **Moderation queue** for review (if reporter/public - pending status)

### ✅ App Icon & Logo
- Custom circular EagleTV logo
- Adaptive icons for Android (with white background)
- iOS launcher icons updated

### Technical Implementation Details

#### Demo Mode Architecture
```
PostRepository     → In-memory _demoPosts + _userCreatedPosts
AuthRepository     → SharedPreferences for session
ProfileRepository  → Mock data
SearchRepository   → Searches sample posts locally
CommentRepository  → In-memory storage
```

#### Sample Content Sources
- **Videos**: Google Cloud Storage public samples
- **Images**: Unsplash public URLs  
- **PDF**: Local asset `assets/sample.pdf`

# EagleTV - Quick Reference Guide

## 📋 Document Overview

This folder contains comprehensive documentation for the EagleTV Flutter application project.

### Main Documents

1. **[PRD.md](file:///home/vinay/Desktop/EagleTV_Flutter/docs/PRD.md)** - Complete Product Requirements Document
   - Executive summary and app identity
   - User roles and permissions
   - Complete design system specifications
   - 40+ user stories across all features
   - Technical architecture and implementation details
   - Development phases and timeline

---

## 🎯 Quick Access

### Design System

**Colors**
- Primary: `#1C375C` (Trust, stability)
- Secondary: `#A4C3B2` (Calm, empathy)  
- Accent: `#E07A5F` (CTA emphasis, ≤10% usage)
- Background Light: `#E9EBF0`
- Surface: `#FFFFFF`
- Text Primary: `#333333`

**Typography**
- Font: Plus Jakarta Sans
- Sizes: H1(30sp), H2(24sp), H3(20sp), Body(16sp), Caption(12sp)
- Line height: 1.4-1.6x

**Spacing**
- Base unit: 8dp
- Card radius: 8dp
- Button radius: 20dp
- Input radius: 10dp

---

## 👥 User Roles

| Role | Upload | Moderate | Latest Content | Delay |
|------|--------|----------|----------------|-------|
| **Admin** | ✅ Immediate | ✅ Yes | ✅ | None |
| **Reporter** | ✅ Pending | ❌ | ✅ | None |
| **Public** | ❌ | ❌ | ❌ | 7 days |
| **Subscribed** | ❌ | ❌ | ✅ | None |

---

## 🔑 Core Features

### Authentication
- Phone + OTP login (test OTP: `123456`)
- Persistent session
- One-time role selection

### Feed
- Way2News-style flip cards (vertical)
- Offline-first (50 cached posts)
- Pull-to-refresh
- Infinite scroll

### Content Creation
- Admin: Immediate publish
- Reporter: Queue for approval
- Image/video upload
- Background upload with progress

### Moderation (Admin Only)
- Approve/reject/edit posts
- Pending queue management
- Rejection reasons

### Profile
- Stats display
- Edit profile
- Posts grid (3 columns)
- Bookmarks

### Search & Explore
- User search
- Category filtering
- Hashtag support

### Internationalization
- English ⟷ Telugu
- Complete UI translation
- Language switcher in settings

---

## 📦 Tech Stack

```yaml
# Key Dependencies
google_fonts: ^6.1.0          # Plus Jakarta Sans
sqflite: ^2.3.0               # Local database
provider: ^6.1.1              # State management
image_picker: ^1.0.5          # Media selection
connectivity_plus: ^5.0.2     # Network status
share_plus: ^7.2.1            # Share functionality
```

---

## 🗄️ Database Schema

### Tables
- `users` - User profiles and roles
- `posts` - Content with metadata
- `user_interactions` - Likes, bookmarks
- `sync_queue` - Offline action queue
- `session` - Authentication tokens

---

## 📱 Screen Flow

```
Launch → Splash → Auth Check
         ├─ Authenticated → Feed
         └─ Not Authenticated → Phone Login → OTP → Role Selection → Feed

Bottom Nav: Home | Explore | Create+ | Profile
           (Create+ visible for Admin/Reporter only)
```

---

## 🎨 Design Principles

✅ **DO**
- Calm, professional aesthetics
- One content card = one focus
- Soft shadows and rounded corners
- Smooth, ease-in-out animations (200-300ms)
- Minimum 48dp touch targets
- 4.5:1 contrast ratio

❌ **DON'T**
- Pure black (#000000)
- Neon or saturated colors
- Gradients or glassmorphism
- Bouncy or playful animations
- Sharp corners
- Aggressive effects

---

## 🚀 Development Phases

1. **Foundation** (Week 1-2): Setup, theme, auth, database
2. **Core Features** (Week 3-5): Feed, interactions, offline
3. **Content Creation** (Week 6-7): Post creation, moderation
4. **Profile** (Week 8): Profile view/edit, stats
5. **Search** (Week 9): Search, filters, hashtags
6. **i18n** (Week 10): English/Telugu translations
7. **Polish** (Week 11-12): Animations, testing, optimization

---

## 📊 Success Metrics

- Session duration: > 5 minutes
- App crash rate: < 0.5%
- Sync success rate: > 95%
- Feed scroll: 60 FPS
- App launch: < 2 seconds

---

## 📝 Next Steps

1. ✅ Review this PRD document
2. Set up Flutter project with dependencies
3. Implement design system (colors, typography, theme)
4. Create database schema
5. Build authentication flow
6. Develop core feed functionality

---

**For complete details, refer to [PRD.md](file:///home/vinay/Desktop/EagleTV_Flutter/docs/PRD.md)**

**Document Version**: 1.0  
**Last Updated**: 2025-12-14

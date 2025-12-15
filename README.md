# 📱 EagleTV - Flutter News App

> A **Way2News-inspired** vertical flip feed news application built with Flutter, featuring internationalization, role-based access, and content moderation.

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## ✨ Features

### 🎨 User Experience
- **Vertical Flip Feed** - Way2News-style full-screen content cards
- **Swipe Navigation** - Smooth vertical scrolling with snap-to-page
- **Immersive UI** - 60/40 media-to-content ratio with gradient overlays
- **Minimal Chrome** - Distraction-free content-first design

### 🌍 Internationalization
- **3 Languages**: English, Telugu (తెలుగు), Hindi (हिंदी)
- **Dynamic Switching** - Change language on-the-fly
- **Comprehensive Translations** - All UI elements localized

### 👥 User System
- **Phone Authentication** - OTP-based login
- **Role-Based Access** - Admin, Reporter, Public user roles
- **Profile Management** - Edit profile, upload picture, manage bio
- **Session Persistence** - Stay logged in across app restarts

### 📝 Content Management
- **Create Posts** - Admin/Reporter content creation
- **Media Upload** - Image and video support with cropping
- **Moderation System** - Admin approval/rejection workflow
- **Status Tracking** - Pending, Approved, Rejected states

### 🔍 Discovery
- **Smart Search** - Debounced search for posts and users
- **Category Browsing** - 8 color-coded categories
- **Hashtag Navigation** - Clickable hashtags and trending tags
- **Trending Posts** - Most-liked content from last 7 days

### 💾 Data & Storage
- **SQLite Database** - Offline-first architecture
- **Local Caching** - Fast content loading
- **Bookmarks** - Save posts for later
- **Session Management** - Persistent authentication

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.0 or higher
- Dart 2.17 or higher
- Android Studio / VS Code
- Android SDK (for Android builds)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-repo/eagletv-flutter.git
   cd eagletv-flutter
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

4. **Build APK**
   ```bash
   # Debug APK
   flutter build apk --debug

   # Release APK
   flutter build apk --release
   ```

---

## 📁 Project Structure

```
lib/
├── app/
│   ├── routes/               # Navigation & routing
│   └── theme/                # Design system (colors, typography)
├── core/
│   ├── localization/         # i18n translations
│   └── services/             # Core services (DB, language, etc.)
├── features/
│   ├── auth/                 # Authentication flow
│   ├── feed/                 # Content feed & creation
│   ├── moderation/           # Admin moderation panel
│   ├── profile/              # User profiles
│   └── search/               # Search & explore
└── shared/
    ├── models/               # Data models
    └── widgets/              # Reusable UI components
```

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.x |
| **Language** | Dart 2.17+ |
| **Database** | SQLite (sqflite) |
| **Storage** | SharedPreferences |
| **Media** | image_picker, image_cropper |
| **Share** | share_plus |
| **State Management** | StatefulWidget |

---

## 🎯 Key Highlights

### Way2News-Style Feed
- Full-screen vertical cards
- 60% media / 40% content split
- Gradient overlays for readability
- Floating action buttons
- Color-coded category badges

### Internationalization
- English (default)
- Telugu (తెలుగు)
- Hindi (हिंदी)
- Language toggle on every card
- Persistent language preference

### Role-Based Access Control
- **Admin**: Create posts, moderate, manage users
- **Reporter**: Create posts
- **Public**: View and interact with content

### Content Moderation
- Approve/reject posts
- Rejection reasons
- Status indicators
- Admin-only panel

---

## 📋 Features List

### Implemented ✅
- [x] Phone authentication with OTP
- [x] Role selection (Admin/Reporter/Public)
- [x] Vertical flip feed
- [x] Content creation (Admin/Reporter)
- [x] Image/video upload with cropping
- [x] Post moderation (Admin)
- [x] User profiles
- [x] Edit profile
- [x] Posts grid view
- [x] Bookmarks
- [x] Search (posts & users)
- [x] Category filtering
- [x] Hashtag support
- [x] Explore screen
- [x] Trending posts
- [x] Internationalization (3 languages)
- [x] Post detail screen
- [x] More options menu
- [x] Like/bookmark/share

### Future Enhancements 🔮
- [ ] Cloud media storage
- [ ] Comments system
- [ ] Follow/unfollow users
- [ ] Push notifications
- [ ] Real-time sync
- [ ] Video player
- [ ] Stories
- [ ] Dark mode
- [ ] Analytics

---

## 🗄️ Database Schema

### Tables
- **users**: User profiles and authentication
- **posts**: Content with metadata
- **user_interactions**: Likes and bookmarks

### Relationships
- Users → Posts (one-to-many)
- Users → Interactions → Posts (many-to-many via bookmarks)

---

## 🌐 Internationalization

All UI strings are centralized in `app_localizations.dart`:

```dart
String get home => _translate('Home', 'హోమ్', 'होम');
String get explore => _translate('Explore', 'అన్వేషించండి', 'एक्सप्लोर');
```

Translations cover:
- UI labels
- Actions
- Categories
- Time formats
- Error messages

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👏 Acknowledgments

- **Design Inspiration**: Way2News
- **Framework**: Flutter by Google
- **Community**: Flutter developers worldwide

---

## 📊 Project Status

**Version**: 1.0.0  
**Status**: ✅ Complete (All 7 phases delivered)  
**Last Updated**: December 14, 2024

---

Made with ❤️ using Flutter

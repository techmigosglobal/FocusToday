# EagleTV Role-Based User Guide

This guide provides a comprehensive overview of the different user roles in the EagleTV application, detailing their workflows, specific features, and limitations.

## Table of Contents
1. [Overview](#overview)
2. [Role: Admin](#role-admin)
3. [Role: Reporter](#role-reporter)
4. [Role: Public User](#role-public-user)
5. [Feature Comparison Matrix](#feature-comparison-matrix)

---

## Overview

EagleTV supports three distinct user roles, each designed for a specific purpose within the news ecosystem:
- **Admin**: Full control over content and users.
- **Reporter**: Content creators who submit news for approval.
- **Public User**: Consumers of news who can interact and subscribe.

---

## Role: Admin

**Persona**: The Editor-in-Chief or System Administrator.
**Primary Goal**: Manage the platform, approve content ensure quality, and oversee user activity.

### Workflow
1.  **Login**: Access the app via Phone or Email.
2.  **Dashboard**: Sees the latest content (no restrictions).
3.  **Content Creation**: Can create Posts (Text, Image, Video) via the FAB (Floating Action Button). Posts are **published immediately**.
4.  **Moderation**:
    - Access the **Moderation Dashboard** (via Settings or dedicated tab).
    - Review **Pending Posts** from Reporters.
    - **Approve**: Publishes the post to the main feed.
    - **Reject**: Sends the post back to the Reporter with status update.
5.  **User Management**: View user profiles and manage permissions (if applicable).

### Features
- ✅ **Instant Publishing**: No approval required for own posts.
- ✅ **Moderation Tools**: Approve/Reject content from others.
- ✅ **Full Access**: View all content immediately, including premium content.
- ✅ **Analytics**: View engagement stats for all posts.

### Limitations
- None (Superuser access).

---

## Role: Reporter

**Persona**: Journalists, Field Reporters, or Contributors.
**Primary Goal**: Create high-quality news content and build an audience.

### Workflow
1.  **Login**: Access the app.
2.  **Content Creation**:
    - Click `+` to create a new post.
    - Add Headlines, Content, Images/Videos/PDFs.
    - **Submit**: Post enters **Pending** state.
3.  **Status Tracking**:
    - View status of submitted posts in **Profile > Posts**.
    - Status badges: `PENDING`, `APPROVED`, `REJECTED`.
4.  **Feed Access**: Can view approved posts from other reporters and admins.

### Features
- ✅ **Content Creation**: Tools for rich media posts.
- ✅ **Latest Access**: View latest news without subscription delay.
- ✅ **Profile Stats**: Track followers and post views.

### Limitations
- ❌ **Approval Required**: Posts must be approved by an Admin before appearing in the public feed.
- ❌ **No Moderation**: Cannot approve/reject other users' posts.

---

## Role: Public User

**Persona**: General audience, News readers.
**Primary Goal**: Consume news, stay updated, and interact with content.

### Workflow
1.  **Onboarding**: Select Language (English, Telugu, Hindi) and Topics.
2.  **Feed Consumption**:
    - Browse the **Home Feed** with Flip Animation.
    - View **Recent News** (Standard Access).
    - **Premium News**: Timed delay (e.g., 7 days) for free users? (Implied by "Access latest content" feature of others).
3.  **Interaction**:
    - **Like** posts.
    - **Bookmark** stories for later.
    - **Share** interesting news.
4.  **Subscription**:
    - Upgrade to **Premium/Elite** plans via Profile/Settings.
    - Unlocks **Latest Content** immediately.
    - Removes Ads (if applicable).

### Features
- ✅ **Localized Experience**: News in preferred language.
- ✅ **Interaction**: Like, Bookark, Share.
- ✅ **PDF Viewer**: Read full documents/newspapers in-app.
- ✅ **Dark Mode**: Personalized viewing experience.

### Limitations
- ❌ **No Uploads**: Cannot create posts.
- ❌ **Content Delay**: May not see breaking news immediately without subscription (depending on configuration).
- ❌ **Read-Only**: Cannot modify content.

---

## Feature Comparison Matrix

| Feature | Admin | Reporter | Public User (Free) | Public User (Premium) |
| :--- | :---: | :---: | :---: | :---: |
| **View Feed** | ✅ | ✅ | ✅ | ✅ |
| **Create Posts** | ✅ (Instant) | ✅ (Approval) | ❌ | ❌ |
| **Approve/Reject** | ✅ | ❌ | ❌ | ❌ |
| **Latest Content** | ✅ | ✅ | ❌ (Delayed) | ✅ |
| **Like/Bookmark** | ✅ | ✅ | ✅ | ✅ |
| **Edit Profile** | ✅ | ✅ | ✅ | ✅ |
| **Analytics** | ✅ (Full) | ✅ (Own) | ❌ | ❌ |
| **Subscription** | N/A | N/A | Optional | Active |

---

## Technical Notes for Developers
- **UserRole Enum**: Defined in `lib/shared/models/user.dart`.
- **Permissions**:
    - `canUploadContent`: Admin & Reporter.
    - `canModerate`: Admin only.
    - `hasLatestContentAccess`: Admin, Reporter, & Subscribed Users.
- **Role Selection**: Occurs during onboarding (`RoleSelectionScreen`). To test different roles, create a new account or clear app data.

## Demo Credentials
To login via **Phone Number**:
- **OTP**: `123456`
- **Admin**: Any number ending in `111` (e.g., `9999999111`)
- **Reporter**: Any number ending in `222` (e.g., `9999999222`)
- **Public User**: Any other number (e.g., `9999999333`)

# CRII App UI/UX - Visual Reference & Design System
**Date:** March 19, 2026

---

## 🎨 Visual Mockup Comparisons

### TOP BAR

```
BEFORE:
┌─────────────────────────────┐
│ [LOGO] ... [🔔] [EN]       │
└─────────────────────────────┘

AFTER:
┌─────────────────────────────────────────┐
│ ┌────────────────┐      [🔔:3] [⚙️]     │
│ │ CRII           │                      │
│ │ Civil Rights   │                      │
│ │ News           │                      │
│ └────────────────┘                      │
├─────────────────────────────────────────┤
(divider line)
```

**Key Changes:**
- ✅ Logo + subtitle in branded container
- ✅ Notification badge shows count (red=1-3, orange=4+)
- ✅ Settings/menu icon
- ✅ Dividing line below

---

### POST CARD

```
BEFORE:
┌────────────────────────┐
│                        │
│      IMAGE (55%)       │
│                        │
├────────────────────────┤
│ Author: Name | 5d ago  │
│                        │
│ Post Title             │
│ Snippet text here...   │
│                        │
│ [🔖] [💬] [❤️] [↗️]    │
└────────────────────────┘


AFTER:
┌────────────────────────┐
│ 📰 News      [🔥 Trend]│  ← Category + trending
│                        │
│       IMAGE (60%)      │
│    (with gradient)     │
│    (overlay at bottom) │
│                        │
├────────────────────────┤
│ [Avatar] Author Name   │
│           5 days ago   │
│                        │
│ BIG, BOLD POST TITLE   │
│ That Spans 2 Lines     │
│                        │
│ Snippet preview text   │
│ that shows the gist    │
│ of the post...         │
│                        │
│ ❤️ 234  💬 45          │  ← Visible counts
│                        │
│ [🔖 Save]  [↗️ Share]  │
└────────────────────────┘
```

**Key Changes:**
- ✅ Category badge with icon (📰, 📝, 📸, etc.)
- ✅ Trending indicator (🔥) for popular posts
- ✅ Media section 60% (vs 55%)
- ✅ Gradient overlay at bottom for text readability
- ✅ Better author attribution (visible avatar + name)
- ✅ Headline size increased to 18-20px, bold
- ✅ Engagement counts visible (❤️ 234, 💬 45)
- ✅ Better button labels

---

### CATEGORY FILTERS

```
BEFORE:
[All] [News] [Articles] [Videos]
^tight spacing, no counts, small

AFTER:
┌─────────────────────────────────────────┐
│ [All (45)] [📰 News (28)] [📝 Articles]│ →
│            (selected, bright blue)      │
├─────────────────────────────────────────┤

Key improvements:
- Post counts per category: (45), (28)
- Category icons: 📰, 📝, 📸, 🎬
- Selected state: Bright blue background
- Better spacing & larger touch targets
- 🔥 badge on trending categories
```

---

### ENGAGEMENT BUTTONS

```
BEFORE:
[🔖] [💬] [❤️] [↗️]
^Icons only, small, no counts

AFTER:
Button Row 1:
[❤️ 234]  [💬 45]    |    [🔖]  [↗️]
 ^^^^^^     ^^^^^^         (Right side)
 Like       Comment        Save  Share
 (counts)   (counts)

Key improvements:
- Like button shows count
- Comment button shows count  
- Better visual separation
- Larger touch targets (44x44+ minimum)
- Red color when liked (#DC2626)
- Haptic feedback on tap
```

---

## 🎨 Design System Reference

### COLOR PALETTE

```
┌─────────────────────────────────────────────┐
│ PRIMARY COLORS (Brand Identity)             │
├─────────────────────────────────────────────┤
│ 🔵 Primary Blue        #1E3A8A              │
│    Used for: Buttons, Links, Selected items │
│    Meaning: Trust, stability, authority     │
│                                              │
│ 🔵 Primary Dark        #0F172A              │
│    Used for: Hover states, Depth            │
│                                              │
│ 🔴 Accent Red          #DC2626              │
│    Used for: Likes, Urgent actions          │
│    Meaning: Passion, Justice, Action        │
│                                              │
│ 🟢 Accent Green        #059669              │
│    Used for: Success, Approval, Growth      │
│                                              │
│ 🟠 Featured Orange     #F97316              │
│    Used for: Trending, Highlights           │
└─────────────────────────────────────────────┘
```

### NEUTRAL PALETTE

```
Light Mode:
- Background:      #F8FAFC (Very light gray-blue)
- Surface:         #FFFFFF (White)
- Text Primary:    #1A202C (90% black)
- Text Secondary:  #64748B (60% opacity)
- Divider:         #E2E8F0 (Light gray)

Dark Mode:
- Background:      #0F172A (Very dark blue)
- Surface:         #1A1A2E (Dark gray-blue)
- Text Primary:    #F1F5F9 (Near white)
- Text Secondary:  #94A3B8 (60% opacity)
- Divider:         #334155 (Dark gray)
```

### TYPOGRAPHY SCALE

```
Headline Large:    24px / 32px • Bold (700) • Line height 1.3
Headline Small:    20px / 28px • Bold (700) • Line height 1.3

Post Title:        18px / 26px • Bold (700) • Line height 1.3
Body Large:        16px / 24px • Regular (400) • Line height 1.6
Body Medium:       14px / 20px • Regular (400) • Line height 1.6

Labels:            12px / 16px • Semi-bold (600) • Line height 1.4
Small Text:        11px / 16px • Medium (500) • Line height 1.4
Caption:           10px / 14px • Medium (500) • Line height 1.4

Font Family: Inter (Google Fonts) or system fonts
- Android: Roboto
- iOS: San Francisco
- Web: Inter, -apple-system, BlinkMacSystemFont
```

### SPACING SCALE (8dp base)

```
Spacing 2xs:    4dp   (Minor adjustments)
Spacing xs:     8dp   (Tight spacing between elements)
Spacing sm:    12dp   (Standard small gap)
Spacing md:    16dp   (Default padding/margin)
Spacing lg:    24dp   (Large gap between sections)
Spacing xl:    32dp   (Extra large gap)

Application:
- Button padding:       16dp horizontal, 12dp vertical
- Card padding:         16dp (all sides)
- List item padding:    16dp horizontal, 12dp vertical
- Section margin:       24dp between major sections
- Page margin:          16dp sides
```

### BORDER RADIUS

```
Tight:   4dp    (Used for small elements)
Small:   8dp    (Buttons, small cards)
Medium: 12dp    (Standard cards, chips)
Large:  16dp    (FABs, large containers)
Full:  999dp    (Fully rounded, pills)

Application:
- Buttons:          8dp
- Cards:           12dp
- Category chips:  20dp (fully rounded)
- Image corners:    0-12dp (depends on usage)
```

### ELEVATION / SHADOWS

```
Surface Elevation (Cards, subtle):
  Box Shadow: 0 1px 2px rgba(0,0,0,0.05)

Component Elevation (Buttons, inputs):
  Box Shadow: 0 2px 8px rgba(0,0,0,0.10)

Dialog Elevation (Modals, popovers):
  Box Shadow: 0 4px 16px rgba(0,0,0,0.15)

Status:
- Default:    No shadow (flat)
- Hover/Focus: Surface elevation
- Active:     Component elevation
```

---

## 📐 COMPONENT SPECIFICATIONS

### Button Sizes

```
Large Button (Primary CTAs):
- Height: 48dp
- Padding: 0 24dp
- Font: 14px Bold
- Min touch target: 48x48dp
- Example: "Create Post", "Sign In"

Medium Button (Secondary actions):
- Height: 40dp
- Padding: 0 16dp
- Font: 12px Semi-bold
- Min touch target: 40x44dp (width flexible)
- Example: "Save", "Like"

Small Button (Tertiary actions):
- Height: 36dp
- Padding: 0 12dp
- Font: 11px Semi-bold
- Example: "Share", "Options"

Icon Button (Touch):
- Min size: 44x44dp
- Can contain: Icon (24dp) or Icon + label
- Example: Like, Comment, Share

Floating Action Button:
- Size: 56x56dp
- Icon size: 24dp
- Elevation: Component (3)

# CRII — iOS Build & Deployment Guide

## Prerequisites

- **macOS** (required for iOS builds — cannot build iOS on Linux/Windows)
- **Xcode 15+** from Mac App Store
- **Apple Developer Account** ($99/year for App Store distribution)
- **CocoaPods**: `sudo gem install cocoapods`

## Initial Setup

### 1. Open the iOS project

```bash
cd /path/to/CRII_Flutter_With_Backend
flutter pub get
cd ios
pod install
cd ..
```

### 2. Open in Xcode

```bash
open ios/Runner.xcworkspace
```

### 3. Configure Signing

In Xcode:
1. Select **Runner** project in the navigator
2. Select **Runner** target → **Signing & Capabilities** tab
3. Check **Automatically manage signing**
4. Select your **Team** (Apple Developer account)
5. Set **Bundle Identifier**: `com.crii.eagletv` (or your preferred ID)

### 4. Update Info.plist

The following permissions are already configured but verify them at `ios/Runner/Info.plist`:

```xml
<!-- Camera -->
<key>NSCameraUsageDescription</key>
<string>CRII needs camera access to capture photos and videos for posts</string>

<!-- Photo Library -->
<key>NSPhotoLibraryUsageDescription</key>
<string>CRII needs photo library access to select media for posts</string>

<!-- Microphone (for video recording) -->
<key>NSMicrophoneUsageDescription</key>
<string>CRII needs microphone access for video recording</string>

<!-- Push Notifications -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>

<!-- Location (if used for emergency alerts) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>CRII needs location access for emergency alerts in your area</string>
```

### 5. Firebase iOS Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project → Add iOS app
3. Bundle ID: `com.crii.eagletv`
4. Download `GoogleService-Info.plist`
5. Place it in `ios/Runner/GoogleService-Info.plist`
6. Verify it's added to the Xcode project (drag into Runner group)

### 6. Push Notifications (APNs)

1. In Xcode → Runner → **Signing & Capabilities** → **+ Capability**
2. Add **Push Notifications**
3. Add **Background Modes** → check **Remote notifications**
4. In Apple Developer portal → Certificates → create APNs key
5. Upload the APNs key to Firebase → Project Settings → Cloud Messaging → iOS

### 7. Razorpay iOS

Already configured via Flutter plugin. Ensure in `ios/Podfile`:
```ruby
platform :ios, '13.0'  # Minimum iOS 13 for Razorpay
```

## Building

### Debug (Simulator)

```bash
flutter run -d ios
```

### Release (Physical Device)

```bash
flutter build ios --release
```

### Archive for App Store

```bash
flutter build ipa
```

The IPA will be at `build/ios/ipa/`.

## App Store Submission

### 1. Create App Store Connect Record

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. **My Apps** → **+** → **New App**
3. Fill: Platform (iOS), Name (CRII / EagleTV), Bundle ID, SKU

### 2. Upload via Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. **Product** → **Archive**
3. In Organizer → **Distribute App** → **App Store Connect** → **Upload**

### 3. App Review Checklist

- [ ] App screenshots for all required device sizes
- [ ] App description, keywords, categories
- [ ] Privacy policy URL (required)
- [ ] Support URL
- [ ] Marketing URL (optional)
- [ ] Age rating (likely 4+ or 12+ depending on content)
- [ ] In-App Purchases configured (for donations)

## iOS-Specific Considerations

### 1. Payment Guidelines

Apple requires in-app purchases for digital goods/services. However, **charitable donations** can use external payment (UPI/Razorpay) IF:
- The organization is a registered nonprofit
- You link to an external website for donations
- You don't process the payment within the app

Otherwise, use Apple's StoreKit for in-app donations (Apple takes 15-30%).

### 2. App Transport Security (ATS)

If your backend uses HTTP (not HTTPS), add to `Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**For production**: Use HTTPS only and remove this exception.

### 3. Notification Permissions

iOS requires explicit user permission for notifications. Already handled by:
- `firebase_messaging` requests permission on first use
- `flutter_local_notifications` handles iOS presentation options

### 4. Universal Links (Deep Linking)

For the share feature to open the app:
1. Add Associated Domains capability in Xcode
2. Add: `applinks:yourdomain.com`
3. Host `apple-app-site-association` file on your domain

### 5. Testing

- **TestFlight**: Upload builds to test with real users before App Store
- **Simulator**: Test on multiple iPhone sizes (SE, 14, 15 Pro Max)
- **Real device**: Test push notifications (don't work on simulator)

## Common iOS Build Issues

| Issue | Solution |
|-------|----------|
| `CocoaPods not installed` | `sudo gem install cocoapods` |
| `Pod install fails` | `cd ios && pod deintegrate && pod install` |
| `Signing error` | Check team/bundle ID in Xcode |
| `Module not found` | `cd ios && rm -rf Pods && pod install` |
| `Minimum deployment target` | Set `platform :ios, '13.0'` in Podfile |
| `Bitcode error` | Add `ENABLE_BITCODE = NO` in Xcode Build Settings |

# Android Publish Readiness (2026-03-26)

## Release posture
- Branch strategy: Android-only release branch
- Build target: Play App Bundle (`.aab`)
- Cleartext policy: Blocked in production (`android:usesCleartextTraffic="false"`)
- Dev/profile HTTP: Allowed via debug/profile manifests + network security config

## Versioning
- App version updated to `1.0.2+3` in `pubspec.yaml`

## Signing identity (release)
- Keystore: `android/upload-keystore.jks`
- Alias: `upload`
- SHA-1: `E0:CD:B4:9A:A5:40:CB:16:AE:11:3A:9B:13:9A:6D:FC:26:8C:FD:77`
- SHA-256: `97:4F:A6:4E:57:62:0E:E8:7D:F2:81:C3:E9:76:AE:92:BD:E2:D8:B2:09:C0:CA:84:81:AE:5D:AF:75:F0:3D:E2`

## Play Console declaration checklist
- Permissions in manifest reviewed:
  - `CAMERA`
  - `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`
  - `RECORD_AUDIO`
  - `POST_NOTIFICATIONS`
  - `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`
- Ensure Data Safety form reflects actual runtime data use and sharing.
- Ensure notifications/foreground behavior is documented in app content.

## Runtime smoke checklist (manual)
- Launch app on Android 13+ device
- Sign in with production-like account
- Feed load + scroll
- Upload image and verify rendering
- Send and receive FCM notification, open deep link target
- Verify no HTTP-only endpoint dependency in release path

## Build verification commands
- `flutter build appbundle --release`
- `cd android && ./gradlew app:signingReport`
- `jarsigner -verify -verbose -certs build/app/outputs/bundle/release/Focus_today_app-release.aab`

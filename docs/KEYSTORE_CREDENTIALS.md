# EagleTV Keystore Credentials

> ⚠️ **KEEP THIS FILE SECURE** - Never share these credentials publicly.

## Keystore Information

| Property | Value |
|----------|-------|
| **Keystore File** | `android/upload-keystore.jks` |
| **Keystore Type** | JKS |
| **Key Alias** | `upload` |

## Passwords

| Property | Value |
|----------|-------|
| **Store Password** | `EagleTV@2024Secure` |
| **Key Password** | `EagleTV@2024Secure` |

## Certificate Details

| Property | Value |
|----------|-------|
| **Owner** | CN=EagleTV, OU=Mobile Development, O=EagleTV, L=India, ST=India, C=IN |
| **Valid From** | December 30, 2025 |
| **Valid Until** | May 17, 2053 |
| **Algorithm** | 2048-bit RSA |

## Certificate Fingerprints

| Algorithm | Fingerprint |
|-----------|-------------|
| **SHA1** | `E0:CD:B4:9A:A5:40:CB:16:AE:11:3A:9B:13:9A:6D:FC:26:8C:FD:77` |
| **SHA256** | `97:4F:A6:4E:57:62:0E:E8:7D:F2:81:C3:E9:76:AE:92:BD:E2:D8:B2:09:C0:CA:84:81:AE:5D:AF:75:F0:3D:E2` |

## Important Notes

1. **Google Play App Signing**: If you're using Google Play App Signing, the SHA1 fingerprint above is your **upload key**. Google will sign the final APK with their key.

2. **Firebase Configuration**: If you need to add SHA1 fingerprint to Firebase:
   - Go to Firebase Console → Project Settings → Your Apps → Android
   - Add the SHA1 fingerprint: `E0:CD:B4:9A:A5:40:CB:16:AE:11:3A:9B:13:9A:6D:FC:26:8C:FD:77`

3. **Backup**: Keep a secure backup of the keystore file and this credentials document. If you lose the keystore, you won't be able to update your app on the Play Store.

## Build Commands

```bash
# Build release APK
flutter build apk --release

# Build release App Bundle (for Play Store)
flutter build appbundle --release
```

## File Locations

- **Keystore**: `/home/vinay/Desktop/EagleTV_Flutter/android/upload-keystore.jks`
- **Key Properties**: `/home/vinay/Desktop/EagleTV_Flutter/android/key.properties`
- **Release AAB**: `/home/vinay/Desktop/EagleTV_Flutter/build/app/outputs/bundle/release/app-release.aab`

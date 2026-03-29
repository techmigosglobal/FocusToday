# Focus Today OTP Auto-Read Checklist (Android)

Use this checklist whenever OTP auto-read is not filling automatically.

## Required SMS Template Format (SMS Retriever)

1. Message starts with `<#>` in the first line.
2. Message contains only one OTP code in the expected format (`4` digits in app).
3. Message includes your Android app signature hash in the last line.
4. Avoid extra numeric strings that can confuse OTP parsing.

Example format:

```text
<#> Your Focus Today OTP is 1234.
Do not share this code with anyone.
FA+9qCX9VSu
```

## Dashboard and App Checks

1. Verify Msg91 template used for OTP includes the app hash.
2. Confirm template is approved and active for production route.
3. Confirm app package/signing configuration used to generate hash matches release build.
4. Confirm app is running on Android device (auto-read is Android-only).

## Runtime Verification

1. OTP screen should show `Auto-read is active on Android` while listening.
2. If no compatible SMS is received within timeout, UI should show `Auto-read timed out`.
3. User can always use `Paste OTP` or `Resend OTP` fallback.
4. Telemetry events to monitor:
   - `otp_autoread_listening`
   - `otp_autoread_success`
   - `otp_autoread_timeout`
   - `otp_autoread_unavailable`

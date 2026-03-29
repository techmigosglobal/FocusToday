# MSG91 OTP Authentication — Analysis & Troubleshooting

This document analyzes the MSG91 OTP flow in the CRII application and identifies potential failure points.

---

## 1. End-to-End Flow Overview

```
┌─────────────────┐     sendOTP(phone)      ┌──────────────────┐
│  Flutter App    │ ──────────────────────► │  MSG91 Widget    │
│  PhoneLogin     │ ◄────────────────────── │  API             │
└────────┬────────┘     reqId               └──────────────────┘
         │
         │  Navigate to OTPVerificationScreen(phoneNumber, reqId)
         ▼
┌─────────────────┐     verifyOTP(reqId,otp) ┌──────────────────┐
│  Flutter App    │ ───────────────────────► │  MSG91 Widget    │
│  OTP Verify     │ ◄─────────────────────── │  verify OTP API  │
└────────┬────────┘     access_token         └──────────────────┘
         │
         │  POST /auth/verify-otp { phone_number, access_token }
         ▼
┌─────────────────┐     verifyAccessToken    ┌──────────────────┐
│  NestJS Backend │ ───────────────────────► │  MSG91           │
│  AuthService    │ ◄─────────────────────── │  verifyAccessToken│
└────────┬────────┘     success/fail         └──────────────────┘
         │
         │  Return user + JWT tokens
         ▼
    Session saved, user logged in
```

---

## 2. Credential Usage

| Component | Credential | Purpose |
|-----------|------------|---------|
| **Flutter** | `MSG91_WIDGET_ID` | Widget identification |
| **Flutter** | `MSG91_TOKEN_AUTH` (or `MSG91_AUTH_KEY`) | Widget token for sendOTP, retryOTP, verifyOTP |
| **Backend** | `MSG91_AUTH_KEY` | Used as `authkey` in verifyAccessToken API |
| **Backend** | `MSG91_TOKEN_AUTH` (fallback) | Included in verifyAuthKeys for retry |

**Important:** MSG91 has two credential types:
- **Widget token (tokenAuth)** — Used by client SDK; format often like `490052TCJ8zE6VO697338afP1`
- **API auth key (authkey)** — Used for server-side verifyAccessToken; format like `490052AM5DWgMU69734236P1`

The backend tries two payload formats: (1) `authkey` + `access-token`, (2) `tokenAuth` + `widgetId` + `access-token`. Widget-generated tokens typically require the **widget token (MSG91_TOKEN_AUTH)** with format 2. **Ensure both MSG91_AUTH_KEY and MSG91_TOKEN_AUTH are set in the backend `.env`** on the production server.

---

## 3. Potential Failure Points

### A. OTP Not Received (SMS Never Arrives)

**Possible causes:**
1. **sendOTP fails with 401** — Widget credentials invalid
   - Check `MSG91_WIDGET_ID` and `MSG91_TOKEN_AUTH` in Flutter `.env`
   - Ensure widget token is **enabled** in MSG91 dashboard
   - Run: `bash scripts/msg91-widget-check.sh --send 91XXXXXXXXXX`

2. **MSG91 account / DLT / Sender ID**
   - DLT (Do Not Disturb) registration must be complete for India
   - Sender ID and template must be approved
   - Check MSG91 dashboard for OTP logs and delivery status

3. **Mobile Integration not enabled**
   - In MSG91 OTP Widget config, **Mobile Integration** must be enabled
   - See: https://msg91.com/help/sendotp/integrate-otp-widget-into-mobile-application

4. **Phone number format**
   - Flutter sends identifier as `91` + 10 digits (e.g. `919876543210`)
   - Ensure no leading zeros or extra characters

### B. sendOTP Returns Success but OTP Not Delivered

- Check MSG91 OTP logs in dashboard
- Verify SMS balance and DLT compliance
- Try a different number to rule out carrier issues

### C. verifyOTP Fails (Invalid OTP / No Access Token)

1. **Access token extraction**
   - SDK may return token in `access-token`, `accessToken`, `access_token`, or `message`
   - Your `_extractAccessToken` already checks these keys
   - Add debug: `debugPrint('[OTPVerification] verifyOTP response: $response')` and inspect the actual keys

2. **reqId expiry**
   - reqId typically valid for a few minutes; if user waits too long, verifyOTP will fail

3. **retryOTP parameter mismatch**
   - Your code uses `retryType: 'text'`
   - MSG91 SDK docs sometimes show `retryChannel: 11` for SMS
   - If resend fails, try `retryChannel: 11` instead of `retryType: 'text'`

### D. Backend verifyAccessToken Fails

1. **Wrong auth key**
   - `verifyAccessToken` expects `authkey` (API key), not widget token
   - Ensure backend `.env` has `MSG91_AUTH_KEY` set
   - Test manually:
     ```bash
     cd backend_nestjs
     ACCESS_TOKEN="<actual_msg91_access_token>" \
     MSG91_AUTH_KEY="<your_api_auth_key>" \
     bash scripts/msg91-verify-token.sh
     ```

2. **Token format**
   - Ensure access token from Flutter is passed as-is (no truncation or encoding)

3. **Dev mode**
   - In development (`NODE_ENV=development`), backend **bypasses** Msg91 verification and accepts any access_token

### E. Backend Not Reachable

- Flutter uses `API_BASE_URL` from `.env` (e.g. `https://techmigos.com/eagletv_nestjs/nestjs_app/api/v1`)
- On Android emulator, default is `http://10.0.2.2:3001/api/v1` if no `API_BASE_URL`
- On physical device, use machine LAN IP or production URL

---

## 4. Configuration Checklist

### Flutter `.env` (project root)

```
MSG91_WIDGET_ID=366177684853393831393932
MSG91_TOKEN_AUTH=490052TCJ8zE6VO697338afP1
MSG91_AUTH_KEY=490052AM5DWgMU69734236P1
API_BASE_URL=https://techmigos.com/eagletv_nestjs/nestjs_app/api/v1
```

### Backend `backend_nestjs/.env`

```
MSG91_AUTH_KEY=490052AM5DWgMU69734236P1
MSG91_WIDGET_ID=366177684853393831393932
# Optional: MSG91_VERIFY_AUTH_KEYS=key1,key2 for multiple keys
```

### MSG91 Dashboard

- [ ] Widget created and Mobile Integration enabled
- [ ] Widget token generated and **enabled**
- [ ] DLT template and sender ID approved (India)
- [ ] Sufficient SMS balance

---

## 5. Debugging Commands

**1. Test widget credentials (from project root):**
```bash
bash scripts/msg91-widget-check.sh
# Optional: send live OTP
bash scripts/msg91-widget-check.sh --send 919876543210
```

**2. Test backend token verification:**
```bash
cd backend_nestjs
# After getting access_token from Flutter verifyOTP success
ACCESS_TOKEN="<paste_access_token_here>" bash scripts/msg91-verify-token.sh
```

**3. Flutter debug logs:**
- Look for `[Msg91Service]`, `[PhoneLogin]`, `[OTPVerification]` in console
- Check `[Msg91Service] sendOTP response:` and `[Msg91Service] verifyOTP response:` for exact payloads

---

## 6. Summary of Likely Issues

| Symptom | Most Likely Cause |
|---------|-------------------|
| "OTP service authentication failed" | Wrong MSG91_WIDGET_ID or MSG91_TOKEN_AUTH |
| OTP never arrives | DLT/sender ID, Mobile Integration off, or SMS balance |
| "Verification failed: No access token" | SDK returns token in different key; check response in debug |
| Backend returns 401 on verify-otp | verifyAccessToken fails — wrong MSG91_AUTH_KEY or token format |
| Works in dev, fails in prod | NODE_ENV=development bypasses OTP; prod uses real Msg91 verification |

---

## 7. Next Steps

1. Run `scripts/msg91-widget-check.sh` to validate widget credentials
2. Enable debug logging and capture `sendOTP` and `verifyOTP` responses
3. If OTP is received but backend fails, run `msg91-verify-token.sh` with the access token
4. Verify backend `MSG91_AUTH_KEY` matches the API key from MSG91 dashboard (not the widget token)

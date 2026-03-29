# MSG91 OTP Fix — Production Deployment

## What Was Fixed

1. **Backend** (`auth.service.ts`): Now tries multiple MSG91 verifyAccessToken formats:
   - `authkey` + `access-token` in body
   - `authkey` in header + `access-token` in body
   - `tokenAuth` + `widgetId` + `access-token` in body
   - Variants with `accessToken` and `access_token` parameter names
2. **Backend env**: `MSG91_TOKEN_AUTH` added to `.env.production` — **required** for widget-generated tokens
3. **Backend logging**: Warnings logged for each MSG91 response (helps diagnose failures)
4. **Flutter**: Clearer 401 error message for users

## Log Analysis Summary

From your logs:
- sendOTP: OK (reqId: `36626f6b7979333931383631`)
- verifyOTP: OK (access token in `message` field — JWT format)
- POST /auth/verify-otp: **401 Unauthorized** — backend's MSG91 verifyAccessToken failed

## Required: Update Production Backend .env

On the production server (techmigos.com / cPanel), add **MSG91_TOKEN_AUTH** to the backend `.env`:

```bash
# In /home/techmigo/.../nestjs_app/.env (or wherever your Node app .env lives)

# Add or ensure these MSG91 vars exist:
MSG91_AUTH_KEY=490052AM5DWgMU69734236P1
MSG91_TOKEN_AUTH=490052TCJ8zE6VO697338afP1   # <-- THIS IS CRITICAL
MSG91_WIDGET_ID=366177684853393831393932
```

Then **restart the Node.js app** from cPanel.

## Deploy Updated Backend Code

1. Build and deploy the updated `auth.service.ts` to production
2. Ensure `.env` on the server includes `MSG91_TOKEN_AUTH`
3. Restart the app

## If Still Failing

1. **Token expiry**: MSG91 access tokens are short-lived. Complete OTP entry and backend call within a few minutes.
2. **MSG91 dashboard**: Verify widget token is **enabled** and matches `MSG91_TOKEN_AUTH`
3. **Test verify script** (with a fresh token from the app):
   ```bash
   cd backend_nestjs
   ACCESS_TOKEN="<paste_fresh_token_from_flutter_debug_log>" \
   MSG91_TOKEN_AUTH=490052TCJ8zE6VO697338afP1 \
   MSG91_WIDGET_ID=366177684853393831393932 \
   bash scripts/msg91-verify-token.sh
   ```
   Note: The script uses `authkey`; if it fails, the backend now also tries `tokenAuth`+`widgetId`.

# Production Observability Setup

This document covers:
1. Crashlytics alerts (mobile client)
2. OTP latency/error dashboards
3. Backend Cloud Functions error alerts

Project: `crii-focus-today`

## 0) Billing-Safe OTP Runtime Guardrails

`verifyMsg91OtpAndExchangeToken` supports runtime instance tuning via env vars:
- `OTP_VERIFY_MIN_INSTANCES` (default `0`, allowed `0..2`)
- `OTP_VERIFY_MAX_INSTANCES` (default `3`, allowed `1..30`)

Recommended production starting point:
- `OTP_VERIFY_MIN_INSTANCES=0` (lowest idle cost)
- `OTP_VERIFY_MAX_INSTANCES=3` (conservative burst cap)

If login latency under peak load needs improvement, raise warm pool gradually:
- `OTP_VERIFY_MIN_INSTANCES=1` (small warm pool, additional fixed cost)

Always couple changes with latency dashboard checks and billing budget alerts.

## 1) Crashlytics Alerts (Mobile)

Crashlytics is already initialized in app startup and now OTP failures are also
reported as non-fatal events.

### Configure alerts in Firebase Console
1. Open Firebase Console -> Crashlytics -> Alerts.
2. Create alerts to the production on-call email/Slack:
   - New fatal issue
   - Fatal crash-free users drops below 99.5%
   - New non-fatal issue (OTP/Auth filters)
3. Add owners:
   - Primary: mobile on-call
   - Secondary: backend on-call

### OTP-specific non-fatal signals now emitted
- `send_otp_failed`
- `otp_verify_failed`
- `otp_verify_access_token_missing`
- `otp_session_setup_failed`
- `otp_verify_exception`

Use these for saved searches in Crashlytics issue list.

## 2) OTP Latency/Error Dashboard

### Backend latency source
`verifyMsg91OtpAndExchangeToken` now returns optional `debug` timing fields:
- `verify_token_ms`
- `user_lookup_and_upsert_ms`
- `firestore_upsert_ms`
- `custom_token_ms`
- `total_ms`

### Client latency source
The app emits OTP perf logs:
- `[PhoneLogin][Perf] sendOtpMs=...`
- `[OTPVerification][Perf] msg91VerifyMs=...`
- `[OTPVerification][Perf] exchangeAndSignInMs=...`
- `[OTPVerification][Perf] totalVerifyFlowMs=...`

### Product telemetry event for dashboarding
After successful OTP login:
- Collection: `telemetry_events`
- Event: `otp_verify_success`
- Group: `system`
- Metadata:
  - `msg91_verify_ms`
  - `exchange_signin_ms`
  - `server_total_ms`
  - `server_verify_token_ms`
  - `server_lookup_upsert_ms`

Recommended dashboard tiles:
1. OTP success count per hour (`event_name=otp_verify_success`)
2. p50/p95 `metadata.server_total_ms`
3. p50/p95 `metadata.exchange_signin_ms`
4. Backend function error count (`verifyMsg91OtpAndExchangeToken`)

## 3) Backend Function Error Alerts

Use the automation script to create Monitoring alert policies:

```bash
bash scripts/setup_observability_alerts.sh crii-focus-today your-alerts@company.com
```

This creates:
1. `prod-functions-error-count`
2. `prod-otp-verify-latency-p95`

After running:
1. Confirm the email notification channel in Google Cloud Monitoring.
2. Test alert routing with a temporary low threshold and revert.

## 4) Handoff Checklist

1. Crashlytics alerts configured and verified.
2. Monitoring policies created and visible.
3. On-call email/Slack recipients confirmed.
4. OTP dashboard shared with production team.
5. Runbook link included in release notes.

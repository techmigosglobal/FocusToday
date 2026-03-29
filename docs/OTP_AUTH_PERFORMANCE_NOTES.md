# OTP Auth Performance Notes

## Callable: `verifyMsg91OtpAndExchangeToken`

The response remains backward-compatible:

- Existing keys:
  - `ok`
  - `custom_token`
  - `user`
- New optional key:
  - `debug` (timing-only metadata)

### `debug` fields (optional)

- `verify_token_ms`
- `user_lookup_and_upsert_ms`
- `firestore_upsert_ms`
- `custom_token_ms`
- `total_ms`

Clients must treat `debug` as optional and ignore missing keys.

## Client flow optimization

- `AuthRepository.verifyAndSaveSession(...)` now returns:
  - `isSuccess`
  - `errorMessage`
  - optional `user`
  - optional `diagnostics`
- OTP screen uses `result.user` immediately and falls back to `restoreSession()`
  if needed, preserving existing behavior.

## Latency checkpoints logged in app

- `PhoneLogin`: `sendOtpMs`, `otpScreenNavigationMs`
- `OTPVerification`: `msg91VerifyMs`, `exchangeAndSignInMs`, `navigateMs`, `totalVerifyFlowMs`

#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash scripts/setup_observability_alerts.sh <PROJECT_ID> <ALERT_EMAIL>
#
# Example:
#   bash scripts/setup_observability_alerts.sh crii-focus-today sre@company.com

PROJECT_ID="${1:-}"
ALERT_EMAIL="${2:-}"

if [[ -z "${PROJECT_ID}" || -z "${ALERT_EMAIL}" ]]; then
  echo "Usage: bash scripts/setup_observability_alerts.sh <PROJECT_ID> <ALERT_EMAIL>"
  exit 1
fi

CHANNEL_BASE_CMD=()
if gcloud monitoring channels list --help >/dev/null 2>&1; then
  CHANNEL_BASE_CMD=(gcloud monitoring channels)
elif gcloud beta monitoring channels list --help >/dev/null 2>&1; then
  CHANNEL_BASE_CMD=(gcloud beta monitoring channels)
else
  echo "[obs] ERROR: gcloud monitoring channels commands are unavailable."
  echo "[obs] Run once (interactive) then retry:"
  echo "      gcloud components install beta"
  exit 2
fi

POLICY_BASE_CMD=()
if gcloud monitoring policies list --help >/dev/null 2>&1; then
  POLICY_BASE_CMD=(gcloud monitoring policies)
elif gcloud beta monitoring policies list --help >/dev/null 2>&1; then
  POLICY_BASE_CMD=(gcloud beta monitoring policies)
else
  echo "[obs] ERROR: gcloud monitoring policies commands are unavailable."
  echo "[obs] Run once (interactive) then retry:"
  echo "      gcloud components install beta"
  exit 2
fi

echo "[obs] Creating/using email notification channel for ${ALERT_EMAIL}..."
CHANNEL_ID="$(
  "${CHANNEL_BASE_CMD[@]}" list \
    --project="${PROJECT_ID}" \
    --format="value(name)" \
    --filter="type=\"email\" AND labels.email_address=\"${ALERT_EMAIL}\"" \
    | head -n 1
)"

if [[ -z "${CHANNEL_ID}" ]]; then
  CHANNEL_ID="$(
    "${CHANNEL_BASE_CMD[@]}" create \
      --project="${PROJECT_ID}" \
      --type="email" \
      --channel-labels="email_address=${ALERT_EMAIL}" \
      --display-name="Prod Alerts (${ALERT_EMAIL})" \
      --format="value(name)"
  )"
fi

echo "[obs] Using channel: ${CHANNEL_ID}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

cat > "${TMP_DIR}/policy_function_errors.json" <<EOF
{
  "displayName": "prod-functions-error-count",
  "combiner": "OR",
  "conditions": [
    {
      "displayName": "Cloud Functions non-ok > 20 in 5m",
      "conditionThreshold": {
        "filter": "resource.type=\\"cloud_function\\" AND metric.type=\\"cloudfunctions.googleapis.com/function/execution_count\\" AND metric.labels.status!=\\"ok\\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 20,
        "duration": "0s",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "perSeriesAligner": "ALIGN_DELTA",
            "crossSeriesReducer": "REDUCE_SUM",
            "groupByFields": []
          }
        ],
        "trigger": { "count": 1 }
      }
    }
  ],
  "notificationChannels": ["${CHANNEL_ID}"],
  "enabled": true,
  "alertStrategy": {
    "autoClose": "1800s"
  }
}
EOF

cat > "${TMP_DIR}/policy_otp_latency_p95.json" <<EOF
{
  "displayName": "prod-otp-verify-latency-p95",
  "combiner": "OR",
  "conditions": [
    {
      "displayName": "OTP verify function p95 > 3s (10m)",
      "conditionThreshold": {
        "filter": "resource.type=\\"cloud_function\\" AND resource.labels.function_name=\\"verifyMsg91OtpAndExchangeToken\\" AND metric.type=\\"cloudfunctions.googleapis.com/function/execution_times\\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 3000000000,
        "duration": "600s",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "perSeriesAligner": "ALIGN_PERCENTILE_95",
            "crossSeriesReducer": "REDUCE_MEAN",
            "groupByFields": ["resource.labels.function_name"]
          }
        ],
        "trigger": { "count": 1 }
      }
    }
  ],
  "notificationChannels": ["${CHANNEL_ID}"],
  "enabled": true,
  "alertStrategy": {
    "autoClose": "3600s"
  }
}
EOF

upsert_policy() {
  local display_name="$1"
  local file_path="$2"
  local existing
  existing="$(
    "${POLICY_BASE_CMD[@]}" list \
      --project="${PROJECT_ID}" \
      --format="value(name)" \
      --filter="displayName=\"${display_name}\"" \
      | head -n 1
  )"

  if [[ -z "${existing}" ]]; then
    echo "[obs] Creating alert policy: ${display_name}"
    "${POLICY_BASE_CMD[@]}" create \
      --project="${PROJECT_ID}" \
      --policy-from-file="${file_path}" >/dev/null
    return
  fi

  echo "[obs] Updating alert policy: ${display_name} (${existing})"
  "${POLICY_BASE_CMD[@]}" update "${existing}" \
    --project="${PROJECT_ID}" \
    --policy-from-file="${file_path}" >/dev/null
}

dedupe_policy_by_display_name() {
  local display_name="$1"
  local matches=()
  while IFS= read -r policy_name; do
    [[ -z "${policy_name}" ]] && continue
    matches+=("${policy_name}")
  done < <(
    "${POLICY_BASE_CMD[@]}" list \
      --project="${PROJECT_ID}" \
      --format="value(name)" \
      --filter="displayName=\"${display_name}\""
  )

  if [[ "${#matches[@]}" -le 1 ]]; then
    return
  fi

  local keep
  keep="$(printf '%s\n' "${matches[@]}" | sort | head -n 1)"
  echo "[obs] Deduping ${display_name}: keeping ${keep}"
  for policy_id in "${matches[@]}"; do
    if [[ "${policy_id}" == "${keep}" ]]; then
      continue
    fi
    echo "[obs] Removing duplicate policy: ${policy_id}"
    "${POLICY_BASE_CMD[@]}" delete "${policy_id}" \
      --project="${PROJECT_ID}" \
      --quiet >/dev/null
  done
}

upsert_policy "prod-functions-error-count" "${TMP_DIR}/policy_function_errors.json"
upsert_policy "prod-otp-verify-latency-p95" "${TMP_DIR}/policy_otp_latency_p95.json"

dedupe_policy_by_display_name "prod-functions-error-count"
dedupe_policy_by_display_name "prod-otp-verify-latency-p95"

echo "[obs] Done. Ensured:"
echo "  - prod-functions-error-count (idempotent)"
echo "  - prod-otp-verify-latency-p95 (idempotent, 3s = 3,000,000,000 ns)"
echo
echo "[obs] Next step: confirm email channel in Google Cloud Monitoring."

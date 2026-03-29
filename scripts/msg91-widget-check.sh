#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

usage() {
  cat <<USAGE
Usage:
  bash scripts/msg91-widget-check.sh [--env /path/to/.env] [--send <91xxxxxxxxxx>]

Checks Msg91 widget credentials with getWidgetProcess.
Optionally sends OTP to a number with --send.

Env vars read:
  MSG91_WIDGET_ID     (required)
  MSG91_TOKEN_AUTH    (preferred)
  MSG91_AUTH_KEY      (fallback if MSG91_TOKEN_AUTH is empty)
USAGE
}

SEND_TO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_FILE="$2"
      shift 2
      ;;
    --send)
      SEND_TO="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

WIDGET_ID="${MSG91_WIDGET_ID:-}"
TOKEN_AUTH="${MSG91_TOKEN_AUTH:-${MSG91_AUTH_KEY:-}}"

mask() {
  local v="${1:-}"
  if [[ -z "$v" ]]; then
    printf '<empty>'
    return
  fi
  local len=${#v}
  if (( len <= 8 )); then
    printf '%s****' "${v:0:2}"
    return
  fi
  printf '%s****%s' "${v:0:4}" "${v:len-4:4}"
}

if [[ -z "$WIDGET_ID" ]]; then
  echo "MSG91_WIDGET_ID is missing"
  exit 1
fi
if [[ -z "$TOKEN_AUTH" ]]; then
  echo "MSG91_TOKEN_AUTH/MSG91_AUTH_KEY missing"
  exit 1
fi

echo "Widget : $(mask "$WIDGET_ID")"
echo "Token  : $(mask "$TOKEN_AUTH")"

printf '\n[1/2] Checking getWidgetProcess...\n'
GET_URL="https://control.msg91.com/api/v5/widget/getWidgetProcess?widgetId=${WIDGET_ID}&tokenAuth=${TOKEN_AUTH}"
GET_RESP="$(curl -sS "$GET_URL")"
echo "$GET_RESP"

if echo "$GET_RESP" | rg -q '"code"\s*:\s*"?401"?|"AuthenticationFailure"'; then
  printf '\nResult: FAILED (widget authentication error 401)\n'
  echo "Action: Set correct MSG91_TOKEN_AUTH for this widget and keep token enabled in Msg91 dashboard."
  exit 2
fi

if [[ -n "$SEND_TO" ]]; then
  printf '\n[2/2] Sending OTP to %s...\n' "$SEND_TO"
  SEND_RESP="$(curl -sS -X POST 'https://control.msg91.com/api/v5/widget/sendOtpMobile' \
    -H 'Content-Type: application/json' \
    --data "{\"widgetId\":\"${WIDGET_ID}\",\"tokenAuth\":\"${TOKEN_AUTH}\",\"identifier\":\"${SEND_TO}\"}")"
  echo "$SEND_RESP"
else
  printf '\n[2/2] Skipped sendOtpMobile. Use --send <91xxxxxxxxxx> to test live OTP.\n'
fi

printf '\nResult: OK (credentials look valid).\n'

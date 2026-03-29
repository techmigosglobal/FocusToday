#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   PROJECT_ID=crii-focus-today ./scripts/min_cost_backend_commands.sh
#
# Purpose:
#   Keep only OTP callable backend live for low-cost launch mode.

: "${PROJECT_ID:?Set PROJECT_ID, for example PROJECT_ID=crii-focus-today}"

echo ">> Setting active project: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

echo ">> Enabling only Cloud Functions API"
gcloud services enable cloudfunctions.googleapis.com

echo ">> Disabling non-essential billable backend APIs"
gcloud services disable run.googleapis.com --force || true
gcloud services disable eventarc.googleapis.com --force || true
gcloud services disable cloudscheduler.googleapis.com --force || true
gcloud services disable sqladmin.googleapis.com --force || true
gcloud services disable artifactregistry.googleapis.com --force || true
gcloud services disable cloudbuild.googleapis.com --force || true

echo ">> Deploying only OTP callable function"
firebase deploy --only functions:verifyMsg91OtpAndExchangeToken --project "${PROJECT_ID}"

echo ">> Deploying hosting config (preview route fallback to index.html)"
firebase deploy --only hosting --project "${PROJECT_ID}"

cat <<'EOF'
Done.

Recommended launch build flags:
  --dart-define=INTERACTION_CALLABLE_ENABLED=false
  --dart-define=ROLE_MANAGEMENT_CALLABLE_ENABLED=false
  --dart-define=STORAGE_CONFIG_CALLABLE_ENABLED=false
  --dart-define=CAMPAIGN_CALLABLE_ENABLED=false
  --dart-define=FUNCTION_PREVIEW_ROUTE_ENABLED=false
EOF

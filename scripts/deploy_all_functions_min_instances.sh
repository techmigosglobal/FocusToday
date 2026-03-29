#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   PROJECT_ID=crii-focus-today ./scripts/deploy_all_functions_min_instances.sh
#
# Purpose:
#   Enable required APIs and deploy all Cloud Functions with min instances at 0.

: "${PROJECT_ID:?Set PROJECT_ID, for example PROJECT_ID=crii-focus-today}"

echo ">> Setting active project: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

echo ">> Enabling required Cloud Functions Gen2 APIs"
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable eventarc.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable cloudscheduler.googleapis.com

echo ">> Deploying all functions (region + limits come from source config)"
firebase deploy --only functions --project "${PROJECT_ID}"

echo ">> Deploying hosting (includes /p/** -> servePostPreview rewrite)"
firebase deploy --only hosting --project "${PROJECT_ID}"

cat <<'EOF'
Done.

Current code defaults:
  OTP minInstances default: 0
  OTP maxInstances default: 3
  Global maxInstances default: 3

If needed, override at deploy/runtime:
  OTP_VERIFY_MIN_INSTANCES=0
  OTP_VERIFY_MAX_INSTANCES=3
EOF

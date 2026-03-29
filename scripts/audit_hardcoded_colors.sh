#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Intentional exceptions where direct black/white overlays are required for media readability.
ALLOWLIST_REGEX='(video_player_screen\.dart|pdf_viewer_screen\.dart|pdf_thumbnail\.dart|optimized_image\.dart)'

# Find direct hardcoded color usage.
matches="$(rg -n "\bColors\.[a-zA-Z_]+|\bColor\(0x[0-9A-Fa-f]{8}\)" lib/features --glob '*.dart' || true)"

if [[ -z "$matches" ]]; then
  echo "Dark-mode audit passed: no hardcoded colors found in lib/features/**."
  exit 0
fi

violations="$(echo "$matches" | rg -v "$ALLOWLIST_REGEX" || true)"

if [[ -n "$violations" ]]; then
  echo "Dark-mode audit failed. Hardcoded colors detected outside allowlist:"
  echo "$violations"
  exit 1
fi

echo "Dark-mode audit passed (remaining matches are in allowlisted media files)."

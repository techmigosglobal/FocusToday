#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_DIR="$ROOT_DIR/archives"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_PATH="$ARCHIVE_DIR/ci4_backend_backup_${TIMESTAMP}.tar.gz"

TARGETS=(
  "backend_ci4"
  "backend_ci4_deploy"
)

EXECUTE_REMOVE=0

for arg in "$@"; do
  case "$arg" in
    --execute)
      EXECUTE_REMOVE=1
      ;;
    --help|-h)
      echo "Usage: ./scripts/safe-remove-ci4-backend.sh [--execute]"
      echo "  default: create backup only (no deletion)"
      echo "  --execute: create backup and remove CI4 folders"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

EXISTING_TARGETS=()
for target in "${TARGETS[@]}"; do
  if [ -d "$ROOT_DIR/$target" ]; then
    EXISTING_TARGETS+=("$target")
  fi
done

if [ "${#EXISTING_TARGETS[@]}" -eq 0 ]; then
  echo "No CI4 backend folders found. Nothing to archive/remove."
  exit 0
fi

mkdir -p "$ARCHIVE_DIR"

echo "Creating CI4 backup archive..."
echo "Archive: $ARCHIVE_PATH"
(
  cd "$ROOT_DIR"
  tar -czf "$ARCHIVE_PATH" "${EXISTING_TARGETS[@]}"
)

echo "Validating archive integrity..."
tar -tzf "$ARCHIVE_PATH" > /dev/null
echo "Backup created and validated."

if [ "$EXECUTE_REMOVE" -eq 0 ]; then
  echo "Dry run complete. No folders were removed."
  echo "To remove CI4 folders after backup, run:"
  echo "  ./scripts/safe-remove-ci4-backend.sh --execute"
  exit 0
fi

echo "Removing CI4 backend folders..."
for target in "${EXISTING_TARGETS[@]}"; do
  rm -rf "$ROOT_DIR/$target"
  echo "Removed: $target"
done

echo "CI4 backend folders removed safely."
echo "Restore command if needed:"
echo "  tar -xzf \"$ARCHIVE_PATH\" -C \"$ROOT_DIR\""

#!/bin/bash
# Shared helper for daily_backup.sh and rebuild_and_install.sh: maintains a
# small status JSON on the Mac and pushes it to the device so the app's
# home screen can show whether the automation is actually working
# (WorkoutLog/Utilities/DeviceSyncStatus.swift reads it).
#
# Expects DEVICE_ID, BUNDLE_ID, LOG_DIR and LOG_FILE to already be set by
# the caller. Requires `jq`.

STATUS_FILE_LOCAL="$LOG_DIR/device_status.json"

# update_and_push_status '<jq filter>' [jq args...]
# Example: update_and_push_status '.lastBackupPulledAt = $now' --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
update_and_push_status() {
  local jq_filter="$1"
  shift

  [[ -f "$STATUS_FILE_LOCAL" ]] || echo '{}' > "$STATUS_FILE_LOCAL"

  local tmp
  tmp=$(mktemp)
  if jq "$@" "$jq_filter" "$STATUS_FILE_LOCAL" > "$tmp"; then
    mv "$tmp" "$STATUS_FILE_LOCAL"
  else
    rm -f "$tmp"
    echo "Failed to update local status file." >> "$LOG_FILE"
    return 0
  fi

  xcrun devicectl device copy to \
    --device "$DEVICE_ID" \
    --domain-type appDataContainer \
    --domain-identifier "$BUNDLE_ID" \
    --source "$STATUS_FILE_LOCAL" \
    --destination Documents/workoutlog_status.json >> "$LOG_FILE" 2>&1 || \
    echo "Status push failed." >> "$LOG_FILE"
}

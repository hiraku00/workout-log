#!/bin/bash
# Shared helper for daily_backup.sh and rebuild_and_install.sh: maintains a
# small status JSON on the Mac and pushes it to the device so the app's
# home screen can show whether the automation is actually working
# (WorkoutLog/Utilities/DeviceSyncStatus.swift reads it). Also owns log
# rotation, since both callers run every 30 minutes and would otherwise
# accumulate one log file per run forever.
#
# Expects DEVICE_ID, BUNDLE_ID, LOG_DIR and LOG_FILE to already be set by
# the caller (see config.sh). Requires `jq`.

STATUS_FILE_LOCAL="$LOG_DIR/device_status.json"

# Deletes log files older than LOG_RETENTION_DAYS (default 14) from LOG_DIR.
# Call this once per run, after LOG_FILE for the current run already exists,
# so a script never deletes the very file it's about to write to.
prune_old_logs() {
  local retention_days="${LOG_RETENTION_DAYS:-14}"
  find "$LOG_DIR" -maxdepth 1 -name '*.log' -mtime +"$retention_days" -delete 2>/dev/null || true
}

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

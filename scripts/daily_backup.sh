#!/bin/bash
# Pulls the app's auto-exported JSON (Documents/workoutlog_backup.json) off
# the device daily, independent of the 5-day rebuild cycle. Keeps the
# "how much data could I lose" window to at most ~1 day instead of ~5.
# Run daily via LaunchAgent com.hiraku.workoutlog.dailybackup.plist.

set -euo pipefail

BUNDLE_ID="com.hiraku.WorkoutLog"
DEVICE_ID="2BD60440-485E-5D54-BE5A-23FE8E220A05"
LOG_DIR="$HOME/Library/Logs/WorkoutLogRebuild"
BACKUP_DIR="$HOME/Library/Application Support/WorkoutLogBackups"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"
LOG_FILE="$LOG_DIR/dailybackup_$(date +%Y%m%d_%H%M%S).log"

echo "=== $(date) : daily backup check ===" >> "$LOG_FILE"

DEVICE_LINE=$(xcrun devicectl list devices 2>>"$LOG_FILE" | grep "$DEVICE_ID" || true)
if [[ -z "$DEVICE_LINE" ]] || echo "$DEVICE_LINE" | grep -qE "unavailable|shutdown"; then
  echo "Device $DEVICE_ID not reachable. Skipping. ($DEVICE_LINE)" >> "$LOG_FILE"
  exit 0
fi

xcrun devicectl device copy from \
  --device "$DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE_ID" \
  --source Documents/workoutlog_backup.json \
  --destination "$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).json" >> "$LOG_FILE" 2>&1 || \
  echo "Backup pull failed (device locked, app never opened yet, etc)." >> "$LOG_FILE"

# Keep only the 30 most recent backups (shared pool with rebuild_and_install.sh).
ls -t "$BACKUP_DIR"/backup_*.json 2>/dev/null | tail -n +31 | while read -r old; do rm -f -- "$old"; done

echo "=== $(date) : done ===" >> "$LOG_FILE"

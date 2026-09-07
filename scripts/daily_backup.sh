#!/bin/bash
# Pulls the app's auto-exported JSON (Documents/workoutlog_backup.json) off
# the device, independent of the 5-day rebuild cycle. Run every 30 minutes
# via LaunchAgent com.hiraku.workoutlog.dailybackup.plist (StartInterval) —
# not a single fixed time of day, since betting on the phone being unlocked
# and reachable at one exact moment is unreliable. Most runs are a no-op
# either because a backup already succeeded today, or because the device
# isn't reachable; whichever run happens to be the first to catch the phone
# connected on a given day does the actual pull, and the rest skip.

set -euo pipefail

BUNDLE_ID="com.hiraku.WorkoutLog"
DEVICE_ID="2BD60440-485E-5D54-BE5A-23FE8E220A05"
LOG_DIR="$HOME/Library/Logs/WorkoutLogRebuild"
BACKUP_DIR="$HOME/Library/Application Support/WorkoutLogBackups"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"
LOG_FILE="$LOG_DIR/dailybackup_$(date +%Y%m%d_%H%M%S).log"

echo "=== $(date) : daily backup check ===" >> "$LOG_FILE"

# shellcheck source=lib_status.sh
source "$SCRIPT_DIR/lib_status.sh"

# Already got today's backup? Nothing left to do until tomorrow.
if ls "$BACKUP_DIR"/backup_"$(date +%Y%m%d)"_*.json > /dev/null 2>&1; then
  echo "Already backed up today. Skipping." >> "$LOG_FILE"
  exit 0
fi

DEVICE_LINE=$(xcrun devicectl list devices 2>>"$LOG_FILE" | grep "$DEVICE_ID" || true)
if [[ -z "$DEVICE_LINE" ]] || echo "$DEVICE_LINE" | grep -qE "unavailable|shutdown"; then
  echo "Device $DEVICE_ID not reachable. Skipping. ($DEVICE_LINE)" >> "$LOG_FILE"
  exit 0
fi

if xcrun devicectl device copy from \
  --device "$DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE_ID" \
  --source Documents/workoutlog_backup.json \
  --destination "$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).json" >> "$LOG_FILE" 2>&1; then
  update_and_push_status '.lastBackupPulledAt = $now | .lastBackupResult = "success"' \
    --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
else
  echo "Backup pull failed (device locked, app never opened yet, etc)." >> "$LOG_FILE"
  update_and_push_status '.lastBackupAttemptAt = $now | .lastBackupResult = "failed"' \
    --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi

# Keep only the 30 most recent backups (shared pool with rebuild_and_install.sh).
ls -t "$BACKUP_DIR"/backup_*.json 2>/dev/null | tail -n +31 | while read -r old; do rm -f -- "$old"; done

echo "=== $(date) : done ===" >> "$LOG_FILE"

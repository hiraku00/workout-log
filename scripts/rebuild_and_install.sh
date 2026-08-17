#!/bin/bash
# Rebuilds WorkoutLog and reinstalls it on the physical iPhone so the
# free-account provisioning profile (7-day validity) never expires.
# Run daily at 7am via LaunchAgent com.hiraku.workoutlog.rebuild.plist,
# but only actually builds once every REBUILD_INTERVAL_DAYS days.

set -euo pipefail

PROJECT_DIR="/Users/hiraku/Practice/gym-app"
SCHEME="WorkoutLog"
BUNDLE_ID="com.hiraku.WorkoutLog"
DEVICE_ID="2BD60440-485E-5D54-BE5A-23FE8E220A05"
LOG_DIR="$HOME/Library/Logs/WorkoutLogRebuild"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/WorkoutLog-cfclcjrmrzlbaybmoashsgdrhqap"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/WorkoutLog.app"
STATE_FILE="$LOG_DIR/last_success"
REBUILD_INTERVAL_DAYS=5
BACKUP_DIR="$HOME/Library/Application Support/WorkoutLogBackups"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"
LOG_FILE="$LOG_DIR/rebuild_$(date +%Y%m%d_%H%M%S).log"

echo "=== $(date) : daily check ===" >> "$LOG_FILE"

# Skip unless REBUILD_INTERVAL_DAYS have passed since the last successful run.
if [[ -f "$STATE_FILE" ]]; then
  LAST=$(cat "$STATE_FILE")
  NOW=$(date +%s)
  ELAPSED_DAYS=$(( (NOW - LAST) / 86400 ))
  if (( ELAPSED_DAYS < REBUILD_INTERVAL_DAYS )); then
    echo "Only $ELAPSED_DAYS day(s) since last success (need $REBUILD_INTERVAL_DAYS). Skipping." >> "$LOG_FILE"
    exit 0
  fi
fi

# Bail out (without updating STATE_FILE) if the device isn't reachable,
# whether via USB ("connected") or Wi-Fi ("available (paired)").
DEVICE_LINE=$(xcrun devicectl list devices 2>>"$LOG_FILE" | grep "$DEVICE_ID" || true)
if [[ -z "$DEVICE_LINE" ]] || echo "$DEVICE_LINE" | grep -qE "unavailable|shutdown"; then
  echo "Device $DEVICE_ID not reachable. Skipping. ($DEVICE_LINE)" >> "$LOG_FILE"
  exit 0
fi


# Pull the app's own auto-exported JSON backup (Documents/workoutlog_backup.json,
# written by the app itself on every background transition) off the device
# before touching the install. This only ever reads app data, never the
# device as a whole. Never call `devicectl device uninstall` in this script —
# an in-place `install` preserves the data container, an uninstall wipes it.
xcrun devicectl device copy from \
  --device "$DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE_ID" \
  --source Documents/workoutlog_backup.json \
  --destination "$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).json" >> "$LOG_FILE" 2>&1 || \
  echo "Backup pull failed or no backup file yet on device (ok on first run)." >> "$LOG_FILE"

# Keep only the 30 most recent backups.
ls -t "$BACKUP_DIR"/backup_*.json 2>/dev/null | tail -n +31 | while read -r old; do rm -f -- "$old"; done

cd "$PROJECT_DIR"

# Force Xcode to request a fresh profile from Apple instead of reusing a
# locally cached one that is still (barely) valid at build time but expires
# before the next scheduled rebuild.
rm -f ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.mobileprovision

xcodebuild \
  -project WorkoutLog.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -allowProvisioningUpdates \
  build >> "$LOG_FILE" 2>&1

xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" >> "$LOG_FILE" 2>&1

date +%s > "$STATE_FILE"
echo "=== $(date) : done ===" >> "$LOG_FILE"

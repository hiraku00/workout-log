#!/bin/bash
# Rebuilds WorkoutLog and reinstalls it on the physical iPhone so the
# free-account provisioning profile (7-day validity) never expires.
# Run every 30 minutes via LaunchAgent com.hiraku.workoutlog.rebuild.plist
# (StartInterval, not a fixed time of day — betting on the phone being
# unlocked and reachable at one exact moment is unreliable). The interval
# check below makes every run an instant no-op except on days a rebuild is
# actually due, and on those days it keeps retrying every 30 minutes until
# the device happens to be reachable, instead of getting only one shot.

set -euo pipefail

SCHEME="WorkoutLog"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/WorkoutLog-cfclcjrmrzlbaybmoashsgdrhqap"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/WorkoutLog.app"
REBUILD_INTERVAL_DAYS=5
PROFILE_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
PROFILE_REFRESH_THRESHOLD_DAYS=2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"

STATE_FILE="$LOG_DIR/last_success"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"
LOG_FILE="$LOG_DIR/rebuild_$(date +%Y%m%d_%H%M%S).log"

echo "=== $(date) : daily check ===" >> "$LOG_FILE"

# shellcheck source=lib_status.sh
source "$SCRIPT_DIR/lib_status.sh"
prune_old_logs

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


# Pull the app's own auto-exported JSON backup off the device before
# touching the install (same logic also runs every 30 minutes on its own
# via daily_backup.sh / com.hiraku.workoutlog.dailybackup.plist). --force
# skips daily_backup.sh's "already backed up today" skip, since without it
# this pull would be a no-op whenever today's backup already happened —
# leaving the copy pushed back to the device below (if needed) up to a day
# stale instead of just-taken. This only ever reads app data, never the
# device as a whole. Never call `devicectl device uninstall` in this
# script — an in-place `install` preserves the data container, an
# uninstall wipes it.
"$PROJECT_DIR/scripts/daily_backup.sh" --force >> "$LOG_FILE" 2>&1 || true

cd "$PROJECT_DIR"

# Only force a fresh profile fetch from Apple when the cached one for this
# app is actually close to expiring. Deleting it unconditionally on every
# run (the previous approach) had two side effects: it required a fresh
# "Trust This Developer" tap on every single successful rebuild instead of
# only when the profile genuinely renewed, and it made every rebuild
# depend on Xcode's account session being valid at that exact moment —
# when that session was flaky (see "No Accounts" failures in the logs),
# the build failed outright instead of falling back to the still-valid
# cached profile.
NEEDS_FRESH_PROFILE=true
for f in "$PROFILE_DIR"/*.mobileprovision; do
  [[ -e "$f" ]] || continue
  APP_ID=$(security cms -D -i "$f" 2>/dev/null | plutil -extract Entitlements.application-identifier raw -o - - 2>/dev/null || true)
  [[ "$APP_ID" == *".$BUNDLE_ID" ]] || continue

  EXPIRATION=$(security cms -D -i "$f" 2>/dev/null | plutil -extract ExpirationDate raw -o - - 2>/dev/null || true)
  EXPIRATION_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$EXPIRATION" +%s 2>/dev/null || echo 0)
  REMAINING_DAYS=$(( (EXPIRATION_EPOCH - $(date +%s)) / 86400 ))

  if (( REMAINING_DAYS > PROFILE_REFRESH_THRESHOLD_DAYS )); then
    NEEDS_FRESH_PROFILE=false
    echo "Cached profile $f still has $REMAINING_DAYS day(s) left. Reusing it." >> "$LOG_FILE"
  else
    echo "Cached profile $f has $REMAINING_DAYS day(s) left (<= $PROFILE_REFRESH_THRESHOLD_DAYS). Removing to force renewal." >> "$LOG_FILE"
    rm -f "$f"
  fi
done

if $NEEDS_FRESH_PROFILE; then
  echo "No usable cached profile found; xcodebuild will request one." >> "$LOG_FILE"
fi

# Wrapped with set +e/-e so a build or install failure can still push a
# status update to the device (visible on the app's home screen) before
# this script exits, instead of set -e killing it silently mid-way.
set +e
xcodebuild \
  -project WorkoutLog.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -allowProvisioningUpdates \
  build >> "$LOG_FILE" 2>&1
BUILD_EXIT=$?
set -e

if [[ $BUILD_EXIT -ne 0 ]]; then
  update_and_push_status '.lastRebuildAttemptAt = $now | .lastRebuildResult = "build_failed" | .rebuildIntervalDays = $days' \
    --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson days "$REBUILD_INTERVAL_DAYS"
  echo "Build failed. Exiting without updating STATE_FILE." >> "$LOG_FILE"
  exit 1
fi

set +e
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" >> "$LOG_FILE" 2>&1
INSTALL_EXIT=$?
set -e

if [[ $INSTALL_EXIT -ne 0 ]]; then
  update_and_push_status '.lastRebuildAttemptAt = $now | .lastRebuildResult = "install_failed" | .rebuildIntervalDays = $days' \
    --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson days "$REBUILD_INTERVAL_DAYS"
  echo "Install failed. Exiting without updating STATE_FILE." >> "$LOG_FILE"
  exit 1
fi

update_and_push_status \
  '.lastRebuildAttemptAt = $now | .lastRebuildSuccessAt = $now | .lastRebuildResult = "success" | .rebuildIntervalDays = $days' \
  --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson days "$REBUILD_INTERVAL_DAYS"

# Push the most recent Mac-side backup back onto the device as a "pending
# restore" file. The app merges it in by ID on next launch and skips any
# record that already exists, so this is a no-op when the data container
# survived the install and only matters when it didn't (profile fully
# expired, app was reinstalled from scratch, etc).
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/backup_*.json 2>/dev/null | head -n 1 || true)
if [[ -n "$LATEST_BACKUP" ]]; then
  xcrun devicectl device copy to \
    --device "$DEVICE_ID" \
    --domain-type appDataContainer \
    --domain-identifier "$BUNDLE_ID" \
    --source "$LATEST_BACKUP" \
    --destination Documents/workoutlog_backup_restore.json >> "$LOG_FILE" 2>&1 || \
    echo "Restore file push failed." >> "$LOG_FILE"
fi

date +%s > "$STATE_FILE"
echo "=== $(date) : done ===" >> "$LOG_FILE"

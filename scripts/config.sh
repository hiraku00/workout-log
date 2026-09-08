#!/bin/bash
# Shared configuration for rebuild_and_install.sh and daily_backup.sh.
# Previously each script hardcoded its own copy of DEVICE_ID/BUNDLE_ID/
# LOG_DIR/BACKUP_DIR, which meant switching devices required editing two
# files in sync. Source this before lib_status.sh.
#
# DEVICE_ID is environment-specific: run `xcrun devicectl list devices`
# and paste the Identifier of your own device here.

PROJECT_DIR="/Users/hiraku/Practice/gym-app"
BUNDLE_ID="com.hiraku.WorkoutLog"
DEVICE_ID="2BD60440-485E-5D54-BE5A-23FE8E220A05"
LOG_DIR="$HOME/Library/Logs/WorkoutLogRebuild"
BACKUP_DIR="$HOME/Library/Application Support/WorkoutLogBackups"

# ログの保持日数。rebuild_and_install.sh・daily_backup.shとも30分おきに
# 実行されるログファイルを毎回新規作成するため、これがないと際限なく増え続ける。
LOG_RETENTION_DAYS=14

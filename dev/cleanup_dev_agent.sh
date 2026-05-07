#!/usr/bin/env bash

set -euo pipefail

LABEL="com.deskpulse.test"
LAUNCH_DOMAIN="gui/$(id -u)"
JOB_REF="${LAUNCH_DOMAIN}/${LABEL}"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
TEST_SUPPORT_DIR="${HOME}/Library/Application Support/DeskPulseTest"
OUT_LOG_PATH="/tmp/deskpulse-test-out.txt"
ERR_LOG_PATH="/tmp/deskpulse-test-err.txt"

launchctl bootout "${LAUNCH_DOMAIN}" "${PLIST_PATH}" >/dev/null 2>&1 || true
launchctl bootout "${JOB_REF}" >/dev/null 2>&1 || true

rm -f "${PLIST_PATH}"
rm -f "${OUT_LOG_PATH}" "${ERR_LOG_PATH}"
rm -rf "${TEST_SUPPORT_DIR}"

echo "Test DeskPulse agent cleaned up."
echo "Removed plist, build, test CLI, logs, and test support files."

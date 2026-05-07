#!/usr/bin/env bash

set -euo pipefail

LABEL="com.deskpulse.test"
LAUNCH_DOMAIN="gui/$(id -u)"
HOMEBREW_JOB_REF="${LAUNCH_DOMAIN}/homebrew.mxcl.deskpulse"
TEST_SUPPORT_DIR="${HOME}/Library/Application Support/DeskPulseTest"
CLI_PATH="${TEST_SUPPORT_DIR}/bin/deskpulse"

if command -v deskpulse >/dev/null 2>&1 && {
    brew list --versions deskpulse >/dev/null 2>&1 ||
    launchctl print "${HOMEBREW_JOB_REF}" >/dev/null 2>&1
}; then
    echo "Stopping installed DeskPulse service..."
    deskpulse down >/dev/null 2>&1 || true
fi

if [[ ! -x "${CLI_PATH}" ]]; then
    echo "ERROR: test environment is not installed." >&2
    echo "Run: ./src/dev/install_dev_environment.sh" >&2
    exit 1
fi

"${CLI_PATH}" up

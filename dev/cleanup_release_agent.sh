#!/usr/bin/env bash

set -euo pipefail

LABEL="homebrew.mxcl.deskpulse"
LAUNCH_DOMAIN="gui/$(id -u)"
JOB_REF="${LAUNCH_DOMAIN}/${LABEL}"
CONFIG_DIR="${HOME}/Library/Application Support/DeskPulse"
OUT_LOG_PATH="/tmp/deskpulse-out.txt"
ERR_LOG_PATH="/tmp/deskpulse-err.txt"
BREW_FORMULA="aresukio/deskpulse/deskpulse"

if command -v deskpulse >/dev/null 2>&1; then
    deskpulse down >/dev/null 2>&1 || true
fi

if command -v brew >/dev/null 2>&1; then
    brew services stop "${BREW_FORMULA}" >/dev/null 2>&1 || true
    brew uninstall --force "${BREW_FORMULA}" >/dev/null 2>&1 || true

    brew_prefix="$(brew --prefix 2>/dev/null || true)"
    if [[ -n "${brew_prefix}" ]]; then
        rm -f "${brew_prefix}/var/log/deskpulse-out.txt" "${brew_prefix}/var/log/deskpulse-err.txt"
    fi
fi

launchctl bootout "${JOB_REF}" >/dev/null 2>&1 || true

rm -f "${OUT_LOG_PATH}" "${ERR_LOG_PATH}"
rm -rf "${CONFIG_DIR}"

echo "Release DeskPulse agent cleaned up."
echo "Stopped Homebrew service, uninstalled package, and removed release config/log files."

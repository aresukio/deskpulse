#!/usr/bin/env bash

set -euo pipefail

LABEL="com.deskpulse.agent"
LEGACY_LABEL="com.monitorservice.agent"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_PLIST="${SCRIPT_DIR}/${LABEL}.plist"
SOURCE_SWIFT="${SCRIPT_DIR}/DeskPulseAgent.swift"
SOURCE_CTL="${SCRIPT_DIR}/deskpulse"

INSTALL_DIR="${HOME}/Library/.DeskPulse"
DEST_SWIFT="${INSTALL_DIR}/DeskPulseAgent.swift"
USER_BIN_DIR="${HOME}/.local/bin"
DEST_CTL="${USER_BIN_DIR}/deskpulse"
LEGACY_DEST_SWIFT="${HOME}/Library/.MonitorService/MonitorService.swift"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
DEST_PLIST="${LAUNCH_AGENTS_DIR}/${LABEL}.plist"
LEGACY_DEST_PLIST="${LAUNCH_AGENTS_DIR}/${LEGACY_LABEL}.plist"
LAUNCH_DOMAIN="gui/$(id -u)"

require_file() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        echo "Missing required file: ${file}" >&2
        exit 1
    fi
}


require_file "${SOURCE_PLIST}"
require_file "${SOURCE_SWIFT}"
require_file "${SOURCE_CTL}"

terminate_existing_processes() {
    local targets=("${DEST_SWIFT}" "${LEGACY_DEST_SWIFT}")
    for target in "${targets[@]}"; do
        local pids
        pids="$(pgrep -f "${target}" || true)"
        if [[ -z "${pids}" ]]; then
            continue
        fi

        echo "Stopping existing DeskPulse process(es) for ${target}: ${pids}"
        kill ${pids} >/dev/null 2>&1 || true
        sleep 1

        local remaining
        remaining="$(pgrep -f "${target}" || true)"
        if [[ -n "${remaining}" ]]; then
            echo "Force stopping remaining process(es): ${remaining}"
            kill -9 ${remaining} >/dev/null 2>&1 || true
        fi
    done
}

stop_legacy_launch_agent() {
    launchctl bootout "${LAUNCH_DOMAIN}" "${LEGACY_DEST_PLIST}" >/dev/null 2>&1 || true
    launchctl disable "${LAUNCH_DOMAIN}/${LEGACY_LABEL}" >/dev/null 2>&1 || true
}

install_cli() {
    mkdir -p "${USER_BIN_DIR}"
    cp "${SOURCE_CTL}" "${DEST_CTL}"
    chmod +x "${DEST_CTL}"
}

mkdir -p "${INSTALL_DIR}" "${LAUNCH_AGENTS_DIR}"
cp "${SOURCE_SWIFT}" "${DEST_SWIFT}"
cp "${SOURCE_PLIST}" "${DEST_PLIST}"
install_cli

# launchd does not expand "~" in plist path values.
# Rewrite the copied plist with fully expanded absolute paths.
/usr/libexec/PlistBuddy -c "Set :ProgramArguments:1 ${DEST_SWIFT}" "${DEST_PLIST}"
/usr/libexec/PlistBuddy -c "Set :WorkingDirectory ${INSTALL_DIR}" "${DEST_PLIST}"

plutil -lint "${DEST_PLIST}" >/dev/null

launchctl bootout "${LAUNCH_DOMAIN}" "${DEST_PLIST}" >/dev/null 2>&1 || true
stop_legacy_launch_agent
terminate_existing_processes
launchctl bootstrap "${LAUNCH_DOMAIN}" "${DEST_PLIST}"
launchctl enable "${LAUNCH_DOMAIN}/${LABEL}" >/dev/null 2>&1 || true
launchctl kickstart -k "${LAUNCH_DOMAIN}/${LABEL}"

echo "Installed and started ${LABEL}"
echo "Swift: ${DEST_SWIFT}"
echo "Plist: ${DEST_PLIST}"
echo "CLI: ${DEST_CTL}"
if [[ ":${PATH}:" != *":${USER_BIN_DIR}:"* ]]; then
    echo "Note: add ${USER_BIN_DIR} to PATH to use 'deskpulse' globally."
fi
first_deskpulse="$(command -v deskpulse 2>/dev/null || true)"
if [[ -n "${first_deskpulse}" && "${first_deskpulse}" != "${DEST_CTL}" ]]; then
    echo "" >&2
    echo "Note: \`command -v deskpulse\` is ${first_deskpulse}, not this install." >&2
    echo "  Homebrew and other PATH entries can shadow ${DEST_CTL}." >&2
    echo "  Put ${USER_BIN_DIR} before them, or call: ${DEST_CTL} <args>" >&2
fi

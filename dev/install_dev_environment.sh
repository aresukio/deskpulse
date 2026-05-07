#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd -- "${SCRIPT_DIR}/../src" && pwd)"
cd "${SRC_DIR}"

LABEL="com.deskpulse.test"
LAUNCH_DOMAIN="gui/$(id -u)"
JOB_REF="${LAUNCH_DOMAIN}/${LABEL}"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
TEST_SUPPORT_DIR="${HOME}/Library/Application Support/DeskPulseTest"
TEST_BIN_DIR="${TEST_SUPPORT_DIR}/bin"
BUILD_PATH="${TEST_BIN_DIR}/deskpulse-agent-test"
CLI_IMPL_PATH="${TEST_BIN_DIR}/deskpulse.real"
CLI_PATH="${TEST_BIN_DIR}/deskpulse"
CONFIG_PATH="${TEST_SUPPORT_DIR}/config.json"
PERMISSION_STATUS_PATH="${TEST_SUPPORT_DIR}/permission-status.txt"
OUT_LOG_PATH="/tmp/deskpulse-test-out.txt"
ERR_LOG_PATH="/tmp/deskpulse-test-err.txt"
DEFAULT_CONFIG_PATH="${HOME}/Library/Application Support/DeskPulse/config.json"

mkdir -p "${HOME}/Library/LaunchAgents" "${TEST_SUPPORT_DIR}" "${TEST_BIN_DIR}"

if [[ ! -f "${CONFIG_PATH}" ]]; then
    if [[ -f "${DEFAULT_CONFIG_PATH}" ]]; then
        cp "${DEFAULT_CONFIG_PATH}" "${CONFIG_PATH}"
    else
        cat > "${CONFIG_PATH}" <<'EOF'
{
  "idleThresholdSeconds": 5,
  "loopIntervalSeconds": 1,
  "pixelOffset": 2,
  "disableIfSSIDPresentEnabled": false,
  "disableIfSSIDPresentList": [],
  "wifiScanIntervalSeconds": 60,
  "disableIfOutsideHoursEnabled": true,
  "disableIfOutsideHoursRange": "8-17"
}
EOF
    fi
fi

echo "Building test agent..."
swiftc "DeskPulseAgent.swift" -O -o "${BUILD_PATH}"
cp "deskpulse" "${CLI_IMPL_PATH}"
chmod +x "${BUILD_PATH}" "${CLI_IMPL_PATH}"

cat > "${CLI_PATH}" <<EOF
#!/usr/bin/env bash
export DESKPULSE_LAUNCH_LABEL="${LABEL}"
export DESKPULSE_CONFIG_PATH="${CONFIG_PATH}"
export DESKPULSE_PERMISSION_STATUS_PATH="${PERMISSION_STATUS_PATH}"
export DESKPULSE_OUT_LOG_PATH="${OUT_LOG_PATH}"
export DESKPULSE_ERR_LOG_PATH="${ERR_LOG_PATH}"
export DESKPULSE_SERVICE_PLIST_PATH="${PLIST_PATH}"
exec "${CLI_IMPL_PATH}" "\$@"
EOF
chmod +x "${CLI_PATH}"

launchctl bootout "${LAUNCH_DOMAIN}" "${PLIST_PATH}" >/dev/null 2>&1 || true
rm -f "${PLIST_PATH}"

cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>

  <key>ProgramArguments</key>
  <array>
    <string>${BUILD_PATH}</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>${OUT_LOG_PATH}</string>

  <key>StandardErrorPath</key>
  <string>${ERR_LOG_PATH}</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>DESKPULSE_LAUNCH_LABEL</key>
    <string>${LABEL}</string>
    <key>DESKPULSE_CONFIG_PATH</key>
    <string>${CONFIG_PATH}</string>
    <key>DESKPULSE_PERMISSION_STATUS_PATH</key>
    <string>${PERMISSION_STATUS_PATH}</string>
    <key>DESKPULSE_OUT_LOG_PATH</key>
    <string>${OUT_LOG_PATH}</string>
    <key>DESKPULSE_ERR_LOG_PATH</key>
    <string>${ERR_LOG_PATH}</string>
  </dict>
</dict>
</plist>
EOF

echo ""
echo "Test environment installed."
echo "Job: ${JOB_REF}"
echo "Binary: ${BUILD_PATH}"
echo "CLI: ${CLI_PATH}"
echo "Plist: ${PLIST_PATH}"
echo "Config: ${CONFIG_PATH}"
echo "Permission status: ${PERMISSION_STATUS_PATH}"
echo "Stdout log: ${OUT_LOG_PATH}"
echo "Stderr log: ${ERR_LOG_PATH}"
echo ""
echo "Start it with:"
echo "  ${SCRIPT_DIR}/dev_agent_up.sh"
echo "or"
echo "  ${CLI_PATH} up"

#!/usr/bin/env bash

set -euo pipefail

TEST_SUPPORT_DIR="${HOME}/Library/Application Support/DeskPulseTest"
CLI_PATH="${TEST_SUPPORT_DIR}/bin/deskpulse"

if [[ ! -x "${CLI_PATH}" ]]; then
    echo "ERROR: test environment is not installed." >&2
    echo "Run: ./src/dev/install_dev_environment.sh" >&2
    exit 1
fi

"${CLI_PATH}" status

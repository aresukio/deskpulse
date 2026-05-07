#!/usr/bin/env bash

set -euo pipefail

# Allow invocation from any directory by anchoring to script location.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

usage() {
    cat <<'EOF'
Usage: ./release.sh

Environment variables:
  DESKPULSE_SOURCE_REPO     GitHub source repository used for tag archives
                            Default: aresukio/deskpulse
  DESKPULSE_TAP_REPO_PATH   Path to local Homebrew tap repo
                            Default: ../homebrew-deskpulse

This script will:
  1) verify source and tap working trees are clean
  2) increment VERSION (integer)
  3) commit, tag, and push the source repo
  4) calculate the sha256 for the GitHub tag archive
  5) sync README.md and img/ into the tap repo
  6) update Formula/deskpulse.rb in the tap repo
  7) commit and push the tap repo
EOF
}

if [[ $# -ne 0 ]]; then
    usage >&2
    exit 1
fi

if [[ ! -f "VERSION" ]]; then
    echo "ERROR: VERSION file is missing." >&2
    exit 1
fi

source_repo="${DESKPULSE_SOURCE_REPO:-aresukio/deskpulse}"
source_homepage="https://github.com/${source_repo}"
tap_repo_path="${DESKPULSE_TAP_REPO_PATH:-${SCRIPT_DIR}/../homebrew-deskpulse}"
formula_file="${tap_repo_path}/Formula/deskpulse.rb"

if [[ ! -d ".git" ]]; then
    echo "ERROR: release.sh must be run from inside the DeskPulse git repo." >&2
    exit 1
fi
if [[ ! -d "${tap_repo_path}/.git" ]]; then
    echo "ERROR: Homebrew tap repo not found at ${tap_repo_path}" >&2
    exit 1
fi
if [[ ! -f "${formula_file}" ]]; then
    echo "ERROR: formula file not found at ${formula_file}" >&2
    exit 1
fi
for required_file in "README.md" "src/DeskPulseAgent.swift" "src/deskpulse"; do
    if [[ ! -f "${required_file}" ]]; then
        echo "ERROR: required source file is missing: ${required_file}" >&2
        exit 1
    fi
done
if [[ ! -d "img" ]]; then
    echo "ERROR: required image directory is missing: img" >&2
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: source working tree is not clean. Commit/stash changes first." >&2
    exit 1
fi
if [[ -n "$(git -C "${tap_repo_path}" status --porcelain)" ]]; then
    echo "ERROR: tap working tree is not clean: ${tap_repo_path}" >&2
    exit 1
fi

current_version="$(tr -d '[:space:]' < VERSION)"
if [[ ! "${current_version}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: VERSION must contain only an integer." >&2
    exit 1
fi

version="$((current_version + 1))"
tag="${version}"

if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
    echo "ERROR: tag ${tag} already exists locally." >&2
    exit 1
fi

for cmd in git curl shasum ruby python3; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "ERROR: required command not found: ${cmd}" >&2
        exit 1
    fi
done

if git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
    echo "ERROR: tag ${tag} already exists on origin." >&2
    exit 1
fi

build_dir="$(mktemp -d "/tmp/deskpulse-${tag}.XXXXXX")"
archive_path="${build_dir}/deskpulse-${tag}.tar.gz"
archive_url="${source_homepage}/archive/refs/tags/${tag}.tar.gz"

cleanup() {
    rm -rf "${build_dir}"
}
trap cleanup EXIT

printf '%s\n' "${version}" > VERSION
git add VERSION
git commit -m "$(cat <<EOF
release: deskpulse ${version}

EOF
)"
git tag "${tag}"
git push origin HEAD
git push origin "${tag}"

echo "Downloading GitHub source archive..."
downloaded=0
for attempt in 1 2 3 4 5; do
    if curl -fsSL "${archive_url}" -o "${archive_path}"; then
        downloaded=1
        break
    fi
    echo "Archive was not available yet; retrying (${attempt}/5)..."
    sleep 2
done
if [[ "${downloaded}" -ne 1 ]]; then
    echo "ERROR: failed to download source archive: ${archive_url}" >&2
    exit 1
fi

archive_sha256="$(shasum -a 256 "${archive_path}" | awk '{print $1}')"

cp "README.md" "${tap_repo_path}/README.md"
rm -rf "${tap_repo_path}/img"
mkdir -p "${tap_repo_path}/img"
cp -R "img/." "${tap_repo_path}/img/"

python3 - "${formula_file}" "${source_homepage}" "${archive_url}" "${tag}" "${archive_sha256}" <<'PY'
import re
import sys
from pathlib import Path

formula_path = Path(sys.argv[1])
homepage, url, version, sha256 = sys.argv[2:]

replacements = {
    r'^  homepage ".*"$': f'  homepage "{homepage}"',
    r'^  url ".*"$': f'  url "{url}"',
    r'^  version ".*"$': f'  version "{version}"',
    r'^  sha256 ".*"$': f'  sha256 "{sha256}"',
}

text = formula_path.read_text(encoding="utf-8")
for pattern, replacement in replacements.items():
    text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"ERROR: formula pattern was not found: {pattern}")

formula_path.write_text(text, encoding="utf-8")
PY

if git -C "${tap_repo_path}" diff --quiet -- "Formula/deskpulse.rb" "README.md" "img"; then
    echo "ERROR: tap repo was not updated." >&2
    exit 1
fi

ruby -c "${formula_file}"
git -C "${tap_repo_path}" add "Formula/deskpulse.rb" "README.md" "img"
git -C "${tap_repo_path}" commit -m "$(cat <<EOF
formula: deskpulse ${version}

EOF
)"
git -C "${tap_repo_path}" push origin HEAD

echo ""
echo "Release complete."
echo "Tag: ${tag}"
echo "Source archive URL: ${archive_url}"
echo "SHA256: ${archive_sha256}"

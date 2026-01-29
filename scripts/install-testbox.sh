#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTBOX_DIR="${ROOT_DIR}/testbox"

if [ -d "${TESTBOX_DIR}/system" ]; then
  echo "TestBox already present at ${TESTBOX_DIR}"
  exit 0
fi

mkdir -p "${TESTBOX_DIR}"

if command -v box >/dev/null 2>&1; then
  echo "Installing TestBox via CommandBox..."
  (cd "${TESTBOX_DIR}" && box install testbox)
  exit 0
fi

URL="${TESTBOX_ZIP_URL:-https://downloads.ortussolutions.com/ortussolutions/testbox/testbox-4.6.0.zip}"
TMP_ZIP="$(mktemp -t testbox.XXXXXX.zip)"

echo "Downloading TestBox from ${URL}"
curl -L "${URL}" -o "${TMP_ZIP}"
unzip -q "${TMP_ZIP}" -d "${TESTBOX_DIR}"
rm -f "${TMP_ZIP}"

echo "TestBox installed at ${TESTBOX_DIR}"

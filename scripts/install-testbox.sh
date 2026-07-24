#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTBOX_DIR="${ROOT_DIR}/testbox"
TESTBOX_FORGEBOX_PACKAGE="${TESTBOX_FORGEBOX_PACKAGE:-testbox@4.5.0+5}"
MOCKDATA_FORGEBOX_PACKAGE="${MOCKDATA_FORGEBOX_PACKAGE:-mockdatacfc@3.3.0+22}"
CBSTREAMS_FORGEBOX_PACKAGE="${CBSTREAMS_FORGEBOX_PACKAGE:-cbstreams@1.5.0+51}"
DEFAULT_TESTBOX_ZIP_URL="https://downloads.ortussolutions.com/ortussolutions/testbox/4.5.0/testbox-4.5.0.zip"
DEFAULT_TESTBOX_ZIP_SHA256="c2d114da9ee49cabe430599b3610821886d382802df7d09cef91869c6fb4ed14"
DEFAULT_MOCKDATA_ZIP_URL="https://downloads.ortussolutions.com/ortussolutions/coldbox-modules/MockDataCFC/3.3.0/MockDataCFC-3.3.0.zip"
DEFAULT_MOCKDATA_ZIP_SHA256="699d1afa812a39b6e7cf519a4876a64cd0308335122de2ffb1e685d3ca747e76"
DEFAULT_CBSTREAMS_ZIP_URL="https://downloads.ortussolutions.com/ortussolutions/coldbox-modules/cbstreams/1.5.0/cbstreams-1.5.0.zip"
DEFAULT_CBSTREAMS_ZIP_SHA256="8642c8c3b36dbbcba053935cf6490ca0409351b996c0ea8d79dcbef94d2f13b1"
MOCKDATA_DIR="${TESTBOX_DIR}/system/modules/mockdatacfc"
CBSTREAMS_DIR="${TESTBOX_DIR}/system/modules/cbstreams"

if [ -d "${TESTBOX_DIR}/system" ] \
  && [ -f "${MOCKDATA_DIR}/models/MockData.cfc" ] \
  && [ -f "${CBSTREAMS_DIR}/models/Stream.cfc" ]; then
  echo "TestBox, MockDataCFC, and cbstreams already present at ${TESTBOX_DIR}"
  exit 0
fi

if command -v box >/dev/null 2>&1; then
  echo "Installing ${TESTBOX_FORGEBOX_PACKAGE} with ${MOCKDATA_FORGEBOX_PACKAGE} and ${CBSTREAMS_FORGEBOX_PACKAGE} via CommandBox..."
  (cd "${ROOT_DIR}" && box install "${TESTBOX_FORGEBOX_PACKAGE}" --!save)
  if [ ! -d "${TESTBOX_DIR}/system" ] \
    || [ ! -f "${MOCKDATA_DIR}/models/MockData.cfc" ] \
    || [ ! -f "${CBSTREAMS_DIR}/models/Stream.cfc" ]; then
    echo "CommandBox completed without creating the required TestBox dependency tree." >&2
    exit 1
  fi
  exit 0
fi

TESTBOX_URL="${TESTBOX_ZIP_URL:-${DEFAULT_TESTBOX_ZIP_URL}}"
TESTBOX_EXPECTED_SHA256="${TESTBOX_ZIP_SHA256:-${DEFAULT_TESTBOX_ZIP_SHA256}}"
MOCKDATA_URL="${MOCKDATA_ZIP_URL:-${DEFAULT_MOCKDATA_ZIP_URL}}"
MOCKDATA_EXPECTED_SHA256="${MOCKDATA_ZIP_SHA256:-${DEFAULT_MOCKDATA_ZIP_SHA256}}"
CBSTREAMS_URL="${CBSTREAMS_ZIP_URL:-${DEFAULT_CBSTREAMS_ZIP_URL}}"
CBSTREAMS_EXPECTED_SHA256="${CBSTREAMS_ZIP_SHA256:-${DEFAULT_CBSTREAMS_ZIP_SHA256}}"
TMP_TESTBOX_ZIP="$(mktemp -t fpw-testbox.XXXXXX)"
TMP_MOCKDATA_ZIP="$(mktemp -t fpw-mockdatacfc.XXXXXX)"
TMP_CBSTREAMS_ZIP="$(mktemp -t fpw-cbstreams.XXXXXX)"
TMP_EXTRACT_DIR="$(mktemp -d -t fpw-testbox-extract.XXXXXX)"

cleanup() {
  rm -f "${TMP_TESTBOX_ZIP}" "${TMP_MOCKDATA_ZIP}" "${TMP_CBSTREAMS_ZIP}"
  rm -rf "${TMP_EXTRACT_DIR}"
}
trap cleanup EXIT

if [ ! -d "${TESTBOX_DIR}/system" ]; then
  echo "Downloading TestBox from ${TESTBOX_URL}"
  curl --fail --location "${TESTBOX_URL}" --output "${TMP_TESTBOX_ZIP}"

  TESTBOX_ACTUAL_SHA256="$(shasum -a 256 "${TMP_TESTBOX_ZIP}" | awk '{print $1}')"
  if [ "${TESTBOX_ACTUAL_SHA256}" != "${TESTBOX_EXPECTED_SHA256}" ]; then
    echo "TestBox archive SHA-256 mismatch." >&2
    echo "Expected: ${TESTBOX_EXPECTED_SHA256}" >&2
    echo "Actual:   ${TESTBOX_ACTUAL_SHA256}" >&2
    exit 1
  fi

  unzip -q "${TMP_TESTBOX_ZIP}" -d "${TMP_EXTRACT_DIR}"
  if [ ! -d "${TMP_EXTRACT_DIR}/testbox/system" ]; then
    echo "Verified TestBox archive does not contain testbox/system." >&2
    exit 1
  fi
fi

if [ ! -f "${MOCKDATA_DIR}/models/MockData.cfc" ]; then
  echo "Downloading MockDataCFC from ${MOCKDATA_URL}"
  curl --fail --location "${MOCKDATA_URL}" --output "${TMP_MOCKDATA_ZIP}"

  MOCKDATA_ACTUAL_SHA256="$(shasum -a 256 "${TMP_MOCKDATA_ZIP}" | awk '{print $1}')"
  if [ "${MOCKDATA_ACTUAL_SHA256}" != "${MOCKDATA_EXPECTED_SHA256}" ]; then
    echo "MockDataCFC archive SHA-256 mismatch." >&2
    echo "Expected: ${MOCKDATA_EXPECTED_SHA256}" >&2
    echo "Actual:   ${MOCKDATA_ACTUAL_SHA256}" >&2
    exit 1
  fi

  mkdir -p "${TMP_EXTRACT_DIR}/mockdatacfc"
  unzip -q "${TMP_MOCKDATA_ZIP}" -d "${TMP_EXTRACT_DIR}/mockdatacfc"
  if [ ! -f "${TMP_EXTRACT_DIR}/mockdatacfc/models/MockData.cfc" ]; then
    echo "Verified MockDataCFC archive does not contain models/MockData.cfc." >&2
    exit 1
  fi
fi

if [ ! -f "${CBSTREAMS_DIR}/models/Stream.cfc" ]; then
  echo "Downloading cbstreams from ${CBSTREAMS_URL}"
  curl --fail --location "${CBSTREAMS_URL}" --output "${TMP_CBSTREAMS_ZIP}"

  CBSTREAMS_ACTUAL_SHA256="$(shasum -a 256 "${TMP_CBSTREAMS_ZIP}" | awk '{print $1}')"
  if [ "${CBSTREAMS_ACTUAL_SHA256}" != "${CBSTREAMS_EXPECTED_SHA256}" ]; then
    echo "cbstreams archive SHA-256 mismatch." >&2
    echo "Expected: ${CBSTREAMS_EXPECTED_SHA256}" >&2
    echo "Actual:   ${CBSTREAMS_ACTUAL_SHA256}" >&2
    exit 1
  fi

  mkdir -p "${TMP_EXTRACT_DIR}/cbstreams"
  unzip -q "${TMP_CBSTREAMS_ZIP}" -d "${TMP_EXTRACT_DIR}/cbstreams"
  if [ ! -f "${TMP_EXTRACT_DIR}/cbstreams/models/Stream.cfc" ]; then
    echo "Verified cbstreams archive does not contain models/Stream.cfc." >&2
    exit 1
  fi
fi

if [ ! -d "${TESTBOX_DIR}/system" ]; then
  mkdir -p "${TESTBOX_DIR}"
  cp -R "${TMP_EXTRACT_DIR}/testbox/." "${TESTBOX_DIR}/"
fi
if [ ! -f "${MOCKDATA_DIR}/models/MockData.cfc" ]; then
  mkdir -p "${MOCKDATA_DIR}"
  cp -R "${TMP_EXTRACT_DIR}/mockdatacfc/." "${MOCKDATA_DIR}/"
fi
if [ ! -f "${CBSTREAMS_DIR}/models/Stream.cfc" ]; then
  mkdir -p "${CBSTREAMS_DIR}"
  cp -R "${TMP_EXTRACT_DIR}/cbstreams/." "${CBSTREAMS_DIR}/"
fi
if [ ! -d "${TESTBOX_DIR}/system" ] \
  || [ ! -f "${MOCKDATA_DIR}/models/MockData.cfc" ] \
  || [ ! -f "${CBSTREAMS_DIR}/models/Stream.cfc" ]; then
  echo "TestBox installation did not create the required dependency tree." >&2
  exit 1
fi

echo "TestBox, MockDataCFC, and cbstreams installed at ${TESTBOX_DIR}"

#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/docs/screenshots}"
CONFIGURATION="${CONFIGURATION:-Release-AppStore}"
SCHEME="${SCHEME:-SaneClick}"
TEST_FILTER="SaneClickTests/AppStoreScreenshotRenderTests"

log() {
  printf '[screenshots] %s\n' "$1" >&2
}

run_xcodebuild() {
  local output_file="$1"
  shift

  (
    cd "${PROJECT_ROOT}"
    env SANECLICK_SCREENSHOT_DIR="${OUTPUT_DIR}" "$@" | tee "${output_file}"
  )
}

mkdir -p "${OUTPUT_DIR}"

log "Regenerating Xcode project"
(
  cd "${PROJECT_ROOT}"
  xcodegen generate >/dev/null
)

base_cmd=(
  xcodebuild
  -project SaneClick.xcodeproj
  -scheme "${SCHEME}"
  -configuration "${CONFIGURATION}"
  -destination platform=macOS
  ARCHS=arm64
  VALID_ARCHS=arm64
  CODE_SIGN_STYLE=Manual
  CODE_SIGN_IDENTITY=-
  DEVELOPMENT_TEAM=
  ENABLE_TESTABILITY=YES
)

filtered_log="$(mktemp /tmp/saneclick_screenshot_test.XXXXXX.log)"
full_log="$(mktemp /tmp/saneclick_screenshot_test_full.XXXXXX.log)"
trap 'rm -f "${filtered_log}" "${full_log}"' EXIT

log "Rendering screenshots with ${TEST_FILTER}"
if ! run_xcodebuild "${filtered_log}" "${base_cmd[@]}" -only-testing:"${TEST_FILTER}" test; then
  if grep -Eqi 'No matching test cases were found|Cannot find test|There are no test bundles available to test|Testing failed' "${filtered_log}"; then
    log "Filtered test selection was unavailable; rerunning full test bundle"
    run_xcodebuild "${full_log}" "${base_cmd[@]}" test
  else
    cat "${filtered_log}" >&2
    exit 1
  fi
fi

log "Wrote screenshots to ${OUTPUT_DIR}"

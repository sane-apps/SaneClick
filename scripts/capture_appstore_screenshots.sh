#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/docs/screenshots}"
RENDER_OUTPUT_DIR="${RENDER_OUTPUT_DIR:-$HOME/Library/Containers/com.saneclick.SaneClick/Data/tmp/AppStoreScreenshots}"
CONFIGURATION="${CONFIGURATION:-Release-AppStore}"
SCHEME="${SCHEME:-SaneClick-AppStore-Screenshots}"
TEST_FILTER="SaneClickAppStoreScreenshotTests/AppStoreScreenshotRenderTests"
MINI_HOST="${MINI_HOST:-mini}"
ALLOW_LOCAL_CAPTURE="${ALLOW_LOCAL_CAPTURE:-0}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/SaneClickAppStoreShots}"
SECRETS_ENV_FILE="${SECRETS_ENV_FILE:-$HOME/.config/saneprocess/secrets.env}"
OUTPUT_HINT_FILE="${OUTPUT_HINT_FILE:-/tmp/saneclick_screenshot_dir.txt}"

log() {
  printf '[screenshots] %s\n' "$1" >&2
}

enforce_mini_first() {
  local host_short host_lc user_lc
  host_short="$(hostname -s 2>/dev/null || hostname)"
  host_lc="$(printf '%s' "${host_short}" | tr '[:upper:]' '[:lower:]')"
  user_lc="$(printf '%s' "${USER:-}" | tr '[:upper:]' '[:lower:]')"

  if [[ "${host_lc}" == *mini* ]] || [[ "${user_lc}" == "stephansmac" ]]; then
    return 0
  fi

  if [[ "${ALLOW_LOCAL_CAPTURE}" == "1" ]]; then
    log "ALLOW_LOCAL_CAPTURE=1 set; bypassing mini-first enforcement."
    return 0
  fi

  if command -v ssh >/dev/null 2>&1 && ssh -o BatchMode=yes -o ConnectTimeout=2 "${MINI_HOST}" true >/dev/null 2>&1; then
    echo "Refusing local screenshot capture while Mini is reachable." >&2
    echo "Run this on Mini instead:" >&2
    echo "  ssh ${MINI_HOST} 'cd ${PROJECT_ROOT} && bash scripts/capture_appstore_screenshots.sh'" >&2
    exit 2
  fi

  log "Mini unreachable; continuing locally."
}

run_xcodebuild() {
  local output_file="$1"
  shift

  (
    cd "${PROJECT_ROOT}"
    env SANECLICK_CAPTURE_SCREENSHOTS=1 SANECLICK_SCREENSHOT_DIR="${RENDER_OUTPUT_DIR}" "$@" | tee "${output_file}"
  )
}

load_signing_env() {
  if [[ -f "${SECRETS_ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    set -a
    . "${SECRETS_ENV_FILE}"
    set +a
  fi
}

prepare_signing_session() {
  load_signing_env

  local login_keychain keychain_password
  login_keychain="${SANEBAR_KEYCHAIN_PATH:-${KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}}"
  keychain_password="${SANEBAR_KEYCHAIN_PASSWORD:-${KEYCHAIN_PASSWORD:-${KEYCHAIN_PASS:-}}}"

  if [[ ! -f "${login_keychain}" || -z "${keychain_password}" ]]; then
    log "Signing session secrets unavailable; continuing without explicit keychain prep."
    return 0
  fi

  security default-keychain -d user -s "${login_keychain}" >/dev/null 2>&1 || true
  security list-keychains -d user -s "${login_keychain}" /Library/Keychains/System.keychain >/dev/null 2>&1 || true
  security set-keychain-settings -lut 21600 "${login_keychain}" >/dev/null 2>&1 || true
  security unlock-keychain -p "${keychain_password}" "${login_keychain}" >/dev/null 2>&1

  if [[ "${OTHER_CODE_SIGN_FLAGS:-}" != *"--keychain ${login_keychain}"* ]]; then
    if [[ -n "${OTHER_CODE_SIGN_FLAGS:-}" ]]; then
      export OTHER_CODE_SIGN_FLAGS="--keychain ${login_keychain} ${OTHER_CODE_SIGN_FLAGS}"
    else
      export OTHER_CODE_SIGN_FLAGS="--keychain ${login_keychain}"
    fi
  fi
}

mkdir -p "${OUTPUT_DIR}" "${RENDER_OUTPUT_DIR}"
enforce_mini_first
prepare_signing_session

log "Regenerating Xcode project"
(
  cd "${PROJECT_ROOT}"
  xcodegen generate >/dev/null
)

rm -rf "${DERIVED_DATA_PATH}"
rm -f \
  "${RENDER_OUTPUT_DIR}/onboarding.png" \
  "${RENDER_OUTPUT_DIR}/main-window.png" \
  "${RENDER_OUTPUT_DIR}/finder-context-menu.png" \
  "${RENDER_OUTPUT_DIR}/script-library.png" \
  "${OUTPUT_DIR}/onboarding.png" \
  "${OUTPUT_DIR}/main-window.png" \
  "${OUTPUT_DIR}/finder-context-menu.png" \
  "${OUTPUT_DIR}/script-library.png"
printf '%s\n' "${RENDER_OUTPUT_DIR}" > "${OUTPUT_HINT_FILE}"

base_cmd=(
  xcodebuild
  -project SaneClick.xcodeproj
  -scheme "${SCHEME}"
  -configuration "${CONFIGURATION}"
  -destination "platform=macOS,arch=arm64"
  -derivedDataPath "${DERIVED_DATA_PATH}"
  ARCHS=arm64
  VALID_ARCHS=arm64
  ENABLE_DEBUG_DYLIB=NO
  ENABLE_TESTABILITY=YES
)

filtered_log="$(mktemp -t saneclick_screenshot_test)"
full_log="$(mktemp -t saneclick_screenshot_test_full)"
trap 'rm -f "${filtered_log}" "${full_log}" "${OUTPUT_HINT_FILE}"' EXIT

log "Rendering screenshots with scheme ${SCHEME} and test filter ${TEST_FILTER}"
if ! run_xcodebuild "${filtered_log}" "${base_cmd[@]}" -only-testing:"${TEST_FILTER}" test; then
  if grep -Eqi 'No matching test cases were found|Cannot find test|There are no test bundles available to test|Testing failed' "${filtered_log}"; then
    log "Filtered test selection was unavailable; rerunning full test bundle"
    run_xcodebuild "${full_log}" "${base_cmd[@]}" test
  else
    cat "${filtered_log}" >&2
    exit 1
  fi
fi

for screenshot in onboarding.png main-window.png finder-context-menu.png script-library.png; do
  if [[ ! -f "${RENDER_OUTPUT_DIR}/${screenshot}" ]]; then
    echo "Missing rendered screenshot: ${RENDER_OUTPUT_DIR}/${screenshot}" >&2
    exit 1
  fi
  cp "${RENDER_OUTPUT_DIR}/${screenshot}" "${OUTPUT_DIR}/${screenshot}"
done

log "Wrote screenshots to ${OUTPUT_DIR}"

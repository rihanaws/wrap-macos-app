#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-WarpClone}"
BUNDLE_ID="${BUNDLE_ID:-com.warpclone.app}"
VERSION="${VERSION:-1.0.0-beta}"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
RESOURCE_DIR="${ROOT_DIR}/Sources/WarpClone/Resources"
BUILD_DIR="${ROOT_DIR}/.build/${BUILD_CONFIGURATION}"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
SIGNING_ID="${SIGNING_ID:-}"
NOTARIZE="${NOTARIZE:-false}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-${TEAM_ID:-}}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-notarytool}"

echo "Building ${APP_NAME} (${BUILD_CONFIGURATION})"
swift build -c "${BUILD_CONFIGURATION}" --product "${APP_NAME}"

EXECUTABLE_PATH="$(swift build -c "${BUILD_CONFIGURATION}" --show-bin-path)/${APP_NAME}"
if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "ERROR: executable not found at ${EXECUTABLE_PATH}" >&2
  exit 1
fi

rm -rf "${APP_PATH}" "${DMG_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS" "${APP_PATH}/Contents/Resources"
cp "${EXECUTABLE_PATH}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"
cp "${RESOURCE_DIR}/Info.plist" "${APP_PATH}/Contents/Info.plist"
rsync -a --exclude Info.plist --exclude Entitlements.plist "${RESOURCE_DIR}/" "${APP_PATH}/Contents/Resources/"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "${APP_PATH}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_PATH}/Contents/Info.plist"
if [[ -n "${GITHUB_OAUTH_CLIENT_ID:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :GitHubOAuthClientID ${GITHUB_OAUTH_CLIENT_ID}" "${APP_PATH}/Contents/Info.plist"
fi

if [[ -n "${SIGNING_ID}" ]]; then
  echo "Signing with Developer ID: ${SIGNING_ID}"
  codesign --force --deep --options runtime \
    --entitlements "${RESOURCE_DIR}/Entitlements.plist" \
    --sign "${SIGNING_ID}" \
    "${APP_PATH}"
else
  echo "No SIGNING_ID provided; applying ad-hoc signature for local testing"
  codesign --force --deep --sign - "${APP_PATH}"
fi

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

if [[ "${NOTARIZE}" == "true" ]]; then
  if [[ -z "${APPLE_ID}" || -z "${APPLE_TEAM_ID}" ]]; then
    echo "ERROR: NOTARIZE=true requires APPLE_ID and APPLE_TEAM_ID" >&2
    exit 1
  fi

  ZIP_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.zip"
  rm -f "${ZIP_PATH}"
  ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"
  xcrun notarytool submit "${ZIP_PATH}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --team-id "${APPLE_TEAM_ID}" \
    --wait
  xcrun stapler staple "${APP_PATH}"
fi

echo "Creating DMG: ${DMG_PATH}"
hdiutil create -volname "${APP_NAME} ${VERSION}" \
  -srcfolder "${APP_PATH}" \
  -ov -format UDZO \
  "${DMG_PATH}"

echo "Release artifact ready: ${DMG_PATH}"

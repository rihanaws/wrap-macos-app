#!/usr/bin/env bash
set -euo pipefail

KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-notarytool}"

read -r -p "Apple ID email: " APPLE_ID
read -r -p "Apple Team ID: " APPLE_TEAM_ID
read -r -s -p "App-specific password: " APP_PASSWORD
echo

xcrun notarytool store-credentials "${KEYCHAIN_PROFILE}" \
  --apple-id "${APPLE_ID}" \
  --team-id "${APPLE_TEAM_ID}" \
  --password "${APP_PASSWORD}"

cat <<EOF
Stored notarization credentials in keychain profile '${KEYCHAIN_PROFILE}'.

Use:
  APPLE_ID=${APPLE_ID} APPLE_TEAM_ID=${APPLE_TEAM_ID} NOTARIZE=true ./script/build_and_sign.sh
EOF

#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${WARPCLONE_REPO_URL:-https://github.com/rihanaws/wrap-macos-app.git}"
INSTALL_DIR="${WARPCLONE_INSTALL_DIR:-$HOME/.local/bin}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Installing WarpClone CLI from $REPO_URL"

git clone --depth 1 "$REPO_URL" "$TMP_DIR/WarpClone"
cd "$TMP_DIR/WarpClone"

swift build -c release --product warp

BIN_PATH="$(swift build -c release --show-bin-path)/warp"
mkdir -p "$INSTALL_DIR"
cp "$BIN_PATH" "$INSTALL_DIR/warp"
chmod 755 "$INSTALL_DIR/warp"

echo "Installed warp to $INSTALL_DIR/warp"
echo "Run: warp --help"

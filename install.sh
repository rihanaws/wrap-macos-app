#!/usr/bin/env bash
set -euo pipefail

REPO="${WARPCLONE_REPO:-rihanaws/wrap-macos-app}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
  darwin)
    PLATFORM="macos"
    ;;
  linux)
    PLATFORM="linux"
    ;;
  *)
    echo "Unsupported operating system: $(uname -s)" >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  arm64|aarch64)
    ARCH="arm64"
    ;;
  x86_64|amd64)
    ARCH="x86_64"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

ASSET="warp-${PLATFORM}-${ARCH}.tar.gz"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

echo "Looking for latest WarpClone CLI release asset: $ASSET"

RELEASE_JSON="$TMP_DIR/release.json"
curl -fsSL "$API_URL" -o "$RELEASE_JSON"

DOWNLOAD_URL="$(python3 - "$RELEASE_JSON" "$ASSET" <<'PY'
import json
import sys

release_path, asset_name = sys.argv[1], sys.argv[2]
with open(release_path, "r", encoding="utf-8") as handle:
    release = json.load(handle)

for asset in release.get("assets", []):
    if asset.get("name") == asset_name:
        print(asset.get("browser_download_url", ""))
        break
PY
)"

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Release asset '$ASSET' was not found in latest release for $REPO." >&2
  echo "Expected assets: warp-macos-arm64.tar.gz, warp-macos-x86_64.tar.gz, warp-linux-x86_64.tar.gz" >&2
  exit 1
fi

ARCHIVE="$TMP_DIR/warp.tar.gz"
curl -fL "$DOWNLOAD_URL" -o "$ARCHIVE"
tar -xzf "$ARCHIVE" -C "$TMP_DIR"

if [ ! -f "$TMP_DIR/warp" ]; then
  echo "Archive did not contain a warp binary at its root." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
cp "$TMP_DIR/warp" "$INSTALL_DIR/warp"
chmod 755 "$INSTALL_DIR/warp"

SHELL_RC=""
case "${SHELL:-}" in
  */zsh)
    SHELL_RC="$HOME/.zshrc"
    ;;
  */bash)
    SHELL_RC="$HOME/.bashrc"
    ;;
esac

if [ -n "$SHELL_RC" ] && ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  touch "$SHELL_RC"
  if ! grep -q "export PATH=\"$INSTALL_DIR:\$PATH\"" "$SHELL_RC"; then
    {
      echo ""
      echo "# WarpClone CLI"
      echo "export PATH=\"$INSTALL_DIR:\$PATH\""
    } >> "$SHELL_RC"
    echo "Added $INSTALL_DIR to PATH in $SHELL_RC"
  fi
fi

echo "Installed warp to $INSTALL_DIR/warp"
echo "Run: warp --help"

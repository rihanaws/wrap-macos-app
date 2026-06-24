#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <1024x1024 PNG>" >&2
  exit 1
fi

SOURCE_PNG="$1"
ICONSET_DIR="Sources/WarpClone/Resources/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "${SOURCE_PNG}" ]]; then
  echo "ERROR: source PNG not found: ${SOURCE_PNG}" >&2
  exit 1
fi

WIDTH="$(sips -g pixelWidth "${SOURCE_PNG}" | awk '/pixelWidth/ { print $2 }')"
HEIGHT="$(sips -g pixelHeight "${SOURCE_PNG}" | awk '/pixelHeight/ { print $2 }')"
if [[ "${WIDTH}" != "1024" || "${HEIGHT}" != "1024" ]]; then
  echo "ERROR: icon source must be 1024x1024; got ${WIDTH}x${HEIGHT}" >&2
  exit 1
fi

mkdir -p "${ICONSET_DIR}"

for size in 16 32 128 256 512; do
  sips -z "${size}" "${size}" "${SOURCE_PNG}" --out "${ICONSET_DIR}/icon_${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "${double}" "${double}" "${SOURCE_PNG}" --out "${ICONSET_DIR}/icon_${size}@2x.png" >/dev/null
done

echo "Generated app icon assets in ${ICONSET_DIR}"

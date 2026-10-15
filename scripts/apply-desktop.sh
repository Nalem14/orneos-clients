#!/bin/bash
# Applies the Orneos overlay to a checkout of nextcloud/desktop at the tag from versions.env.
# Usage: scripts/apply-desktop.sh <path-to-desktop-checkout>
# Idempotent. Fails loudly when an upstream file changed shape, so a release never ships half-branded.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?path to the nextcloud/desktop checkout}"
[ -f "$SRC/NEXTCLOUD.cmake" ] || { echo "not a nextcloud/desktop checkout: $SRC" >&2; exit 1; }

# 1. Values: our branding.cmake, included at the end of upstream NEXTCLOUD.cmake (overrides without rewriting it)
mkdir -p "$SRC/orneos"
cp "$HERE/desktop/branding.cmake" "$SRC/orneos/branding.cmake"
grep -q 'orneos/branding.cmake' "$SRC/NEXTCLOUD.cmake" \
    || printf '\n# Orneos\ninclude(${CMAKE_SOURCE_DIR}/orneos/branding.cmake)\n' >> "$SRC/NEXTCLOUD.cmake"

# 2. Icons and logos (replace Nextcloud trademarks)
cp "$HERE"/desktop/theme/colored/* "$SRC/theme/colored/"

# 3. Windows CfApi shell extension ids are set in CMakeLists.txt after NEXTCLOUD.cmake: ours, fixed forever
replace() { # file, old, new
    if grep -qF "$3" "$1"; then return; fi
    grep -qF "$2" "$1" || { echo "upstream changed: '$2' not found in $1" >&2; exit 1; }
    sed -i "s|$2|$3|g" "$1"
}
replace "$SRC/CMakeLists.txt" '{E314A650-DCA4-416E-974E-18EA37C213EA}' '{5E0A9C2B-6B1D-4C8E-9F3A-2D7B41E8C6A1}'
replace "$SRC/CMakeLists.txt" '1E62D59A-6EA4-476C-B707-4A32E88ED822' '8C3F1E27-4A9B-4D6C-B2E5-7F1A0D9C3B42'
replace "$SRC/CMakeLists.txt" '6FF9B5B6-389F-444A-9FDD-A286C36EA079' 'B7D24A93-1E5F-4C08-A6B9-3E8F2C1D7A53'

# 4. Linux AppImage: the packaging script hard-codes the icon name
if [ -f "$SRC/admin/linux/build-appimage.sh" ]; then
    replace "$SRC/admin/linux/build-appimage.sh" 'apps/Nextcloud.png' 'apps/Orneos.png'
fi

echo "desktop overlay applied on $(git -C "$SRC" describe --tags 2>/dev/null || echo "$SRC")"

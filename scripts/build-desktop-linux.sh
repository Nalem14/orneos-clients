#!/bin/bash
# Builds the Orneos desktop client AppImage in Nextcloud's own CI image (same toolchain as their releases).
# Usage: scripts/build-desktop-linux.sh <desktop-checkout-with-overlay> [build-number]
set -euo pipefail
SRC="$(cd "${1:?path to the branded desktop checkout}" && pwd)"
BUILDNR="${2:-0}"
IMAGE=$(grep -oP 'container:\s*\K\S+' "$SRC/.github/workflows/linux-appimage.yml" | head -1)
echo "image: $IMAGE"
# The script leaves orneos-<version>-x86_64.AppImage at the root of the checkout
docker run --rm -v "$SRC":/src -w /src "$IMAGE" bash -c "
    BUILDNR=$BUILDNR BUILD_UPDATER=ON DESKTOP_CLIENT_ROOT=/src APPNAME=Orneos EXECUTABLE_NAME=orneos \
    QT_BASE_DIR=/root/linux-gcc-x86_64 ./admin/linux/build-appimage.sh; status=\$?; chown -R $(id -u):$(id -g) /src; exit \$status"
# Named after the version the client reports (and the update feed compares): orneos-35.0.0.<build>-x86_64.AppImage
V=$(for k in MAJOR MINOR PATCH; do grep -oP "MIRALL_VERSION_$k \K\d+" "$SRC/VERSION.cmake"; done | paste -sd.)
for f in "$SRC"/orneos-*-x86_64.AppImage; do
    [ "$f" = "$SRC/orneos-$V.$BUILDNR-x86_64.AppImage" ] || mv "$f" "$SRC/orneos-$V.$BUILDNR-x86_64.AppImage"
done
ls -la "$SRC/orneos-$V.$BUILDNR-x86_64.AppImage"

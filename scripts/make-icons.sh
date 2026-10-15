#!/bin/bash
# Regenerates the PNG icons of the overlays from brand/mark-1024.svg (ImageMagick). Run after a logo change, then commit.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=brand/mark-1024.svg
png() { convert -background none -density 72 "$1" -resize "$2x$2" "$3"; }

C=desktop/theme/colored
for n in wizard_logo wizard-nextcloud; do
    cp "$SRC" "$C/$n.svg"; png "$SRC" 64 "$C/$n.png"; png "$SRC" 128 "$C/$n@2x.png"
done
png "$SRC" 150 "$C/Orneos-w10starttile.png"

# Android launcher fallbacks (the adaptive icon itself is a vector, res/drawable/ic_launcher_*.xml)
for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
    mkdir -p "android/res/mipmap-${d%%:*}"; png "$SRC" "${d##*:}" "android/res/mipmap-${d%%:*}/ic_launcher.png"
done
echo "icons ok"

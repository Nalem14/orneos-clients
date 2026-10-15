#!/bin/bash
# Applies the Orneos Meet overlay to a checkout of nextcloud/talk-desktop at the tag from versions.env.
# Talk Desktop has an official branding hook: .overrides/build.config.json (name, enforced server, ids, colors);
# our images replace the Nextcloud Talk ones of the same name in img/.
# Usage: scripts/apply-talk-desktop.sh <path-to-talk-desktop-checkout>. Idempotent; fails loudly when upstream changed.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?path to the nextcloud/talk-desktop checkout}"
[ -f "$SRC/build/resolveBuildConfig.js" ] || { echo "not a nextcloud/talk-desktop checkout: $SRC" >&2; exit 1; }
grep -q "'../.overrides/build.config.json'" "$SRC/build/resolveBuildConfig.js" \
    || { echo "upstream changed: .overrides/build.config.json is no longer read" >&2; exit 1; }

# 1. Branding (⚠ never change the app ids once published: the installed apps would not update)
mkdir -p "$SRC/.overrides"
cp "$HERE/talk-desktop/build.config.json" "$SRC/.overrides/build.config.json"

# 2. Images (every Nextcloud Talk trademark image that ships in the app or its installers)
for f in $(cd "$HERE/talk-desktop/img" && find . -type f | sed 's#^\./##'); do
    [ -e "$SRC/img/$f" ] || { echo "upstream changed: img/$f does not exist anymore" >&2; exit 1; }
    cp "$HERE/talk-desktop/img/$f" "$SRC/img/$f"
done

# 3. Windows "Apps & features" icon is fetched from a URL: ours
OLD='https://raw.githubusercontent.com/nextcloud/talk-desktop/refs/heads/main/img/icons/icon.ico'
NEW='https://raw.githubusercontent.com/Nalem14/orneos-clients/main/talk-desktop/img/icons/icon.ico'
if ! grep -qF "$NEW" "$SRC/forge.config.js"; then
    grep -qF "$OLD" "$SRC/forge.config.js" || { echo "upstream changed: Squirrel iconUrl not found" >&2; exit 1; }
    OLD="$OLD" NEW="$NEW" perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$SRC/forge.config.js"
fi

echo "talk-desktop overlay applied on $(git -C "$SRC" describe --tags 2>/dev/null || echo "$SRC")"

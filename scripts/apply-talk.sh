#!/bin/bash
# Applies the Orneos Meet overlay to a checkout of nextcloud/talk-android at the tag from versions.env.
# "generic" flavor (no Google Play services, UnifiedPush with the embedded FCM distributor of our Firebase project);
# our resources go into its source set, merged over app/src/main by Android.
# Usage: scripts/apply-talk.sh <path-to-talk-android-checkout>. Idempotent; fails loudly when upstream changed shape.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?path to the nextcloud/talk-android checkout}"
GRADLE=$(ls "$SRC"/app/build.gradle* 2>/dev/null | head -1)
[ -n "$GRADLE" ] || { echo "not a nextcloud/talk-android checkout: $SRC" >&2; exit 1; }

# 1. Resources: settings (server, account shared with Orneos Files, Firebase), icons
mkdir -p "$SRC/app/src/generic/res"
cp -r "$HERE"/talk/res/* "$SRC/app/src/generic/res/"

# The Google API key stays out of this public repo. The server passes google-services.json
# (ORNEOS_GOOGLE_SERVICES); CI leaves the BUILD_INJECTED placeholder, which is enough to compile.
SETUP="$SRC/app/src/generic/res/values/setup.xml"
if [ -n "${ORNEOS_GOOGLE_SERVICES:-}" ]; then
    [ -f "$ORNEOS_GOOGLE_SERVICES" ] || { echo "missing $ORNEOS_GOOGLE_SERVICES" >&2; exit 1; }
    python3 - "$ORNEOS_GOOGLE_SERVICES" "$SETUP" <<'PY'
import json, sys
src, dest = sys.argv[1:]
key = json.load(open(src))["client"][0]["api_key"][0]["current_key"]
if not key.startswith("AIza") or len(key) < 30:
    sys.exit("google-services.json has no API key")
text = open(dest).read()
if text.count("BUILD_INJECTED") != 2:
    sys.exit("setup.xml is missing the two Firebase key placeholders")
open(dest, "w").write(text.replace("BUILD_INJECTED", key))
PY
fi

# 2. Package id of the generic flavor: eu.orneos.talk (⚠ never change once published; registered in Firebase)
python3 - "$GRADLE" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
if 'applicationId = "eu.orneos.talk"' not in s:
    m = re.search(r'create\("generic"\)\s*\{\s*applicationId\s*=\s*"com\.nextcloud\.talk2"', s)
    if not m:
        sys.exit('upstream changed: generic flavor applicationId not found in ' + p)
    s = s[:m.start()] + m.group(0).replace('com.nextcloud.talk2', 'eu.orneos.talk') + s[m.end():]
    open(p, 'w').write(s)
PY

# 3. Nothing left under the Nextcloud trademark in what we ship
for f in drawable/ic_logo.xml drawable/ic_launcher_foreground.xml drawable/ic_notification.xml drawable/ic_talk.xml; do
    [ -f "$SRC/app/src/generic/res/$f" ] || { echo "missing replacement for $f" >&2; exit 1; }
done

echo "talk overlay applied on $(git -C "$SRC" describe --tags 2>/dev/null || echo "$SRC")"

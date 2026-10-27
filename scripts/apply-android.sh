#!/bin/bash
# Applies the Orneos overlay to a checkout of nextcloud/android at the tag from versions.env.
# We build the "generic" flavor (the F-Droid one: no Google services); our resources go into its source set,
# which Android merges over app/src/main. Usage: scripts/apply-android.sh <path-to-android-checkout>
# Idempotent; fails loudly when upstream changed shape.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?path to the nextcloud/android checkout}"
GRADLE="$SRC/app/build.gradle.kts"
[ -f "$GRADLE" ] || { echo "not a nextcloud/android checkout: $SRC" >&2; exit 1; }

# 1. Resources: settings, logos, launcher icons
mkdir -p "$SRC/app/src/generic/res"
cp -r "$HERE"/android/res/* "$SRC/app/src/generic/res/"

# 2. Package id of the generic flavor: eu.orneos.files (⚠ never change once published)
python3 - "$GRADLE" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
if 'applicationId = "eu.orneos.files"' not in s:
    m = re.search(r'register\("generic"\)\s*\{\s*applicationId\s*=\s*"com\.nextcloud\.client"', s)
    if not m:
        sys.exit('upstream changed: generic flavor applicationId not found in ' + p)
    s = s[:m.start()] + m.group(0).replace('com.nextcloud.client', 'eu.orneos.files') + s[m.end():]
    open(p, 'w').write(s)
PY

# 3. Nothing left under the Nextcloud trademark in what we ship
for f in drawable/logo.xml drawable/ic_launcher_foreground.xml drawable/nextcloud_logo.xml; do
    [ -f "$SRC/app/src/generic/res/$f" ] || { echo "missing replacement for $f" >&2; exit 1; }
done

# 4. Phone photos go into the library: camera folders upload to /Photos/<folder> (instant_upload_path,
#    translated in many languages upstream, so overridden in each) and other auto-upload folders to /Photos,
#    the folder the cloud's Photos and Orneos Photos show by default. Only new folders: those already set up
#    on a phone keep their path.
python3 - "$SRC/app/src" <<'PY'
import os, re, sys
src = sys.argv[1]
main = os.path.join(src, "main", "res")
found = 0
for folder in sorted(os.listdir(main)):
    path = os.path.join(main, folder, "strings.xml")
    if not folder.startswith("values") or not os.path.isfile(path):
        continue
    if not re.search(r'<string name="instant_upload_path"', open(path, encoding="utf-8").read()):
        continue
    found += 1
    out = os.path.join(src, "generic", "res", folder)
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "orneos_photos.xml"), "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '    <string name="instant_upload_path" translatable="false">/Photos</string>\n'
                '    <string name="auto_upload_path" translatable="false">/Photos</string>\n</resources>\n')
if not found:
    sys.exit("upstream changed: instant_upload_path not found in " + main)
print(f"photos upload path set in {found} languages")
PY

# 5. Same official tag, new overlay: versionBuild is the stable increment (90–99) added into
#    versionCode. Upstream ships 90; ANDROID_REVISION in versions.env takes the next slot.
#    versionName stays 35.0.x. Idempotent. 0 leaves the official number untouched.
REV=$(sed -n 's/^ANDROID_REVISION=//p' "$HERE/versions.env")
python3 - "$GRADLE" "${REV:-0}" <<'PY'
import re, sys
p, rev = sys.argv[1], int(sys.argv[2])
if rev == 0:
    sys.exit(0)
s = open(p).read()
m = re.search(r'val versionBuild = (\d+)', s)
if not m:
    sys.exit('upstream changed: versionBuild not found in ' + p)
current = int(m.group(1))
if not 90 <= current <= 99:
    sys.exit(f'upstream versionBuild {current} is not a stable build')
target = 90 + rev
if not 90 <= target <= 99:
    sys.exit(f'ANDROID_REVISION {rev} leaves the stable band 90-99')
if target < current:
    sys.exit(f'ANDROID_REVISION {rev} would downgrade versionBuild {current} to {target}')
if target != current:
    s = s.replace(f'val versionBuild = {current}', f'val versionBuild = {target}', 1)
    open(p, 'w').write(s)
    print(f'versionBuild {current} -> {target}')
PY

echo "android overlay applied on $(git -C "$SRC" describe --tags 2>/dev/null || echo "$SRC")"

#!/bin/bash
# Applies the Orneos Passwords overlay to a checkout of hegocre/NextcloudPasswords (Android client of the Passwords
# app of the cloud, GPL-3.0) at PASSWORDS_TAG from versions.env.
# This app has no branding settings (no flavor, no setup.xml): the overlay replaces resources by name in app/src/main
# and changes a few values in place. The code patches are kept to what no resource can do: the Orneos server
# instead of a server field, the Orneos colours by default, and a fixed client name for the cloud's session list.
# Usage: scripts/apply-passwords.sh <path-to-NextcloudPasswords-checkout>. Idempotent; fails loudly when upstream changed shape.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?path to the hegocre/NextcloudPasswords checkout}"
GRADLE="$SRC/app/build.gradle"
MAIN="$SRC/app/src/main"
JAVA="$MAIN/java/com/hegocre/nextcloudpasswords"
grep -q "namespace = 'com.hegocre.nextcloudpasswords'" "$GRADLE" 2>/dev/null || { echo "not a hegocre/NextcloudPasswords checkout: $SRC" >&2; exit 1; }

# 1. Icons: the upstream launcher fallbacks are .webp, ours .png (same name: the .webp must go)
rm -f "$MAIN"/res/mipmap-*/ic_launcher.webp
cp -r "$HERE"/passwords/res/* "$MAIN/res/"
for f in drawable/ic_launcher_foreground.xml drawable/ic_launcher_background.xml drawable/ic_tile.xml drawable/app_icon.png mipmap-xxxhdpi/ic_launcher.png; do
    [ -f "$HERE/passwords/res/$f" ] || { echo "missing replacement for $f" >&2; exit 1; }
done

REV=$(sed -n 's/^PASSWORDS_REVISION=//p' "$HERE/versions.env")
python3 - "$SRC" "${REV:-0}" <<'PY'
import glob, os, re, sys
src, rev = sys.argv[1], int(sys.argv[2])
main = os.path.join(src, 'app/src/main')
java = os.path.join(main, 'java/com/hegocre/nextcloudpasswords')

def patch(path, old, new, done=None):
    """Replaces old by new once; done (default new) tells it is already applied"""
    s = open(path).read()
    if (done or new) in s:
        return
    if old not in s:
        sys.exit(f'upstream changed: {old!r} not found in {path}')
    open(path, 'w').write(s.replace(old, new, 1))

gradle = os.path.join(src, 'app/build.gradle')
# 2. Package id: eu.orneos.passwords (⚠ never change once published)
patch(gradle, 'applicationId "com.hegocre.nextcloudpasswords"', 'applicationId "eu.orneos.passwords"')
# One universal APK (signed by build-android.sh), not one per ABI
patch(gradle, 'enable = !isBuildingBundle', 'enable = false')
# versionCode: upstream × 100 + PASSWORDS_REVISION, so the overlay can be republished on the same tag
s = open(gradle).read()
m = re.search(r'def vCode = (\d+)', s)
if not m:
    sys.exit('upstream changed: vCode not found in ' + gradle)
code = int(m.group(1))
if code < 1000:  # not yet scaled
    if not 0 <= rev <= 99:
        sys.exit(f'PASSWORDS_REVISION {rev} must be 0-99')
    s = s.replace(m.group(0), f'def vCode = {code * 100 + rev}', 1)
    open(gradle, 'w').write(s)
    print(f'versionCode {code} -> {code * 100 + rev}')

# 3. Names: no Nextcloud trademark in what we ship
names = {'values': 'Orneos Passwords', 'values-fr-rFR': 'Mots de passe Orneos', 'values-de-rDE': 'Orneos Passwörter'}
colours = {'values': 'Use Orneos colors', 'values-fr-rFR': "Utiliser les couleurs d\\'Orneos", 'values-de-rDE': 'Orneos-Farben verwenden'}
for path in glob.glob(os.path.join(main, 'res/values*/strings.xml')):
    folder = os.path.basename(os.path.dirname(path))
    s = open(path).read()
    s = re.sub(r'(<string name="app_name">)[^<]*(</string>)', lambda m: m.group(1) + names.get(folder, names['values']) + m.group(2), s)
    if folder in colours:
        s = re.sub(r'(<string name="use_nextcloud_color_preference_title">)[^<]*(</string>)', lambda m: m.group(1) + colours[folder] + m.group(2), s)
    s = re.sub(r"Nextcloud(u|\\'i)?", 'Orneos', s)
    open(path, 'w').write(s)

# 4. No server to choose: the sign-in opens straight on Orneos (Login Flow v1 of app.orneos.eu); the card stays,
#    filled in, if the person goes back
login = os.path.join(java, 'ui/components/LoginView.kt')
patch(login, 'val (urlText, setUrlText) = rememberSaveable { mutableStateOf("") }',
      'val (urlText, setUrlText) = rememberSaveable { mutableStateOf("https://app.orneos.eu") }')
patch(login, 'import androidx.compose.runtime.Composable\n',
      'import androidx.compose.runtime.Composable\nimport androidx.compose.runtime.LaunchedEffect\n')
patch(login, '''    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.verticalScroll(rememberScrollState())
        ) {
            LoginCard(''', '''    // Orneos: straight to the Orneos sign-in, once
    var orneosStarted by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (!orneosStarted) {
            orneosStarted = true
            loginIntent.putExtra("login_url", "https://app.orneos.eu")
            launchLoginWebView.launch(loginIntent)
        }
    }

    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.verticalScroll(rememberScrollState())
        ) {
            LoginCard(''', done='orneosStarted')
patch(login, '"${stringResource(R.string.example)}: https://cloud.example.com/"', '"Orneos"')
# The sign-in browser's user agent names the app password in the cloud (Security, sessions): one fixed name,
# the one tools/client-release.php looks for to tell its users about an update
patch(login, 'settings.userAgentString = it.getString(R.string.app_name)', 'settings.userAgentString = "Orneos Passwords (Android)"')

# 5. Orneos colours by default: the cloud's accent (Klein, theming) until the person changes it in the settings
prefs = os.path.join(java, 'utils/PreferencesManager.kt')
patch(prefs, 'getPreference(PreferenceKeys.INSTANCE_COLOR, "#745bca")', 'getPreference(PreferenceKeys.INSTANCE_COLOR, "#002FA7")')
patch(prefs, 'getPreference(PreferenceKeys.USE_NEXTCLOUD_INSTANCE_COLOR, false)', 'getPreference(PreferenceKeys.USE_NEXTCLOUD_INSTANCE_COLOR, true)')
PY

echo "passwords overlay applied on $(git -C "$SRC" describe --tags 2>/dev/null || echo "$SRC")"

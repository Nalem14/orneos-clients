#!/bin/bash
# Looks for new official releases. Prints what changed; with --write, bumps versions.env.
# A bump is then built (scripts/build-*), tested, and published (tools/client-release.php).
set -euo pipefail
cd "$(dirname "$0")/.."
. ./versions.env
latest() { # repo, tag regex (final releases only: no rc/beta)
    git ls-remote --tags --refs "https://github.com/nextcloud/$1.git" | grep -oE "refs/tags/$2$" | sed 's#refs/tags/##' | sort -V | tail -1
}
NEW_DESKTOP=$(latest desktop 'v[0-9]+\.[0-9]+\.[0-9]+')
NEW_ANDROID=$(latest android 'stable-[0-9]+\.[0-9]+\.[0-9]+')
NEW_TALK=$(latest talk-android 'v[0-9]+\.[0-9]+\.[0-9]+')
NEW_TALK_DESKTOP=$(latest talk-desktop 'v[0-9]+\.[0-9]+\.[0-9]+')
changed=0
[ "$NEW_DESKTOP" != "$DESKTOP_TAG" ] && { echo "desktop: $DESKTOP_TAG -> $NEW_DESKTOP"; changed=1; }
[ "$NEW_ANDROID" != "$ANDROID_TAG" ] && { echo "android: $ANDROID_TAG -> $NEW_ANDROID"; changed=1; }
[ "$NEW_TALK" != "$TALK_TAG" ] && { echo "talk: $TALK_TAG -> $NEW_TALK"; changed=1; }
[ "$NEW_TALK_DESKTOP" != "$TALK_DESKTOP_TAG" ] && { echo "talk-desktop: $TALK_DESKTOP_TAG -> $NEW_TALK_DESKTOP"; changed=1; }
if [ "$changed" = 1 ] && [ "${1:-}" = "--write" ]; then
    sed -i "s/^DESKTOP_TAG=.*/DESKTOP_TAG=$NEW_DESKTOP/; s/^ANDROID_TAG=.*/ANDROID_TAG=$NEW_ANDROID/; s/^TALK_TAG=.*/TALK_TAG=$NEW_TALK/; s/^TALK_DESKTOP_TAG=.*/TALK_DESKTOP_TAG=$NEW_TALK_DESKTOP/" versions.env
    # A new official tag brings its own versionCode; the overlay increment starts over
    [ "$NEW_ANDROID" != "$ANDROID_TAG" ] && sed -i 's/^ANDROID_REVISION=.*/ANDROID_REVISION=0/' versions.env
    [ "$NEW_TALK" != "$TALK_TAG" ] && sed -i 's/^TALK_REVISION=.*/TALK_REVISION=0/' versions.env
fi
[ "$changed" = 0 ] && echo "up to date (desktop $DESKTOP_TAG, android $ANDROID_TAG, talk $TALK_TAG, talk-desktop $TALK_DESKTOP_TAG)"
exit 0

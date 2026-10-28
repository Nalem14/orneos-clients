#!/bin/bash
# Builds an Orneos Android app (generic flavor): Orneos Files (nextcloud/android) or Orneos Meet (nextcloud/talk-android),
# in a JDK 21 container; the Android SDK, NDK and Gradle caches live in $CACHE so later builds are fast.
# Usage: scripts/build-android.sh <checkout-with-overlay> [debug|release]
# release: needs ORNEOS_KEYSTORE (path), ORNEOS_KEYSTORE_PASS and ORNEOS_KEY_ALIAS;
# output <ORNEOS_APK_NAME, default orneos>-<versionCode>.apk (the Files app's updater expects orneos-<versionCode>.apk)
set -euo pipefail
SRC="$(cd "${1:?path to the branded android checkout}" && pwd)"
MODE="${2:-debug}"
if [ "$MODE" = release ] && grep -q BUILD_INJECTED "$SRC/app/src/generic/res/values/setup.xml" 2>/dev/null; then
    echo "release build still has the Firebase key placeholder: pass ORNEOS_GOOGLE_SERVICES to apply-talk.sh" >&2
    exit 1
fi
CACHE="${CACHE:-$HOME/.cache/orneos-android-build}"
mkdir -p "$CACHE/sdk" "$CACHE/gradle"
NAME="${ORNEOS_APK_NAME:-orneos}"
NDK_VERSION=""; CMAKE_VERSION=""
[ -f "$SRC/ndk.env" ] && . "$SRC/ndk.env" # only the Files app has native code
NATIVE=$( [ -n "$NDK_VERSION" ] && echo "'ndk;$NDK_VERSION' 'cmake;$CMAKE_VERSION'" || true)
TASK=$([ "$MODE" = release ] && echo assembleGenericRelease || echo assembleGenericDebug)

# Gradle may drop transform dirs while chown walks the cache; with bash -e that
# would discard a successful build status. Keep the gradle exit code either way.
docker run --rm -v "$SRC":/src -v "$CACHE/sdk":/sdk -v "$CACHE/gradle":/root/.gradle -w /src \
    -e ANDROID_HOME=/sdk -e ANDROID_SDK_ROOT=/sdk -e DEBIAN_FRONTEND=noninteractive \
    eclipse-temurin:21-jdk bash -ec "
    apt-get -qq update >/dev/null && apt-get -qq install -y unzip curl >/dev/null
    if [ ! -x /sdk/cmdline-tools/latest/bin/sdkmanager ]; then
        curl -sSL -o /tmp/tools.zip https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
        unzip -q /tmp/tools.zip -d /sdk/cmdline-tools && mv /sdk/cmdline-tools/cmdline-tools /sdk/cmdline-tools/latest
    fi
    yes | /sdk/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null || true
    [ -z \"$NATIVE\" ] || /sdk/cmdline-tools/latest/bin/sdkmanager --install $NATIVE >/dev/null
    ./gradlew --no-daemon -q $TASK; status=\$?
    chown -R $(id -u):$(id -g) /src /sdk /root/.gradle 2>/dev/null || true
    exit \$status"

OUT="$SRC/app/build/outputs/apk/generic/$MODE"
if [ "$MODE" = release ]; then
    APK=$(ls "$OUT"/*-unsigned.apk | head -1)
    CODE=$(docker run --rm -v "$CACHE/sdk":/sdk -v "$OUT":/out eclipse-temurin:21-jdk bash -c \
        "/sdk/build-tools/\$(ls /sdk/build-tools | sort -V | tail -1)/aapt2 dump badging /out/$(basename "$APK")" | grep -oP "versionCode='\K\d+")
    docker run --rm -v "$CACHE/sdk":/sdk -v "$OUT":/out -v "$(dirname "$ORNEOS_KEYSTORE")":/ks -e PASS="$ORNEOS_KEYSTORE_PASS" eclipse-temurin:21-jdk bash -c \
        "/sdk/build-tools/\$(ls /sdk/build-tools | sort -V | tail -1)/apksigner sign --ks /ks/$(basename "$ORNEOS_KEYSTORE") --ks-key-alias '$ORNEOS_KEY_ALIAS' \
         --ks-pass env:PASS --v4-signing-enabled false --out /out/$NAME-$CODE.apk /out/$(basename "$APK") \
         && chown $(id -u):$(id -g) /out/$NAME-$CODE.apk"
    echo "$CODE" > "$OUT/latest"
fi
ls -la "$OUT"

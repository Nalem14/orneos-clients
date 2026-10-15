#!/bin/bash
# Builds the Orneos Android app (generic flavor) in a JDK 21 container; the Android SDK, NDK and Gradle caches
# live in $CACHE so later builds are fast.
# Usage: scripts/build-android.sh <android-checkout-with-overlay> [debug|release]
# release: needs ORNEOS_KEYSTORE (path), ORNEOS_KEYSTORE_PASS and ORNEOS_KEY_ALIAS; output orneos-<versionCode>.apk
set -euo pipefail
SRC="$(cd "${1:?path to the branded android checkout}" && pwd)"
MODE="${2:-debug}"
CACHE="${CACHE:-$HOME/.cache/orneos-android-build}"
mkdir -p "$CACHE/sdk" "$CACHE/gradle"
. "$SRC/ndk.env"
TASK=$([ "$MODE" = release ] && echo assembleGenericRelease || echo assembleGenericDebug)

docker run --rm -v "$SRC":/src -v "$CACHE/sdk":/sdk -v "$CACHE/gradle":/root/.gradle -w /src \
    -e ANDROID_HOME=/sdk -e ANDROID_SDK_ROOT=/sdk eclipse-temurin:21-jdk bash -ec "
    apt-get -qq update >/dev/null && apt-get -qq install -y unzip curl >/dev/null
    if [ ! -x /sdk/cmdline-tools/latest/bin/sdkmanager ]; then
        curl -sSL -o /tmp/tools.zip https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
        unzip -q /tmp/tools.zip -d /sdk/cmdline-tools && mv /sdk/cmdline-tools/cmdline-tools /sdk/cmdline-tools/latest
    fi
    yes | /sdk/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null || true
    /sdk/cmdline-tools/latest/bin/sdkmanager --install 'ndk;$NDK_VERSION' 'cmake;$CMAKE_VERSION' >/dev/null
    ./gradlew --no-daemon -q $TASK; status=\$?
    chown -R $(id -u):$(id -g) /src /sdk /root/.gradle; exit \$status"

OUT="$SRC/app/build/outputs/apk/generic/$MODE"
if [ "$MODE" = release ]; then
    APK=$(ls "$OUT"/*-unsigned.apk | head -1)
    CODE=$(docker run --rm -v "$CACHE/sdk":/sdk -v "$OUT":/out eclipse-temurin:21-jdk bash -c \
        "/sdk/build-tools/\$(ls /sdk/build-tools | sort -V | tail -1)/aapt2 dump badging /out/$(basename "$APK")" | grep -oP "versionCode='\K\d+")
    docker run --rm -v "$CACHE/sdk":/sdk -v "$OUT":/out -v "$(dirname "$ORNEOS_KEYSTORE")":/ks -e PASS="$ORNEOS_KEYSTORE_PASS" eclipse-temurin:21-jdk bash -c \
        "/sdk/build-tools/\$(ls /sdk/build-tools | sort -V | tail -1)/apksigner sign --ks /ks/$(basename "$ORNEOS_KEYSTORE") --ks-key-alias '$ORNEOS_KEY_ALIAS' \
         --ks-pass env:PASS --out /out/orneos-$CODE.apk /out/$(basename "$APK")"
    echo "$CODE" > "$OUT/latest"
fi
ls -la "$OUT"

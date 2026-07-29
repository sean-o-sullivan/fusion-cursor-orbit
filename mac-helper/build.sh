#!/bin/zsh
set -eu

root=${0:A:h:h}
source_file="$root/mac-helper/CursorOrbitHelper.m"
info_plist="$root/mac-helper/Info.plist"
app="$root/dist/CursorOrbitHelper.app"
macos="$app/Contents/MacOS"

rm -rf "$app"
mkdir -p "$macos"
cp "$info_plist" "$app/Contents/Info.plist"

xcrun clang \
    -fobjc-arc \
    -mmacosx-version-min=14.0 \
    -Wall \
    -Wextra \
    -Werror \
    -framework Cocoa \
    -framework ApplicationServices \
    "$source_file" \
    -o "$macos/CursorOrbitHelper"

codesign \
    --force \
    --deep \
    --sign - \
    --identifier com.sean.CursorOrbitHelper \
    "$app"

echo "$app"

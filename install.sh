#!/bin/zsh
set -eu

root=${0:A:h}
uid=$(id -u)
label="com.sean.CursorOrbitHelper"

fusion_addins="$HOME/Library/Application Support/Autodesk/Autodesk Fusion 360/API/AddIns"
addin="$fusion_addins/CursorOrbit"
applications="$HOME/Applications"
helper="$applications/CursorOrbitHelper.app"
helper_executable="$helper/Contents/MacOS/CursorOrbitHelper"
launch_agents="$HOME/Library/LaunchAgents"
agent="$launch_agents/$label.plist"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "CursorOrbit supports macOS only." >&2
    exit 1
fi

if ! xcrun --find clang >/dev/null 2>&1; then
    echo "Install Xcode Command Line Tools first: xcode-select --install" >&2
    exit 1
fi

zsh "$root/mac-helper/build.sh"

launchctl bootout "gui/$uid/$label" 2>/dev/null || true

mkdir -p "$fusion_addins" "$applications" "$launch_agents"
rm -rf "$addin" "$helper"
cp -R "$root/CursorOrbit" "$addin"
cp -R "$root/dist/CursorOrbitHelper.app" "$helper"
cp "$root/mac-helper/com.sean.CursorOrbitHelper.plist" "$agent"
plutil -replace ProgramArguments.0 -string "$helper_executable" "$agent"

launchctl bootstrap "gui/$uid" "$agent"

echo
echo "CursorOrbit installed."
echo "1. Enable CursorOrbitHelper in System Settings > Privacy & Security > Accessibility."
echo "2. Restart Fusion. CursorOrbit will run automatically."

open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" \
    >/dev/null 2>&1 || true

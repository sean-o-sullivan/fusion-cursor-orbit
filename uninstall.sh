#!/bin/zsh
set -eu

uid=$(id -u)
label="com.sean.CursorOrbitHelper"
agent="$HOME/Library/LaunchAgents/$label.plist"
helper="$HOME/Applications/CursorOrbitHelper.app"
addin="$HOME/Library/Application Support/Autodesk/Autodesk Fusion 360/API/AddIns/CursorOrbit"

launchctl bootout "gui/$uid/$label" 2>/dev/null || true
rm -f "$agent"
rm -rf "$helper" "$addin"

echo "CursorOrbit removed. Restart Fusion to unload the add-in."

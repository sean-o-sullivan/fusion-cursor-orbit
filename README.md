# Fusion Cursor Orbit

Cursor-centred orbit for Autodesk Fusion on a Mac trackpad.

Hold **Shift** to lock the orbit pivot to the point beneath the cursor. Keep
holding Shift across as many two-finger swipes as needed. Release Shift to
return to Fusion's automatic orbit-centre behaviour.

## Requirements

- Autodesk Fusion
- macOS 14 or newer
- Xcode Command Line Tools

Install the command-line tools if needed:

```sh
xcode-select --install
```

## Install

```sh
git clone https://github.com/sean-o-sullivan/fusion-cursor-orbit.git
cd fusion-cursor-orbit
./install.sh
```

Enable **CursorOrbitHelper** in **System Settings > Privacy & Security >
Accessibility**, then restart Fusion. Both components start automatically
after that.

The installer builds the helper locally, installs the Fusion add-in, and
creates a per-user macOS LaunchAgent. It does not require `sudo`.

## Uninstall

```sh
./uninstall.sh
```

Restart Fusion afterward. You may also remove CursorOrbitHelper manually from
the Accessibility list.

## What Accessibility access does

The helper listens only for modifier-flag changes. When Fusion is the
frontmost application and Shift is pressed, it posts one synthetic middle
click at the current cursor position. It does not record text, inspect other
keystrokes, access documents, or use the network.

The Fusion add-in waits on a per-user local socket. On Shift release, the
helper asks it to run Fusion's native orbit-centre reset command. Neither
component polls the camera or rewrites the view.

## Limitations

- macOS only.
- Tested on Apple silicon.
- Uses Fusion's built-in `ResetOrbitCenterCommand` identifier, which Autodesk
  could change in a future update.

Logs are written to:

- `$TMPDIR/CursorOrbit.log`
- `$TMPDIR/CursorOrbitHelper.log`

## Development

```sh
zsh mac-helper/build.sh
python3 -m py_compile CursorOrbit/CursorOrbit.py
```

## Licence

[MIT](LICENSE)

Autodesk and Fusion are trademarks of Autodesk, Inc. This project is
independent and is not affiliated with or endorsed by Autodesk.

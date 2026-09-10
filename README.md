# Media Player

An unofficial Noctalia media widget for viewing and controlling MPRIS-compatible
music and video players from the desktop. It keeps the focus on the essentials:
the current title, artist or channel, playback progress, and transport controls,
without using album artwork or taking up unnecessary space.

The widget communicates with the active player through `playerctl`, so it can
work with Spotify, VLC, Firefox, and other MPRIS-compatible applications. It
can also hide itself when no player is active, keeping the desktop uncluttered
when media is not in use.

<img width="287" height="108" alt="image" src="https://github.com/user-attachments/assets/b7f2a88c-85f7-41b0-a7e0-541fd7f693a5" />

## Structure

```text
media_widget.luau      Widget implementation
plugin.toml            Plugin manifest and settings
translations/en.json   English labels
LICENSE                MIT license
```

## Requirements

- Noctalia v5 with plugin API 24 or later
- `playerctl` available on `PATH`
- An MPRIS-compatible media player

## Install and enable

These commands assume that this repository is located at
`./noctalia-media-widget`. If you cloned it elsewhere, replace the
source path with your checkout location. When updating an existing installation,
replace the previous `media-widget` directory before copying so the installed
files stay in sync with the repository.

```sh
mkdir -p ~/.local/share/noctalia/plugins
cp -r ./noctalia-media-widget ~/.local/share/noctalia/plugins/media-widget
noctalia msg plugins enable kmw0410/media-player
```

After enabling the plugin, open Noctalia's **Desktop Widgets** editor, add
**Media Player** from the plugin list, and position it where you prefer. If the
widget does not appear, reload Noctalia and check that `playerctl status` runs
successfully in a terminal.

## Settings

The widget settings let you adjust:

- Progress bar visibility
- Font selection from the system-installed font list
- Card edge shadow
- Whether to hide the widget when no player is active

When more than one player is running, the widget shows the MPRIS player selected
by `playerctl`. Play/pause, previous, and next controls are available when the
selected player exposes those MPRIS actions.

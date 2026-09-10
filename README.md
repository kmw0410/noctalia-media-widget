# Media Player

A compact Noctalia desktop widget for MPRIS-compatible media players. It shows
the track title, artist, playback progress, and playback controls without album
artwork.

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
- An MPRIS-compatible player

## Install

```sh
mkdir -p ~/.local/share/noctalia/plugins
ln -s /home/kmw/noctalia-media-widget ~/.local/share/noctalia/plugins/media-player
noctalia msg plugins enable kmw0410/media-player
```

Then add **Media Player** from the plugin section in Noctalia's Desktop Widgets
editor and position it as desired.

## Settings

The widget supports progress visibility, font family, background, edge shadow,
and hiding when no player is active.

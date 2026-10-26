# Now Playing

An [Omarchy](https://omarchy.org) bar widget that shows **album art** and a **live audio
waveform** for whatever is playing, with one-click media controls.

![Now Playing in the Omarchy bar](preview.png)

## Features

- **Album art:** the cover of the current track, shown in the bar.
- **Jump to the player:** click the cover to go straight to what's playing:
  - switches to the **workspace** the player is on,
  - focuses its **window**,
  - brings the playing **tab** to the front in Chromium-based browsers (Chromium, Chrome,
    Brave, Edge and Chromium web apps).

  If a player can't switch tabs (Firefox, for example), it still focuses the right window.
- **Live waveform:** 10 bars driven by [cava](https://github.com/karlstav/cava) that move
  with the audio.
- **Media controls:** click the waveform to open a small, minimal card with **⏮ Previous**,
  **⏯ Play / Pause** and **⏭ Next**. Unavailable controls are dimmed.
- **Hover support:** if your bar opens panels on hover, the controls card opens on hover too.
- **Works with any MPRIS player:** Spotify, Spotifast, browsers, mpv, VLC and so on. It
  controls the player that is playing, or the first player if none is.
- **Stays out of the way:** the widget hides itself when no player is running.

## Requirements

| Package | Why | Install |
|---|---|---|
| **cava** | The waveform | `sudo pacman -S cava` |
| **jq** | Finding the player's window | Installed on Omarchy by default |

## Install

```bash
omarchy plugin add https://github.com/Jaideepo7/omarchy-now-playing.git --enable
```

**To choose where it goes in the bar:**

```bash
omarchy plugin enable jaideepo7.now-playing --section center
# or next to another widget:
omarchy plugin enable jaideepo7.now-playing --before omarchy.clock
```

## Uninstall

```bash
omarchy plugin remove jaideepo7.now-playing
```

## Customizing

- **Card size:** change `popupScale` in `BarWidget.qml`. The default is `1.35`.
- **Waveform:** `cava.conf` sets the bar count and frame rate. If you change `bars`, change
  `barCount` in `BarWidget.qml` to match.

## How "jump to the player" works

`focus-player.sh` takes the player's MPRIS bus name and does the following:

1. Asks D-Bus which process owns the player.
2. Finds the Hyprland window owned by that process, or by one of its parent processes.
   If no window matches, it falls back to the window class. When there are several matches,
   it prefers the window titled after the track, then the one used most recently.
3. Focuses that window, which also switches to its workspace.
4. Calls MPRIS `Raise`, which makes Chromium switch to the playing tab, then re-focuses the
   window that now shows the track.

To see which window it would pick without switching to it:

```bash
DRY_RUN=1 ./focus-player.sh org.mpris.MediaPlayer2.spotify spotify ""
```

## License

[MIT](LICENSE)

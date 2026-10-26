#!/bin/bash
# Jump to the window (and, where the player supports it, the tab) playing media.
# Usage: focus-player.sh <mpris bus name> <desktop entry> <track title>
#
# 1. Find the player's process from its D-Bus name, then the Hyprland window
#    owned by it or one of its ancestors (browsers own windows from the main
#    process). Several windows of one browser: prefer the one titled after the
#    track, else the most recently focused.
# 2. Focus it, which also switches to its workspace.
# 3. Ask the player to Raise itself (Chromium switches to the playing tab),
#    then re-focus by title in case the tab swap changed which window matches.

bus=$1
entry=$2
title=$3
[[ $bus == org.mpris.MediaPlayer2.* ]] || bus="org.mpris.MediaPlayer2.$bus"

focus() {
  [[ -n $1 ]] || return 1
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$1\" })" >/dev/null 2>&1 ||
    hyprctl dispatch focuswindow "address:$1" >/dev/null 2>&1
}

pid=$(busctl --user call org.freedesktop.DBus / org.freedesktop.DBus GetConnectionUnixProcessID s "$bus" 2>/dev/null | awk '{print $2}')

# The player's pid and its ancestors, nearest first.
pids=()
p=$pid
while [[ -n $p && $p -gt 1 ]]; do
  pids+=("$p")
  p=$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null)
done

clients=$(hyprctl clients -j 2>/dev/null)

pick() {
  jq -r --argjson pids "$(printf '%s\n' "${pids[@]}" | jq -sc 'map(tonumber)')" \
    --arg entry "$entry" --arg title "$title" '
    def byPid: [ .[] | select(.pid as $p | $pids | index($p)) ];
    def byClass: if $entry == "" then [] else [ .[] | select((.class // "") | test($entry; "i")) ] end;
    byPid as $owned
    | (if ($owned | length) > 0 then $owned else byClass end)
    | sort_by(.focusHistoryID)
    | (map(select($title != "" and ((.title // "") | contains($title)))) + .)
    | first.address // empty' <<<"$clients"
}

address=$(pick)
[[ -n $DRY_RUN ]] && { echo "$address"; exit 0; }
focus "$address"

# Raise picks the tab inside the browser; then follow it to its window.
busctl --user call "$bus" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2 Raise >/dev/null 2>&1 || exit 0
[[ -n $title ]] || exit 0
sleep 0.3
clients=$(hyprctl clients -j 2>/dev/null)
again=$(jq -r --arg title "$title" \
  'sort_by(.focusHistoryID) | map(select((.title // "") | contains($title))) | first.address // empty' <<<"$clients")
[[ -n $again ]] && focus "$again"
exit 0

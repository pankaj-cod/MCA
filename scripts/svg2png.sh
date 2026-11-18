#!/usr/bin/env bash
# Render every docs/figures/*.svg to a 3x PNG using headless Chrome (macOS).
set -euo pipefail
cd "$(dirname "$0")/../docs/figures"
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for f in *.svg; do
  read -r W H < <(grep -o "viewBox=.0 0 [0-9.]* [0-9.]*" "$f" | head -1 | awk '{print int($3+0.99), int($4+0.99)}')
  # headless Chrome loses ~90px of viewport height to the window frame: pad, then crop
  "$CH" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=3 \
        --default-background-color=ffffffff --window-size=$W,$((H+120)) \
        --screenshot="$PWD/${f%.svg}.png" "file://$PWD/$f" >/dev/null 2>&1
  sips -c $((H*3)) $((W*3)) --cropOffset 1 1 "${f%.svg}.png" >/dev/null
done

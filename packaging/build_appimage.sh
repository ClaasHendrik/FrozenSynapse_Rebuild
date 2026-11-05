#!/usr/bin/env bash
# Builds build/Cold_Synapse-<ver>-x86_64.AppImage. Run this on your own machine.
# Requires `appimagetool` (https://github.com/AppImage/appimagetool/releases). Download it yourself, check where it
# comes from, make it executable and put it on your PATH (or pass its path as the second argument).
# Usage: packaging/build_appimage.sh /path/to/Godot_v4.3-stable_linux.x86_64 [/path/to/appimagetool]
set -euo pipefail
GODOT="${1:?usage: $0 /path/to/Godot_v4.3-stable_linux.x86_64 [appimagetool]}"
TOOL="${2:-appimagetool}"
VER="${VERSION:-0.4.0}"
cd "$(dirname "$0")/.."
OUT=build; A="$OUT/Cold_Synapse.AppDir"
rm -rf "$A" && mkdir -p "$A/usr/bin"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-pack "Linux" "$OUT/cold-synapse.pck" >/dev/null
cp "$GODOT" "$A/usr/bin/cold-synapse"; chmod 755 "$A/usr/bin/cold-synapse"
cp "$OUT/cold-synapse.pck" "$A/usr/bin/"
cat > "$A/AppRun" <<'RUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/cold-synapse" --main-pack "$HERE/usr/bin/cold-synapse.pck" "$@"
RUN
chmod 755 "$A/AppRun"
cp packaging/cold-synapse.desktop "$A/"
cp packaging/icon.png "$A/cold-synapse.png"
cp packaging/LICENSE-GODOT.txt "$A/"
ARCH=x86_64 "$TOOL" "$A" "$OUT/Cold_Synapse-$VER-x86_64.AppImage"

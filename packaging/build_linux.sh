#!/usr/bin/env bash
# Builds the Linux packages: build/cold-synapse_<ver>_amd64.deb and build/cold-synapse-<ver>-linux-x86_64.tar.gz
# Usage: packaging/build_linux.sh /path/to/Godot_v4.3-stable_linux.x86_64
# The Godot binary is used as the runtime ("player") for the game's .pck file.
set -euo pipefail
GODOT="${1:?usage: $0 /path/to/Godot_v4.3-stable_linux.x86_64}"
VER="${VERSION:-0.4.0}"
cd "$(dirname "$0")/.."
OUT=build
rm -rf "$OUT/pkg" && mkdir -p "$OUT/pkg"

echo "== exporting game pack"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-pack "Linux" "$OUT/cold-synapse.pck" >/dev/null

LAUNCHER='#!/bin/sh
DIR="$(dirname "$(readlink -f "$0")")"
exec "$DIR/cold-synapse" --main-pack "$DIR/cold-synapse.pck" "$@"'

echo "== portable tarball"
P="$OUT/pkg/cold-synapse"
mkdir -p "$P"
cp "$GODOT" "$P/cold-synapse"; chmod 755 "$P/cold-synapse"
cp "$OUT/cold-synapse.pck" "$P/"
printf '%s\n' "$LAUNCHER" > "$P/run.sh"; chmod 755 "$P/run.sh"
cp packaging/icon.png packaging/cold-synapse.desktop packaging/LICENSE-GODOT.txt README.md "$P/"
tar -C "$OUT/pkg" -czf "$OUT/cold-synapse-$VER-linux-x86_64.tar.gz" cold-synapse

echo "== .deb package"
D="$OUT/pkg/deb"
mkdir -p "$D/DEBIAN" "$D/opt/cold-synapse" "$D/usr/bin" "$D/usr/share/applications" "$D/usr/share/icons/hicolor/256x256/apps" "$D/usr/share/doc/cold-synapse"
cp "$GODOT" "$D/opt/cold-synapse/cold-synapse"; chmod 755 "$D/opt/cold-synapse/cold-synapse"
cp "$OUT/cold-synapse.pck" "$D/opt/cold-synapse/"
printf '%s\n' "$LAUNCHER" > "$D/opt/cold-synapse/run.sh"; chmod 755 "$D/opt/cold-synapse/run.sh"
ln -s /opt/cold-synapse/run.sh "$D/usr/bin/cold-synapse"
cp packaging/cold-synapse.desktop "$D/usr/share/applications/"
cp packaging/icon.png "$D/usr/share/icons/hicolor/256x256/apps/cold-synapse.png"
cp packaging/LICENSE-GODOT.txt "$D/usr/share/doc/cold-synapse/copyright"
SIZE=$(du -sk "$D/opt" | cut -f1)
cat > "$D/DEBIAN/control" <<CTRL
Package: cold-synapse
Version: $VER
Section: games
Priority: optional
Architecture: amd64
Installed-Size: $SIZE
Depends: libc6, libgl1, libx11-6, libxcursor1, libxi6, libxinerama1, libxrandr2
Maintainer: Cold Synapse project <noreply@example.invalid>
Description: Simultaneous-turn tactics game with a 79-mission campaign
 Plan your orders while the opponent plans theirs, preview the result, then watch
 the five seconds resolve. Includes five game modes plus Upload, Light and Dark play,
 hotseat, a computer opponent, a 55-mission campaign and two extra mission packs.
CTRL
dpkg-deb --build --root-owner-group "$D" "$OUT/cold-synapse_${VER}_amd64.deb" >/dev/null
ls -la "$OUT"/*.deb "$OUT"/*.tar.gz

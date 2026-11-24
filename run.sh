#!/usr/bin/env bash
set -euo pipefail
game_dir="$(cd "$(dirname "$0")" && pwd)"
engine="$game_dir/.tools/Godot_v4.7.2-stable_linux.x86_64"
if command -v godot >/dev/null 2>&1 && [[ "$(godot --version 2>/dev/null)" == 4.7.2* ]]; then
  engine="$(command -v godot)"
elif [[ ! -x "$engine" ]]; then
  mkdir -p "$game_dir/.tools"
  archive="$game_dir/.tools/godot.zip"
  curl -L --fail --show-error --silent \
    https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip \
    -o "$archive"
  unzip -o -q "$archive" -d "$game_dir/.tools"
  chmod +x "$engine"
fi
if [[ ! -d "$game_dir/.godot/imported" ]]; then
  "$engine" --headless --editor --import --path "$game_dir" --quit >/dev/null
fi
exec "$engine" --path "$game_dir" "$@"

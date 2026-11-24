#!/usr/bin/env bash
set -euo pipefail
game_dir="$(cd "$(dirname "$0")" && pwd)"
engine="$game_dir/.tools/Godot_v4.7.2-stable_linux.x86_64"
if [[ ! -x "$engine" ]]; then
  echo "Run ./run.sh once to download the Linux runtime." >&2
  exit 1
fi
stage_root="$(mktemp -d)"
trap 'rm -rf "$stage_root"' EXIT
stage="$stage_root/ashen-gate-linux"
mkdir -p "$stage/.tools"
cp "$engine" "$stage/.tools/"
cp -r "$game_dir"/{art,audio,assets,fonts,licenses,scripts,shaders} "$stage/"
cp "$game_dir"/{README.md,project.godot,main.tscn,run.sh} "$stage/"
find "$stage" -name '*.import' -delete
mkdir -p "$game_dir/dist"
tar -czf "$game_dir/dist/ashen-gate-linux.tar.gz" -C "$stage_root" ashen-gate-linux
echo "$game_dir/dist/ashen-gate-linux.tar.gz"

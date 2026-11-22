#!/usr/bin/env bash
# Zrzut ekranu sceny Godota bez fizycznego ekranu (Xvfb + programowy Vulkan/lavapipe; GODOT_DRIVER=opengl3 jako fallback).
# Użycie: tools/screenshot.sh [res://scenes/main.tscn] [/abs/sciezka.png] [klatki]
set -euo pipefail
cd "$(dirname "$0")/.."
SCENE="${1:-res://scenes/main.tscn}"
OUT="${2:-$PWD/build/screenshot.png}"
FRAMES="${3:-30}"
mkdir -p "$(dirname "$OUT")"
exec xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --rendering-driver "${GODOT_DRIVER:-vulkan}" --resolution 1280x720 \
  --script res://tools/screenshot.gd -- "$SCENE" "$OUT" "$FRAMES" "${@:4}"

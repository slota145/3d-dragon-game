#!/usr/bin/env bash
# Przygotowuje środowisko deweloperskie (Linux x86_64, Debian/Ubuntu).
# Idempotentny — można uruchamiać wielokrotnie.
#
#   tools/setup.sh            # wszystko
#   SKIP_APT=1 tools/setup.sh # bez pakietów systemowych (np. brak roota)
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT_VERSION="4.7.2"
GODOT_DIR="/opt/godot"
GODOT_BIN="$GODOT_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"

# 1) Godot
if ! command -v godot >/dev/null 2>&1; then
  echo ">> Instaluję Godot $GODOT_VERSION"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  mkdir -p "$GODOT_DIR"
  unzip -o -q "$tmp/godot.zip" -d "$GODOT_DIR"
  ln -sf "$GODOT_BIN" /usr/local/bin/godot
  rm -rf "$tmp"
fi
echo ">> Godot: $(godot --headless --version 2>/dev/null | tail -1)"

# 2) Biblioteki do renderowania bez ekranu (Blender EGL + Godot przez Xvfb/lavapipe)
if [[ -z "${SKIP_APT:-}" ]] && ! command -v xvfb-run >/dev/null 2>&1; then
  echo ">> Instaluję xvfb, mesa (EGL/GL/Vulkan software)"
  apt-get update -q
  apt-get install -y -q xvfb libegl1 libgl1 libegl-mesa0 mesa-vulkan-drivers
fi

# 3) Blender jako moduł Pythona (bpy) w lokalnym venv
if [[ ! -x .venv-tools/bin/python ]] || ! .venv-tools/bin/python -c "import bpy" 2>/dev/null; then
  echo ">> Instaluję bpy (Blender jako moduł Pythona) do .venv-tools"
  python3 -m venv .venv-tools
  .venv-tools/bin/pip install -q --upgrade pip
  .venv-tools/bin/pip install -q bpy
fi
echo ">> Blender (bpy): $(.venv-tools/bin/python -c 'import bpy; print(bpy.app.version_string)')"

# 4) Import zasobów Godota (generuje .godot/ i pliki .import)
echo ">> Import projektu Godot"
godot --headless --path . --import >/dev/null 2>&1 || true
echo ">> Gotowe."

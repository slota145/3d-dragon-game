#!/usr/bin/env bash
# Przygotowuje środowisko deweloperskie (Linux x86_64, Debian/Ubuntu).
# Idempotentny — można uruchamiać wielokrotnie.
#
#   tools/setup.sh            # wszystko
#   SKIP_APT=1 tools/setup.sh # bez pakietów systemowych (np. brak roota)
#   WITH_EXPORT=1 tools/setup.sh   # + szablony eksportu (.exe)
#   WITH_ANDROID=1 tools/setup.sh  # + JDK, Android SDK i szablony (.apk)
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

# 4) (opcjonalnie) Android: JDK 17 + Android SDK do eksportu APK
if [[ -n "${WITH_ANDROID:-}" ]]; then
  export ANDROID_HOME=/opt/android-sdk
  if [[ -z "${SKIP_APT:-}" ]] && ! command -v keytool >/dev/null 2>&1; then
    apt-get install -y -q openjdk-17-jdk-headless
  fi
  if [[ ! -x "$ANDROID_HOME/build-tools/35.0.0/apksigner" ]]; then
    echo ">> Instaluję Android SDK"
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/clt.zip" https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
    unzip -q -o "$tmp/clt.zip" -d "$ANDROID_HOME/cmdline-tools"
    rm -rf "$ANDROID_HOME/cmdline-tools/latest" && mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
    yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
    "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "platform-tools" "build-tools;35.0.0" "platforms;android-35" >/dev/null
    rm -rf "$tmp"
  fi
  JAVA_HOME_DIR="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
  mkdir -p ~/.config/godot
  printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/android/android_sdk_path = "%s"\nexport/android/java_sdk_path = "%s"\n' \
    "$ANDROID_HOME" "$JAVA_HOME_DIR" > ~/.config/godot/editor_settings-4.7.tres
  echo ">> Android SDK: $ANDROID_HOME"
fi

# 5) Szablony eksportu Godota (do budowania .exe / .apk)
TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
if [[ -n "${WITH_EXPORT:-}${WITH_ANDROID:-}" && ! -f "$TPL_DIR/windows_release_x86_64.exe" ]]; then
  echo ">> Pobieram szablony eksportu Godota"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/t.tpz" "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
  unzip -q -o "$tmp/t.tpz" -d "$tmp" && mkdir -p "$TPL_DIR" && cp -r "$tmp/templates/"* "$TPL_DIR/"
  rm -rf "$tmp"
fi

# 6) Import zasobów Godota (generuje .godot/ i pliki .import)
echo ">> Import projektu Godot"
godot --headless --path . --import >/dev/null 2>&1 || true
echo ">> Gotowe."

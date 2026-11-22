#!/usr/bin/env bash
# Szybka weryfikacja projektu: import zasobów + uruchomienie sceny głównej bez ekranu.
# Kończy się błędem, jeśli Godot zgłosi SCRIPT ERROR / ERROR / Parse Error.
#   tools/check.sh [klatki]
set -euo pipefail
cd "$(dirname "$0")/.."
FRAMES="${1:-120}"
log="$(mktemp)"
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --quit-after "$FRAMES" >"$log" 2>&1 || true
if grep -E "SCRIPT ERROR|Parse Error|^ERROR" "$log" | grep -v "audio" ; then
  echo "!! Błędy w logu Godota (pełny log: $log)"
  exit 1
fi
echo "OK — scena główna działa ($FRAMES klatek, bez błędów)."

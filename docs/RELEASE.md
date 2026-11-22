# Wydania i aktualizacje

## Jak działa aktualizacja w grze

1. Gra startuje od `scenes/boot.tscn`. Jeśli w `user://` jest pobrana łatka
   (`update.pck` + `update_version.txt`) nowsza niż wersja wbudowana w `.exe`,
   wczytuje ją (`ProjectSettings.load_resource_pack`) i dopiero potem świat.
2. W świecie `Updater` (HUD, prawy górny róg) pyta GitHuba o najnowsze wydanie:
   `GET https://api.github.com/repos/slota145/3d-dragon-game/releases/latest`.
3. Jeśli tag (np. `v0.2.0`) jest nowszy, pokazuje „Dostępna aktualizacja”.
   - Wydanie ma plik `game-<wersja silnika>.pck` (np. `game-4.7.2.pck`) → „Pobierz”,
     potem „Uruchom ponownie”.
   - Brak zgodnej łatki (np. zmiana wersji Godota) → „Otwórz stronę” z nowym `.exe`.

Łatka `.pck` zawiera całą zawartość gry (sceny, skrypty, modele), ale silnik
pozostaje z `.exe`/`.apk` — dlatego nazwa łatki zawiera wersję silnika. Android ma
osobną łatkę (`game-4.7.2-android.pck`), bo używa innych formatów tekstur.

## Łatka czy pełna aktualizacja? (`base_api`)

Łatka `.pck` podmienia sceny, skrypty i modele, ale **nie** ustawienia projektu wbudowane
w APK/EXE (mapowanie przycisków / input map, renderer, ustawienia eksportu, wersja silnika).
Dlatego `project.godot` ma `config/base_api`, a łatki mają go w nazwie
(`game-4.7.2-android-b2.pck`). Gra szuka tylko łatki ze swoim numerem.

**Podbij `config/base_api`**, gdy zmieniasz: input map (nowa akcja/przycisk), cokolwiek
w `[rendering]`, `[display]`, `[input_devices]` itp., `export_presets.cfg`, wersję Godota,
dodajesz nową klasę `class_name` używaną jako typ w innych skryptach. Gracze ze starszą
bazą dostaną wtedy „Pobierz grę” (pełne APK), a nie łatkę.

(Lekcja z v0.3.0: łatka dodała przycisk Skrzydła, ale stare APK nie znało akcji `flap`.)

## Jak wydać nową wersję

1. Podbij `config/version` w `project.godot` (np. `"0.1.0"` → `"0.2.0"`).
2. Wypchnij na gałąź `main`.
3. Workflow `.github/workflows/release.yml` zobaczy, że wydania `v0.2.0` jeszcze nie ma,
   zbuduje `DragonGame.exe` + `game-4.7.2.pck` i opublikuje wydanie (kilka minut).
4. Gracze ze starszą wersją zobaczą w grze przycisk aktualizacji.

Wypchnięcie bez zmiany wersji niczego nie publikuje. Można też ręcznie utworzyć
wydanie na GitHubie (tag `vX.Y.Z`) — workflow dobuduje do niego pliki.

Stałe linki do najnowszej wersji gry:
- https://github.com/slota145/3d-dragon-game/releases/latest/download/DragonGame.apk
- https://github.com/slota145/3d-dragon-game/releases/latest/download/DragonGame.exe

## Android: podpis APK

Android instaluje nową wersję APK „na” starą tylko wtedy, gdy obie są podpisane tym
samym kluczem. Workflow używa sekretów repozytorium (Settings → Secrets and variables →
Actions → New repository secret):

| Sekret | Wartość |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | plik `.keystore` zakodowany base64 (`base64 -w0 dragon-release.keystore`) |
| `ANDROID_KEYSTORE_PASSWORD` | hasło keystore |
| `ANDROID_KEY_ALIAS` | alias klucza (`dragon`) |

Bez sekretów workflow podpisuje APK kluczem tymczasowym — gra działa, ale przed
instalacją nowego APK trzeba odinstalować stare. Zwykłe aktualizacje przez łatkę
`.pck` w grze działają niezależnie od klucza. **Nie commituj keystore do repo.**

## Budowanie lokalnie

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/DragonGame.exe
godot --headless --path . --export-pack "Windows Desktop" build/game-4.7.2.pck
# Android (WITH_ANDROID=1 tools/setup.sh instaluje JDK + SDK do /opt/android-sdk)
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=... GODOT_ANDROID_KEYSTORE_RELEASE_USER=dragon \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=... \
  godot --headless --path . --export-release "Android" build/android/DragonGame.apk
```

## Testy

```bash
# sterowanie (klawiatura + gałka dotykowa), z zrzutami ekranu
xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_walk.gd -- /tmp
# aktualizator z lokalnym serwerem (patrz tools/test_updater.gd)
DRAGON_UPDATE_API=http://127.0.0.1:8765/release.json godot --headless --path . --script res://tools/test_updater.gd -- download 0.1.1
```

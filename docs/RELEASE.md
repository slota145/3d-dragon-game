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
pozostaje z `.exe` — dlatego nazwa łatki zawiera wersję silnika.

## Jak wydać nową wersję

1. Podbij `config/version` w `project.godot` (np. `"0.1.0"` → `"0.2.0"`).
2. Wypchnij na domyślną gałąź repozytorium.
3. Workflow `.github/workflows/release.yml` zobaczy, że wydania `v0.2.0` jeszcze nie ma,
   zbuduje `DragonGame.exe` + `game-4.7.2.pck` i opublikuje wydanie (kilka minut).
4. Gracze ze starszą wersją zobaczą w grze przycisk aktualizacji.

Wypchnięcie bez zmiany wersji niczego nie publikuje. Można też ręcznie utworzyć
wydanie na GitHubie (tag `vX.Y.Z`) — workflow dobuduje do niego pliki.

Stały link do najnowszej wersji gry:
https://github.com/slota145/3d-dragon-game/releases/latest/download/DragonGame.exe

## Budowanie lokalnie

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/DragonGame.exe
godot --headless --path . --export-pack "Windows Desktop" build/game-4.7.2.pck
```

## Testy

```bash
# sterowanie (klawiatura + gałka dotykowa), z zrzutami ekranu
xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/test_walk.gd -- /tmp
# aktualizator z lokalnym serwerem (patrz tools/test_updater.gd)
DRAGON_UPDATE_API=http://127.0.0.1:8765/release.json godot --headless --path . --script res://tools/test_updater.gd -- download 0.1.1
```

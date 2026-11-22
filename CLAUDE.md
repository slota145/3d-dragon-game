# CLAUDE.md — wskazówki dla agentów AI

Gra 3D o smoku w **Godot 4.7** (GDScript, renderer **Mobile**).
**Platforma docelowa: Android (telefon)** — Windows wstrzymany (`BUILD_WINDOWS` w CI),
przeniesiemy grę później. Projektuj pod dotyk (gałka, przeciąganie) i wydajność telefonu. Assety 3D są
generowane **proceduralnie skryptami Blendera (bpy)** i eksportowane do `.glb`.
Język dokumentacji i komunikacji z właścicielem: **polski**. Kod, nazwy
plików, węzłów i zmiennych: **angielski**.

## Szybki start

```bash
tools/setup.sh                 # Godot, bpy (Blender), xvfb/mesa — idempotentne
tools/check.sh                 # import + uruchomienie sceny głównej, fail przy błędach
tools/screenshot.sh res://scenes/main.tscn "$PWD/build/shot.png" 60   # zrzut ekranu
.venv-tools/bin/python tools/blender/gen_dragon.py -- --preview /tmp/prev   # smok + rendery Blendera
tools/screenshot.sh res://scenes/dragon_showcase.tscn "$PWD/build/d.png" 20 cam=ref anim=Roar t=1.25
```

## Struktura

| Ścieżka | Zawartość |
|---|---|
| `project.godot` | konfiguracja projektu, input map |
| `scenes/` | sceny: `boot.tscn` (start) → `world.tscn` (świat + `dragon_player.tscn` + `hud.tscn`), `dragon_showcase.tscn` |
| `scripts/game/` | rozgrywka: `boot.gd` (łatki), `world.gd`, `dragon_controller.gd`, `follow_camera.gd`, `updater.gd`, `game_version.gd` |
| `scripts/ui/` | interfejs: `touch_joystick.gd` (gałka) |
| `scripts/` | pozostałe (np. `model_showcase.gd`) |
| `assets/models/` | wygenerowane `.glb` (+ pliki `.import` — commitujemy je) |
| `assets/textures/`, `materials/`, `audio/` | pozostałe zasoby |
| `tools/blender/` | generatory assetów (Python + bpy): `gen_dragon.py` (smok), `meshkit.py` (lofty, rury, kolce, płaty, wagi), `common.py` (scena, materiały, render) |
| `assets/models/*_import.gd` | skrypty post-importu (materiały, pętle animacji) |
| `tools/*.sh`, `tools/*.gd` | setup, weryfikacja, zrzuty ekranu, testy (`test_walk.gd`, `test_updater.gd`) |
| `export_presets.cfg`, `.github/workflows/release.yml` | eksport Windows; CI buduje `.exe` + łatkę przy wydaniu (`docs/RELEASE.md`) |
| `docs/` | styl graficzny, research narzędzi, obrazki |
| `ROADMAP.md` | plan rozwoju i status |

## Zasady pracy

1. **Zawsze weryfikuj**: po zmianach w scenach/skryptach uruchom `tools/check.sh`.
   Po zmianach wizualnych zrób `tools/screenshot.sh` i obejrzyj obraz.
2. **Assety = kod.** Każdy model ma swój generator w `tools/blender/gen_*.py`.
   Nie edytuj `.glb` ręcznie — zmień generator i wygeneruj ponownie. Commituj
   i generator, i wynikowy `.glb`.
3. Po wygenerowaniu nowego `.glb` uruchom `godot --headless --path . --import`,
   żeby powstał plik `.import`, i commituj go razem z modelem.
4. Pliki `.tscn`/`.tres` piszemy ręcznie tylko w prostych przypadkach; złożone
   sceny lepiej budować skryptem lub w edytorze. Nie wpisuj ręcznie `uid://` —
   Godot nada je przy imporcie (ścieżki `res://` wystarczą).
5. Aktualizuj `ROADMAP.md`, gdy zadanie zostaje ukończone lub zmienia się plan.
6. Po zmianach w sterowaniu uruchom `tools/test_walk.gd` i `tools/test_flight.gd`
   (test lotu sprawdza całą specyfikację sterowania właściciela — patrz nagłówek
   `scripts/game/dragon_controller.gd`). Parametry lotu są w `@export` (grupy w inspektorze).
   Nazwa klasy nie może kolidować z klasą Godota (np. `VirtualJoystick` istnieje w 4.7).
7. **Wydania:** podbij `config/version`. Jeśli zmieniasz input map / ustawienia projektu /
   eksportu / silnik — podbij też `config/base_api` (inaczej łatka zepsuje grę u graczy;
   patrz `docs/RELEASE.md`).

## Konwencje 3D

- **Skala:** 1 jednostka = 1 metr. Smok: ~12 m długości (z ogonem), ~16,6 m
  rozpiętości skrzydeł, ~3,5 m do czubka głowy.
- **Orientacja:** w Blenderze model patrzy w **−Y**, Z w górę → po eksporcie
  glTF patrzy w **+Z** w Godocie (`Vector3.MODEL_FRONT`). Przy `look_at()`
  używaj `use_model_front = true`.
- **Pivot** na ziemi, pod środkiem modelu.
- **Styl: stylizowany low-poly** (decyzja właściciela, patrz `docs/ART_STYLE.md`):
  flat shading, jednolite kolory materiałów bez tekstur + losowa jasność ścianek
  (atrybut koloru `Col`, mnożony w materiale). Organiczne bryły: lofty → voxel
  remesh → wygładzenie → decimate (efekt „ciosany”). Detale (zęby, kolce, pazury)
  jako osobne ostre bryły.
- **Budżet:** bohater (smok) ~10k trójkątów, 37 kości; zwykłe postacie ≤ 5k.
- **Rig:** kości z sufiksem `.L`/`.R`; wagi — tułów i błona wg odległości od
  kości, detale sztywno do jednej kości. Animacje = akcje Blendera eksportowane
  jako ścieżki NLA; pętle ustawia skrypt post-importu. Pozy złożonych kończyn
  najlepiej opisywać kierunkami kości (`aim_chain` w `gen_dragon.py`), nie kątami.
- **Pysk:** domyślnie zamknięty (`JAW_REST_OPEN = 0`); otwiera go kość `Jaw`.
- **Postawa na ziemi:** wywerna opiera się nadgarstkami skrzydeł o ziemię
  (`standing_wings`, `WRIST_GROUND`); szpony „dłoni” są na kości `Thumb.L/.R`.
- Nazwy materiałów: `<Asset>_<Część>` (np. `Dragon_Scales`).

## GDScript

- Godot 4.x, statyczne typowanie wszędzie (`var speed: float = 10.0`, typy
  zwracane funkcji).
- `snake_case` dla funkcji/zmiennych, `PascalCase` dla klas i węzłów,
  `class_name` dla skryptów wielokrotnego użytku.
- Wcięcia tabami (patrz `.editorconfig`).
- Komentarze dokumentujące `##` po polsku są OK.

## Środowisko (chmura / headless)

- Godot: `/usr/local/bin/godot` (4.7.2). Blender: moduł `bpy` 5.3 w `.venv-tools/`.
- Brak GPU: zrzuty ekranu idą przez Xvfb + Vulkan lavapipe (renderer Mobile jak na telefonie, wolne,
  ale wierne). Fallback: `GODOT_DRIVER=opengl3 tools/screenshot.sh ...`.
- Komunikaty `ALSA`/`audio driver` w logach są niegroźne (brak karty dźwiękowej).
- Komunikaty `Draco/MeshOptimizer not available` z bpy są niegroźne.

## Git

- Commity małe, z opisem po polsku lub angielsku, w trybie rozkazującym.
- Nie commituj `.godot/`, `.venv-tools/`, `build/`.

# CLAUDE.md — wskazówki dla agentów AI

Gra 3D o smoku w **Godot 4.7** (GDScript, renderer **Mobile**).
**Platforma docelowa: Android (telefon)** — Windows wstrzymany (`BUILD_WINDOWS` w CI),
przeniesiemy grę później. Projektuj pod dotyk (gałka, przeciąganie) i wydajność telefonu. Assety 3D są
generowane **proceduralnie skryptami Blendera (bpy)** i eksportowane do `.glb`.
**Koncepcja gry: `docs/GAME_DESIGN.md`** (od pisklęcia do postrachu baśniowego królestwa).
Język dokumentacji i komunikacji z właścicielem: **polski**. Kod, nazwy
plików, węzłów i zmiennych: **angielski**.

## Szybki start

```bash
tools/setup.sh                 # Godot, bpy (Blender), xvfb/mesa — idempotentne
tools/check.sh                 # import + uruchomienie sceny głównej, fail przy błędach
tools/screenshot.sh res://scenes/world.tscn "$PWD/build/shot.png" 60  # zrzut ekranu gry
.venv-tools/bin/python tools/blender/gen_dragon.py -- --preview /tmp/prev   # smok + rendery Blendera
tools/screenshot.sh res://scenes/dragon_showcase.tscn "$PWD/build/d.png" 20 cam=ref anim=Roar t=1.25 youth=1  # youth: proporcje pisklęcia
```

## Struktura

| Ścieżka | Zawartość |
|---|---|
| `project.godot` | konfiguracja projektu, input map |
| `scenes/` | sceny: `boot.tscn` (start) → `world.tscn` (świat + `dragon_player.tscn` + `hud.tscn`), `dragon_showcase.tscn` |
| `scripts/game/` | rozgrywka: `boot.gd` (łatki), `world.gd`, `terrain.gd` (proceduralny teren z kawałków: wysokość, LOD, kolizja, woda), `terrain_decor.gd` (las, skały, krzewy, trawa, kwiaty — LOD drzew, wiatr), `clouds.gd` (chmury), `fauna.gd` (ptaki, motyle, świetliki), `landmarks.gd` (ciekawe miejsca + odkrywanie), `villages.gd` (wioski, mieszkańcy, zagrody, kamień ofiarny), `merchant_cart.gd` (wóz kupiecki na drodze), `castle.gd` (zamek na wzgórzu: mury, wieże, łucznicy, skarbiec), `ballista.gd` + `bolt.gd` (balista z linią celowania, bełt), `roads.gd` (wstęga drogi, mosty), `villager.gd` (człowiek: reakcja wg wielkości smoka, myśliwy z łukiem), `arrow.gd` (strzała), `dragon_fire.gd` (ogień smoka: kula / strumień), `fireball.gd` (kula ognia), `dragon_controller.gd`, `dragon_stats.gd` (rozmiar, stadia, zdrowie, głód), `dragon_proportions.gd` (proporcje pisklęcia — modyfikator szkieletu), `lair.gd` (legowisko: jaskinia, gniazdo, jajo), `save_game.gd` (zapis `user://save.json`), `day_night.gd` (cykl dnia i nocy), `gold_finds.gd` (złoto w świecie), `treasure_pile.gd` (stos skarbu), `treasure.gd` (siatki skarbów), `upgrades.gd` (ulepszenia za złoto), `prey.gd` + `prey_spawner.gd` + `wildlife.gd` (zwierzyna: gatunki, siedliska, animacja części), `follow_camera.gd`, `updater.gd`, `game_version.gd` |
| `scripts/ui/` | interfejs: `touch_joystick.gd` (gałka), `touch_button.gd` (Skrzydła/Zryw/Ugryzienie/Ogień), `stat_bars.gd` (paski), `crosshair.gd` (celownik ognia), `hoard_menu.gd` (okno „Sen na skarbie” — ulepszenia), `pause_menu.gd` (menu pauzy + okienko trybu deweloperskiego: stadia, reset wzrostu) |
| `scripts/fx/`, `assets/shaders/` | efekty: `dust_burst.gd` (pył), `fire_fx.gd` (płomienie, wybuch, dym), `speed_lines.gdshader` (linie pędu), `wind.gdshader` (kołysanie roślin), `water.gdshader` (woda), `sky.gdshader` (niebo: słońce, księżyc, gwiazdy) |
| `scripts/` | pozostałe (np. `model_showcase.gd`) |
| `assets/models/` | wygenerowane `.glb` (+ pliki `.import` — commitujemy je) |
| `assets/textures/`, `materials/`, `audio/` | pozostałe zasoby |
| `tools/blender/` | generatory assetów (Python + bpy): `gen_dragon.py` (smok), `gen_animals.py` (królik, owca, sarna, dzik, koza, kaczka, kura — części do animacji w kodzie, `animals.glb`), `gen_lair.py` (jaskinia-legowisko), `gen_treasure.py` (moneta, kielich, korona, skrzynia, klejnot), `gen_landmarks.py` (kamienny krąg, wieża, drzewo, szkielet, łuk), `gen_village.py` (chata, stodoła, studnia, płot, stóg, wóz, koń, most), `gen_people.py` (wieśniak, pasterz, myśliwy — części do animacji w kodzie), `gen_castle.py` (mury, wieże, brama, donżon, balista, bełt), `gen_nature.py` (drzewa, kamienie, krzewy, żywopłot, murek), `meshkit.py` (lofty, rury, kolce, płaty, wagi), `common.py` (scena, materiały, render) |
| `assets/models/*_import.gd` | skrypty post-importu (materiały, pętle animacji) |
| `assets/data/roads.json` | trasy dróg — generuje `tools/gen_roads.gd` (A*); **uruchom ponownie po zmianie terenu lub wiosek** |
| `tools/*.sh`, `tools/*.gd` | setup, weryfikacja, zrzuty ekranu, testy (`test_walk.gd`, `test_flight.gd`, `test_hunt.gd`, `test_pause.gd`, `test_lair.gd`, `test_world.gd`, `test_village.gd`, `test_fire.gd`, `test_catch.gd`, `test_wildlife.gd`, `test_castle.gd`, `test_updater.gd`) |
| `export_presets.cfg`, `.github/workflows/release.yml` | eksport Android (+ Windows wstrzymany); CI buduje APK + łatkę `.pck` przy podbiciu wersji (`docs/RELEASE.md`) |
| `docs/` | `GAME_DESIGN.md` (koncepcja), `SESSION_HANDOFF.md` (prompt dla następnej sesji), styl graficzny, wydania, research narzędzi |
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
6. Po zmianach w sterowaniu uruchom `tools/test_walk.gd`, `tools/test_flight.gd` i `tools/test_hunt.gd`
   (po zmianach w menu / HUD także `tools/test_pause.gd`, w legowisku / zapisie — `tools/test_lair.gd`).
   Testy ustawiają `world.use_save = false` (piaskownica: bez zapisu i intro, start na łące);
   `test_lair.gd` kasuje zapis gry.
   (test lotu sprawdza całą specyfikację sterowania właściciela — patrz nagłówek
   `scripts/game/dragon_controller.gd`). Parametry lotu są w `@export` (grupy w inspektorze).
   Nazwa klasy nie może kolidować z klasą Godota (np. `VirtualJoystick` istnieje w 4.7).
   **Interpolacja fizyki jest włączona** (płynność na ekranach 90/120 Hz): ruch w
   `_physics_process`, kamera czyta `get_global_transform_interpolated()`, po teleporcie
   wołaj `reset_physics_interpolation()`.
7. **Wydania:** podbij `config/version`. Jeśli zmieniasz input map / ustawienia projektu /
   eksportu / silnik — podbij też `config/base_api` (inaczej łatka zepsuje grę u graczy;
   patrz `docs/RELEASE.md`).
8. **Przekazanie sesji (handoff).** Gdy sesja robi się długa (dużo zadań, długa rozmowa,
   kontekst bliski limitu) albo właściciel kończy pracę, **przygotuj prompt dla następnej
   sesji**: stan projektu i wersji, co zrobiono, otwarte problemy / uwagi właściciela,
   następny krok z `ROADMAP.md` i najważniejsze pliki. Dopisz go na górze
   `docs/SESSION_HANDOFF.md` (z datą i wersją), zacommituj i **wklej też w odpowiedzi**,
   żeby właściciel mógł go skopiować do nowej sesji. Nowa sesja zaczyna od przeczytania
   `docs/SESSION_HANDOFF.md`.
9. **Git:** pracujemy na `main` (gałąź domyślna). Po zakończonym zadaniu: testy → commit →
   push na `main`.

## Tryb deweloperski

Menu pauzy (przycisk „II” w prawym górnym rogu, Esc) → przełącznik „Tryb deweloperski”
(zapisywany w `user://settings.cfg`). Okienko dewelopera po lewej działa w trakcie gry.
Nowe narzędzia testowe dodawaj w `scripts/ui/pause_menu.gd` (`_build_dev_panel`).

## Konwencje 3D

- **Skala:** 1 jednostka = 1 metr. Model smoka 1:1: ~12 m długości (z ogonem), ~16,6 m
  rozpiętości skrzydeł. W grze rozmiar zmienia się płynnie (`DragonStats.size`, start 1 m — pisklę wielkości królika);
  kontroler skaluje węzeł `Visual`, kolizję, prędkości i kamerę.
- **Orientacja:** w Blenderze model patrzy w **−Y**, Z w górę → po eksporcie
  glTF patrzy w **+Z** w Godocie (`Vector3.MODEL_FRONT`). Przy `look_at()`
  używaj `use_model_front = true`.
- **Pivot** na ziemi, pod środkiem modelu.
- **Teren:** świat nie jest płaski — wysokość gruntu daje `Terrain.height(x, z)` (statyczna,
  deterministyczna). Wszystko, co stawiasz na ziemi, ustaw na tej wysokości; `Terrain.is_walkable`
  odrzuca wodę i strome/wysokie zbocza. Łąka wokół (0, 0, 0) i plac legowiska są płaskie (y = 0).
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

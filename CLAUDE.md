# CLAUDE.md — wskazówki dla agentów AI

Gra 3D o smoku w **Godot 4.7** (GDScript, renderer Forward+). Assety 3D są
generowane **proceduralnie skryptami Blendera (bpy)** i eksportowane do `.glb`.
Język dokumentacji i komunikacji z właścicielem: **polski**. Kod, nazwy
plików, węzłów i zmiennych: **angielski**.

## Szybki start

```bash
tools/setup.sh                 # Godot, bpy (Blender), xvfb/mesa — idempotentne
tools/check.sh                 # import + uruchomienie sceny głównej, fail przy błędach
tools/screenshot.sh res://scenes/main.tscn "$PWD/build/shot.png" 60   # zrzut ekranu
.venv-tools/bin/python tools/blender/gen_dragon_placeholder.py -- --preview /tmp/d.png
```

## Struktura

| Ścieżka | Zawartość |
|---|---|
| `project.godot` | konfiguracja projektu, input map |
| `scenes/` | sceny `.tscn` (`main.tscn` = scena startowa) |
| `scripts/` | skrypty GDScript |
| `assets/models/` | wygenerowane `.glb` (+ pliki `.import` — commitujemy je) |
| `assets/textures/`, `materials/`, `audio/` | pozostałe zasoby |
| `tools/blender/` | generatory assetów (Python + bpy); `common.py` = helpery |
| `tools/*.sh`, `tools/*.gd` | setup, weryfikacja, zrzuty ekranu |
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

## Konwencje 3D

- **Skala:** 1 jednostka = 1 metr. Smok-placeholder ma ok. 4 m długości tułowia
  (bez ogona) i ~8 m rozpiętości skrzydeł.
- **Orientacja:** w Blenderze model patrzy w **−Y**, Z w górę → po eksporcie
  glTF patrzy w **+Z** w Godocie (`Vector3.MODEL_FRONT`). Przy `look_at()`
  używaj `use_model_front = true`.
- **Pivot** na ziemi, pod środkiem modelu.
- **Styl:** do decyzji — patrz `docs/ART_STYLE.md`. Dopóki nie ustalony,
  generujemy low-poly z flat shadingiem i jednolitymi kolorami materiałów
  (bez tekstur), budżet ≤ 5k trójkątów na postać.
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
- Brak GPU: zrzuty ekranu idą przez Xvfb + Vulkan lavapipe (Forward+, wolne,
  ale wierne). Fallback: `GODOT_DRIVER=opengl3 tools/screenshot.sh ...`.
- Komunikaty `ALSA`/`audio driver` w logach są niegroźne (brak karty dźwiękowej).
- Komunikaty `Draco/MeshOptimizer not available` z bpy są niegroźne.

## Git

- Commity małe, z opisem po polsku lub angielsku, w trybie rozkazującym.
- Nie commituj `.godot/`, `.venv-tools/`, `build/`.

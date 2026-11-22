# 🐉 3D Dragon Game

Gra 3D o smoku tworzona w **Godot 4.7**, z assetami generowanymi proceduralnie
w **Blenderze** (skrypty Pythona).

![Smok](docs/img/dragon_roar.png)

## Pobierz i graj

- **Android:** [⬇ DragonGame.apk](https://github.com/slota145/3d-dragon-game/releases/latest/download/DragonGame.apk)
  — otwórz link na telefonie, zezwól przeglądarce na instalację aplikacji z nieznanych źródeł.
  Wymaga 64-bitowego telefonu (arm64) z Vulkanem (praktycznie każdy z ostatnich lat).
- **Windows:** wstrzymany — na razie rozwijamy wersję na telefon (ostatni build: v0.2.0 na
  [stronie wydania](https://github.com/slota145/3d-dragon-game/releases/tag/v0.2.0)).

Gra sama sprawdza aktualizacje na GitHubie (przycisk w prawym górnym rogu).

Sterowanie:
- **gałka** (lewy dół): chód; w locie: przód = nurkowanie, tył = w górę / wyrównanie, boki = skręt
- **Skrzydła** (prawy dół, spacja, A na padzie): na ziemi tap = skok, przytrzymanie = start;
  w powietrzu tap = machnięcie w górę (z gałką w przód: w przód i w górę), trzymanie = zawis
- **Zryw** (przycisk obok Skrzydeł, Shift, X na padzie): na ziemi trzymaj = bieg;
  w locie = potężne machnięcie, które mocno przyspiesza w kierunku dzioba
- **kamera:** przeciąganie ekranu (PPM, Q/E, prawa gałka pada)

## Uruchomienie ze źródeł

1. Zainstaluj [Godot 4.7](https://godotengine.org/download) (wersja standardowa, GDScript).
2. Otwórz `project.godot` w edytorze i naciśnij **F5**.

## Praca z assetami (Linux)

```bash
tools/setup.sh   # Godot, Blender (bpy) w .venv-tools, xvfb/mesa
.venv-tools/bin/python tools/blender/gen_dragon.py   # -> assets/models/dragon.glb (model + rig + animacje)
tools/check.sh   # weryfikacja projektu bez ekranu
```

## Dokumenty

- [ROADMAP.md](ROADMAP.md): plan rozwoju
- [CLAUDE.md](CLAUDE.md): konwencje i instrukcje dla agentów AI
- [docs/ART_STYLE.md](docs/ART_STYLE.md): wybór stylu graficznego
- [docs/RELEASE.md](docs/RELEASE.md): wydania, aktualizacje w grze, budowanie .exe
- [docs/TOOLS.md](docs/TOOLS.md): darmowe narzędzia (3D, Godot, assety)

# 🐉 3D Dragon Game

Gra 3D o smoku tworzona w **Godot 4.7**, z assetami generowanymi proceduralnie
w **Blenderze** (skrypty Pythona).

![Smok](docs/img/dragon_roar.png)

## Pobierz i graj (Windows)

**[⬇ DragonGame.exe (najnowsza wersja)](https://github.com/slota145/3d-dragon-game/releases/latest/download/DragonGame.exe)**
— jeden plik, bez instalacji. Windows może ostrzec o nieznanym wydawcy
(plik nie jest podpisany): „Więcej informacji” → „Uruchom mimo to”.
Gra sama sprawdza aktualizacje na GitHubie.

Sterowanie: gałka na ekranie (mysz/dotyk), WASD/strzałki lub pad; kamera:
przeciąganie ekranu, prawy przycisk myszy, Q/E lub prawa gałka pada.

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

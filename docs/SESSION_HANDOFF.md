# Przekazanie sesji (handoff)

> Prompt do wklejenia na start nowej sesji z agentem. Aktualizuje go agent na końcu
> długiej sesji (zasada nr 8 w `CLAUDE.md`). Najnowszy wpis jest na górze.

---

## 2026-11-22 — po wersji v0.5.3

```text
Kontynuujemy pracę nad grą „3D Dragon Game” (Godot 4.7, Android, repo slota145/3d-dragon-game,
gałąź main). Przeczytaj najpierw CLAUDE.md, docs/GAME_DESIGN.md i ROADMAP.md.

Stan (v0.5.3, wydana na GitHubie, APK: releases/latest/download/DragonGame.apk):
- Gra: lekki surwiwal — wykluwasz się jako pisklę smoka (1 m, wielkości królika) w baśniowym
  świecie, polujesz (króliki, owce), jesz, płynnie rośniesz; od 4 m stadium Młodzik = lot.
- Sterowanie (telefon): gałka + 4 przyciski: Skrzydła (skok/sus, start, machanie, zawis),
  Zryw (bieg / przyspieszenie w locie), Ugryzienie (celowanie + doskok, zjedzenie), Ogień
  (zablokowany, do zrobienia w fazie 7). Lot: szybowanie z nośnością i przeciągnięciem,
  nurkowanie, wyrównanie z rozpędu; efekty prędkości (linie pędu, FOV).
- Smok: generator tools/blender/gen_dragon.py (model low-poly ~9.8k trójkątów, 39 kości,
  animacje Idle/Walk/Run/Leap/TakeOff/Fly/Glide/Dive/Bite/Eat/Roar). Zwierzęta: gen_animals.py.
- Wydania: podbicie config/version w project.godot + push na main -> CI buduje APK i łatkę
  .pck; gra aktualizuje się sama. Zmiany input map / ustawień projektu -> podbij też
  config/base_api (wtedy gracz pobiera pełne APK).
- Testy: tools/check.sh oraz tools/test_walk.gd, test_flight.gd, test_hunt.gd (xvfb + Vulkan).

Ostatnie poprawki po testach właściciela na telefonie: kamera bez kręcenia przy sprincie,
ruch na ziemi bez driftu, lot skalowany z rozmiarem, punkty odniesienia (trawa, kwiaty,
krzaki), interpolacja fizyki (koniec „rozmycia” przy dużych prędkościach).

Następny krok wg ROADMAP: faza 4 — pisklę i etapy: płynne proporcje pisklę -> dorosły
(skalowanie kości: duża głowa, krótka szyja, małe skrzydła), wytrzymałość lotu młodzika,
wyszarzone przyciski przed odblokowaniem. Zapytaj właściciela, czy zaczynamy od fazy 4,
czy ma nowe uwagi z testów na telefonie.

Komunikacja z właścicielem po polsku. Po każdym zadaniu: testy, commit, push na main,
a dla zmian w grze — wydanie (podbicie wersji) i link do APK.
```

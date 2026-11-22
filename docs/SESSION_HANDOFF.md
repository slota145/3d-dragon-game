# Przekazanie sesji (handoff)

> Prompt do wklejenia na start nowej sesji z agentem. Aktualizuje go agent na końcu
> długiej sesji (zasada nr 8 w `CLAUDE.md`). Najnowszy wpis jest na górze.

---

## 2026-11-22 — po wersji v0.6.4 (koniec fazy 4)

```text
Kontynuujemy pracę nad grą „3D Dragon Game” (Godot 4.7, Android, repo slota145/3d-dragon-game,
gałąź main). Przeczytaj najpierw CLAUDE.md, docs/GAME_DESIGN.md i ROADMAP.md.

Stan (v0.6.4, wydana, APK: releases/latest/download/DragonGame.apk). Fazy 0–4 gotowe:
- Lekki surwiwal: pisklę 1 m poluje (króliki, owce), je, płynnie rośnie; stadia wg rozmiaru
  (Pisklę <4 m, Młodzik 4 m = lot, Dorosły 9 m, Pradawny 16 m).
- Sterowanie: gałka + Skrzydła / Zryw / Ugryzienie / Ogień (zablokowany do fazy 7).
- Faza 4 (ta sesja):
  * 0.6.0 proporcje pisklęcia: scripts/game/dragon_proportions.gd (SkeletonModifier3D po
    animacji; duża głowa z krótkim pyszczkiem, krótka szyja, małe skrzydła, krótszy ogon),
    sterowane DragonStats.youth() (1 = pisklę, 0 = dorosły 9 m). Podgląd:
    tools/screenshot.sh res://scenes/dragon_showcase.tscn out.png 20 anim=Idle youth=1
  * 0.6.1 przybliżanie kamery: szczypanie dwoma palcami / kółko myszy (follow_camera.gd, user_zoom)
  * 0.6.2 wytrzymałość lotu: DragonStats.stamina, koszty w kontrolerze (@export „Wytrzymałość
    lotu”), pasek „Siła lotu” w HUD; bez sił tylko szybowanie; odnowa na ziemi; zużycie maleje
    z rozmiarem ((4/rozmiar)^2.5 — dorosły prawie bez limitu)
  * 0.6.3 menu pauzy („II” / Esc) + tryb deweloperski (scripts/ui/pause_menu.gd): skok do
    stadium, reset wzrostu. Właściciel: na razie zostawić okienko dewelopera jak jest.
  * 0.6.4 animacja odblokowania przycisku (TouchActionButton.celebrate()) + podpowiedź startu
- Testy: tools/check.sh oraz tools/test_walk.gd, test_flight.gd, test_hunt.gd, test_pause.gd.

Uwagi otwarte:
- Systemowy „wstecz” na Androidzie zamyka grę (zmiana wymaga ustawień projektu → base_api,
  pełne APK) — zrobić przy najbliższej zmianie ustawień projektu.
- Pisklę ma duże kolce/zęby (rosną z głową) — ew. łagodniejsze pisklę w generatorze.
- Czekamy na uwagi właściciela z telefonu (proporcje, zoom, siła lotu).

Następny krok wg ROADMAP: faza 5 — legowisko i świat (jaskinia-legowisko: sen = zapis + nowy
dzień + leczenie; złoto i stos skarbu; region ~4×4 km; strumieniowanie świata; dzień i noc).
Zapytaj właściciela, od czego zacząć fazę 5.

Komunikacja z właścicielem po polsku. Po każdym zadaniu: testy, commit, push na main,
a dla zmian w grze — wydanie (podbicie wersji) i link do APK.
```

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

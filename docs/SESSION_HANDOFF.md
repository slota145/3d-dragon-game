# Przekazanie sesji (handoff)

> Prompt do wklejenia na start nowej sesji z agentem. Aktualizuje go agent na końcu
> długiej sesji (zasada nr 8 w `CLAUDE.md`). Najnowszy wpis jest na górze.

---

## 2026-11-24 — po wersji v0.13.2 (wygląd świata)

```text
Kontynuujemy pracę nad grą „3D Dragon Game” (Godot 4.7, Android, repo slota145/3d-dragon-game,
gałąź main). Przeczytaj najpierw CLAUDE.md, docs/GAME_DESIGN.md i ROADMAP.md.

Stan (v0.13.2, wydana, APK: releases/latest/download/DragonGame.apk; base_api 6).
- Rdzeń: pisklę → Młodzik (4 m: lot + kula ognia) → Dorosły (9 m: strumień ognia) → Pradawny (16 m);
  polowanie, głód, jaskinia-legowisko (sen = zapis + dzień + ulepszenia „sen na skarbie”), dzień/noc,
  złoto i stos skarbu, świat 4×4 km (terrain.gd), 40 ciekawych miejsc, 6 wiosek z ludźmi (reakcja wg
  wielkości smoka, ludzi można jeść), rozgłos + myśliwi, ogień (palenie wiosek), celowanie głową za
  kamerą + pomoc w celowaniu + żyroskop (opcja), łapanie w locie (ŁAP / PUŚĆ / ZJEDZ).
- Wygląd (ostatnie wydania, uwagi właściciela, „baśniowy pastel”):
  * 0.13.0 gen_nature.py: drzewa (sosny, dąb, brzoza, jesienne, kwitnące) z LOD (sylwetki z daleka),
    kamienie, krzewy; usunięte kamienne słupy; łąki kwiatów; pola w działkach z żywopłotami / murkami,
    ogrodzone pastwiska (Terrain.field_parcel / is_pasture, villages._build_fields).
  * 0.13.1 wiatr (wind.gdshader), chmury (clouds.gd), woda (water.gdshader + mapa głębokości z terenu w tle).
  * 0.13.2 niebo z shadera (sky.gdshader: słońce, księżyc, gwiazdy; fog_sky_affect 0.25), fauna.gd
    (ptaki, motyle, świetliki), świecące okna chat + lampy w wioskach (Villages.set_night).
- Testy: tools/check.sh + tools/test_walk/flight/hunt/pause/lair/world/village/fire/catch.gd (pełny zestaw
  ~40 min — uruchamiaj w tle; testy: world.use_save = false).

Uwagi otwarte:
- Do sprawdzenia na telefonie: płynność (świat, drzewa z LOD, cząsteczki ognia, woda), osie żyroskopu.
- Drzewa nie płoną; rzeki bez widocznego nurtu.

Następny krok wg ROADMAP: reszta fazy 6 (danina vs. łupienie wiosek, wozy kupieckie) albo faza 8
(gryfy, rycerze, zamek). Zapytaj właściciela ankietą.

Komunikacja z właścicielem po polsku. Po każdym zadaniu: testy, commit, push na main,
a dla zmian w grze — wydanie (podbicie wersji) i link do APK.
```

---

## 2026-11-23 — po wersji v0.12.1 (łapanie w locie)

Jak wpisy niżej, plus łapanie w locie: DragonController.carried / _try_grab / _drop_carried /
_eat_carried (Ugryzienie: w powietrzu ŁAP/PUŚĆ, na ziemi ZJEDZ — etykieta w world._process),
Prey.pick_up / drop / _process_fall (upadek zabija → Prey.roasted = truchło do zjedzenia).
Test: tools/test_catch.gd. Następny krok: reszta fazy 6 (danina vs. łupienie, wozy kupieckie)
albo faza 8 (gryfy, rycerze, zamek). Zapytaj ankietą.

## 2026-11-23 — po wersji v0.12.0 (celowanie)

Jak wpis v0.11.0 poniżej, plus (uwagi właściciela): pysk otwiera się w dół (DragonProportions.jaw_angle
ujemny); celowanie: głowa/szyja za kamerą (DragonProportions.head_yaw/head_pitch, DragonController
._update_aim: promień z kamery podniesiony o AIM_RAISE_DEG, pomoc w celowaniu w stożku), celownik
(scripts/ui/crosshair.gd), żyroskop — opcja w menu pauzy (FollowCamera.gyro_enabled; mapowanie osi
do sprawdzenia na telefonie!), „wstecz” na Androidzie = pauza. base_api 6 (pełne APK).

## 2026-11-23 — po wersji v0.11.0 (faza 7: ogień)

```text
Kontynuujemy pracę nad grą „3D Dragon Game” (Godot 4.7, Android, repo slota145/3d-dragon-game,
gałąź main). Przeczytaj najpierw CLAUDE.md, docs/GAME_DESIGN.md i ROADMAP.md.

Stan (v0.11.0, wydana, APK: releases/latest/download/DragonGame.apk). Fazy 0–5 gotowe, faza 6 w dużej
części (wioski, ludzie, rozgłos, myśliwi), faza 7 — ogień gotowy.
- Rdzeń: pisklę → Młodzik (4 m: lot + kula ognia) → Dorosły (9 m: strumień ognia) → Pradawny (16 m);
  polowanie, głód, jaskinia-legowisko (sen = zapis + dzień + leczenie + ulepszenia „sen na skarbie”),
  dzień/noc, złoto i stos skarbu, świat 4×4 km (terrain.gd), 40 ciekawych miejsc (landmarks.gd),
  6 wiosek (villages.gd, villager.gd: reakcja wg wielkości smoka, ludzi można jeść), rozgłos + myśliwi.
- Ogień (ta sesja): dragon_fire.gd (węzeł „Fire” smoka; kula ognia młodzika / strumień dorosłego,
  sygnał fire_hit -> world._on_fire_hit: Prey.burn (pieczeń do zjedzenia), Villages.ignite_near
  (chaty/stodoły/stogi płoną 12 s → zgliszcza, rozgłos +5, odbudowa po nocy)), fireball.gd, fire_fx.gd
  (CPUParticles3D, mieszanie MIX — w dzień płomienie pomarańczowe), szczęka: DragonProportions.jaw_open.
- Testy: tools/check.sh + tools/test_walk/flight/hunt/pause/lair/world/village/fire.gd
  (testy: world.use_save = false; test_lair kasuje zapis). test_fire trwa ~10 min (zrzuty + pożar).

Uwagi otwarte:
- Systemowy „wstecz” na Androidzie zamyka grę (zmiana ustawień projektu → base_api, pełne APK).
- Właściciel nie sprawdził jeszcze na telefonie: świat 4×4 km, wioski, ogień (płynność cząsteczek!).
- Drzewa (MultiMesh) nie płoną — ew. później.

Następny krok wg ROADMAP: faza 7 — łapanie w locie (Ugryzienie w powietrzu: niesienie, upuszczanie),
albo reszta fazy 6 (danina vs. łupienie wiosek, wozy kupieckie). Zapytaj ankietą.

Komunikacja z właścicielem po polsku. Po każdym zadaniu: testy, commit, push na main,
a dla zmian w grze — wydanie (podbicie wersji) i link do APK.
```

---

## 2026-11-23 — po wersji v0.10.1 (faza 6: ludzie, w toku)

```text
Kontynuujemy pracę nad grą „3D Dragon Game” (Godot 4.7, Android, repo slota145/3d-dragon-game,
gałąź main). Przeczytaj najpierw CLAUDE.md, docs/GAME_DESIGN.md i ROADMAP.md.

Stan (v0.10.1, wydana, APK: releases/latest/download/DragonGame.apk). Fazy 0–5 gotowe, faza 6 w toku.
- Rdzeń: pisklę → Młodzik (4 m, lot) → Dorosły (9 m) → Pradawny (16 m); polowanie, głód (balans 0.9.1:
  ~9 min do zera, posiłki sycą mocno), jaskinia-legowisko (sen = zapis + dzień + leczenie + ulepszenia
  „sen na skarbie”), dzień/noc, złoto i stos skarbu, świat 4×4 km (terrain.gd, LOD, 4 jeziora, 3 rzeki,
  góry z legowiskiem), 40 ciekawych miejsc z odkrywaniem i skrzyniami (landmarks.gd).
- Faza 6 (decyzje właściciela z ankiety: reakcja wg wielkości smoka, smok MOŻE jeść ludzi; zakres:
  wioski+farmy, wieśniacy+pasterze, rozgłos, myśliwi):
  * 0.10.0 wioski (Terrain.VILLAGES — 6 wyrównanych placów, pola wokół = kolor terenu), villages.gd:
    chaty, stodoła, studnia, stogi, zagroda z owcami (Prey.home/home_radius), mieszkańcy;
    modele: tools/blender/gen_village.py, gen_people.py (części Body/LegL/LegR/ArmL/ArmR animowane w kodzie).
    villager.gd: pisklę → dźgają widłami, młodzik → cofają się, dorosły → panika; zjadanie ludzi.
  * 0.10.1 rozgłos (world.gd: renown 0..100, poziomy Nieznany/Plotka/Postrach/Legenda w HUD, zapis)
    + myśliwi z łukami (Villager.archer, arrow.gd), 0/1/2/3 na wioskę wg poziomu.
- Testy: tools/check.sh + tools/test_walk/flight/hunt/pause/lair/world/village.gd
  (testy: world.use_save = false; test_lair kasuje zapis).

Uwagi otwarte:
- Systemowy „wstecz” na Androidzie zamyka grę (zmiana ustawień projektu → base_api, pełne APK).
- Właściciel jeszcze nie sprawdził na telefonie świata 4×4 km i wiosek (płynność!).

Następny krok wg ROADMAP: reszta fazy 6 (danina vs. łupienie wiosek — złoto z wiosek, wozy kupieckie)
albo faza 7 — ogień (kula ognia młodzika, strumień dorosłego, palenie budynków). Zapytaj ankietą.

Komunikacja z właścicielem po polsku. Po każdym zadaniu: testy, commit, push na main,
a dla zmian w grze — wydanie (podbicie wersji) i link do APK.
```

---

## 2026-11-23 — po wersji v0.9.0 (faza 5 zakończona)

```text
Kontynuujemy pracę nad grą „3D Dragon Game” (Godot 4.7, Android, repo slota145/3d-dragon-game,
gałąź main). Przeczytaj najpierw CLAUDE.md, docs/GAME_DESIGN.md i ROADMAP.md.

Stan (v0.9.0, wydana, APK: releases/latest/download/DragonGame.apk). Fazy 0–5 gotowe.
- Rdzeń: pisklę poluje, je, rośnie (Młodzik 4 m = lot, Dorosły 9 m, Pradawny 16 m), siła lotu,
  zoom kamery, menu pauzy + tryb deweloperski, jaskinia-legowisko (wyklucie z jaja, sen = zapis
  + nowy dzień + leczenie, śmierć = pobudka w gnieździe), dzień/noc, złoto (znaleziska, skrytki,
  stos skarbu), ulepszenia „sen na skarbie” (łuski, skrzydła, zdrowie, oko).
- Świat (ta sesja, decyzje właściciela z ankiet): proceduralny teren 4×4 km (scripts/game/terrain.gd:
  Terrain.height(x,z) statyczna; kawałki 128 m, LOD 32/16/8/4, kolizja HeightMapShape wokół smoka,
  zasięg 1,5 km + mgła), las/skały/trawa w pierścieniu wokół smoka (terrain_decor.gd), pasmo gór
  na północy z legowiskiem u podnóża (Lair.POSITION (0,0,-80)), wyżyna za górami, 4 jeziora, 3 rzeki,
  łąka startowa płaska wokół (0,0,0). 40 ciekawych miejsc (landmarks.gd + tools/blender/gen_landmarks.py)
  z odkrywaniem (licznik w HUD, zapis) i skrzynią skarbów przy każdym.
- Właściciel: świat 2×2 km działał na telefonie dobrze; 4×4 km — do sprawdzenia płynności.
- Testy: tools/check.sh + tools/test_walk/flight/hunt/pause/lair/world.gd (test_world: teren, LOD,
  jeziora, miejsca, odkrycie, zrzuty). Testy: world.use_save = false (łąka, bez zapisu i intro).

Uwagi otwarte:
- Systemowy „wstecz” na Androidzie zamyka grę (zmiana ustawień projektu → base_api, pełne APK).
- Pisklę ma duże kolce/zęby — ew. łagodniejsze pisklę w generatorze.

Następny krok wg ROADMAP: faza 6 — ludzie (wieśniacy, pasterze, myśliwi; farmy i wioski; rozgłos
i odwet; danina vs. łupienie). Zapytaj właściciela ankietą o zakres pierwszej wersji ludzi.

Komunikacja z właścicielem po polsku. Po każdym zadaniu: testy, commit, push na main,
a dla zmian w grze — wydanie (podbicie wersji) i link do APK.
```

---

## 2026-11-22 — po wersji v0.7.2 (faza 5: legowisko, dzień/noc, złoto)

```text
Kontynuujemy pracę nad grą „3D Dragon Game” (Godot 4.7, Android, repo slota145/3d-dragon-game,
gałąź main). Przeczytaj najpierw CLAUDE.md, docs/GAME_DESIGN.md i ROADMAP.md.

Stan (v0.7.2, wydana, APK: releases/latest/download/DragonGame.apk). Fazy 0–4 gotowe, faza 5 w toku.
- Lekki surwiwal: pisklę poluje, je, płynnie rośnie; stadia wg rozmiaru (Młodzik 4 m = lot,
  Dorosły 9 m, Pradawny 16 m); proporcje pisklęcia, siła lotu, zoom kamery, menu pauzy +
  tryb deweloperski (stadia, reset wzrostu — właściciel: na razie bez zmian).
- Faza 5 (decyzje właściciela z ankiety):
  * 0.7.0 jaskinia-legowisko (tools/blender/gen_lair.py, scripts/game/lair.gd) w Lair.POSITION
    (0,0,-80), wejście w stronę łąki. Nowa gra = wyklucie z jaja w gnieździe (intro).
    Przycisk ŚPIJ w komorze: zapis + nowy dzień + leczenie. Zapis: scripts/game/save_game.gd
    (user://save.json) przy śnie + autozapis co 60 s + przy wyjściu/tle. Śmierć: budzisz się
    w gnieździe, wzrost zostaje. Menu pauzy: „Nowa gra” (z potwierdzeniem).
  * 0.7.1 cykl dnia i nocy (scripts/game/day_night.gd): dzień 10 min, noc 4 min; sen do 7:00.
  * 0.7.2 złoto: znaleziska na łące (co dzień nowe, złoty słup światła), skrytki-skrzynie na
    szczytach skalnych słupów (tylko lotem); złoto niesione → odkładane na stos w komorze
    (scripts/game/treasure_pile.gd, MultiMesh monet); śmierć = utrata połowy niesionego.
    Modele: tools/blender/gen_treasure.py. Na razie złoto = tylko stos (prestiż).
- Testy: tools/check.sh + tools/test_walk/flight/hunt/pause/lair.gd. Testy ustawiają
  world.use_save = false (piaskownica: łąka, bez zapisu i intro); test_lair kasuje zapis.

Uwagi otwarte:
- Systemowy „wstecz” na Androidzie zamyka grę (zmiana ustawień projektu → base_api, pełne APK).
- Pisklę ma duże kolce/zęby (rosną z głową) — ew. łagodniejsze pisklę w generatorze.
- Czekamy na uwagi właściciela z telefonu (jaskinia, sen, noc, złoto).

Następny krok wg ROADMAP (faza 5): ulepszenia za złoto; większy, gęsty region ~4×4 km
(teren, las, jezioro, góry) + strumieniowanie świata/LOD (wydajność telefonu).
Zapytaj właściciela (ankietą), od czego dalej.

Komunikacja z właścicielem po polsku. Po każdym zadaniu: testy, commit, push na main,
a dla zmian w grze — wydanie (podbicie wersji) i link do APK.
```

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

# Roadmap — 3D Dragon Game

Legenda: ✅ zrobione · 🔄 w trakcie · ⬜ do zrobienia · ❓ decyzja do podjęcia

## Faza 0 — Fundamenty ✅

- ✅ Repozytorium, struktura katalogów, `.gitignore`, `.editorconfig`
- ✅ Projekt Godot 4.7 (Forward+), scena testowa z niebem, światłem, ziemią
- ✅ Pipeline assetów: Blender (bpy, headless) → `.glb` → import do Godota
- ✅ Placeholder smoka low-poly (~820 trójkątów) → zastąpiony docelowym modelem
- ✅ Narzędzia: `tools/setup.sh`, `tools/check.sh`, `tools/screenshot.sh`
- ✅ Dokumentacja dla agentów (`CLAUDE.md`), research narzędzi (`docs/TOOLS.md`)

## Faza 1 — Decyzje projektowe ❓

- ✅ **Styl graficzny** — stylizowany low-poly (`docs/ART_STYLE.md`)
- ✅ **Model smoka (wywerna)** wg referencji: ~10k trójkątów, rig 37 kości,
  animacje Idle / Glide / Fly / Roar (`tools/blender/gen_dragon.py`, `scenes/dragon_showcase.tscn`)
- ✅ Poprawki smoka: nowa głowa (zamknięty pysk, warga zachodzi na żuchwę, mniej i większe zęby,
  kły, nozdrza), grzywa jako równy kołnierz z płytek, naturalnie złożone skrzydła (solver kierunków)
- ✅ Postawa wywerny: w Idle smok stoi na nadgarstkach złożonych skrzydeł (IK 2-kościowe, kość `Thumb` dla szponów)
- ✅ **Gatunek i pętla rozgrywki**: lekki surwiwal w otwartym, baśniowym świecie; od pisklęcia
  do postrachu królestwa, polowanie, wzrost, skarb, ludzie jako wróg, nowe pokolenie (prestiż)
- ✅ **Kamera**: trzecia osoba za smokiem
- ✅ **Platforma**: Android (telefon) najpierw, Windows później
- ✅ Dokument projektu gry: **`docs/GAME_DESIGN.md`**

## Faza 2 — Prototyp lotu (vertical slice mechaniki) ⬜

- ✅ Chód po ziemi: animacja Walk (IK nóg i nadgarstków), kontroler, kamera, świat testowy
- ✅ Sterowanie: gałka na ekranie (dotyk/mysz), WASD, pad
- ✅ Build Windows (.exe) + aktualizacje w grze z GitHub Releases + CI (`docs/RELEASE.md`)
- ✅ Skok, start, lot: przycisk „Skrzydła” (tap/przytrzymanie), zawis, machanie,
  szybowanie z modelem nośności i przeciągnięcia, nurkowanie, wyrównanie z rozpędu, lądowanie
- ✅ Animacja Dive, góry i skalne słupy z kolizją, kamera lotu, status wys./prędkości
- ✅ Machnięcia bez spamu (czas trwania + zapamiętane naciśnięcie), potężny start (animacja TakeOff:
  przysiad, wybicie z łap, uderzenie skrzydeł) z chmurą pyłu, pył przy twardym lądowaniu
- ✅ Przycisk Zryw: bieg na ziemi, potężne przyspieszenie w locie (z odnowieniem)
- ✅ Animacja Run (galop susami) przy biegu; sus do przodu po łuku (~17 m) z animacją Leap
- ✅ Efekty prędkości: linie pędu, winieta, FOV, drganie kamery, rozbłysk przy zrywie
- ⬜ Dopracowanie odczucia lotu na telefonie (strojenie parametrów w `dragon_controller.gd`)
- ⬜ Model lotu: prędkość, przechylenie (bank), nurkowanie, szybowanie, wznoszenie
- ⬜ Kamera trzecioosobowa z opóźnieniem i dynamicznym FOV przy prędkości
- ✅ Build Android (APK, arm64) + osobna łatka `.pck` dla Androida w aktualizatorze
- ✅ Szkielet (rig) smoka + animacje: machanie skrzydłami, szybowanie, idle (rozglądanie się, oddech), ryk
- ⬜ Kolejne animacje: chód, start/lądowanie, zianie ogniem, obrót w locie
- ⬜ Teren testowy: wzgórza, góry, woda (heightmap lub generator)

> **Priorytet platform:** Android (telefon). Windows wstrzymany do czasu „przeniesienia”
> (włączenie: `BUILD_WINDOWS: "true"` w `.github/workflows/release.yml`).

## Faza 3 — Rdzeń: polowanie i wzrost ⬜

- ⬜ Przycisk **Ugryzienie** (atak na ziemi) + animacja Bite
- ⬜ Pierwsza zwierzyna (owce, króliki) z prostą SI: pasie się, ucieka przed smokiem
- ⬜ Jedzenie, **pasek głodu**, zdrowie, HUD
- ⬜ **Wzrost**: punkty wzrostu z jedzenia, smok płynnie rośnie (skala, kamera, prędkości)
- ⬜ Sprawdzenie na telefonie: czy polowanie i rośnięcie to frajda?

## Faza 4 — Pisklę i etapy ⬜

- ⬜ Model **pisklęcia** z generatora (proporcje: duża głowa, krótka szyja, małe skrzydła)
- ⬜ Etapy Pisklę → Młodzik → Dorosły → Pradawny; odblokowania (lot, ogień, łapanie)
- ⬜ Wytrzymałość lotu młodzika, wyszarzone przyciski przed odblokowaniem

## Faza 5 — Legowisko i świat ⬜

- ⬜ Jaskinia-legowisko: sen = zapis + nowy dzień + leczenie; łagodna śmierć
- ⬜ Złoto i proceduralny stos skarbu; ulepszenia za złoto
- ⬜ Baśniowy region **~4 × 4 km, gęsty** (zasada 20 s, węzły POI, punkty orientacyjne;
  `docs/GAME_DESIGN.md` → Skala i gęstość): teren, las, łąki, farmy, jezioro, góry
- ⬜ Strumieniowanie świata kawałkami, LOD, MultiMesh (wydajność na telefonie)
- ⬜ Cykl dnia i nocy

## Faza 6 — Ludzie ⬜

- ⬜ Wieśniacy, pasterze, drwale, myśliwi (łuki, sieci, pułapki), wozy kupieckie
- ⬜ Farmy i wioski; **rozgłos** i odwet
- ⬜ Danina vs. palenie i łupienie wiosek; odbudowa

## Faza 7 — Ogień i łapanie ⬜

- ⬜ Kula ognia młodzika (czas odnowienia), strumień ognia dorosłego, palenie budynków
- ⬜ Łapanie w locie (Ugryzienie w powietrzu): niesienie, upuszczanie z wysokości

## Faza 8 — Wielcy przeciwnicy i zamki ⬜

- ⬜ Gryfy (dzikie, w górach), rycerze, balisty
- ⬜ Zamek: mury, łucznicy, wieże z gryfami, boss: dowódca jeźdźców gryfów, skarbiec

## Faza 9 — Nowe pokolenie ⬜

- ⬜ Składanie jaja, warianty smoka (ognisty / mroźny / burzowy / cieniowy), dziedzictwo

## Faza 10 — Dopracowanie i wydanie ⬜

- ⬜ Dźwięk i muzyka, menu główne, pauza, ustawienia
- ⬜ Optymalizacja (LOD, MultiMesh, occlusion culling)
- ⬜ Przeniesienie na Windows (`BUILD_WINDOWS`), testy z graczami

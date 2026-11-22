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
- ❓ **Gatunek i pętla rozgrywki** — np. eksploracja otwartego świata,
  walka powietrzna, zbieranie skarbów, rozwój smoka od pisklęcia…
- ❓ **Kamera** — trzecia osoba za smokiem (domyślnie) czy inna
- ❓ **Platformy docelowe** — PC (Windows/Linux), Web, mobile?
- ⬜ Krótki dokument koncepcyjny gry (`docs/GAME_DESIGN.md`)

## Faza 2 — Prototyp lotu (vertical slice mechaniki) ⬜

- ⬜ Kontroler smoka: chodzenie po ziemi ↔ start ↔ lot ↔ lądowanie
- ⬜ Model lotu: prędkość, przechylenie (bank), nurkowanie, szybowanie, wznoszenie
- ⬜ Kamera trzecioosobowa z opóźnieniem i dynamicznym FOV przy prędkości
- ⬜ Sterowanie: klawiatura + mysz, gamepad
- ✅ Szkielet (rig) smoka + animacje: machanie skrzydłami, szybowanie, idle (rozglądanie się, oddech), ryk
- ⬜ Kolejne animacje: chód, start/lądowanie, zianie ogniem, obrót w locie
- ⬜ Teren testowy: wzgórza, góry, woda (heightmap lub generator)

## Faza 3 — Świat ⬜

- ⬜ Generator terenu / większa mapa (chunking, LOD)
- ⬜ Biomy, roślinność (MultiMesh), skały, chmury
- ⬜ Cykl dnia i nocy, pogoda
- ⬜ Assety środowiska generowane skryptami (drzewa, skały, budynki, zamki)

## Faza 4 — Rozgrywka ⬜

- ⬜ Zieje ogniem (VFX cząsteczkowe, obrażenia)
- ⬜ Przeciwnicy / NPC, cele, zbieranie przedmiotów
- ⬜ UI: HUD (zdrowie, stamina, mapa), menu główne, pauza
- ⬜ Zapis gry

## Faza 5 — Dopracowanie i wydanie ⬜

- ⬜ Dźwięk i muzyka
- ⬜ Optymalizacja (profilowanie, LOD, occlusion culling)
- ⬜ Eksport buildów (presety eksportu), CI (GitHub Actions: check + build)
- ⬜ Testy z graczami, poprawki

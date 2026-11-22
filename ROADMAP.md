# Roadmap — 3D Dragon Game

Legenda: ✅ zrobione · 🔄 w trakcie · ⬜ do zrobienia · ❓ decyzja do podjęcia

## Faza 0 — Fundamenty ✅

- ✅ Repozytorium, struktura katalogów, `.gitignore`, `.editorconfig`
- ✅ Projekt Godot 4.7 (Forward+), scena testowa z niebem, światłem, ziemią
- ✅ Pipeline assetów: Blender (bpy, headless) → `.glb` → import do Godota
- ✅ Placeholder smoka low-poly (~820 trójkątów)
- ✅ Narzędzia: `tools/setup.sh`, `tools/check.sh`, `tools/screenshot.sh`
- ✅ Dokumentacja dla agentów (`CLAUDE.md`), research narzędzi (`docs/TOOLS.md`)

## Faza 1 — Decyzje projektowe ❓

- ❓ **Styl graficzny** — low-poly / voxel / kreskówkowy / realistyczny
  (analiza i rekomendacja w `docs/ART_STYLE.md`)
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
- ⬜ Szkielet (rig) smoka + animacje: machanie skrzydłami, szybowanie, idle, chód
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

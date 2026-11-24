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

- ✅ Przycisk **Ugryzienie** (atak na ziemi, celowanie + doskok) + animacje Bite i Eat
- ✅ Pierwsza zwierzyna (króliki, owce; `gen_animals.py`) z prostą SI: pasie się, ucieka przed smokiem
- ✅ Jedzenie, **pasek głodu**, zdrowie, HUD (paski, napisy, 4 przyciski — Ogień zablokowany)
- ✅ **Płynny wzrost** (trawienie): jedzenie powiększa smoka (skala, kamera, prędkości),
  progi rozmiaru → wyższe stadium (napis + odblokowania; Młodzik = lot), pasek wzrostu w HUD
- ✅ Start jako pisklę wielkości królika (1 m) bez lotu; wzrost procentowy (małe ofiary
  coraz mniej dają), lot skalowany z rozmiarem, kamera oddala się wolniej niż smok rośnie
- ✅ Punkty odniesienia przy ziemi: trawa, kwiaty, krzaki (MultiMesh); kamera bez kręcenia przy sprincie
- ⬜ Sprawdzenie na telefonie: czy polowanie i rośnięcie to frajda?

## Faza 4 — Pisklę i etapy ✅

- ✅ **Płynne proporcje** pisklę → dorosły (0.6.0): modyfikator szkieletu `dragon_proportions.gd`
  wg `DragonStats.youth()` — duża głowa z krótkim pyszczkiem, krótka szyja, małe skrzydła, krótszy ogon
- ✅ Przybliżanie kamery (0.6.1): szczypanie dwoma palcami, kółko myszy — oglądanie smoka z bliska
- ✅ Etapy Pisklę → Młodzik → Dorosły → Pradawny wg rozmiaru; odblokowanie lotu
  (ogień i łapanie → faza 7)
- ✅ Wytrzymałość lotu (0.6.2): pasek „Siła lotu”; start, machanie, zawis, zryw zużywają siłę,
  szybowanie trochę, nurkowanie wcale; odnowa na ziemi; zużycie maleje z rozmiarem (dorosły prawie bez limitu)
- ✅ Menu pauzy + tryb deweloperski (0.6.3): skok do stadium, reset wzrostu
- ✅ Wyszarzone przyciski z kłódką + animacja odblokowania (0.6.4): napis stadium,
  przycisk podskakuje i pulsuje złotem, fale; podpowiedź „Przytrzymaj SKRZYDŁA…”

## Faza 5 — Legowisko i świat ✅

- ✅ Jaskinia-legowisko (0.7.0, `gen_lair.py`): wyklucie z jaja w gnieździe (intro nowej gry),
  przycisk ŚPIJ w komorze = zapis + nowy dzień + leczenie; autozapis co 60 s i przy wyjściu;
  łagodna śmierć — budzisz się w gnieździe, wzrost zostaje; „Nowa gra” w menu pauzy
- ✅ Cykl dnia i nocy (0.7.1, `day_night.gd`): dzień 10 min (6–20), noc 4 min; słońce/księżyc,
  kolory nieba, zmierzch z podpowiedzią; sen przewija do 7:00; godzina w zapisie i w HUD
- ✅ Złoto i proceduralny stos skarbu (0.7.2, `gen_treasure.py`): błyszczące znaleziska na łące
  (co dzień nowe), skrytki-skrzynie na szczytach skalnych słupów (tylko lotem); złoto niesione →
  odkładane na stos w komorze; śmierć = utrata połowy niesionego; licznik w HUD
- ✅ Ulepszenia za złoto (0.7.3) — „sen na skarbie”: przy śnie smok wtapia złoto ze stosu w ciało
  (stos maleje); Twarde łuski (łuski złocieją), Silne skrzydła, Smocze zdrowie, Bystre oko; po 3 poziomy
- ✅ Proceduralny region **2 × 2 km** (0.8.0, `terrain.gd`, `terrain_decor.gd`): wzgórza i doliny,
  pasmo gór na północy z legowiskiem u podnóża, jezioro + rzeka (wschód), las (zachód), stawy,
  łąka w środku; kawałki 128 m z LOD (4/8/16 m), kolizja HeightMapShape tylko wokół smoka,
  roślinność MultiMesh na kawałek (trawa tylko blisko), ściany na krawędzi świata
- ✅ Świat **4 × 4 km** (0.9.0): pasmo gór z wyżyną i jeziorem za nim, 4 jeziora, 3 rzeki, LOD 4 poziomy,
  zasięg rysowania 1,5 km + mgła, roślinność tylko wokół smoka (pierścień kawałków)
- ✅ **Ciekawe miejsca** (0.9.0, `gen_landmarks.py`, `landmarks.gd`): 40 miejsc — kamienne kręgi, ruiny
  wież, pradawne drzewa, szkielety smoków, skalne łuki; odkrywanie (licznik w HUD, zapis) + skrzynia skarbów
  przy każdym (na drzewie i łuku — tylko lotem); blisko łąki gęściej
- ⬜ Farmy i wioski — w fazie 6

- ✅ Balans głodu (0.9.1): głód spada 2,5× wolniej (~9 min), posiłki sycą 2,5× mocniej (uwaga właściciela)

## Faza 6 — Ludzie ⬜

- ✅ Wioski i farmy (0.10.0, `gen_village.py`, `villages.gd`): 6 wiosek na wyrównanych placach — studnia,
  chaty ze strzechą, stodoła, stogi, zagroda z owcami, pola wokół; kolizje budynków
- ✅ Ludzie (0.10.0, `gen_people.py`, `villager.gd`): wieśniacy z widłami i pasterze; reakcja wg wielkości
  smoka: pisklę — dźgają widłami, młodzik — cofają się, dorosły — panika; smok może ich zjeść;
  zjedzeni mieszkańcy i owce wracają następnego dnia
- ✅ Rozgłos + myśliwi (0.10.1, `arrow.gd`): rozgłos rośnie od zjadania ludzi (+8), owiec z farm (+3)
  i straszenia (+0,4), opada powoli i przez noc; poziomy Nieznany / Plotka / Postrach / Legenda →
  0/1/2/3 myśliwych z łukami na wioskę (strzelają z dystansu z wyprzedzeniem, z bliska odskakują)
- ✅ Danina i łupienie (0.14.0): od rozgłosu „Postrach” wioski co dzień zostawiają złoto na kamieniu ofiarnym;
  napaść (spalenie, zjedzenie mieszkańca / owcy) = wioska nie płaci 3 dni; spalone chaty i stodoły dają łup;
  wioski mają nazwy; drogi między wioskami (ubita ziemia), wozy kupieckie z koniem — spalenie = skrzynia z łupem
- ✅ Sensowne drogi (0.14.1, uwagi właściciela): trasy A* po terenie (`tools/gen_roads.gd` → `assets/data/roads.json`:
  omijają góry i jeziora, rzekę przecinają), gładka wstęga drogi z poboczami (`roads.gd`), drewniane mosty z kolizją
  nad wodą, pola i żywopłoty obok drogi (nie na niej)

- ⬜ Danina vs. palenie i łupienie wiosek; odbudowa

## Faza 7 — Ogień i łapanie ⬜

- ✅ Ogień (0.11.0, `dragon_fire.gd`, `fireball.gd`, `fire_fx.gd`): od Młodzika kula ognia (tap, odnowienie
  2,2 s, pierścień na przycisku), od Dorosłego strumień ognia (trzymanie do 3,5 s); pysk otwiera się
  (kość Jaw w `dragon_proportions.gd`); ogień piecze zwierzęta i ludzi (pieczeń do zjedzenia), podpala
  chaty, stodoły i stogi (płoną 12 s → zgliszcza z dymem, rozgłos +5); odbudowa po nocy
- ✅ Celowanie (0.12.0, uwagi właściciela): pysk otwiera się w dół; głowa i szyja obracają się za kamerą,
  ogień leci w punkt celownika (kierunek kamery podniesiony o jej nachylenie), pomoc w celowaniu łapie cel
  w stożku ~10° (pomarańczowa obwódka); celowanie żyroskopem — opcja w menu pauzy (domyślnie wył.);
  „wstecz” na Androidzie = pauza (base_api 6 → pełne APK)
- ✅ Łapanie w locie (0.12.1): Ugryzienie w powietrzu = ŁAP (zwierzę / człowiek / truchło pod smokiem,
  do 60% jego wielkości), niesienie w szponach (słabsze machnięcia, większe zużycie siły), ponownie = PUŚĆ
  (upadek > ~13 m/s zabija → truchło do zjedzenia), na ziemi = ZJEDZ; porwanie człowieka +2 rozgłosu

## Wygląd świata (uwagi właściciela)

- ✅ 0.13.0: różnorodne drzewa (sosny, dęby, brzozy, jesienne, kwitnące) i kamienie (`gen_nature.py`),
  LOD drzew (z daleka sylwetki), usunięte kamienne słupy; baśniowy pastel (Filmic, żywsza zieleń, turkusowa
  woda); łąki kwiatów; pola w kolorowych działkach z żywopłotami / kamiennymi murkami, ogrodzone pastwiska
- ✅ 0.13.1: wiatr (`wind.gdshader` — trawa, kwiaty, korony drzew), chmury low-poly dryfujące nad światem
  (`clouds.gd`), woda (`water.gdshader`: zmarszczki, błyski, turkus→błękit, piana przy brzegu z mapy głębokości
  liczonej w tle z terenu — bez bufora głębi, działa na każdym telefonie)
- ✅ 0.13.2: niebo z shadera (`sky.gdshader`: gradient, słońce, księżyc, migoczące gwiazdy; mgła nie zakrywa już
  nieba), świetliki nocą, świecące okna chat i lampy w wioskach, stada ptaków i motyle nad kwiatami (`fauna.gd`)

## Faza 8 — Wielcy przeciwnicy i zamki ⬜

- ⬜ Gryfy (dzikie, w górach), rycerze, balisty
- ⬜ Zamek: mury, łucznicy, wieże z gryfami, boss: dowódca jeźdźców gryfów, skarbiec

## Faza 9 — Nowe pokolenie ⬜

- ⬜ Składanie jaja, warianty smoka (ognisty / mroźny / burzowy / cieniowy), dziedzictwo

## Faza 10 — Dopracowanie i wydanie ⬜

- ⬜ Dźwięk i muzyka, menu główne, pauza, ustawienia
- ⬜ Optymalizacja (LOD, MultiMesh, occlusion culling)
- ⬜ Przeniesienie na Windows (`BUILD_WINDOWS`), testy z graczami

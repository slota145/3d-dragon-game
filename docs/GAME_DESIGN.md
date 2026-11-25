# Dokument projektu gry (GDD)

> Żywy dokument — zmienia się razem z grą. Ustalenia z burzy mózgów z właścicielem (listopad 2026).

## Jednym zdaniem

**Wykluwasz się jako ostatni smok na świecie — maleńkie pisklę w baśniowej krainie,
w której ludzie polują na takich jak ty. Polujesz, rośniesz, gromadzisz skarb i z czasem
stajesz się postrachem królestwa.**

## Filary

1. **Wzrost zmienia sposób grania** — każdy etap smoka to nowe możliwości, inne ofiary i inne zagrożenia.
2. **Ludzie to żywy system** — reagują na to, co robisz (rozgłos, danina, odwet), a nie stoją w miejscu.
3. **Skarb to trwały postęp** — złoto w legowisku rośnie na oczach gracza i daje prestiż oraz ulepszenia.
4. **Lekki surwiwal na telefon** — krótkie sesje, mało przycisków, łagodne kary.

## Klimat i styl

- **Baśniowy świat, który kontrastuje ze smokiem.** Kraina jest kolorowa, ciepła i „zabawkowa”:
  soczyste łąki, czerwone dachy, chorągiewki, okrągłe drzewa, wesołe zwierzęta. Smok jest
  ciemny, kanciasty i groźny jak z mrocznej legendy (obecny model). Ten kontrast to tożsamość gry.
- Low-poly z flat shadingiem (`docs/ART_STYLE.md`): świat w nasyconych, jasnych kolorach,
  smok w stonowanych szarościach z kremową grzywą.
- Humor sytuacyjny zamiast mroku: uciekające kury, wieśniak gubiący widły, przerażony rycerz.

## Główna pętla

**Poluj → jedz → rośnij → odblokuj zdolności → większe ofiary i większe ryzyko**,
a równolegle **zdobywaj złoto → znoś do legowiska → ulepszenia i prestiż**.

## Etapy smoka

| Etap | Rozmiar | Zdolności | Ofiary | Zagrożenia |
|---|---|---|---|---|
| **Pisklę** | ~1 m (wielkości królika) → 4 m | chód, bieg, **sus**, szybowanie z wysokości, ugryzienie — **bez lotu** | kury, króliki, kaczki, ryby | lisy, psy, wieśniacy z widłami |
| **Młodzik** | ~5 m | **krótki lot** (wytrzymałość), zryw, **mała kula ognia** (z czasem odnowienia) | owce, kozy, sarny | wilki, myśliwi z łukami i sieciami |
| **Dorosły** | ~12 m | pełny lot, **zionięcie ogniem** (strumień), łapanie w locie dużych ofiar | jelenie, dziki, bydło, wozy kupieckie | rycerze, patrole, **gryfy** |
| **Pradawny** | ~20 m | ryk płoszący wrogów, burzenie budowli, napady na zamki | niedźwiedzie, gryfy, zamki | balisty, **jeźdźcy gryfów**, zakon łowców smoków |

- **Wzrost jest płynny.** Każde zjedzone zwierzę od razu trochę powiększa smoka: rośnie
  rozmiar, a razem z nim siła, prędkość, zasięg kroku i dystans kamery. Nie ma skoków
  rozmiaru „z dnia na dzień”.
- **Etap zależy od rozmiaru.** Po przekroczeniu progu (np. 4 m → Młodzik, 9 m → Dorosły,
  16 m → Pradawny) smok **od razu wchodzi na wyższe stadium**: krótki efekt (ryk, rozbłysk,
  napis „Młodzik!”) i odblokowanie nowych zdolności. Pasek wzrostu w HUD pokazuje postęp
  do następnego progu.
- **Proporcje też zmieniają się płynnie.** Pisklę ma dużą głowę, krótką szyję i małe
  skrzydła; z rozmiarem głowa robi się względnie mniejsza, a szyja, ogon i skrzydła dłuższe.
  Technicznie: jeden szkielet i skalowanie poszczególnych kości zależnie od rozmiaru
  (albo przejście między modelem pisklęcia i dorosłego), więc nie ma podmiany modelu
  w trakcie gry.
- Wzrost spowalnia z rozmiarem: większy smok potrzebuje większych ofiar, żeby urosnąć,
  a drobne zwierzęta dają mu coraz mniej.
- Do etapu **Pradawny** potrzeba też odpowiednio dużego **skarbu**.
- **Pierwszy lot** (wejście w stadium Młodzika) to celowo ważny moment gry: wcześniej świat
  oglądamy z ziemi.
- Generator smoka jest kodem, więc etapy mają **własne proporcje** (pisklę: duża głowa,
  krótka szyja, małe skrzydła), a nie tylko skalę.

## Sterowanie (4 przyciski + gałka)

| Wejście | Na ziemi | W powietrzu |
|---|---|---|
| **Gałka** | chód / bieg | przód: nurkowanie, tył: w górę, boki: skręt |
| **Skrzydła** | tap: skok/sus, przytrzymanie: start | tap: machnięcie, trzymanie: zawis |
| **Zryw** | trzymanie: bieg | potężne przyspieszenie (czas odnowienia) |
| **Ugryzienie** | atak paszczą (zabija/rani, potem jedzenie) | **łapanie** w szpony: unieś ofiarę, zanieś do legowiska albo upuść z wysokości |
| **Ogień** | Młodzik: kula ognia z odnowieniem; Dorosły+: strumień ognia | to samo z powietrza (ostrzał z góry) |

Pisklę nie ma ognia ani lotu: przyciski są wtedy wyszarzone, a ich odblokowanie jest nagrodą.

## Przetrwanie (lekkie)

- **Zdrowie**: odnawia się powoli, szybko w legowisku.
- **Głód**: spada powoli i jest łagodną presją; najedzony smok regeneruje się szybciej,
  głodny słabnie. Bez pragnienia, temperatury i craftingu.
- **Wytrzymałość**: lot młodzika i zryw (u dorosłego lot jest bez limitu).
- **Śmierć jest łagodna**: budzisz się w legowisku, tracisz część niesionego złota i trochę
  rozgłosu. **Wzrostu nie tracisz.**

## Ludzie i rozgłos

> **Decyzje właściciela (faza 6):** reakcja ludzi zależy od wielkości smoka — pisklę wieśniacy
> przeganiają widłami, młodzika się boją (cofają się), przed dorosłym uciekają w panice.
> Smok **może zjadać ludzi** (duży wzrost rozgłosu). Rozgłos ściąga myśliwych z łukami.

- **Siedliska**: farmy i pastwiska (łatwe jedzenie, ale ryzyko), wioski, zamki.
- **Ludzie w drodze**: drwale, pasterze, wozy kupieckie (złoto!), patrole, myśliwi z pułapkami.
- **Rozgłos** (jak poziom poszukiwania): owca z pastwiska to mały rozgłos, spalona stodoła
  albo zjedzony rycerz to duży. Rozgłos ściąga coraz groźniejsze siły: myśliwych, rycerzy,
  gryfy, a na końcu jeźdźców gryfów i zakon łowców smoków z balistami. Z czasem opada.
- **Wioski i wybór**: dorosły smok może wioskę **zastraszyć** (płaci **daninę**: złoto co
  jakiś czas trafia do legowiska, ale wioska nie może być niszczona) albo **spalić i złupić**
  (jednorazowo dużo złota, ale ogromny rozgłos). Wioska odbudowuje się po czasie.
- **Zamki** to finał każdego regionu: mury z łucznikami, balisty, gryfy w wieżach,
  dowódca jeźdźców gryfów jako boss, a za nimi wielki skarbiec.

## Świat

- **Otwarty świat do dalszego grania**, bez „końca gry”.
- Zaczynamy od **jednego gęstego regionu** (dolina/wyspa): las, łąki, farmy, jezioro,
  góry z jaskinią-legowiskiem, jedna wioska, jeden zamek. Potem kolejne regiony.
- **Dzień i noc**: w nocy ludzie gorzej widzą (pisklę może zakraść się do kurnika),
  w dzień jest więcej ludzi w drodze.
- **Duży, ale gęsty** (szczegóły niżej): dużo miejsca do latania, ale zawsze coś w zasięgu wzroku.
- **Brak innych smoków**: jesteśmy ostatni. Najwięksi przeciwnicy to gryfy (dzikie,
  w górach) i jeźdźcy gryfów (elita królestwa).

## Skala i gęstość świata

Cel: świat jest **na tyle duży, żeby lot był przyjemnością**, ale **nigdy pusty**.

- **Region startowy ok. 4 × 4 km.** Przelot w poprzek zwykłym lotem (~20 m/s) trwa około
  3 minuty, a nurkowaniem i zrywem szybciej. Kolejne regiony mają podobną skalę.
- **Zasada 20 sekund:** w locie co ~15–25 s (czyli co ~300–500 m) mijasz coś ciekawego:
  stado, farmę, drogę z wozem, ruiny, wodospad, obóz myśliwych, gniazdo gryfa, skarb.
- **Skupiska zamiast równomiernego rozsypania.** Ciekawe miejsca łączą się w „węzły”
  (wioska + pola + pastwisko + droga + młyn), a między nimi są krótsze przerwy:
  las, łąki, rzeka. Przerwy też mają zwierzynę i drobiazgi, więc nie są pustką.
- **Punkty orientacyjne widoczne z daleka:** góry z legowiskiem, wieże zamku, jezioro,
  wielkie drzewo, wodospad. Gracz zawsze widzi, dokąd chce lecieć.
- **Świat „kurczy się” razem ze smokiem.** Pisklę zaczyna w gęstej dolinie o średnicy ok. 500 m,
  w której jest wszystko, czego potrzebuje (las, strumień, kurnik, króliki), a dalsze części
  świata są na razie zbyt groźne. Dla młodzika i dorosłego ta sama mapa robi się mała
  i odsłania dalsze cele.
- **Pionowość:** góry, klify, wąwozy i wysokie wieże dają powód do nurkowania,
  wyciągania w górę i lądowania na szczytach.
- **Wydajność na telefonie:** świat dzielony na kawałki wczytywane wokół smoka,
  uproszczone modele w oddali (LOD), drzewa i trawa rysowane zbiorczo (MultiMesh),
  mgła ukrywająca horyzont.

## Początek gry: dolina rodzinna i matka

- Pisklę wykluwa się w gnieździe matki — dorosłej smoczycy — w zamkniętej dolinie za górami na północy.
- **Samouczek** w dolinie: ruch i skok, polowanie na króliki, jedzenie, pierwsze złoto, sen na skarbie
  i pierwsze ulepszenie (matka leży obok, podpowiada).
- **Napad**: do doliny wchodzą ludzie (rycerze z balistą). Matka ryczy, łapie pisklę w szpony i ucieka.
- **Przelot** (przerywnik): kamera pokazuje świat z góry — wioski, zamek, kanion, cel na przyszłość.
- **Pościg**: jeźdźcy gryfów z dowódcą ranią matkę; ta resztką sił dolatuje do nowej kryjówki (legowisko
  w górze), kładzie pisklę i umiera. Jej grób zostaje miejscem pamięci; dowódca jeźdźców to cel zemsty.
- Samouczek można pominąć (przy każdej nowej grze).

## Legowisko i skarb

- **Jaskinia** w górach: sen = zapis gry + przejście do następnego dnia + leczenie.
  Nowa gra zaczyna się w gnieździe w tej jaskini: pisklę wykluwa się z jaja (decyzja właściciela).
  Zapis: pełny przy śnie (przycisk „Śpij” w komorze) + ciche autozapisy (telefon zabija grę w tle).
- **Stos złota rośnie wizualnie** (generowany proceduralnie z monet, kielichów, koron).
- Złoto to **prestiż i ulepszenia legowiska oraz smoka**: twardsze łuski, większy zasięg
  ognia, szybsza regeneracja, większa pojemność skarbca.
- **Lore ulepszeń — „sen na skarbie”** (decyzja właściciela): smoki śpią na swoim skarbie,
  a złoto i klejnoty wtapiają się w ich łuski i skrzydła. Ulepszenia kupuje się przy śnie
  w legowisku; stos naprawdę maleje, a łuski z każdym poziomem „Twardych łusek” złocieją.
  Na start: Twarde łuski, Silne skrzydła, Smocze zdrowie, Bystre oko (po 3 poziomy).

## Nowe pokolenie (prestiż jak w grach idle)

- Gdy smok jest Pradawny (albo w dowolnym momencie późnej gry), może **złożyć jajo**.
- Z jaja wykluwa się **nowe pisklę z innymi cechami**, np. wariant ognisty, mroźny, burzowy
  albo cieniowy, z innym kolorem, rogami i grzywą (generator smoka z parametrami).
- **Dziedzictwo**: część osiągnięć poprzedniego smoka przechodzi dalej (punkty dziedzictwa
  na stałe bonusy, część skarbu, ulepszenia legowiska), więc każde pokolenie rośnie szybciej.
- Świat pamięta poprzedniego smoka: legendy, ruiny spalonych wiosek, wzmocnione zamki.

## Kolejność prac (wycinek rdzenia → reszta)

1. **Polowanie i wzrost**: przycisk Ugryzienie, pierwsza zwierzyna z prostą SI (ucieka),
   jedzenie, pasek głodu, smok **płynnie** rośnie. Pytanie do sprawdzenia: czy to jest frajda?
2. **Pisklę**: model pisklęcia, start gry jako pisklę bez lotu, etapy i odblokowania.
3. **Legowisko**: sen i zapis, pierwsze złoto i stos skarbu.
4. **Pierwsi ludzie**: wieśniak, myśliwy, farma i wioska, rozgłos.
5. **Ogień**: kula ognia młodzika, strumień dorosłego, palenie budynków.
6. **Łapanie w locie**, danina, wozy kupieckie.
7. **Gryfy, rycerze, zamek**, jeźdźcy gryfów.
8. **Nowe pokolenie** (jajo, warianty smoka, dziedzictwo).

## Otwarte pytania

- Jak daleko ma sięgać „łapanie”: tylko zwierzęta, czy też ludzie i wozy?
- Mapa: jedna duża wyspa czy połączone regiony?
- Nazwa gry.

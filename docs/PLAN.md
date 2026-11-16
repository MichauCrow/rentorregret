# Rent or Regret: Północ — plan budowy

> Masz czas do północy, żeby zapłacić czynsz. Jeśli nie zdążysz, Pan Klucznik się zmienia… i zaczyna Cię szukać.

Lekki horror dla dzieci w kooperacji 1–4 graczy. Straszy, ale nie przeraża: nie ma krwi ani umierania, a potwory działają według prostych zasad, które trzeba rozgryźć.

## Zasady bezpieczeństwa dla dzieci
- Nikt nie ginie. Złapany gracz zostaje **duszkiem**: nie widzą go potwory, a on dalej pomaga drużynie (wskazuje monety).
- Potwory są groźne z daleka, ale z bliska zabawne (kreskówkowy wygląd, mruczenie, kapcie).
- Jumpscare'y (nagłe straszenie) można wyłączyć w ustawieniach, a wybór się zapisuje.
- Między rundami jest jasny, bezpieczny hol.
- W ankiecie wiekowej Roblox odpowiadamy uczciwie i celujemy w najniższą możliwą kategorię.

## Pętla rozgrywki
1. **Hol**: gracze stają na wycieraczce przed drzwiami kamienicy (1–4 osoby). Odliczanie trwa 15 s, a przy pełnej drużynie 5 s.
2. **Runda** (domyślnie 8 minut, zegar idzie od 20:00 do 24:00):
   - przeszukujesz meble (przytrzymaj E albo palec) i znajdujesz monety, które nosisz w kieszeniach,
   - zanosisz monety do skrzynki Pana Klucznika na parterze; wspólna wpłata drużyny zbliża Was do celu (czynszu),
   - gdzieś leży **klucz** do zamkniętego mieszkania ze słoikiem pełnym monet,
   - chowasz się w szafach przed potworami,
   - kiedy czynsz jest zapłacony, otwierają się drzwi wyjściowe; możesz uciec od razu albo zbierać dalej na premię.
3. **Północ**:
   - jeśli czynsz jest zapłacony, wszyscy w środku wychodzą bezpiecznie,
   - jeśli nie, **Klucznik się zmienia** i przez 90 s ściga graczy, a drzwi się otwierają i trzeba uciec.
4. **Nagroda**: monety do sklepu w holu (ulepszenia).

## Potwory (każdy ma jedną zasadę)
| Potwór | Gdzie | Zasada |
|---|---|---|
| Cichy Sąsiad | 1. piętro | Słyszy bieganie. Idź powoli, gdy jest blisko. |
| Mruczek | 2. piętro | Idzie za światłem latarki. Zgaś latarkę. |
| Klucznik o północy | cała kamienica | Pojawia się tylko, gdy czynsz nie jest zapłacony. Uciekaj albo schowaj się w szafie. |

## Ulepszenia (sklepik w holu)
- **Latarka**: większa bateria i zasięg.
- **Cichobiegi**: Cichy Sąsiad słyszy bieganie z mniejszej odległości.
- **Kieszenie**: możesz nosić więcej monet naraz.
- **Kondycja**: dłuższy sprint.

## Architektura kodu
- Cały świat (hol, kamienica, potwory) jest budowany z kodu, więc Rojo synchronizuje całą grę.
- `src/server/Services`: `DataService` (zapis z blokadą sesji), `RemoteService` (limity zapytań), `PlayerStateService`, `ShopService`, `LobbyService`, `RoundService`.
- `src/server/Round`: `Round` (jedna rozgrywka), `Monster` (wspólny ruch po ścieżkach i widoczność), `Monsters/*` (zasady potworów).
- `src/server/World`: `BuildingBuilder` (kamienica), `LobbyBuilder` (hol), `MonsterModels` (wygląd potworów), `Parts` (pomocnicze funkcje do klocków).
- `src/shared/Config`: wszystkie liczby do strojenia (czasy, czynsz, prędkości, ceny).
- `src/client/Controllers`: HUD, latarka, sprint, oświetlenie, złapanie, sklep, ustawienia.
- Każda rozgrywka dostaje własną kopię kamienicy daleko od holu (sloty), więc kilka drużyn może grać naraz na jednym serwerze.

## Fazy
- [x] **Faza 0 — fundament**: gałąź `polnoc`, usunięcie starej rozgrywki, nowy zapis danych (osobny magazyn `RoR_Polnoc_v1`).
- [x] **Faza 1 — pierwsza grywalna wersja** (kod gotowy i przetestowany w symulacji Lune; czeka na test w Studio): hol, kamienica (parter + 2 piętra), rundy 1–4 graczy, monety i czynsz, klucz i zamknięte mieszkanie, szafy, duszki, Cichy Sąsiad, Mruczek, Klucznik o północy, sklep z 4 ulepszeniami, ustawienia (jumpscare'y, dźwięk), obsługa telefonu.
- [x] **Faza 2 — klimat** (kod gotowy, czeka na test w Studio):
  - potwory: animacje (uszy, ogon, płomień świecy, klucz) i ikony nad głową 💤 ❓ ❗,
  - migające lampy (na 2. piętrze często, a przy potworze mocno), bicie serca i ciemne brzegi ekranu w czasie pościgu,
  - tykający i pulsujący zegar w ostatniej minucie, dźwięki 3D potworów, raport dźwięków w Studio (okno Output),
  - cel w HUD („🎯 …”) ze strzałką nad celem, a w pierwszej rundzie także nad najbliższym meblem; podpowiedź przy pierwszym wejściu na piętro,
  - wersja angielska: język z konta Roblox albo z ustawień (auto / PL / EN), test pokrycia tłumaczeń.
  - **Do zrobienia przez Ciebie:** wybrać w Toolboxie dźwięki z pustym ID w `AssetsConfig` (zegar, bicie serca, mruczenie, klucze, szum nocy, „buu!”).
- [ ] **Faza 3 — więcej kamienicy**: piwnica z **Pralką**, **Skarpetnik** (kradnie monety), bezpiecznik i proste zagadki, losowy układ mieszkań.
- [ ] **Faza 4 — powody do powrotu**: zwierzaki-pomocnicy (pies węszy monety, sowa widzi w ciemności), nagroda dzienna, kody, ranking najszybszych rund, kosmetyki.
- [ ] **Faza 5 — fabuła**: karteczki i rozmowy, czyli dlaczego Klucznik zmienia się o północy i jak złamać klątwę (zakończenie).
- [ ] **Faza 6 — tryb „Ty jesteś Klucznikiem”**: jeden gracz jest potworem.

## Przed publikacją
- Test w Studio: Test → Clients and Servers, 2–4 graczy.
- Game Settings → Security → Enable Studio Access to API Services (zapisy w Studio).
- Ankieta wiekowa (Experience Questionnaire), miniatury, ikona, opis PL/EN.

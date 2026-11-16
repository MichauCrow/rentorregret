# Rent or Regret: Północ

Lekki horror dla dzieci na Robloxie, w kooperacji 1–4 graczy.
**Masz czas do północy, żeby zapłacić czynsz. Jeśli nie zdążysz, Pan Klucznik się zmienia… i zaczyna Cię szukać.**

Plan rozwoju i zasady gry: [docs/PLAN.md](docs/PLAN.md).

## Jak się gra
- W holu stań na zielonej **wycieraczce** przed kamienicą (sama albo z maksymalnie 3 osobami).
- W kamienicy przeszukuj meble (**E**), zbieraj monety i zanoś je do **skrzynki w biurze** na parterze.
- **F**: latarka, **Shift**: bieg (na telefonie są do tego przyciski).
- 🤫 **Cichy Sąsiad** (1. piętro) słyszy bieganie. 🐾 **Mruczek** (2. piętro) idzie za światłem latarki.
- Pełne kieszenie **brzęczą**, a kółko pod postacią pokazuje, z jak daleka Cię słychać.
- Chowaj się w **szafach**, ale gdy potwór zajrzy, trzeba **wstrzymać oddech** (minigra). Złapany gracz zostaje **duszkiem** i dalej pomaga drużynie.
- **1-4** albo 📣: szybkie komunikaty dla drużyny. Codziennie inna **noc z modyfikatorem**.
- Po zapłacie czynszu otwiera się brama na podwórku. Za monety kupujesz w **sklepiku** lepszy sprzęt.

## Struktura
| Folder | W grze | Co zawiera |
|---|---|---|
| `src/server` | `ServerScriptService` | `Main.server.luau`, `Services` (dane, hol, rundy, sklep), `Round` (runda i potwory), `World` (budowanie świata z kodu) |
| `src/client` | `StarterPlayer/StarterPlayerScripts` | `ClientMain.client.luau`, `Controllers` (HUD, latarka, sprint, oświetlenie, efekty, sklep, ustawienia) |
| `src/shared` | `ReplicatedStorage/Shared` | `Config` (wszystkie liczby do strojenia), `Modules` |
| `tests` | — | testy w Lune (bez Studio) |
| `place/RentOrRegret.rbxl` | — | kopia pliku miejsca (oświetlenie, ustawienia czatu) |

Cały świat (hol, kamienica, potwory) jest budowany z kodu, więc Rojo synchronizuje całą grę.
Liczby do strojenia (czas rundy, czynsz, prędkości potworów, ceny) są w `src/shared/Config`.

## Praca z Roblox Studio
1. Zainstaluj [Rokit](https://github.com/rojo-rbx/rokit), potem w folderze repozytorium uruchom `rokit install`.
2. W Studio zainstaluj plugin **Rojo**.
3. Otwórz grę w Studio (albo `place/RentOrRegret.rbxl`).
4. W folderze repozytorium uruchom `rojo serve`, a w pluginie kliknij **Connect**.
5. Test w kilka osób: zakładka **Test → Clients and Servers** (np. 2 graczy).

Dźwięki: w Studio, po 5 sekundach testu, okno Output pokaże raport `[Dźwięki]`, czyli które dźwięki się wczytują,
a które nie mają jeszcze ID. ID dopisujesz w `src/shared/Config/AssetsConfig.luau`.

Język: gra sama wybiera polski albo angielski (z konta Roblox). Można to zmienić w ⚙️ Ustawieniach.
Nowy tekst w grze trzeba dopisać do `src/shared/Modules/Lang/Entries.luau`, a `lune run tests/test_lang` pokaże, czego brakuje.

Komendy testowe (tylko w Studio, w konsoli klienta):
`game.ReplicatedStorage.Shared.Remotes.DebugCommand:FireServer("coins")`. Inne komendy to `"midnight"` (północ), `"finale"` (23:55), `"scare"` (zdarzenie Reżysera), `"rent"`, `"key"` i `"reset"`.

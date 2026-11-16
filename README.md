# Rent or Regret

Gra Roblox. Kod jest trzymany jako projekt [Rojo](https://rojo.space).

## Struktura

| Folder | W grze | Co zawiera |
|---|---|---|
| `src/server` | `ServerScriptService` | `Main.server.luau` (start serwera), `Services`, `Jobs`, `World`, `Lib`, `Config` |
| `src/client` | `StarterPlayer/StarterPlayerScripts` | `ClientMain.client.luau`, `Controllers` |
| `src/shared` | `ReplicatedStorage/Shared` | `Config` (ustawienia gry), `Modules` (Lang, Format, FurnitureBuilder…) |
| `place/RentOrRegret.rbxl` | — | kopia pliku miejsca (oświetlenie, Workspace, ustawienia czatu) |

Końcówki plików: `.server.luau` = Script, `.client.luau` = LocalScript, `.luau` = ModuleScript.
Folder z `init.luau` to ModuleScript z dziećmi (np. `Modules/Lang`).

## Praca z Roblox Studio

1. Zainstaluj [Rokit](https://github.com/rojo-rbx/rokit), potem w folderze repozytorium: `rokit install`
2. W Studio zainstaluj plugin **Rojo**.
3. Otwórz grę w Studio (albo `place/RentOrRegret.rbxl`).
4. W folderze repozytorium uruchom `rojo serve`, a w pluginie kliknij **Connect**.

Od tej chwili zmiany w plikach w `src/` od razu pojawiają się w Studio.
Zbudowanie pliku gry bez Studio: `rojo build -o RentOrRegret.rbxl`.

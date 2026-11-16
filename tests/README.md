# Testy bez Roblox Studio

Testy działają w [Lune](https://lune-org.github.io/docs), który emuluje obiekty Robloxa.
Usługi silnika (Pathfinding, Players, DataStore…) są w testach podmienione na proste atrapy.
Uruchamiaj je z głównego folderu repozytorium:

```bash
lune run tests/compile_all     # składnia wszystkich plików .luau
lune run tests/test_building   # buduje kamienicę i rysuje rzut pięter w ASCII
lune run tests/test_round      # symulacja rund: monety, czynsz, szafy, potwory, duszki, północ
lune run tests/test_lang       # czy każdy polski tekst ma tłumaczenie na angielski
lune run tests/test_client     # buduje cały interfejs i przechodzi scenariusz gry (hol, sklep, runda, złapanie)
lune run tests/test_client 844 390 touch en   # to samo dla telefonu po angielsku
```

Testy nie zastąpią próby w Studio, ale wyłapują literówki w nazwach właściwości, błędy logiki i `nil`
w kodzie serwera i klienta. Podgląd wyglądu (świat i interfejs jako obrazki): `tools/preview/README.md`.

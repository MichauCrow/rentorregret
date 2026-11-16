# Testy bez Roblox Studio

Testy działają w [Lune](https://lune-org.github.io/docs), który emuluje obiekty Robloxa.
Usługi silnika (Pathfinding, Players, DataStore…) są w testach podmienione na proste atrapy.
Uruchamiaj je z głównego folderu repozytorium:

```bash
lune run tests/compile_all     # składnia wszystkich plików .luau
lune run tests/test_building   # buduje kamienicę i rysuje rzut pięter w ASCII
lune run tests/test_round      # symulacja rund: monety, czynsz, szafy, potwory, duszki, północ
```

Testy nie zastąpią próby w Studio, ale wyłapują literówki, błędy logiki i `nil` w kodzie serwera.

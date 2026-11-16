# Podgląd gry bez Roblox Studio

Przybliżony podgląd świata gry w przeglądarce (three.js). Nie zastępuje Studio (oświetlenie, materiały
i czcionki wyglądają inaczej), ale pozwala szybko sprawdzić kształty, proporcje i ustawienie części.

Wymagania: [Lune](https://lune-org.github.io/docs), Node.js i Playwright z Chromium.

```bash
cd tools/preview && npm install && cd ../..   # raz
lune run tools/preview/export_world            # eksport świata do tools/preview/out/*.json
node tools/preview/render.mjs                  # wszystkie widoki do tools/preview/out/img/*.png
node tools/preview/render.mjs monster eye_     # tylko widoki z "monster" albo "eye_" w nazwie
```

Widoki (położenia kamer) są w `views.mjs`. Kamienica w eksporcie stoi rogiem w punkcie (0, 0.5, 0).

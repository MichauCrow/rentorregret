-- Ogólne ustawienia gry. Zmieniaj liczby tutaj, nie w serwisach.
local GameConfig = {}

-- Zapis danych. Nowy magazyn: zapisy ze starej wersji gry zostają nietknięte.
-- Studio i gra na żywo używają osobnych magazynów, więc testy w Studio nie zmieniają zapisów graczy.
GameConfig.DATASTORE_NAME_LIVE = "RoR_Polnoc_v1"
GameConfig.DATASTORE_NAME_STUDIO = "RoR_Polnoc_v1_test"
GameConfig.DATA_VERSION = 1
GameConfig.AUTOSAVE_INTERVAL = 60 -- sekundy
GameConfig.SESSION_LOCK_STALE = 180 -- po tylu sekundach bez odświeżenia blokada sesji jest uznana za porzuconą
GameConfig.STARTING_COINS = 0

-- Postać
GameConfig.WALK_SPEED = 12 -- cichy chód
GameConfig.SPRINT_SPEED = 21 -- bieg (słychać go)
GameConfig.NOISY_SPEED = 15 -- powyżej tej prędkości gracz hałasuje (serwer liczy z prędkości postaci)
GameConfig.STAMINA = 5 -- sekundy sprintu bez ulepszeń
GameConfig.STAMINA_REGEN = 0.6 -- ile sekund sprintu wraca na sekundę odpoczynku

-- Kolejka w holu
GameConfig.QUEUE_MAX_PLAYERS = 4
GameConfig.QUEUE_COUNTDOWN = 15
GameConfig.QUEUE_FULL_COUNTDOWN = 5

-- Runda
GameConfig.ROUND_DURATION = 360 -- sekundy do północy (6 minut)
GameConfig.CLOCK_START_HOUR = 20 -- zegar w grze idzie od 20:00 do 24:00
GameConfig.HUNT_DURATION = 75 -- pościg Klucznika po północy, gdy czynsz nie jest zapłacony
GameConfig.FINALE_TIME = 45 -- ostatnie sekundy przed północą: "kamienica się budzi" (gdy czynsz niezapłacony)
GameConfig.FINALE_SPEED = 1.2 -- potwory w finale są szybsze
GameConfig.END_SCREEN_TIME = 6 -- tyle sekund gracz widzi podsumowanie przed powrotem do holu
GameConfig.MAX_ROUNDS = 6 -- ile rozgrywek naraz na jednym serwerze (sloty kamienic)

-- Czynsz i monety w kamienicy
GameConfig.RENT_BASE = 120
GameConfig.RENT_PER_EXTRA_PLAYER = 70
GameConfig.COINS_IN_BUILDING_RATIO = 1.7 -- monet w meblach jest tyle razy więcej niż czynszu
GameConfig.SPOT_EMPTY_CHANCE = 0.3 -- szansa, że mebel jest pusty
GameConfig.JAR_COINS_RATIO = 0.35 -- słoik w zamkniętym mieszkaniu: taka część czynszu
GameConfig.SEARCH_TIME = 1.2 -- sekundy przytrzymania przy przeszukiwaniu
GameConfig.DROPPED_BAG_TIME = 60 -- tyle sekund leży worek z monetami złapanego gracza

-- Latarka (serwer pilnuje baterii)
GameConfig.BATTERY_DRAIN = 1 -- jednostek na sekundę świecenia
GameConfig.BATTERY_REGEN = 0.5 -- jednostek na sekundę, gdy latarka jest zgaszona

-- Hałas (wspólne dla serwera i pierścienia hałasu u gracza, moduł Noise)
GameConfig.MOVING_SPEED = 2 -- poniżej tej prędkości gracz stoi (cisza)
GameConfig.NOISE_RUN_RADIUS = 38 -- z tylu studów słychać bieg
GameConfig.NOISE_COIN_RADIUS = 22 -- z tylu studów słychać brzęk pełnych kieszeni (przy chodzeniu)
GameConfig.JINGLE_FROM = 0.4 -- kieszenie brzęczą, gdy są zapełnione powyżej tej części

-- Reżyser nocy (zdarzenia, gdy przez chwilę nic się nie dzieje)
GameConfig.DIRECTOR_CALM_MIN = 22
GameConfig.DIRECTOR_CALM_MAX = 40
GameConfig.DIRECTOR_FINALE_MIN = 10
GameConfig.DIRECTOR_FINALE_MAX = 16

-- "O włos!": potwór przeszedł tuż obok schowanego albo nieruchomego gracza
GameConfig.CLOSE_CALL_RADIUS = 7
GameConfig.CLOSE_CALL_BONUS = 10
GameConfig.CLOSE_CALL_COOLDOWN = 20

-- Zaglądanie do szaf: minigra "wstrzymaj oddech"
GameConfig.BREATH_TIME = 4 -- sekundy minigry
GameConfig.WARDROBE_CHECK_COOLDOWN = 25 -- ta sama szafa nie jest sprawdzana częściej

-- Szybkie komunikaty drużyny (klawisze 1-4 albo przycisk 📣)
GameConfig.QUICK_CHAT = { "💰 Tutaj monety!", "🏃 Uciekaj!", "🔑 Mam klucz!", "🆘 Pomocy!" }
GameConfig.QUICK_CHAT_COOLDOWN = 2

-- Duszki
GameConfig.GHOST_PING_COOLDOWN = 20
GameConfig.GHOST_PING_TIME = 8

-- Nagrody (monety do sklepu w holu)
GameConfig.REWARD_DEPOSIT_SHARE = 1 -- każda moneta wpłacona przez gracza = tyle monet nagrody
GameConfig.REWARD_RENT_PAID = 60 -- premia dla każdego, gdy drużyna zapłaci czynsz
GameConfig.REWARD_BONUS_RATIO = 1.5 -- monety wpłacone po zapłaceniu czynszu liczą się razy tyle
GameConfig.REWARD_CAUGHT_MULTIPLIER = 0.5 -- złapani dostają połowę
GameConfig.REWARD_ESCAPED_UNPAID = 25 -- premia za ucieczkę przed Klucznikiem o północy

-- Debug (działa wyłącznie w Roblox Studio)
GameConfig.DEBUG_IN_STUDIO = true

return GameConfig

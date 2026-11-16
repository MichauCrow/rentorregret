-- Ogólne ustawienia gry. Zmieniaj liczby tutaj, nie w serwisach.
local GameConfig = {}

-- Czas
GameConfig.MONTH_DURATION = 360 -- sekundy (6 minut)
GameConfig.OVERTIME_DURATION = 120 -- dogrywka na spłatę długu
GameConfig.VISIT_AUTO_PAY = 20 -- po tylu sekundach Pan Klucznik sam pobiera czynsz

-- Start
GameConfig.STARTING_COINS = 0

-- Zapis danych
-- Studio i gra na żywo używają osobnych magazynów danych (wybierane automatycznie w DataService),
-- więc testy w Studio nigdy nie zmieniają zapisów prawdziwych graczy.
GameConfig.DATASTORE_NAME_LIVE = "PlayerData_v1"
GameConfig.DATASTORE_NAME_STUDIO = "PlayerData_v1_test"
GameConfig.LEADERBOARD_PREFIX_LIVE = "LB_"
GameConfig.LEADERBOARD_PREFIX_STUDIO = "LBTEST_"
GameConfig.DATA_VERSION = 1
GameConfig.AUTOSAVE_INTERVAL = 60 -- sekundy
GameConfig.SESSION_LOCK_STALE = 180 -- po tylu sekundach bez odświeżenia blokada sesji jest uznana za porzuconą

-- Debug (działa wyłącznie w Roblox Studio)
GameConfig.DEBUG_IN_STUDIO = true
GameConfig.LOG_TRANSACTIONS_IN_STUDIO = true

return GameConfig

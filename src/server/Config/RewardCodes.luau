-- KODY NAGRÓD (tylko na serwerze, gracze ich nie widzą).
-- Jak dodać nowy kod: skopiuj jeden wpis, zmień id (dowolna nazwa, nie zmieniaj jej później),
-- wpisz kody (wielkość liter i spacje nie mają znaczenia) i nagrody. Każde konto wpisze dany kod tylko raz,
-- a wszystkie kody z jednego wpisu liczą się jako jeden (np. polski i angielski).
-- expires = "RRRR-MM-DD": ostatni dzień działania kodu (opcjonalnie). Usunięty wpis = kod przestaje działać.
-- Nagrody: coins (amount albo factor = część czynszu), tokens = klucze, xp, spin = obroty Kołem nagród.
-- Zasada gry: kody dają tylko nagrody z gry, nigdy nie sprzedajemy ich za Robux.
return {
	{
		id = "welcome",
		codes = { "WITAJ", "WELCOME" },
		rewards = {
			{ kind = "tokens", amount = 5 },
			{ kind = "spin", amount = 1 },
		},
	},
	{
		id = "rent",
		codes = { "CZYNSZ", "RENT" },
		rewards = {
			{ kind = "coins", factor = 0.5, min = 50 },
			{ kind = "xp", amount = 50 },
		},
	},
	{
		id = "mrkeys",
		codes = { "KLUCZNIK", "MRKEYS" },
		rewards = {
			{ kind = "tokens", amount = 3 },
			{ kind = "xp", amount = 100 },
		},
	},
	-- Przykład kodu na okazję (np. 1000 polubień), z datą końca:
	-- {
	-- 	id = "likes1000",
	-- 	codes = { "1000LIKES" },
	-- 	expires = "2026-12-31",
	-- 	rewards = { { kind = "tokens", amount = 10 } },
	-- },
}

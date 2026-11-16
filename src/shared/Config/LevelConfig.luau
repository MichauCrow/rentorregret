-- Poziomy gracza (XP), Koło nagród i Złota godzina. Wszystko liczy serwer, klient tylko wyświetla.
-- Koło jest darmowe: obrót raz dziennie i za każdy nowy poziom. Nie da się go kupić (ani za Robux, ani za klucze).
local LevelConfig = {}

LevelConfig.MAX_LEVEL = 99

-- XP potrzebne, żeby z poziomu `level` wejść na następny (szybko na początku, potem coraz wolniej)
function LevelConfig.Need(level: number): number
	return math.floor(60 * level ^ 1.25)
end

-- Skąd jest XP
LevelConfig.XP_PER_COIN = 0.25 -- za monety zarobione pracą (100 monet = 25 XP)
LevelConfig.XP_SHIFT = 15 -- za każdą skończoną zmianę
LevelConfig.XP_PER_STAR = 10 -- plus za każdą gwiazdkę tej zmiany
LevelConfig.XP_CLEAN = 3 -- za każde sprzątnięcie w mieszkaniu (też u współlokatora)
LevelConfig.XP_RENT = 60 -- za zapłacony czynsz
LevelConfig.XP_RENT_PER_MONTH = 10 -- plus tyle razy numer miesiąca
LevelConfig.XP_DAILY_QUEST = 40
LevelConfig.XP_WEEKLY_QUEST = 120

-- Nagroda za nowy poziom: monety, darmowy obrót kołem, a co 5 poziomów także klucze
function LevelConfig.LevelCoins(level: number): number
	return 15 + 5 * level
end
LevelConfig.MILESTONE_EVERY = 5
LevelConfig.MILESTONE_TOKENS = 3

-- Rangi nad głową i w HUD (nazwy bez rodzaju, pasują do każdego)
LevelConfig.Ranks = {
	{ level = 1, emoji = "🐣", name = "Nowa twarz" },
	{ level = 5, emoji = "🏠", name = "Na swoim" },
	{ level = 10, emoji = "🐝", name = "Pracowita pszczółka" },
	{ level = 15, emoji = "🔧", name = "Złota rączka" },
	{ level = 20, emoji = "⭐", name = "Gwiazda osiedla" },
	{ level = 30, emoji = "🏆", name = "Legenda czynszu" },
	{ level = 40, emoji = "💎", name = "Diament miasta" },
	{ level = 50, emoji = "👑", name = "Ikona miasta" },
}

function LevelConfig.RankFor(level: number)
	local found = LevelConfig.Ranks[1]
	for _, rank in LevelConfig.Ranks do
		if level >= rank.level then
			found = rank
		end
	end
	return found
end

-- Ranga zdobyta dokładnie na tym poziomie (albo nil)
function LevelConfig.RankAt(level: number)
	for _, rank in LevelConfig.Ranks do
		if rank.level == level and level > 1 then
			return rank
		end
	end
	return nil
end

-- Koło nagród. Kolejność = kolejność pól na kole (zgodnie z ruchem wskazówek zegara od góry).
-- coins: factor = część czynszu bieżącego miesiąca (nagroda rośnie razem z grą), min = co najmniej tyle monet
LevelConfig.Wheel = {
	spinTime = 4.6, -- tyle trwa animacja; nagroda trafia na konto po jej końcu
	maxBonus = 10, -- najwięcej zapisanych obrotów z poziomów
	prizes = {
		{ kind = "coins", factor = 0.1, min = 15, weight = 24 },
		{ kind = "xp", amount = 40, weight = 20 },
		{ kind = "tokens", amount = 1, weight = 16 },
		{ kind = "coins", factor = 0.25, min = 30, weight = 15 },
		{ kind = "xp", amount = 100, weight = 11 },
		{ kind = "tokens", amount = 3, weight = 8 },
		{ kind = "coins", factor = 0.6, min = 80, weight = 5 },
		{ kind = "tokens", amount = 10, weight = 1 },
	},
}

-- Złota godzina: co jakiś czas na całym serwerze wszystkie wypłaty i XP są podwójne
LevelConfig.GoldenHour = {
	firstAfter = 5 * 60, -- pierwsza po tylu sekundach od startu serwera
	interval = 18 * 60, -- potem co tyle sekund (licząc od początku poprzedniej)
	duration = 3 * 60, -- tyle trwa (cała zmiana się zmieści)
	warnBefore = 30, -- zapowiedź tyle sekund wcześniej
	payBonus = 1, -- +100% do wypłat = x2
	xpMultiplier = 2,
}

-- Combo w pracy: kolejne zadanie w ciągu comboWindow sekund (z JobsConfig) przedłuża serię
LevelConfig.COMBO_SOUND_MAX = 1.8 -- najwyższy ton dźwięku serii

return LevelConfig

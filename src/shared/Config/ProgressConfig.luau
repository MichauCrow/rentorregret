-- Postęp i powroty codzienne: kalendarz, zadania dnia, wyzwania tygodnia, wyzwanie serwera,
-- osiągnięcia, sekretne krasnale i rankingi tygodniowe.
local ProgressConfig = {}

local SECONDS_PER_DAY = 86400

-- Kalendarz Lokatora: 7 nagród po kolei; opuszczony dzień niczego nie zeruje
ProgressConfig.Calendar = {
	{ kind = "coins", factor = 0.10 },
	{ kind = "tokens", amount = 2 },
	{ kind = "coins", factor = 0.15 },
	{ kind = "tokens", amount = 3 },
	{ kind = "coins", factor = 0.20 },
	{ kind = "tokens", amount = 5 },
	{ kind = "furniture", item = "starLamp", fallbackTokens = 10 },
}

-- Zadania dnia (3 losowe na dzień). targetFactor = cel jako część czynszu bieżącego miesiąca
ProgressConfig.DailyQuests = {
	{ kind = "clean", target = 15, text = "Posprzątaj %d rzeczy" },
	{ kind = "shifts", target = 2, text = "Skończ %d zmiany w pracy" },
	{ kind = "stars3", target = 1, text = "Zdobądź 3★ w dowolnej pracy" },
	{ kind = "earn", targetFactor = 0.6, text = "Zarób w pracy %d monet" },
	{ kind = "cans", target = 10, text = "Wrzuć %d butelek do kaucjomatu" },
}
ProgressConfig.DAILY_QUEST_COUNT = 3
ProgressConfig.DAILY_REWARD = { coinsFactor = 0.15, tokens = 2 }

-- Wyzwania tygodnia (3 losowe na tydzień)
ProgressConfig.WeeklyChallenges = {
	{ kind = "clean", target = 150, text = "Posprzątaj %d rzeczy" },
	{ kind = "shifts", target = 12, text = "Skończ %d zmian w pracy" },
	{ kind = "monthsPaid", target = 3, text = "Opłać czynsz %d razy" },
	{ kind = "rare", target = 2, text = "Wykonaj %d rzadkie zlecenia" },
	{ kind = "earn", targetFactor = 5, text = "Zarób w pracy %d monet" },
}
ProgressConfig.WEEKLY_CHALLENGE_COUNT = 3
ProgressConfig.WEEKLY_REWARD = { coinsFactor = 0.5, tokens = 10 }

-- Wspólne wyzwanie serwera (cel rośnie z liczbą graczy i z każdą rundą)
ProgressConfig.ServerChallenges = {
	{ kind = "clean", base = 60, perPlayer = 30, text = "Cały serwer: posprzątajcie razem %d rzeczy" },
	{ kind = "shifts", base = 6, perPlayer = 3, text = "Cały serwer: skończcie razem %d zmian w pracy" },
}
ProgressConfig.SERVER_REWARD_TOKENS = 5
ProgressConfig.SERVER_ROUND_GROWTH = 1.25

-- Osiągnięcia: stat = pole w data.stats, special = warunek liczony osobno (AchievementService)
ProgressConfig.Achievements = {
	{ id = "month1", name = "Pierwszy czynsz", description = "Opłać 1 miesiąc", stat = "monthsPaid", target = 1, tokens = 2 },
	{ id = "month3", name = "Lokator", description = "Opłać 3 miesiące", stat = "monthsPaid", target = 3, tokens = 3 },
	{ id = "month5", name = "Stały lokator", description = "Opłać 5 miesięcy", stat = "monthsPaid", target = 5, tokens = 5 },
	{ id = "month10", name = "Weteran najmu", description = "Opłać 10 miesięcy", stat = "monthsPaid", target = 10, tokens = 10, reward = "trophy" },
	{ id = "month25", name = "Legenda kamienicy", description = "Opłać 25 miesięcy", stat = "monthsPaid", target = 25, tokens = 15 },
	{ id = "month50", name = "Król czynszu", description = "Opłać 50 miesięcy", stat = "monthsPaid", target = 50, tokens = 25 },
	{ id = "streak5", name = "Zawsze na czas", description = "Zapłać 5 razy z rzędu w terminie", stat = "onTimeStreak", target = 5, tokens = 5 },
	{ id = "clean50", name = "Porządnicki", description = "Posprzątaj 50 rzeczy w domu", stat = "cleaned", target = 50, tokens = 3 },
	{ id = "clean250", name = "Mistrz miotły", description = "Posprzątaj 250 rzeczy w domu", stat = "cleaned", target = 250, tokens = 8 },
	{ id = "rare1", name = "Pomocna dłoń", description = "Wykonaj rzadkie zlecenie", stat = "rareDone", target = 1, tokens = 3 },
	{ id = "rare10", name = "Łowca zleceń", description = "Wykonaj 10 rzadkich zleceń", stat = "rareDone", target = 10, tokens = 10 },
	{ id = "helper25", name = "Dobry sąsiad", description = "Pomóż 25 razy w sprzątaniu u kogoś", stat = "helped", target = 25, tokens = 5 },
	{ id = "furnished", name = "Urządzony", description = "Miej 5 mebli w mieszkaniu", special = "furniture", target = 5, tokens = 5 },
	{ id = "master", name = "Mistrz fachu", description = "Zdobądź 3★ w każdej pracy zmianowej", special = "allJobs", target = 8, tokens = 15, reward = "neonSign" },
	{ id = "goldenCan", name = "Złota puszka", description = "Sekret: znajdź złotą puszkę", special = "secret", secret = "goldenCan", target = 1, tokens = 3, reward = "canShelf" },
	{ id = "gnomes", name = "Łowca krasnali", description = "Sekret: znajdź 10 złotych krasnali w mieście", special = "gnomes", target = 10, tokens = 10 },
}

-- Sekretne złote krasnale (pozycje na mapie)
ProgressConfig.Gnomes = {
	Vector3.new(0, 0, 56),
	Vector3.new(-68, 0, -5),
	Vector3.new(68, 0, -46),
	Vector3.new(0, 0, -62),
	Vector3.new(-152, 0, 18),
	Vector3.new(152, 0, 14),
	Vector3.new(112, 0, -34),
	Vector3.new(-122, 0, 104),
	Vector3.new(40, 0, 150),
	Vector3.new(130, 0, 168),
}

-- Rankingi tygodniowe (wartości z data.weekly.stats)
ProgressConfig.Leaderboards = {
	{ id = "earned", name = "Zarobione monety", stat = "earned" },
	{ id = "months", name = "Opłacone miesiące", stat = "monthsPaid" },
	{ id = "cleaned", name = "Posprzątane rzeczy", stat = "cleaned" },
}
ProgressConfig.LEADERBOARD_REFRESH = 90 -- sekundy
ProgressConfig.LEADERBOARD_SIZE = 10

function ProgressConfig.Today(): number
	return math.floor(os.time() / SECONDS_PER_DAY)
end

-- Tydzień zaczyna się w poniedziałek (dzień 0 według Unix to czwartek)
function ProgressConfig.WeekOf(day: number): number
	return math.floor((day + 3) / 7)
end

return ProgressConfig

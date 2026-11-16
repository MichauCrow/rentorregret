-- Prezenty za czas gry i limity kodów nagród. Same kody leżą tylko na serwerze
-- (ServerScriptService.Config.RewardCodes), żeby nikt nie mógł ich podejrzeć w grze.
local RewardsConfig = {}

-- Prezenty za czas gry: liczy się czas w grze w danym dniu (też po ponownym wejściu), od północy UTC od nowa.
-- Nagrody są stałe i widać je z góry (bez losowania).
-- coins: factor = część czynszu bieżącego miesiąca, min = co najmniej tyle monet; spin = obrót Kołem nagród
RewardsConfig.Gifts = {
	{ minutes = 2, kind = "coins", factor = 0.1, min = 10 },
	{ minutes = 5, kind = "xp", amount = 30 },
	{ minutes = 10, kind = "tokens", amount = 1 },
	{ minutes = 15, kind = "coins", factor = 0.2, min = 20 },
	{ minutes = 20, kind = "xp", amount = 60 },
	{ minutes = 30, kind = "tokens", amount = 2 },
	{ minutes = 45, kind = "spin", amount = 1 },
	{ minutes = 60, kind = "tokens", amount = 3 },
}

-- Kody: najdłuższy kod i blokada po kilku błędnych próbach z rzędu
RewardsConfig.CODE_MAX_LENGTH = 24
RewardsConfig.CODE_MAX_FAILS = 5
RewardsConfig.CODE_COOLDOWN = 30

return RewardsConfig

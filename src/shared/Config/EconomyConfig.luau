-- Ekonomia zatwierdzona w Fazie 1. Wszystkie kwoty w monetach.
local EconomyConfig = {}

-- Czynsz i rachunki dla miesięcy 1-10
EconomyConfig.Months = {
	[1] = { rent = 100, bills = 0 },
	[2] = { rent = 120, bills = 15 },
	[3] = { rent = 145, bills = 20 },
	[4] = { rent = 175, bills = 25 },
	[5] = { rent = 210, bills = 30 },
	[6] = { rent = 250, bills = 35 },
	[7] = { rent = 295, bills = 40 },
	[8] = { rent = 345, bills = 45 },
	[9] = { rent = 400, bills = 50 },
	[10] = { rent = 460, bills = 55 },
}

-- Po miesiącu 10 czynsz rośnie o 15%, a rachunki o 5 monet na miesiąc
EconomyConfig.RENT_GROWTH_AFTER_TABLE = 1.15
EconomyConfig.BILLS_GROWTH_AFTER_TABLE = 5

-- Najlepsza stawka (monety/min) dostępna przeciętnemu graczowi w danym miesiącu (tabela z Fazy 1)
EconomyConfig.BestRate = { 30, 40, 49, 62, 78, 95, 115, 135, 160, 175 }

function EconomyConfig.GetBestRate(month: number): number
	local last = #EconomyConfig.BestRate
	if month <= last then
		return EconomyConfig.BestRate[math.max(1, month)]
	end
	return math.floor(EconomyConfig.BestRate[last] * 1.1 ^ (month - last) + 0.5)
end

-- Mnożniki wypłat za prace (używane od Fazy 5)
EconomyConfig.DifficultyMultiplier = { 1.0, 1.35, 1.75 } -- Łatwy, Średni, Trudny
EconomyConfig.StarMultiplier = { [0] = 0.3, [1] = 0.7, [2] = 1.0, [3] = 1.3 }

-- Modyfikatory
EconomyConfig.RESTED_BONUS = 0.10 -- mieszkanie >= 4 gwiazdki
EconomyConfig.TIRED_PENALTY = 0.10 -- mieszkanie <= 1 gwiazdka
EconomyConfig.HAPPY_LANDLORD_DISCOUNT = 0.10
EconomyConfig.ROOMMATE_DISCOUNT = { [1] = 0, [2] = 0.10, [3] = 0.15, [4] = 0.15 }
-- Ulepszenia eko ze sklepu: obniżka rachunków (razem najwyżej MAX_ECO_DISCOUNT)
EconomyConfig.EcoUpgrades = { led = 0.2, aerator = 0.2 }
EconomyConfig.MAX_ECO_DISCOUNT = 0.4

-- Właściciel (Pan Klucznik)
EconomyConfig.Landlord = {
	START_MOOD = 50,
	PAID_ON_TIME = 10,
	PAID_IN_OVERTIME = -10,
	DEBT_CARRIED = -20,
	HAPPY_THRESHOLD = 80,
	GRUMPY_THRESHOLD = 20,
	MAX_WARNINGS = 3, -- trzecie ostrzeżenie = eksmisja
	COLD_SHOWER_PENALTY = 0.10, -- od 2. ostrzeżenia do spłaty długu
}

-- Etapy (dzielnice). Eksmisja cofa na początek bieżącego etapu.
EconomyConfig.Stages = {
	{ name = "Zaułek Startowy", first = 1, last = 3 },
	{ name = "Śródmieście", first = 4, last = 6 },
	{ name = "Wzgórze", first = 7, last = 10 },
}

-- Bezpieczeństwo: żadna pojedyncza transakcja nie może przekroczyć tej kwoty
EconomyConfig.MAX_TRANSACTION = 1000000

function EconomyConfig.GetMonth(month: number)
	local entry = EconomyConfig.Months[month]
	if entry then
		return entry
	end
	local last = #EconomyConfig.Months
	local base = EconomyConfig.Months[last]
	local extra = math.max(0, month - last)
	return {
		rent = math.floor(base.rent * EconomyConfig.RENT_GROWTH_AFTER_TABLE ^ extra + 0.5),
		bills = base.bills + EconomyConfig.BILLS_GROWTH_AFTER_TABLE * extra,
	}
end

-- Czynsz + rachunki za dany miesiąc
function EconomyConfig.GetDue(month: number): number
	local entry = EconomyConfig.GetMonth(month)
	return entry.rent + entry.bills
end

-- Czynsz + rachunki z uwzględnieniem nastroju właściciela (bez starego długu)
function EconomyConfig.GetMonthlyDue(month: number, landlordMood: number): number
	local due = EconomyConfig.GetDue(month)
	if landlordMood >= EconomyConfig.Landlord.HAPPY_THRESHOLD then
		due = math.floor(due * (1 - EconomyConfig.HAPPY_LANDLORD_DISCOUNT) + 0.5)
	end
	return due
end

-- Pełna kwota do zapłaty za miesiąc gracza (bez starego długu): czynsz + rachunki po ulepszeniach eko,
-- zniżka zachwyconego właściciela i zniżka współlokatorska (householdSize = liczba osób w mieszkaniu)
function EconomyConfig.GetMonthlyDueFor(data, householdSize: number): number
	local entry = EconomyConfig.GetMonth(data.month)
	local eco = 0
	for upgradeId, discount in EconomyConfig.EcoUpgrades do
		if data.equipment[upgradeId] then
			eco += discount
		end
	end
	local bills = entry.bills * (1 - math.min(eco, EconomyConfig.MAX_ECO_DISCOUNT))
	local due = entry.rent + bills
	if data.landlordMood >= EconomyConfig.Landlord.HAPPY_THRESHOLD then
		due *= 1 - EconomyConfig.HAPPY_LANDLORD_DISCOUNT
	end
	due *= 1 - (EconomyConfig.ROOMMATE_DISCOUNT[math.clamp(householdSize, 1, 4)] or 0)
	return math.floor(due + 0.5)
end

function EconomyConfig.StageForMonth(month: number): number
	for index, stage in EconomyConfig.Stages do
		if month <= stage.last then
			return index
		end
	end
	return #EconomyConfig.Stages
end

function EconomyConfig.StageStartMonth(stage: number): number
	local entry = EconomyConfig.Stages[stage] or EconomyConfig.Stages[#EconomyConfig.Stages]
	return entry.first
end

return EconomyConfig

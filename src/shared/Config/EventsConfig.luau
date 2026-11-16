-- Zdarzenia losowe w mieszkaniu (zatwierdzone w Fazie 1). Najwyżej 1 zdarzenie w miesiącu, od miesiąca 8 do 2.
local EventsConfig = {}

EventsConfig.WINDOW = { 90, 300 } -- sekundy miesiąca, w których może zacząć się zdarzenie
EventsConfig.SECOND_EVENT_FROM_MONTH = 8
EventsConfig.SECOND_EVENT_CHANCE = 0.4

-- Kolejność używana przez komendy testowe
EventsConfig.Order = { "inspection", "sale", "powerOutage", "flood", "raccoon", "neighborRequest" }

EventsConfig.Events = {
	inspection = { name = "Kontrola Klucznika", minMonth = 2, weight = 25, duration = 45, goodMood = 15, badMood = -10, goodReward = 20 },
	sale = { name = "Wyprzedaż w Mebelkowie", minMonth = 2, weight = 15, duration = 120, discount = 0.3 },
	powerOutage = { name = "Awaria prądu", minMonth = 3, weight = 20, duration = 90, fuseHold = 2 },
	flood = { name = "Zalanie od sąsiada", minMonth = 4, weight = 15, duration = 60, puddles = 5, damageCost = 30 },
	raccoon = { name = "Szop-łasuch", minMonth = 5, weight = 15, duration = 60, catches = 3, reward = 30 },
	neighborRequest = { name = "Prośba sąsiada", minMonth = 3, weight = 10, duration = 0 },
}

-- Szansa na zdarzenie w miesiącu: 0% w miesiącu 1, 30% w 2, 50% w 3-5, 70% od 6
function EventsConfig.Chance(month: number): number
	if month < 2 then
		return 0
	elseif month == 2 then
		return 0.3
	elseif month <= 5 then
		return 0.5
	end
	return 0.7
end

return EventsConfig

-- Zdarzenia losowe: kontrola Klucznika, wyprzedaż, awaria prądu, zalanie, szop-łasuch, prośba sąsiada.
-- Najwyżej jedno zdarzenie naraz; zaczyna się tylko, gdy zegar miesiąca biegnie (nie w trakcie wizyty).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EventsConfig = require(ReplicatedStorage.Shared.Config.EventsConfig)
local ApartmentConfig = require(ReplicatedStorage.Shared.Config.ApartmentConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local PropBuilder = require(ServerScriptService.World.PropBuilder)
local HoldPrompt = require(ServerScriptService.Lib.HoldPrompt)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local ApartmentService = require(Services.ApartmentService)
local MonthService = require(Services.MonthService)
local FailureService = require(Services.FailureService)
local RareContractService = require(Services.RareContractService)
local RoommateService = require(Services.RoommateService)

local EventService = {}

local EVENTS = EventsConfig.Events
local RACCOON_HOLD = 0.8

local active = {} -- [player] = { id, endsAt, ... }
local plans = {} -- [player] = { month, times }
local rng = Random.new()

local function changeMood(data, delta: number)
	data.landlordMood = math.clamp(data.landlordMood + delta, 0, 100)
end

local function eventFolder(player: Player): Folder?
	local unit = ApartmentService.GetUnit(player)
	if not unit then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "EventObjects"
	folder.Parent = unit.model
	return folder
end

local handlers = {}

-- Kończy aktywne zdarzenie. reason: "timeout", "done" albo "leave"
function EventService.End(player: Player, reason: string)
	local event = active[player]
	if not event then
		return
	end
	active[player] = nil
	local handler = handlers[event.id]
	local data = DataService.Get(player)
	if handler.finish and data and reason ~= "leave" then
		local ok, err = pcall(handler.finish, player, data, event, reason)
		if not ok then
			warn("[EventService] Błąd kończenia " .. event.id .. ": " .. tostring(err))
		end
	end
	if handler.cleanup then
		pcall(handler.cleanup, player, event)
	end
	if event.folder then
		event.folder:Destroy()
	end
	StateService.Push(player)
end

-- Kontrola: 45 s na posprzątanie, potem ocena mieszkania
handlers.inspection = {
	start = function(player)
		StateService.Notify(player, "🔍 Pan Klucznik zapowiedział kontrolę za 45 s! Szybko posprzątaj!", "warn")
	end,
	finish = function(player, data)
		local definition = EVENTS.inspection
		local stars = ApartmentConfig.StarsForScore(data.apartment.score)
		if stars >= 3 then
			changeMood(data, definition.goodMood)
			EconomyService.AddCoins(player, definition.goodReward, "inspection")
			StateService.Notify(player, string.format("Kontrola zaliczona (%d★)! Pan Klucznik zadowolony: +%d monet", stars, definition.goodReward), "good")
		elseif stars < 2 then
			changeMood(data, definition.badMood)
			StateService.Notify(player, string.format("Kontrola nieudana (%d★). Pan Klucznik się skrzywił...", stars), "bad")
		else
			StateService.Notify(player, "Kontrola: może być. Następnym razem posprzątaj lepiej!", "info")
		end
	end,
}

-- Wyprzedaż: sklep (Faza 9) pyta o zniżkę przez GetShopDiscount
handlers.sale = {
	start = function(player)
		StateService.Notify(player, "🏷 Wyprzedaż w Mebelkowie: -30% przez 2 minuty!", "good")
	end,
	finish = function(player)
		StateService.Notify(player, "Wyprzedaż się skończyła.", "info")
	end,
}

-- Awaria prądu: ciemno, aż gracz włączy bezpieczniki albo minie czas
handlers.powerOutage = {
	start = function(player, _data, event)
		FailureService.SetOutage(player, true, EVENTS.powerOutage.fuseHold, function()
			if active[player] == event then
				EventService.End(player, "done")
			end
		end)
		StateService.Notify(player, "⚡ Awaria prądu! Włącz bezpieczniki na lewej ścianie w mieszkaniu.", "warn")
	end,
	finish = function(player, _data, _event, reason)
		if reason == "done" then
			StateService.Notify(player, "Światło wróciło! Dzięki, elektryku!", "good")
		else
			StateService.Notify(player, "Elektrownia naprawiła awarię. Światło wróciło.", "info")
		end
	end,
	cleanup = function(player)
		FailureService.SetOutage(player, false)
	end,
}

-- Zalanie: kałuże do zmopowania; szybka reakcja = brak kosztów
handlers.flood = {
	start = function(player, _data, event)
		event.puddles = {}
		for _ = 1, EVENTS.flood.puddles do
			local id = ApartmentService.AddDirt(player, "stain")
			if id then
				table.insert(event.puddles, id)
			end
		end
		StateService.Notify(player, "💦 Sąsiad z góry zalał mieszkanie! Zmopuj kałuże w 60 s, żeby uniknąć kosztów.", "warn")
	end,
	tick = function(player, _data, event)
		for _, id in event.puddles do
			if ApartmentService.HasDirt(player, id) then
				return
			end
		end
		EventService.End(player, "done")
	end,
	finish = function(player, data, event, reason)
		if reason == "done" then
			StateService.Notify(player, "Uratowane! Kałuże zmopowane, zero kosztów.", "good")
			return
		end
		local cost = math.min(EVENTS.flood.damageCost, data.coins)
		if cost > 0 and EconomyService.TrySpend(player, cost, "flood") then
			StateService.Notify(player, string.format("Woda zdążyła narobić szkód: -%d monet.", cost), "bad")
		else
			StateService.Notify(player, "Woda narobiła bałaganu. Zmopuj resztę kałuż!", "warn")
		end
	end,
}

-- Szop-łasuch: trzeba go złapać 3 razy, za każdym razem ucieka w inne miejsce
local function placeRaccoon(player: Player, event)
	local point = ApartmentService.RandomFloorPoint(player)
	if point and event.raccoon then
		event.raccoon:PivotTo(CFrame.new(point) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	end
end

handlers.raccoon = {
	start = function(player, _data, event)
		local point = ApartmentService.RandomFloorPoint(player)
		if not point or not event.folder then
			return
		end
		event.catches = 0
		local raccoon = PropBuilder.Raccoon(CFrame.new(point))
		event.raccoon = raccoon
		HoldPrompt.Create(raccoon.PrimaryPart, { action = "Złap szopa", object = "Szop-łasuch", hold = RACCOON_HOLD, activation = 8, maxDistance = 12 }, function(who)
			if active[player] ~= event or not ApartmentService.CanClean(player, who) then
				return
			end
			event.catches += 1
			if event.catches >= EVENTS.raccoon.catches then
				EventService.End(player, "done")
			else
				StateService.Notify(player, string.format("Uciekł! Jeszcze %d raz(y)!", EVENTS.raccoon.catches - event.catches), "info")
				placeRaccoon(player, event)
			end
		end)
		raccoon.Parent = event.folder
		StateService.Notify(player, "🦝 Szop-łasuch buszuje w kuchni! Złap go 3 razy.", "warn")
	end,
	finish = function(player, _data, event, reason)
		if reason == "done" then
			if event.raccoon then
				RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, event.raccoon.PrimaryPart.Position, "allClean", 0)
			end
			EconomyService.AddCoins(player, EVENTS.raccoon.reward, "raccoon")
			StateService.Notify(player, string.format("Mam cię! Szop wypuszczony do lasu: +%d monet", EVENTS.raccoon.reward), "good")
		else
			ApartmentService.AddDirt(player, "trash")
			ApartmentService.AddDirt(player, "trash")
			StateService.Notify(player, "Szop uciekł z kanapką i zostawił bałagan.", "warn")
		end
	end,
}

-- Prośba sąsiada: od razu dodatkowe rzadkie zlecenie
handlers.neighborRequest = {
	start = function(player)
		if RareContractService.HasActive(player) then
			return
		end
		StateService.Notify(player, "📨 Sąsiad prosi o pomoc!", "info")
		RareContractService.ForceOffer(player)
	end,
}

local function startEvent(player: Player, data, eventId: string)
	if active[player] then
		return
	end
	local definition = EVENTS[eventId]
	local event = {
		id = eventId,
		name = definition.name,
		endsAt = os.clock() + definition.duration,
	}
	if eventId == "raccoon" then
		event.folder = eventFolder(player)
	end
	active[player] = event
	local ok, err = pcall(handlers[eventId].start, player, data, event)
	if not ok then
		warn("[EventService] Błąd startu " .. eventId .. ": " .. tostring(err))
	end
	if definition.duration <= 0 or not ok then
		EventService.End(player, "done")
		return
	end
	StateService.Push(player)
end

local function pickEvent(month: number): string?
	local candidates = {}
	local total = 0
	for _, eventId in EventsConfig.Order do
		local definition = EVENTS[eventId]
		if month >= definition.minMonth then
			table.insert(candidates, eventId)
			total += definition.weight
		end
	end
	if #candidates == 0 then
		return nil
	end
	local roll = rng:NextNumber(0, total)
	for _, eventId in candidates do
		if roll <= EVENTS[eventId].weight then
			return eventId
		end
		roll -= EVENTS[eventId].weight
	end
	return candidates[1]
end

local function tickPlayer(player: Player, data, now: number)
	local event = active[player]
	if event then
		local handler = handlers[event.id]
		if handler.tick then
			handler.tick(player, data, event)
		end
		if active[player] == event and now >= event.endsAt then
			EventService.End(player, "timeout")
		end
		return
	end

	local plan = plans[player]
	if not plan or plan.month ~= data.month then
		plan = { month = data.month, times = {} }
		if rng:NextNumber() < EventsConfig.Chance(data.month) then
			table.insert(plan.times, rng:NextInteger(EventsConfig.WINDOW[1], EventsConfig.WINDOW[2]))
		end
		if data.month >= EventsConfig.SECOND_EVENT_FROM_MONTH and rng:NextNumber() < EventsConfig.SECOND_EVENT_CHANCE then
			table.insert(plan.times, rng:NextInteger(EventsConfig.WINDOW[1], EventsConfig.WINDOW[2]))
		end
		table.sort(plan.times)
		for _ = 1, math.min(data.monthly.events, #plan.times) do
			table.remove(plan.times, 1)
		end
		plans[player] = plan
	end
	if plan.times[1] and data.monthElapsed >= plan.times[1] and MonthService.IsRunning(player) and ApartmentService.GetUnit(player) then
		table.remove(plan.times, 1)
		local eventId = pickEvent(data.month)
		if eventId then
			data.monthly.events += 1
			startEvent(player, data, eventId)
		end
	end
end

-- Zniżka w sklepie (0.3 w trakcie wyprzedaży, inaczej 0)
function EventService.GetShopDiscount(player: Player): number
	local event = active[player]
	if event and event.id == "sale" then
		return EVENTS.sale.discount
	end
	return 0
end

-- Tylko do testów w Studio: zdarzenie nr index z EventsConfig.Order
function EventService.DebugStart(player: Player, index: number)
	local data = DataService.Get(player)
	local eventId = EventsConfig.Order[index]
	if data and eventId then
		startEvent(player, data, eventId)
	end
end

function EventService.Init()
	StateService.AddProvider(function(player, snapshot)
		local event = active[player]
		if event then
			snapshot.event = { name = event.name, endsIn = math.max(0, event.endsAt - os.clock()) }
		end
	end)
end

function EventService.Start()
	Players.PlayerRemoving:Connect(function(player)
		EventService.End(player, "leave")
		plans[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data and not RoommateService.IsGuest(player) then
					local ok, err = pcall(tickPlayer, player, data, now)
					if not ok then
						warn("[EventService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return EventService

-- Praca w pizzerii (bardziej zaawansowana od kebabów): przy stole w kuchni robisz pizzę według zamówienia
-- w minigrze (wałkowanie ciasta, sos, ser, składniki z zamówienia, pieczenie z wyczuciem czasu, pakowanie),
-- potem wsiadasz na skuter przed pizzerią, wieziesz pizzę pod wskazany dom, wracasz i parkujesz.
-- Każdy krok minigry sprawdza serwer (kolejność, odstęp między kliknięciami, czas w piecu); klient tylko pokazuje
-- tryb "pizzaMaker" (PizzaMakerController). Zły składnik albo surowa / przypalona pizza = pizza z błędem.
-- Dowóz, parking skuterów i dostawy: Lib.DeliveryJob.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local DeliveryJob = require(ServerScriptService.Lib.DeliveryJob)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)

local CONFIG = JobsConfig.Jobs.pizza
local TOPPINGS = { "salami", "ham", "mushroom", "pepper", "pineapple", "olive" }
-- Karta pizz: liczba składników = poziom trudności (levelConfig.toppings)
local MENU = {
	{ name = "Salami", toppings = { "salami" } },
	{ name = "Pieczarkowa", toppings = { "mushroom" } },
	{ name = "Hawajska", toppings = { "ham", "pineapple" } },
	{ name = "Capricciosa", toppings = { "ham", "mushroom" } },
	{ name = "Diavola", toppings = { "salami", "pepper" } },
	{ name = "Wege", toppings = { "pepper", "mushroom", "olive" } },
	{ name = "Królewska", toppings = { "ham", "salami", "mushroom" } },
	{ name = "Wiejska", toppings = { "ham", "pepper", "olive" } },
}
local STEP_HINTS = {
	dough = "Rozwałkuj ciasto 👐",
	sauce = "Posmaruj ciasto sosem 🍅",
	cheese = "Posyp serem 🧀",
	toppings = "Dodaj składniki z zamówienia",
	oven = "Włóż pizzę do pieca 🔥",
	baking = "Wyjmij pizzę, gdy pasek jest w zielonym polu!",
	pack = "Zapakuj pizzę do pudełka 📦",
}
local rng = Random.new()

local function contains(list, value): boolean
	return table.find(list, value) ~= nil
end

-- Stan minigry dla klienta (tryb "pizzaMaker")
local function send(session, api, note: string?, bad: boolean?)
	local making = session.state.making
	api.progress(session, STEP_HINTS[making.step] or "", {
		mode = "pizzaMaker",
		step = making.step,
		order = { name = making.order.name, toppings = making.order.toppings },
		toppings = TOPPINGS,
		placed = making.placed,
		rolls = making.rolls,
		rollsNeeded = CONFIG.rolls,
		ovenTime = CONFIG.ovenTime,
		zone = CONFIG.ovenZone,
		note = note,
		noteBad = bad == true,
	})
end

local prep = {}

function prep.start(session, api)
	local wanted = session.levelConfig.toppings or 1
	local options = {}
	for _, pizza in MENU do
		if #pizza.toppings == wanted then
			table.insert(options, pizza)
		end
	end
	local order = options[rng:NextInteger(1, #options)]
	session.state.making = { step = "dough", order = order, rolls = 0, placed = {}, bad = false, last = 0 }
	send(session, api, "Nowe zamówienie: " .. order.name, false)
end

function prep.action(session, action: string, value: any, api)
	local state = session.state
	local making = state.making
	if action ~= "pizza" or not RemoteService.IsString(value, 24) then
		return
	end
	local now = os.clock()
	if now - making.last < CONFIG.minStepInterval then
		return
	end
	making.last = now
	local step = making.step
	if step == "dough" and value == "roll" then
		making.rolls += 1
		if making.rolls >= CONFIG.rolls then
			making.step = "sauce"
		end
		send(session, api)
	elseif step == "sauce" and value == "sauce" then
		making.step = "cheese"
		send(session, api)
	elseif step == "cheese" and value == "cheese" then
		making.step = "toppings"
		send(session, api)
	elseif step == "toppings" and value:sub(1, 2) == "t:" then
		local topping = value:sub(3)
		if not contains(TOPPINGS, topping) or contains(making.placed, topping) then
			return
		end
		if not contains(making.order.toppings, topping) then
			making.bad = true
			send(session, api, "Tego nie ma w zamówieniu! 🙈", true)
			return
		end
		table.insert(making.placed, topping)
		if #making.placed >= #making.order.toppings then
			making.step = "oven"
		end
		send(session, api)
	elseif step == "oven" and value == "oven" then
		making.step = "baking"
		making.ovenAt = now
		send(session, api)
	elseif step == "baking" and value == "take" then
		local fraction = (now - making.ovenAt) / CONFIG.ovenTime
		local note
		if fraction < CONFIG.ovenZone[1] then
			making.bad = true
			note = "Trochę surowa... 😕"
		elseif fraction > CONFIG.ovenZone[2] then
			making.bad = true
			note = "Przypalona! 🔥"
		else
			note = "Idealnie upieczona! 😋"
		end
		making.step = "pack"
		send(session, api, note, making.bad)
	elseif step == "pack" and value == "pack" then
		if making.bad then
			state.bad = (state.bad or 0) + 1
		end
		api.give(session)
	end
end

function prep.stop(session)
	session.state.making = nil
end

return DeliveryJob.Create({
	jobId = "pizza",
	site = "Pizzeria",
	pickupPart = "PrepTable",
	parked = "ParkedMoped",
	vehicle = "moped",
	carrier = "PizzaCrate",
	engineSound = "ScooterEngine",
	fx = "pizza",
	package = { name = "PizzaBox", size = Vector3.new(2, 0.5, 2), color = Color3.fromRGB(230, 150, 60), material = Enum.Material.Cardboard },
	pile = { size = Vector3.new(2.5, 1, 2.5), color = Color3.fromRGB(230, 150, 60), material = Enum.Material.Cardboard, hidden = true },
	texts = {
		take = "Zrób pizzę przy stole w kuchni 🍕",
		takeAction = "Zrób pizzę",
		takeObject = "Stół w kuchni",
		takeGuide = "🍕 Zrób pizzę",
		mount = "Wsiądź na skuter przed pizzerią 🛵",
		back = "Wróć pod pizzerię i zaparkuj skuter 🅿️",
		parkFirst = "Najpierw zaparkuj skuter przed pizzerią 🅿️",
		taken = "Ten skuter jest zajęty. Weź inny!",
		mountAction = "Wsiądź na skuter",
		parkAction = "Zaparkuj skuter",
		vehicleObject = "Skuter",
		mountLabel = "🛵 Wsiądź!",
		deliver = "Zanieś pizzę pod dom nr %d (żółty znacznik)",
		deliverAction = "Dostarcz pizzę",
		icon = "🍕",
	},
	prep = prep,
	-- 3 gwiazdki: wszystkie gorące i najwyżej maxBadFor3Stars pizz z błędem
	evaluate = function(session)
		local state = session.state
		return if state.hot >= state.goal and (state.bad or 0) <= CONFIG.maxBadFor3Stars then 3 else 2
	end,
})

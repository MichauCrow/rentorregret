-- Samouczek dla nowego gracza (pierwsze ~3 minuty). Najpierw krótka wycieczka z drona po mieście (klient,
-- CutsceneController.PlayTour), potem kroki: sprzątanie, butelka w parku, kaucjomat, sklep, droga do Biura i start
-- pierwszej zmiany. Postęp liczy serwer; klient pokazuje pasek z poleceniem i przerywaną linię do celu.
-- W krokach 1-2 zegar miesiąca stoi, żeby nowy gracz mógł spokojnie się rozejrzeć.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local ApartmentService = require(Services.ApartmentService)
local CleaningService = require(Services.CleaningService)

local TutorialService = {}

local REWARD = 20
local OFFICE_RADIUS = 16
local PAUSE_UNTIL_STEP = 2 -- zegar stoi w krokach 1..2

-- target: cel (pozycja dla linii przewodnika albo "shop" = przycisk SKLEP), event: zdarzenie zaliczające krok
local STEPS = {
	{ text = "🧹 Twoja Klitka jest zaniedbana! Posprzątaj trzy rzeczy: podejdź i przytrzymaj E.", target = "dirt", event = "cleaned", goal = 3, label = "🧹 Posprzątaj" },
	{ text = "🍾 Czas zarobić na czynsz! Wyjdź z mieszkania i podnieś butelkę w parku po drugiej stronie ulicy.", target = "park", event = "canPicked", goal = 1, label = "🍾 Butelka" },
	{ text = "💰 Zbierz kilka butelek i wrzuć je do kaucjomatu przy ulicy.", target = "skup", event = "cansSold", goal = 1, label = "♻ Kaucjomat" },
	{ text = "🛒 Otwórz SKLEP (przycisk na dole ekranu). Za monety kupisz meble, które poprawiają ocenę mieszkania.", target = "shop", event = "shopOpened", goal = 1 },
	{ text = "🏢 Prace dają więcej monet! Idź do Biura za żółtą linią.", target = "office", goal = 1, label = "🏢 Biuro" },
	{ text = "💼 Naciśnij E przy recepcji i wybierz poziom ŁATWY, żeby zacząć zmianę Sprzątacza.", target = "jobStart", goal = 1, label = "💼 Recepcja" },
}

local progress = {} -- [player] = postęp bieżącego kroku

local function stepOf(data)
	if data.tutorial.done or data.tutorial.step < 1 then
		return nil
	end
	return STEPS[data.tutorial.step]
end

local function targetPosition(player: Player, target: string): Vector3?
	local map = Workspace:FindFirstChild("Map")
	if target == "dirt" then
		local unit = ApartmentService.GetUnit(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local best, bestDistance = nil, math.huge
		if unit then
			for _, dirt in unit.dirtFolder:GetChildren() do
				local distance = if root then (dirt.Position - root.Position).Magnitude else 0
				if distance < bestDistance then
					best, bestDistance = dirt, distance
				end
			end
		end
		return best and best.Position
	elseif target == "park" then
		local cans = Workspace:FindFirstChild("Cans")
		local can = cans and cans:GetChildren()[1]
		return if can then can.Position else map and map.Park.CanArea.Position
	elseif target == "skup" then
		return map and map.Kaucjomat.Counter.SellAttachment.WorldPosition
	elseif target == "office" or target == "jobStart" then
		return map and map.JobSites.Office.StartPart.StartAttachment.WorldPosition
	end
	return nil
end

-- Czy gracz ma trwającą zmianę w pracy (folder sesji w JobObjects)
local function hasShift(player: Player): boolean
	local jobObjects = Workspace:FindFirstChild("JobObjects")
	for _, folder in (if jobObjects then jobObjects:GetChildren() else {}) do
		if folder.Name:sub(1, 8) == "Session_" and folder:GetAttribute("JobOwner") == player.UserId then
			return true
		end
	end
	return false
end

local function finish(player: Player, data, skipped: boolean)
	data.tutorial.done = true
	progress[player] = nil
	if skipped then
		StateService.Notify(player, "Samouczek pominięty. Powodzenia!", "info")
	else
		EconomyService.AddCoins(player, REWARD, "tutorial")
		StateService.Notify(
			player,
			string.format("🎉 Samouczek ukończony! +%d monet. Zarób na czynsz, zanim skończy się czas na zegarze u góry. Co miesiąc odblokujesz nowe prace!", REWARD),
			"good"
		)
	end
	StateService.Push(player)
end

local function advance(player: Player, data)
	data.tutorial.step += 1
	progress[player] = 0
	if data.tutorial.step > #STEPS then
		finish(player, data, false)
	else
		StateService.Push(player)
	end
end

-- Zdarzenia z innych systemów: "cleaned", "canPicked", "cansSold"; od klienta: "shopOpened"
function TutorialService.Event(player: Player, eventName: string)
	local data = DataService.Get(player)
	local step = data and stepOf(data)
	if not step or eventName ~= step.event then
		return
	end
	progress[player] = (progress[player] or 0) + 1
	if progress[player] >= step.goal then
		advance(player, data)
	else
		StateService.Push(player)
	end
end

-- Komenda testowa: samouczek od początku (z wycieczką po mieście)
function TutorialService.Restart(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.tutorial.step = 1
	data.tutorial.done = false
	data.tutorial.introSeen = nil
	progress[player] = 0
	StateService.Push(player)
end

function TutorialService.IsPausingTime(player: Player): boolean
	local data = DataService.Get(player)
	return data ~= nil and not data.tutorial.done and data.tutorial.step >= 1 and data.tutorial.step <= PAUSE_UNTIL_STEP
end

local function onLoaded(player: Player, data)
	if data.tutorial.done then
		return
	end
	-- Samouczek tylko dla zupełnie nowych graczy; starsze konta od razu go omijają
	if data.tutorial.step == 0 then
		if data.month == 1 and data.stats.monthsPaid == 0 and data.stats.totalEarned == 0 then
			data.tutorial.step = 1
		else
			data.tutorial.done = true
			return
		end
	end
	progress[player] = 0
	StateService.Push(player)
end

function TutorialService.Init()
	DataService.OnLoaded(onLoaded)
	CleaningService.OnCleaned(function(owner: Player, cleaner: Player)
		if owner == cleaner then
			TutorialService.Event(cleaner, "cleaned")
		end
	end)
	RemoteService.OnServerEvent(RemoteNames.Events.TutorialAction, 2, function(player, action)
		local data = DataService.Get(player)
		if not data or data.tutorial.done then
			return
		end
		if action == "skip" then
			finish(player, data, true)
		elseif action == "introDone" then
			data.tutorial.introSeen = true
			StateService.Push(player)
		elseif action == "shopOpened" then
			TutorialService.Event(player, "shopOpened")
		end
	end)
	StateService.AddProvider(function(player, snapshot, data)
		local step = stepOf(data)
		if step then
			snapshot.tutorial = {
				step = data.tutorial.step,
				total = #STEPS,
				text = step.text,
				progress = progress[player] or 0,
				goal = step.goal,
				target = step.target,
				label = step.label,
				targetPosition = targetPosition(player, step.target),
				intro = data.tutorial.introSeen ~= true,
			}
		end
	end)
end

function TutorialService.Start()
	Players.PlayerRemoving:Connect(function(player)
		progress[player] = nil
	end)
	-- Krok "office": wystarczy dojść pod Biuro; "jobStart": zmiana się zaczęła.
	-- Co 2 s odświeżamy też cel linii (butelki się zmieniają).
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				local step = data and stepOf(data)
				if step then
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					local position = targetPosition(player, step.target)
					if step.target == "office" and root and position and (root.Position - position).Magnitude <= OFFICE_RADIUS then
						advance(player, data)
					elseif step.target == "jobStart" and hasShift(player) then
						advance(player, data)
					elseif step.target == "park" then
						StateService.Push(player)
					end
				end
			end
		end
	end)
end

return TutorialService

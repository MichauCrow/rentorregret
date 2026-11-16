-- Pan Klucznik: wizyta na koniec miesiąca, czynsz, dogrywka, ostrzeżenia, zastawy i łagodna eksmisja.
-- Pieniądze są pobierane dopiero przy rozliczeniu, więc wyjście z gry w trakcie wizyty niczego nie psuje.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Format = require(ReplicatedStorage.Shared.Modules.Format)
local LandlordBuilder = require(ServerScriptService.World.LandlordBuilder)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local MonthService = require(Services.MonthService)
local ApartmentService = require(Services.ApartmentService)
local ProgressService = require(Services.ProgressService)
local XpService = require(Services.XpService)

local LandlordService = {}

local L = EconomyConfig.Landlord
local MOOD_EMOJI = { happy = "😊", neutral = "😐", grumpy = "😠" }
local GREETINGS = {
	happy = "Witaj, mój ulubiony lokatorze! Czas na czynsz.",
	neutral = "Dzień dobry! Przyszedłem po czynsz.",
	grumpy = "Hmpf. Znowu ty. Płacimy, płacimy!",
}

local visits = {} -- [player] = { phase = "visit"|"overtime"|"settling", due, startedAt, overtimeEnd, npc }

local function moodOf(mood: number): string
	if mood >= L.HAPPY_THRESHOLD then
		return "happy"
	elseif mood <= L.GRUMPY_THRESHOLD then
		return "grumpy"
	end
	return "neutral"
end

local function changeMood(data, delta: number)
	data.landlordMood = math.clamp(data.landlordMood + delta, 0, 100)
end

local function dialog(player: Player, action: string, payload)
	RemoteService.Event(RemoteNames.Events.LandlordDialog):FireClient(player, action, payload)
end

local function spawnNpc(player: Player, data): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	local feet = root.Position - Vector3.new(0, 3, 0)
	local npcPosition = feet + flat.Unit * 6
	local cframe = CFrame.lookAt(npcPosition, Vector3.new(feet.X, npcPosition.Y, feet.Z))
	return LandlordBuilder.Build(cframe, MOOD_EMOJI[moodOf(data.landlordMood)], Workspace)
end

local function removeNpc(visit)
	if visit.npc then
		visit.npc:Destroy()
		visit.npc = nil
	end
end

local function returnPledges(data): number
	local count = #data.pledged
	for _, item in data.pledged do
		table.insert(data.apartment.furniture, item)
	end
	data.pledged = {}
	return count
end

local function takePledge(data)
	local count = #data.apartment.furniture
	if count == 0 then
		return nil
	end
	local item = table.remove(data.apartment.furniture, count)
	table.insert(data.pledged, item)
	return item
end

local function finishVisit(player: Player, advanceMonth: boolean)
	local visit = visits[player]
	if visit then
		removeNpc(visit)
	end
	visits[player] = nil
	dialog(player, "close")
	-- Zastawy mogły się zmienić: odśwież meble i ocenę mieszkania
	ApartmentService.RenderFurniture(player)
	ApartmentService.Recalculate(player)
	if advanceMonth then
		MonthService.AdvanceMonth(player)
	end
	MonthService.Resume(player)
end

local function paidInFull(player: Player, data, onTime: boolean)
	data.debt = 0
	data.warnings = 0
	local returned = returnPledges(data)
	data.stats.monthsPaid += 1
	ProgressService.Record(player, "monthsPaid", 1)
	XpService.Add(player, LevelConfig.XP_RENT + data.month * LevelConfig.XP_RENT_PER_MONTH, "rent")
	if onTime then
		data.stats.onTimeStreak += 1
		changeMood(data, L.PAID_ON_TIME)
	else
		changeMood(data, L.PAID_IN_OVERTIME)
	end
	local message = if onTime
		then "Czynsz zapłacony! Pan Klucznik jest zadowolony."
		else "Udało się w dogrywce! Czynsz zapłacony."
	if returned > 0 then
		message ..= " Zastaw wrócił do mieszkania."
	end
	StateService.Notify(player, message, "good")
	if moodOf(data.landlordMood) == "happy" then
		StateService.Notify(player, "Pan Klucznik jest zachwycony: -10% czynszu w przyszłym miesiącu!", "good")
	end
	finishVisit(player, true)
end

local function evict(player: Player, data)
	returnPledges(data)
	data.month = EconomyConfig.StageStartMonth(data.stage)
	data.stage = EconomyConfig.StageForMonth(data.month)
	data.monthElapsed = 0
	data.debt = 0
	data.warnings = 0
	data.stats.onTimeStreak = 0
	data.landlordMood = L.START_MOOD
	StateService.Notify(
		player,
		string.format("Eksmisja! Wracasz do miesiąca %d. Monety, meble i odblokowane prace zostają.", data.month),
		"bad"
	)
	finishVisit(player, false)
end

-- Koniec dogrywki bez pełnej kwoty: Klucznik bierze, ile jest, reszta to dług
local function failOvertime(player: Player, data, visit)
	local paid = math.min(data.coins, visit.due)
	if paid > 0 then
		EconomyService.TrySpend(player, paid, "rent-partial:" .. data.month)
	end
	data.debt = visit.due - paid
	data.warnings += 1
	data.stats.onTimeStreak = 0
	changeMood(data, L.DEBT_CARRIED)

	if data.warnings >= L.MAX_WARNINGS then
		evict(player, data)
		return
	end

	local message = string.format(
		"Ostrzeżenie %d/%d. Dług %s monet przechodzi na następny miesiąc.",
		data.warnings,
		L.MAX_WARNINGS,
		Format.Number(data.debt)
	)
	local pledged = takePledge(data)
	if pledged then
		message ..= " Pan Klucznik zabrał w zastaw: " .. tostring(pledged.name or pledged.id) .. "."
	end
	if data.warnings >= 2 then
		message ..= " Zimny prysznic: -10% wypłat do spłaty długu."
	end
	StateService.Notify(player, message, "bad")
	finishVisit(player, true)
end

local function settle(player: Player)
	local visit = visits[player]
	local data = DataService.Get(player)
	if not visit or visit.phase ~= "visit" or not data then
		return
	end
	visit.phase = "settling"
	if data.coins >= visit.due then
		if EconomyService.TrySpend(player, visit.due, "rent:" .. data.month) then
			paidInFull(player, data, true)
			return
		end
	end
	-- Za mało monet: dogrywka. Nic jeszcze nie pobieramy.
	visit.phase = "overtime"
	visit.overtimeEnd = os.clock() + GameConfig.OVERTIME_DURATION
	removeNpc(visit)
	dialog(player, "close")
	StateService.Notify(
		player,
		string.format("Brakuje %s monet. Masz 2 minuty dogrywki, żeby dorobić!", Format.Number(visit.due - data.coins)),
		"warn"
	)
	StateService.Push(player)
end

local function startVisit(player: Player)
	local data = DataService.Get(player)
	if visits[player] or not data then
		return
	end
	local rent = EconomyConfig.GetMonthlyDueFor(data, StateService.GetHouseholdSize(player))
	local visit = {
		phase = "visit",
		due = rent + data.debt,
		startedAt = os.clock(),
	}
	visits[player] = visit
	visit.npc = spawnNpc(player, data)
	local mood = moodOf(data.landlordMood)
	dialog(player, "open", {
		emoji = MOOD_EMOJI[mood],
		line = GREETINGS[mood],
		month = data.month,
		rent = rent,
		debt = data.debt,
		due = visit.due,
		coins = data.coins,
		autoPayIn = GameConfig.VISIT_AUTO_PAY,
	})
	StateService.Push(player)
end

local function onPayDebt(player: Player)
	local data = DataService.Get(player)
	if not data or visits[player] or data.debt <= 0 then
		return
	end
	local amount = math.min(data.coins, data.debt)
	if amount <= 0 then
		StateService.Notify(player, "Nie masz monet na spłatę długu.", "warn")
		return
	end
	if not EconomyService.TrySpend(player, amount, "debt") then
		return
	end
	data.debt -= amount
	if data.debt <= 0 then
		data.debt = 0
		data.warnings = 0
		local returned = returnPledges(data)
		local message = "Dług spłacony! Ostrzeżenia usunięte."
		if returned > 0 then
			message ..= " Zastaw wrócił do mieszkania."
		end
		StateService.Notify(player, message, "good")
	else
		StateService.Notify(player, string.format("Spłacono %s. Zostało %s.", Format.Number(amount), Format.Number(data.debt)), "info")
	end
	ApartmentService.RenderFurniture(player)
	ApartmentService.Recalculate(player)
	StateService.Push(player)
end

local function tick()
	local now = os.clock()
	for player, visit in visits do
		local data = DataService.Get(player)
		if data then
			if visit.phase == "visit" and now - visit.startedAt >= GameConfig.VISIT_AUTO_PAY then
				settle(player)
			elseif visit.phase == "overtime" then
				if data.coins >= visit.due then
					visit.phase = "settling"
					if EconomyService.TrySpend(player, visit.due, "rent-overtime:" .. data.month) then
						paidInFull(player, data, false)
					else
						visit.phase = "overtime"
					end
				elseif now >= visit.overtimeEnd then
					visit.phase = "settling"
					failOvertime(player, data, visit)
				end
			end
		end
	end
end

function LandlordService.Init()
	MonthService.OnMonthEnd(startVisit)
	RemoteService.OnServerEvent(RemoteNames.Events.PayRent, 2, settle)
	RemoteService.OnServerEvent(RemoteNames.Events.PayDebt, 2, onPayDebt)
	StateService.AddProvider(function(player, snapshot)
		local visit = visits[player]
		if not visit then
			snapshot.phase = "month"
			return
		end
		snapshot.due = visit.due
		if visit.phase == "overtime" then
			snapshot.phase = "overtime"
			snapshot.overtimeRemaining = math.max(0, visit.overtimeEnd - os.clock())
		else
			snapshot.phase = "visit"
		end
	end)
end

function LandlordService.Start()
	Players.PlayerRemoving:Connect(function(player)
		local visit = visits[player]
		if visit then
			removeNpc(visit)
			visits[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
end

return LandlordService

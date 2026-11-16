-- Zegar miesiąca. Liczy czas tylko wtedy, gdy gracz jest w grze (bez kar za nieobecność).
-- Na koniec miesiąca zatrzymuje zegar i woła OnMonthEnd (wizyta właściciela).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local Format = require(ReplicatedStorage.Shared.Modules.Format)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local ApartmentService = require(Services.ApartmentService)
local TutorialService = require(Services.TutorialService)

local MonthService = {}

local RESYNC_INTERVAL = 15 -- co tyle sekund klient dostaje poprawiony czas

local paused = {} -- [player] = true, gdy zegar stoi (wizyta, dogrywka)
local monthEndCallbacks = {}

-- callback(player) gdy miesiąc się skończył
function MonthService.OnMonthEnd(callback)
	table.insert(monthEndCallbacks, callback)
end

function MonthService.IsRunning(player: Player): boolean
	return not paused[player]
end

function MonthService.Pause(player: Player)
	paused[player] = true
	StateService.Push(player)
end

function MonthService.Resume(player: Player)
	paused[player] = nil
	StateService.Push(player)
end

-- Przesuwa zegar do przodu (komendy testowe)
function MonthService.Skip(player: Player, seconds: number)
	local data = DataService.Get(player)
	if not data or paused[player] then
		return
	end
	data.monthElapsed = math.min(GameConfig.MONTH_DURATION - 1, data.monthElapsed + seconds)
	StateService.Push(player)
end

-- Rozpoczyna kolejny miesiąc (woła LandlordService po rozliczeniu czynszu)
function MonthService.AdvanceMonth(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.month += 1
	data.monthElapsed = 0
	local previousHighest = data.highestMonth
	data.highestMonth = math.max(data.highestMonth, data.month)
	-- Pierwszy raz w tym miesiącu: klient pokazuje cut scenę z drona nad każdym nowo odblokowanym miejscem pracy
	if data.highestMonth > previousHighest then
		local unlocked = {}
		for _, jobId in JobsConfig.Order do
			local job = JobsConfig.Jobs[jobId]
			if job.implemented and job.site and job.unlockMonth > previousHighest and job.unlockMonth <= data.highestMonth then
				table.insert(unlocked, jobId)
			end
		end
		if #unlocked > 0 then
			RemoteService.Event(RemoteNames.Events.JobUnlocked):FireClient(player, unlocked)
		end
	end
	data.stage = EconomyConfig.StageForMonth(data.month)
	ApartmentService.CheckUpgrade(player) -- nowy etap = przeprowadzka do lepszego mieszkania
	data.monthly.helperCoins = 0
	data.monthly.rareOffered = 0
	data.monthly.failures = 0
	data.monthly.events = 0
	local due = EconomyConfig.GetMonthlyDueFor(data, StateService.GetHouseholdSize(player)) + data.debt
	StateService.Notify(player, string.format("Miesiąc %d się zaczyna! Do zapłaty: %s", data.month, Format.Number(due)), "info")
end

local function onLoaded(player: Player, data)
	if data.month == 1 and data.stats.monthsPaid == 0 then
		StateService.Notify(player, "Cel: zarób na czynsz do końca miesiąca. Butelki kaucyjne znajdziesz w parku naprzeciwko!", "info")
	end
end

local function tick(counter: number)
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data and not paused[player] and not TutorialService.IsPausingTime(player) then
			data.monthElapsed += 1
			if data.monthElapsed >= GameConfig.MONTH_DURATION then
				data.monthElapsed = GameConfig.MONTH_DURATION
				paused[player] = true
				for _, callback in monthEndCallbacks do
					task.spawn(callback, player)
				end
			elseif counter % RESYNC_INTERVAL == 0 then
				StateService.Push(player)
			end
		end
	end
end

function MonthService.Init()
	StateService.AddProvider(function(player, snapshot)
		snapshot.timerRunning = not paused[player] and not TutorialService.IsPausingTime(player)
	end)
	DataService.OnLoaded(onLoaded)
end

function MonthService.Start()
	Players.PlayerRemoving:Connect(function(player)
		paused[player] = nil
	end)
	task.spawn(function()
		local counter = 0
		while true do
			task.wait(1)
			counter += 1
			tick(counter)
		end
	end)
end

return MonthService

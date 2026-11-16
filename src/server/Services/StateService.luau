-- Buduje widok stanu gracza dla klienta i wysyła go po każdej zmianie.
-- Klient dostaje tylko kopię do wyświetlenia, nigdy nie decyduje o wartościach.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local ApartmentConfig = require(ReplicatedStorage.Shared.Config.ApartmentConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)

local StateService = {}

-- Inne serwisy dokładają swoje pola do widoku przez AddProvider (bez cyklicznych require)
local providers = {}

-- Liczba osób w mieszkaniu gracza (ustawia RoommateService); wpływa na zniżkę czynszu
local householdSizeGetter = function(_player: Player): number
	return 1
end

function StateService.SetHouseholdSizeGetter(getter)
	householdSizeGetter = getter
end

function StateService.GetHouseholdSize(player: Player): number
	return householdSizeGetter(player)
end

function StateService.AddProvider(provider)
	table.insert(providers, provider)
end

function StateService.BuildSnapshot(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local snapshot = {
		coins = data.coins,
		tokens = data.tokens,
		month = data.month,
		monthElapsed = data.monthElapsed,
		monthDuration = GameConfig.MONTH_DURATION,
		due = EconomyConfig.GetMonthlyDueFor(data, householdSizeGetter(player)) + data.debt,
		householdSize = householdSizeGetter(player),
		debt = data.debt,
		warnings = data.warnings,
		landlordMood = data.landlordMood,
		apartmentStars = ApartmentConfig.StarsForScore(data.apartment.score),
		apartmentScore = data.apartment.score,
		cleanliness = data.apartment.cleanliness,
		dirtCount = #data.apartment.dirt,
	}
	for _, provider in providers do
		local ok, err = pcall(provider, player, snapshot, data)
		if not ok then
			warn("[StateService] Błąd dostawcy stanu: " .. tostring(err))
		end
	end
	return snapshot
end

function StateService.Push(player: Player)
	local snapshot = StateService.BuildSnapshot(player)
	if snapshot then
		RemoteService.Event(RemoteNames.Events.StateUpdate):FireClient(player, snapshot)
	end
end

-- kind: "info", "good", "warn", "bad"
function StateService.Notify(player: Player, text: string, kind: string?)
	RemoteService.Event(RemoteNames.Events.Notify):FireClient(player, text, kind or "info")
end

function StateService.Init()
	RemoteService.OnServerInvoke(RemoteNames.Functions.GetState, 5, function(player)
		return StateService.BuildSnapshot(player)
	end)
	DataService.OnLoaded(function(player)
		StateService.Push(player)
	end)
end

return StateService

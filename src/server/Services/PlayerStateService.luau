-- Zapisany stan gracza dla klienta (monety, ulepszenia, ustawienia, statystyki) i krótkie komunikaty.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local DataService = require(script.Parent.DataService)
local RemoteService = require(script.Parent.RemoteService)

local PlayerStateService = {}

local SETTINGS = {
	jumpscares = function(value)
		return type(value) == "boolean"
	end,
	sound = function(value)
		return RemoteService.IsInteger(value, 1, 3)
	end,
}

-- Wartość ulepszenia na obecnym poziomie gracza (np. pojemność kieszeni)
function PlayerStateService.UpgradeValue(player: Player, id: string)
	local upgrade = ShopConfig.Upgrades[id]
	local data = DataService.Get(player)
	local level = if data then data.upgrades[id] or 1 else 1
	level = math.clamp(level, 1, #upgrade.levels)
	return upgrade.levels[level].value
end

function PlayerStateService.Snapshot(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	return {
		coins = data.coins,
		upgrades = table.clone(data.upgrades),
		settings = table.clone(data.settings),
		stats = table.clone(data.stats),
		tutorialDone = data.tutorialDone,
	}
end

function PlayerStateService.Push(player: Player)
	local snapshot = PlayerStateService.Snapshot(player)
	if snapshot then
		RemoteService.Event("StateUpdate"):FireClient(player, snapshot)
	end
end

function PlayerStateService.Notify(player: Player, text: string, kind: string?)
	RemoteService.Event("Notify"):FireClient(player, text, kind or "info")
end

function PlayerStateService.AddCoins(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.coins += math.floor(amount)
end

function PlayerStateService.Init() end

function PlayerStateService.Start()
	DataService.OnLoaded(function(player)
		PlayerStateService.Push(player)
	end)

	RemoteService.OnServerInvoke("GetState", 2, function(player)
		return PlayerStateService.Snapshot(player)
	end)

	RemoteService.OnServerEvent("SetSetting", 4, function(player, key, value)
		local data = DataService.Get(player)
		local valid = SETTINGS[key]
		if not data or not valid or not valid(value) then
			return
		end
		data.settings[key] = value
		PlayerStateService.Push(player)
	end)
end

return PlayerStateService

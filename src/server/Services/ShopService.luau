-- Sklepik w holu: kupowanie kolejnych poziomów ulepszeń za monety.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local DataService = require(script.Parent.DataService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local ShopService = {}

local function buy(player: Player, id: any)
	local data = DataService.Get(player)
	if not data then
		return { ok = false, message = "Dane jeszcze się wczytują." }
	end
	if type(id) ~= "string" or not ShopConfig.Upgrades[id] then
		return { ok = false, message = "Nie ma takiego ulepszenia." }
	end
	local upgrade = ShopConfig.Upgrades[id]
	local level = data.upgrades[id] or 1
	local nextLevel = upgrade.levels[level + 1]
	if not nextLevel then
		return { ok = false, message = "To już najwyższy poziom!" }
	end
	if data.coins < nextLevel.cost then
		return { ok = false, message = "Brakuje Ci monet." }
	end
	data.coins -= nextLevel.cost
	data.upgrades[id] = level + 1
	PlayerStateService.Push(player)
	return { ok = true, message = upgrade.icon .. " " .. upgrade.name .. ": poziom " .. (level + 1) .. "!" }
end

function ShopService.Init() end

function ShopService.Start()
	RemoteService.OnServerInvoke("BuyUpgrade", 3, function(player, id)
		local result = buy(player, id)
		result.state = PlayerStateService.Snapshot(player)
		return result
	end)
end

return ShopService

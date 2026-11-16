-- Jedyne miejsce w grze, które zmienia liczbę monet.
-- Każda zmiana ma przyczynę (reason), co ułatwia szukanie błędów i nadużyć.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Services = ServerScriptService.Services
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)

local EconomyService = {}

local LOG = RunService:IsStudio() and GameConfig.LOG_TRANSACTIONS_IN_STUDIO
local earnedCallbacks = {}

-- callback(player, kwota, powód) po każdym dodaniu monet (zadania i rankingi)
function EconomyService.OnEarned(callback)
	table.insert(earnedCallbacks, callback)
end

local function isValidAmount(amount: any): boolean
	return type(amount) == "number"
		and amount == amount
		and amount > 0
		and amount <= EconomyConfig.MAX_TRANSACTION
		and math.floor(amount) == amount
end

local function log(player: Player, change: string, reason: string, balance: number)
	if LOG then
		print(string.format("[Economy] %s %s (%s) -> saldo %d", player.Name, change, reason, balance))
	end
end

function EconomyService.GetCoins(player: Player): number
	local data = DataService.Get(player)
	return if data then data.coins else 0
end

function EconomyService.CanAfford(player: Player, amount: number): boolean
	return isValidAmount(amount) and EconomyService.GetCoins(player) >= amount
end

function EconomyService.AddCoins(player: Player, amount: number, reason: string): boolean
	if not isValidAmount(amount) or type(reason) ~= "string" then
		warn("[Economy] Odrzucono AddCoins: " .. tostring(amount) .. " (" .. tostring(reason) .. ")")
		return false
	end
	local data = DataService.Get(player)
	if not data then
		return false
	end
	data.coins += amount
	if reason ~= "debug" then
		data.stats.totalEarned += amount
	end
	log(player, "+" .. amount, reason, data.coins)
	StateService.Push(player)
	for _, callback in earnedCallbacks do
		task.spawn(callback, player, amount, reason)
	end
	return true
end

-- Zwraca true tylko wtedy, gdy gracz miał wystarczająco monet i zostały pobrane
function EconomyService.TrySpend(player: Player, amount: number, reason: string): boolean
	if not isValidAmount(amount) or type(reason) ~= "string" then
		warn("[Economy] Odrzucono TrySpend: " .. tostring(amount) .. " (" .. tostring(reason) .. ")")
		return false
	end
	local data = DataService.Get(player)
	if not data or data.coins < amount then
		return false
	end
	data.coins -= amount
	log(player, "-" .. amount, reason, data.coins)
	StateService.Push(player)
	return true
end

return EconomyService

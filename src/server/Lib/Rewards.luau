-- Wspólne przyznawanie nagród (prezenty za czas gry, kody): monety, klucze, XP i obroty Kołem nagród.
-- Nagroda: { kind = "coins" | "tokens" | "xp" | "spin", amount = liczba } albo dla monet { factor, min }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local Format = require(ReplicatedStorage.Shared.Modules.Format)
local Services = ServerScriptService.Services
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local XpService = require(Services.XpService)

local Rewards = {}

-- Ile dokładnie dostanie gracz (monety rosną razem z czynszem)
function Rewards.Value(data, reward): number
	if reward.kind == "coins" and reward.factor then
		return math.max(reward.min or 1, math.floor(EconomyConfig.GetDue(data.month) * reward.factor + 0.5))
	end
	return reward.amount or 0
end

-- Krótki napis do okna (np. "+25 💰")
function Rewards.Short(kind: string, value: number): string
	if kind == "coins" then
		return "+" .. Format.Number(value) .. " 💰"
	elseif kind == "tokens" then
		return "+" .. value .. " 🔑"
	elseif kind == "spin" then
		return "+" .. value .. " 🎡"
	end
	return "+" .. value .. " XP"
end

-- Dłuższy napis do komunikatu (np. "+3 klucze")
function Rewards.Long(kind: string, value: number): string
	if kind == "coins" then
		return "+" .. Format.Number(value) .. " " .. Format.Plural(value, "moneta", "monety", "monet")
	elseif kind == "tokens" then
		return "+" .. value .. " " .. Format.Plural(value, "klucz", "klucze", "kluczy")
	elseif kind == "spin" then
		return "+" .. value .. " " .. Format.Plural(value, "obrót kołem", "obroty kołem", "obrotów kołem")
	end
	return "+" .. value .. " XP"
end

-- Przyznaje nagrodę i zwraca jej długi napis (albo nil, gdy dane gracza nie są wczytane)
function Rewards.Grant(player: Player, reward, reason: string): string?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local value = Rewards.Value(data, reward)
	if value <= 0 then
		return nil
	end
	if reward.kind == "coins" then
		EconomyService.AddCoins(player, value, reason)
	elseif reward.kind == "tokens" then
		data.tokens += value
		StateService.Push(player)
	elseif reward.kind == "spin" then
		data.wheel.bonus = math.min(LevelConfig.Wheel.maxBonus, data.wheel.bonus + value)
		StateService.Push(player)
	else
		XpService.Add(player, value, reason)
	end
	return Rewards.Long(reward.kind, value)
end

return Rewards

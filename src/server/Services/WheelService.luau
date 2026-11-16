-- Koło nagród: darmowy obrót raz dziennie i po jednym za każdy nowy poziom (XpService).
-- Nie da się go kupić. Serwer losuje nagrodę, zabiera obrót od razu, a nagrodę daje po animacji
-- (albo przy wyjściu z gry, jeśli gracz wyjdzie w trakcie kręcenia).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local ProgressConfig = require(ReplicatedStorage.Shared.Config.ProgressConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Format = require(ReplicatedStorage.Shared.Modules.Format)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local XpService = require(Services.XpService)

local WheelService = {}

local WHEEL = LevelConfig.Wheel
local SECONDS_PER_DAY = 86400

local rng = Random.new()
local pending = {} -- [player] = { prize, value }, nagroda czekająca na koniec animacji

local function freeAvailable(data): boolean
	return data.wheel.day < ProgressConfig.Today()
end

local function spinsOf(data): number
	return (if freeAvailable(data) then 1 else 0) + data.wheel.bonus
end

-- Wartość nagrody dla gracza (monety rosną razem z czynszem)
local function valueOf(data, prize): number
	if prize.kind == "coins" then
		return math.max(prize.min, math.floor(EconomyConfig.GetDue(data.month) * prize.factor + 0.5))
	end
	return prize.amount
end

local function labelOf(prize, value: number): string
	if prize.kind == "coins" then
		return "+" .. Format.Number(value) .. " " .. Format.Plural(value, "moneta", "monety", "monet")
	elseif prize.kind == "tokens" then
		return "+" .. value .. " " .. Format.Plural(value, "klucz", "klucze", "kluczy")
	end
	return "+" .. value .. " XP"
end

local function build(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local prizes = {}
	for index, prize in WHEEL.prizes do
		prizes[index] = { kind = prize.kind, value = valueOf(data, prize) }
	end
	return {
		prizes = prizes,
		spins = spinsOf(data),
		free = freeAvailable(data),
		bonus = data.wheel.bonus,
		nextFreeIn = SECONDS_PER_DAY - os.time() % SECONDS_PER_DAY,
		spinTime = WHEEL.spinTime,
		busy = pending[player] ~= nil,
	}
end

local function pick(): number
	local total = 0
	for _, prize in WHEEL.prizes do
		total += prize.weight
	end
	local roll = rng:NextNumber() * total
	for index, prize in WHEEL.prizes do
		roll -= prize.weight
		if roll <= 0 then
			return index
		end
	end
	return 1
end

local function grant(player: Player)
	local reward = pending[player]
	pending[player] = nil
	local data = reward and DataService.Get(player)
	if not data then
		return
	end
	local prize = reward.prize
	if prize.kind == "coins" then
		EconomyService.AddCoins(player, reward.value, "wheel")
	elseif prize.kind == "tokens" then
		data.tokens += reward.value
		StateService.Push(player)
	else
		XpService.Add(player, reward.value, "wheel")
	end
	data.wheel.total += 1
end

local function spin(player: Player)
	local data = DataService.Get(player)
	if not data then
		return { ok = false, message = "Chwila, wczytuję dane..." }
	end
	if pending[player] then
		return { ok = false, message = "Koło już się kręci!" }
	end
	if spinsOf(data) <= 0 then
		return { ok = false, message = "Brak obrotów. Wróć jutro albo zdobądź nowy poziom!" }
	end
	if freeAvailable(data) then
		data.wheel.day = ProgressConfig.Today()
	else
		data.wheel.bonus -= 1
	end
	local index = pick()
	local prize = WHEEL.prizes[index]
	local value = valueOf(data, prize)
	pending[player] = { prize = prize, value = value }
	task.delay(WHEEL.spinTime, function()
		if pending[player] and pending[player].prize == prize then
			grant(player)
		end
	end)
	StateService.Push(player)
	return { ok = true, index = index, label = labelOf(prize, value), state = build(player) }
end

function WheelService.Init()
	RemoteService.OnServerInvoke(RemoteNames.Functions.Wheel, 2, function(player, action)
		if action == "spin" then
			return spin(player)
		end
		return build(player)
	end)
	StateService.AddProvider(function(_player, snapshot, data)
		snapshot.wheelSpins = spinsOf(data)
	end)
	-- Wyjście w trakcie kręcenia: nagroda trafia prosto do danych przed zapisem
	-- (XP bez animacji; nowy poziom przyjdzie przy następnym zdobytym XP)
	DataService.OnBeforeRelease(function(player, data)
		local reward = pending[player]
		if not reward or not data then
			return
		end
		pending[player] = nil
		local kind = reward.prize.kind
		if kind == "coins" then
			data.coins += reward.value
		elseif kind == "tokens" then
			data.tokens += reward.value
		else
			data.xp += reward.value
		end
		data.wheel.total += 1
	end)
	DataService.OnLoaded(function(player, data)
		if spinsOf(data) > 0 then
			task.delay(9, function()
				if player.Parent then
					StateService.Notify(player, "🎡 Darmowy obrót kołem nagród czeka! Kliknij 🎡 KOŁO.", "info")
				end
			end)
		end
	end)
end

function WheelService.Start()
	Players.PlayerRemoving:Connect(function(player)
		-- OnBeforeRelease już przyznał nagrodę; tu tylko sprzątamy
		task.delay(5, function()
			pending[player] = nil
		end)
	end)
end

-- Komenda testowa: dodatkowy obrót
function WheelService.DebugAddSpin(player: Player)
	local data = DataService.Get(player)
	if data then
		data.wheel.bonus = math.min(WHEEL.maxBonus, data.wheel.bonus + 1)
		StateService.Push(player)
	end
end

return WheelService

-- Prezenty za czas gry: serwer liczy, ile gracz gra danego dnia (po ponownym wejściu czas się nie zeruje),
-- i odblokowuje 8 prezentów (2, 5, 10 ... 60 minut). Nagrody są stałe i widoczne z góry, bez losowania.
-- Odebrane prezenty to bity w data.playtime.claimed (DataStore nie lubi dziurawych tablic).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local ProgressConfig = require(ReplicatedStorage.Shared.Config.ProgressConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Rewards = require(ServerScriptService.Lib.Rewards)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)

local GiftService = {}

local GIFTS = RewardsConfig.Gifts
local MAX_STEP = 2 -- najwięcej sekund doliczanych naraz (po zacięciu serwera)

local function ensureDay(data)
	local today = ProgressConfig.Today()
	if data.playtime.day ~= today then
		data.playtime.day = today
		data.playtime.seconds = 0
		data.playtime.claimed = 0
	end
end

local function isClaimed(data, index: number): boolean
	return bit32.band(data.playtime.claimed, bit32.lshift(1, index - 1)) ~= 0
end

local function isUnlocked(data, index: number): boolean
	return data.playtime.seconds >= GIFTS[index].minutes * 60
end

local function readyCount(data): number
	local count = 0
	for index in GIFTS do
		if isUnlocked(data, index) and not isClaimed(data, index) then
			count += 1
		end
	end
	return count
end

-- Sekundy do następnego prezentu (nil, gdy wszystkie są już odblokowane)
local function nextIn(data): number?
	for _, gift in GIFTS do
		local left = gift.minutes * 60 - data.playtime.seconds
		if left > 0 then
			return left
		end
	end
	return nil
end

local function build(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	ensureDay(data)
	local gifts = {}
	for index, gift in GIFTS do
		local value = Rewards.Value(data, gift)
		gifts[index] = {
			minutes = gift.minutes,
			kind = gift.kind,
			label = Rewards.Short(gift.kind, value),
			state = if isClaimed(data, index) then "claimed" elseif isUnlocked(data, index) then "ready" else "locked",
			unlockIn = math.max(0, gift.minutes * 60 - data.playtime.seconds),
		}
	end
	return { gifts = gifts, seconds = data.playtime.seconds }
end

local function claimOne(player: Player, data, index: number): string?
	if not isUnlocked(data, index) or isClaimed(data, index) then
		return nil
	end
	data.playtime.claimed = bit32.bor(data.playtime.claimed, bit32.lshift(1, index - 1))
	return Rewards.Grant(player, GIFTS[index], "gift:" .. index)
end

local function handle(player: Player, action: any, index: any)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	ensureDay(data)
	if action == "claim" then
		if not RemoteService.IsInteger(index, 1, #GIFTS) then
			return nil
		end
		local label = claimOne(player, data, index)
		return { ok = label ~= nil, claimed = if label then { { index = index, label = label } } else {}, state = build(player) }
	elseif action == "claimAll" then
		local claimed = {}
		for giftIndex in GIFTS do
			local label = claimOne(player, data, giftIndex)
			if label then
				table.insert(claimed, { index = giftIndex, label = label })
			end
		end
		return { ok = #claimed > 0, claimed = claimed, state = build(player) }
	end
	return build(player)
end

local function tick(dt: number)
	local step = math.min(dt, MAX_STEP)
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data then
			ensureDay(data)
			local before = readyCount(data)
			data.playtime.seconds += step
			if readyCount(data) > before then
				StateService.Notify(player, "🎁 Nowy prezent za grę czeka! Kliknij 🎁, żeby go otworzyć.", "good")
				StateService.Push(player)
			end
		end
	end
end

-- Komenda testowa: przesuwa czas gry do przodu
function GiftService.DebugAddTime(player: Player, seconds: number)
	local data = DataService.Get(player)
	if data then
		ensureDay(data)
		data.playtime.seconds += seconds
		StateService.Push(player)
	end
end

-- Komenda testowa: prezenty od nowa
function GiftService.DebugReset(player: Player)
	local data = DataService.Get(player)
	if data then
		data.playtime.day = 0
		ensureDay(data)
		StateService.Push(player)
	end
end

function GiftService.Init()
	RemoteService.OnServerInvoke(RemoteNames.Functions.Gifts, 4, handle)
	StateService.AddProvider(function(_player, snapshot, data)
		ensureDay(data)
		snapshot.giftReady = readyCount(data)
		snapshot.giftNextIn = nextIn(data)
	end)
end

function GiftService.Start()
	task.spawn(function()
		while true do
			tick(task.wait(1))
		end
	end)
end

return GiftService

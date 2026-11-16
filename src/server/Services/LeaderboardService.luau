-- Rankingi tygodniowe (OrderedDataStore z numerem tygodnia w nazwie, więc co tydzień startują od zera).
-- Wartości pochodzą z data.weekly.stats; wysyłka i pobieranie co LEADERBOARD_REFRESH sekund.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ProgressConfig = require(ReplicatedStorage.Shared.Config.ProgressConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local ProgressService = require(Services.ProgressService)

local LeaderboardService = {}

local FIRST_REFRESH_DELAY = 10
-- Wyniki z testów w Studio nie trafiają do rankingu prawdziwych graczy
local PREFIX = if RunService:IsStudio() then GameConfig.LEADERBOARD_PREFIX_STUDIO else GameConfig.LEADERBOARD_PREFIX_LIVE

local boards = {} -- [boardId] = { { rank, name, value } }
local uploaded = {} -- [player] = { [boardId] = ostatnio wysłana wartość }
local names = {} -- [userId] = nazwa
local available = true

local function storeFor(boardId: string, week: number)
	return DataStoreService:GetOrderedDataStore(PREFIX .. boardId .. "_W" .. week)
end

local function upload(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	ProgressService.EnsurePeriods(player)
	uploaded[player] = uploaded[player] or {}
	for _, board in ProgressConfig.Leaderboards do
		local value = math.floor(tonumber(data.weekly.stats[board.stat]) or 0)
		if value > 0 and uploaded[player][board.id] ~= value then
			local ok, err = pcall(function()
				storeFor(board.id, data.weekly.week):SetAsync(tostring(player.UserId), value)
			end)
			if ok then
				uploaded[player][board.id] = value
			else
				warn("[LeaderboardService] Wysyłka nieudana: " .. tostring(err))
			end
		end
	end
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		names[userId] = online.DisplayName
	elseif userId <= 0 then
		names[userId] = "Gracz testowy"
	else
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		names[userId] = if ok then name else "Gracz"
	end
	return names[userId]
end

local function refresh()
	local week = ProgressConfig.WeekOf(ProgressConfig.Today())
	for _, board in ProgressConfig.Leaderboards do
		local ok, result = pcall(function()
			return storeFor(board.id, week):GetSortedAsync(false, ProgressConfig.LEADERBOARD_SIZE):GetCurrentPage()
		end)
		if ok then
			available = true
			local entries = {}
			for rank, entry in result do
				table.insert(entries, { rank = rank, name = nameOf(tonumber(entry.key) or 0), value = entry.value })
			end
			boards[board.id] = entries
		else
			available = false
			warn("[LeaderboardService] Pobieranie nieudane: " .. tostring(result))
		end
	end
end

local function cycle()
	for _, player in Players:GetPlayers() do
		upload(player)
	end
	refresh()
end

local function build(player: Player)
	local data = DataService.Get(player)
	local list = {}
	for _, board in ProgressConfig.Leaderboards do
		table.insert(list, {
			id = board.id,
			name = board.name,
			entries = boards[board.id] or {},
			yours = if data then math.floor(tonumber(data.weekly.stats[board.stat]) or 0) else 0,
		})
	end
	return { boards = list, available = available, refreshSeconds = ProgressConfig.LEADERBOARD_REFRESH }
end

-- Tylko do testów w Studio: wyślij i pobierz od razu
function LeaderboardService.DebugRefresh()
	task.spawn(cycle)
end

function LeaderboardService.Init()
	RemoteService.OnServerInvoke(RemoteNames.Functions.GetLeaderboard, 2, build)
end

function LeaderboardService.Start()
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(upload, player)
		uploaded[player] = nil
	end)
	task.spawn(function()
		task.wait(FIRST_REFRESH_DELAY)
		while true do
			cycle()
			task.wait(ProgressConfig.LEADERBOARD_REFRESH)
		end
	end)
end

return LeaderboardService

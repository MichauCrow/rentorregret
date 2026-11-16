-- Osiągnięcia (Klucze Lokatora i rzadkie meble) oraz sekretne złote krasnale w mieście.
-- Warunki są sprawdzane na serwerze co kilka sekund na podstawie zapisanych statystyk gracza.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ProgressConfig = require(ReplicatedStorage.Shared.Config.ProgressConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Format = require(ReplicatedStorage.Shared.Modules.Format)
local PropBuilder = require(ServerScriptService.World.PropBuilder)
local HoldPrompt = require(ServerScriptService.Lib.HoldPrompt)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local ApartmentService = require(Services.ApartmentService)

local AchievementService = {}

local CHECK_INTERVAL = 3
local GNOME_HOLD = 0.5

local function gnomeKey(index: number): string
	return "gnome" .. index
end

local function countGnomes(data): number
	local count = 0
	for index in ProgressConfig.Gnomes do
		if data.secrets[gnomeKey(index)] then
			count += 1
		end
	end
	return count
end

local function progressOf(data, achievement): number
	if achievement.stat then
		return tonumber(data.stats[achievement.stat]) or 0
	elseif achievement.special == "furniture" then
		return #data.apartment.furniture
	elseif achievement.special == "allJobs" then
		local count = 0
		for jobId, definition in JobsConfig.Jobs do
			local progress = data.jobs[jobId]
			if definition.site and type(progress) == "table" and (progress.threeStarCount or 0) >= 1 then
				count += 1
			end
		end
		return count
	elseif achievement.special == "secret" then
		return if data.secrets[achievement.secret] then 1 else 0
	elseif achievement.special == "gnomes" then
		return countGnomes(data)
	end
	return 0
end

local function pushProgress(player: Player)
	RemoteService.Event(RemoteNames.Events.ProgressUpdate):FireClient(player)
end

-- Dodaje rzadki mebel do mieszkania (używa też kalendarz w ProgressService)
function AchievementService.GrantFurniture(player: Player, data, itemId: string)
	local item = ShopConfig.Items[itemId]
	if not item then
		return
	end
	table.insert(data.apartment.furniture, { id = itemId, name = item.name })
	ApartmentService.RenderFurniture(player)
	ApartmentService.Recalculate(player)
end

function AchievementService.OwnsFurniture(data, itemId: string): boolean
	for _, owned in data.apartment.furniture do
		if type(owned) == "table" and owned.id == itemId then
			return true
		end
	end
	for _, pledged in data.pledged do
		if type(pledged) == "table" and pledged.id == itemId then
			return true
		end
	end
	return false
end

function AchievementService.Check(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local changed = false
	for _, achievement in ProgressConfig.Achievements do
		if not data.achievements[achievement.id] and progressOf(data, achievement) >= achievement.target then
			data.achievements[achievement.id] = os.time()
			data.tokens += achievement.tokens
			local message = string.format(
				"🏅 Osiągnięcie: %s! +%d %s",
				achievement.name,
				achievement.tokens,
				Format.Plural(achievement.tokens, "klucz", "klucze", "kluczy")
			)
			if achievement.reward and not AchievementService.OwnsFurniture(data, achievement.reward) then
				AchievementService.GrantFurniture(player, data, achievement.reward)
				message ..= " i rzadki mebel: " .. ShopConfig.Items[achievement.reward].name
			end
			StateService.Notify(player, message, "good")
			changed = true
		end
	end
	if changed then
		StateService.Push(player)
		pushProgress(player)
	end
end

-- Lista do panelu "Zadania"
function AchievementService.BuildList(player: Player)
	local data = DataService.Get(player)
	local list = {}
	if not data then
		return list
	end
	for _, achievement in ProgressConfig.Achievements do
		local reward = string.format("+%d %s", achievement.tokens, Format.Plural(achievement.tokens, "klucz", "klucze", "kluczy"))
		if achievement.reward then
			reward ..= " + " .. ShopConfig.Items[achievement.reward].emoji .. " " .. ShopConfig.Items[achievement.reward].name
		end
		table.insert(list, {
			name = achievement.name,
			description = achievement.description,
			unlocked = data.achievements[achievement.id] ~= nil,
			progress = math.min(progressOf(data, achievement), achievement.target),
			target = achievement.target,
			reward = reward,
		})
	end
	return list
end

local function collectGnome(player: Player, index: number)
	local data = DataService.Get(player)
	if not data or data.secrets[gnomeKey(index)] then
		return
	end
	data.secrets[gnomeKey(index)] = true
	local found = countGnomes(data)
	StateService.Notify(player, string.format("🧙 Złoty krasnal %d/%d!", found, #ProgressConfig.Gnomes), "good")
	StateService.Push(player)
	AchievementService.Check(player)
end

local function buildGnomes()
	local folder = Instance.new("Folder")
	folder.Name = "Gnomes"
	for index, position in ProgressConfig.Gnomes do
		local gnome = PropBuilder.Gnome(position)
		gnome:SetAttribute("GnomeIndex", index)
		HoldPrompt.Create(gnome.PrimaryPart, { action = "Zabierz", object = "Złoty krasnal", hold = GNOME_HOLD, activation = 8, maxDistance = 12 }, function(player)
			collectGnome(player, index)
		end)
		gnome.Parent = folder
	end
	folder.Parent = Workspace:WaitForChild("Map")
end

function AchievementService.Init()
	buildGnomes()
	-- Klient ukrywa krasnale, które gracz już znalazł
	StateService.AddProvider(function(_player, snapshot, data)
		local found = {}
		for index in ProgressConfig.Gnomes do
			if data.secrets[gnomeKey(index)] then
				table.insert(found, index)
			end
		end
		snapshot.gnomes = found
	end)
end

function AchievementService.Start()
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(AchievementService.Check, player)
				if not ok then
					warn("[AchievementService] " .. tostring(err))
				end
			end
		end
	end)
end

return AchievementService

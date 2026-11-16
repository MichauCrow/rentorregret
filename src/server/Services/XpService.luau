-- Poziomy gracza: XP za pracę, sprzątanie, czynsz i zadania. Nowy poziom = monety, darmowy obrót kołem,
-- co 5 poziomów klucze, efekt widoczny dla wszystkich i plakietka z poziomem nad głową.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local CleaningService = require(Services.CleaningService)
local JobService = require(Services.JobService)
local GoldenHourService = require(Services.GoldenHourService)

local XpService = {}

-- Zarobki, które dają XP (wypłata za zmianę liczy się osobno, razem z gwiazdkami)
local WORK_PREFIXES = { "job:", "rare:", "help:", "trashbin", "inspection", "raccoon" }
local SHIFT_REASON = "^job:[%w_]+:%dstar$"
local TAG_COLOR = Color3.fromRGB(255, 215, 60)

local levelUpCallbacks = {}

local function need(level: number): number
	return LevelConfig.Need(level)
end

local function startsWithAny(text: string, prefixes): boolean
	for _, prefix in prefixes do
		if string.sub(text, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function rankLabel(level: number): string
	local rank = LevelConfig.RankFor(level)
	return rank.emoji .. " " .. rank.name
end

-- Poziom w liście graczy (prawy górny róg)
local function setLeaderstat(player: Player, level: number)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local value = stats:FindFirstChild("Level")
	if not value then
		value = Instance.new("IntValue")
		value.Name = "Level"
		value.Parent = stats
	end
	value.Value = level
end

-- Plakietka "⭐ 12" nad głową (nad tytułem kosmetycznym, jeśli gracz go nosi)
local function applyTag(player: Player, level: number)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local tag = head:FindFirstChild("LevelTag")
	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = "LevelTag"
		tag.Size = UDim2.fromOffset(84, 26)
		tag.MaxDistance = 60
		tag.LightInfluence = 0
		local badge = Instance.new("TextLabel")
		badge.Name = "Badge"
		badge.Size = UDim2.fromScale(1, 1)
		badge.BackgroundColor3 = Color3.fromRGB(70, 45, 150)
		badge.BackgroundTransparency = 0.15
		badge.Font = Enum.Font.FredokaOne
		badge.TextScaled = true
		badge.TextColor3 = TAG_COLOR
		badge:SetAttribute("NoTranslate", true)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = badge
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 1.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = badge
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 3)
		padding.PaddingBottom = UDim.new(0, 3)
		padding.Parent = badge
		badge.Parent = tag
		local function place()
			tag.StudsOffset = if head:FindFirstChild("CosmeticTitle") then Vector3.new(0, 3.5, 0) else Vector3.new(0, 2.5, 0)
		end
		head.ChildAdded:Connect(place)
		head.ChildRemoved:Connect(place)
		place()
		tag.Parent = head
	end
	tag.Badge.Text = "⭐ " .. level
end

-- Efekt nowego poziomu widoczny dla wszystkich: iskry, błysk światła i napis nad głową
local function burst(player: Player, level: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "LevelUpFx"
	attachment.Parent = root
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 140, 220))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.8, 1.4)
	sparks.Speed = NumberRange.new(10, 18)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 3
	sparks.Acceleration = Vector3.new(0, 6, 0)
	sparks.Rate = 0
	sparks.Parent = attachment
	sparks:Emit(70)
	local light = Instance.new("PointLight")
	light.Color = TAG_COLOR
	light.Range = 16
	light.Brightness = 6
	light.Parent = attachment
	TweenService:Create(light, TweenInfo.new(1.6), { Brightness = 0 }):Play()

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LevelUpText"
	billboard.Size = UDim2.fromOffset(240, 60)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = true
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = TAG_COLOR
	text.Text = "⭐ NOWY POZIOM " .. level .. "!"
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(60, 30, 110)
	stroke.Parent = text
	text.Parent = billboard
	billboard.Parent = attachment
	TweenService:Create(billboard, TweenInfo.new(2.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 7, 0),
	}):Play()
	task.delay(1.8, function()
		TweenService:Create(text, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.8), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(attachment, 3)
end

-- callback(player, nowyPoziom) po każdym nowym poziomie
function XpService.OnLevelUp(callback)
	table.insert(levelUpCallbacks, callback)
end

function XpService.GetLevel(player: Player): number
	local data = DataService.Get(player)
	return if data then data.level else 1
end

-- Dodaje XP (w Złotej godzinie podwójne). Zwraca, ile XP naprawdę dostał gracz.
function XpService.Add(player: Player, amount: number, reason: string): number
	local data = DataService.Get(player)
	if not data or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end
	local golden = GoldenHourService.IsActive()
	local gained = math.max(1, math.floor(amount * GoldenHourService.XpMultiplier() + 0.5))
	data.xp += gained
	local ups = {}
	while data.level < LevelConfig.MAX_LEVEL and data.xp >= need(data.level) do
		data.xp -= need(data.level)
		data.level += 1
		local tokens = if data.level % LevelConfig.MILESTONE_EVERY == 0 then LevelConfig.MILESTONE_TOKENS else 0
		if tokens > 0 then
			data.tokens += tokens
		end
		data.wheel.bonus = math.min(LevelConfig.Wheel.maxBonus, data.wheel.bonus + 1)
		local rank = LevelConfig.RankAt(data.level)
		table.insert(ups, {
			level = data.level,
			coins = LevelConfig.LevelCoins(data.level),
			tokens = tokens,
			rank = if rank then rank.emoji .. " " .. rank.name else nil,
		})
	end
	if data.level >= LevelConfig.MAX_LEVEL then
		data.xp = math.min(data.xp, need(data.level))
	end
	RemoteService.Event(RemoteNames.Events.XpGain):FireClient(player, {
		amount = gained,
		reason = reason,
		golden = golden,
		level = data.level,
		xp = data.xp,
		need = need(data.level),
		ups = ups,
	})
	if #ups > 0 then
		for _, up in ups do
			EconomyService.AddCoins(player, up.coins, "level:" .. up.level)
		end
		setLeaderstat(player, data.level)
		applyTag(player, data.level)
		burst(player, data.level)
		for _, callback in levelUpCallbacks do
			task.spawn(callback, player, data.level)
		end
	end
	StateService.Push(player)
	return gained
end

-- Gracze sprzed systemu poziomów dostają jednorazowo XP za to, co już zrobili (bez nagród za poziomy)
local function migrate(player: Player, data)
	if data.xpInit then
		return
	end
	data.xpInit = true
	local stats = data.stats
	local start = math.floor(
		(tonumber(stats.totalEarned) or 0) * LevelConfig.XP_PER_COIN
			+ (tonumber(stats.monthsPaid) or 0) * LevelConfig.XP_RENT
			+ (tonumber(stats.cleaned) or 0) * LevelConfig.XP_CLEAN
	)
	if start <= 0 then
		return
	end
	data.xp += start
	while data.level < LevelConfig.MAX_LEVEL and data.xp >= need(data.level) do
		data.xp -= need(data.level)
		data.level += 1
	end
	if data.level > 1 then
		task.delay(6, function()
			if player.Parent then
				StateService.Notify(player, "⭐ Nowość: poziomy! Za to, co już zrobione, masz od razu poziom " .. data.level .. ".", "good")
			end
		end)
	end
end

function XpService.Init()
	JobService.SetXpHandler(function(player, _jobId, stars, amount)
		local xp = LevelConfig.XP_SHIFT + stars * LevelConfig.XP_PER_STAR + math.max(0, amount) * LevelConfig.XP_PER_COIN
		return XpService.Add(player, xp, "shift")
	end)
	EconomyService.OnEarned(function(player, amount, reason)
		if type(reason) ~= "string" or string.match(reason, SHIFT_REASON) then
			return
		end
		if reason == "quest:daily" then
			XpService.Add(player, LevelConfig.XP_DAILY_QUEST, "quest")
		elseif reason == "quest:weekly" then
			XpService.Add(player, LevelConfig.XP_WEEKLY_QUEST, "quest")
		elseif startsWithAny(reason, WORK_PREFIXES) then
			XpService.Add(player, math.max(1, amount * LevelConfig.XP_PER_COIN), "work")
		end
	end)
	CleaningService.OnCleaned(function(_owner, cleaner)
		if cleaner then
			XpService.Add(cleaner, LevelConfig.XP_CLEAN, "clean")
		end
	end)

	StateService.AddProvider(function(_player, snapshot, data)
		snapshot.level = data.level
		snapshot.xp = data.xp
		snapshot.xpNeed = need(data.level)
		snapshot.rank = rankLabel(data.level)
	end)
	DataService.OnLoaded(function(player, data)
		migrate(player, data)
		setLeaderstat(player, data.level)
		applyTag(player, data.level)
	end)
end

function XpService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			local data = DataService.Get(player)
			if data then
				applyTag(player, data.level)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return XpService

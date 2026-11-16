-- Sprzątacz: brud w biurze (osobny dla każdego gracza), sprzątanie przytrzymaniem przycisku,
-- do tego brudne okna na tylnej ścianie. Gracz trzyma miotłę; w trakcie przytrzymania ręka zamiata
-- (IKControl celuje w brud i kołysze się na boki), a przy oknie słychać szorowanie.
-- W miejsce sprzątniętego brudu pojawia się nowy. Gwiazdki = ile sprzątnięto względem celu.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ApartmentConfig = require(ReplicatedStorage.Shared.Config.ApartmentConfig)
local AssetsConfig = require(ReplicatedStorage.Shared.Config.AssetsConfig)
local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local ApartmentBuilder = require(ServerScriptService.World.ApartmentBuilder)
local HoldPrompt = require(ServerScriptService.Lib.HoldPrompt)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local JobService = require(Services.JobService)

local CleanerJob = {
	JobId = "cleaner",
}

local CONFIG = JobsConfig.Jobs.cleaner
local KINDS = { "trash", "stain" }
local WINDOW_HOLD = 1.5
local WINDOW_REDIRTY = 8 -- po tylu sekundach czyste okno może znowu się ubrudzić
local DIRTY_WINDOWS = 2 -- ile okien jest brudnych naraz
local COLORS = {
	handle = Color3.fromRGB(255, 170, 60),
	bristles = Color3.fromRGB(255, 220, 90),
	band = Color3.fromRGB(230, 60, 90),
	smudge = Color3.fromRGB(120, 100, 70),
}
local area = nil
local windows = {}
local rng = Random.new()

local function hint(state): string
	if state.cleaned >= state.target then
		return "Cel osiągnięty! Każdy kolejny brud = premia"
	end
	return string.format("Sprzątaj biuro i myj okna! Do celu: %d", state.target - state.cleaned)
end

-- Miotła przyspawana do prawej dłoni (bez kolizji, nie wpływa na ruch)
local function attachBroom(session)
	local character = session.player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not hand then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Broom"
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = hand.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
		return p
	end
	-- Kij biegnie wzdłuż dłoni (oś Y), szczotka na dole lekko z przodu
	local tilt = CFrame.Angles(math.rad(-20), 0, 0)
	piece("Handle", Vector3.new(0.22, 5, 0.22), tilt * CFrame.new(0, 0.3, 0), COLORS.handle)
	piece("Band", Vector3.new(1.3, 0.25, 0.5), tilt * CFrame.new(0, -2.2, 0), COLORS.band)
	piece("Bristles", Vector3.new(1.5, 0.7, 0.45), tilt * CFrame.new(0, -2.65, 0), COLORS.bristles)
	model.Parent = character
	session.state.broom = model
end

-- W trakcie przytrzymania ręka z miotłą sięga do celu i kołysze się na boki
local function startReach(session, targetPart: BasePart, sway: Vector3, soundKey: string?)
	local state = session.state
	local character = session.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local upper = character and character:FindFirstChild("RightUpperArm")
	local hand = character and character:FindFirstChild("RightHand")
	if state.reach or not humanoid or not upper or not hand then
		return
	end
	local point = Instance.new("Attachment")
	point.Name = "ReachPoint"
	point.Position = -sway
	point.Parent = targetPart
	local ik = Instance.new("IKControl")
	ik.Name = "CleanReach"
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = upper
	ik.EndEffector = hand
	ik.Target = point
	ik.Parent = humanoid
	local swing = TweenService:Create(point, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = sway })
	swing:Play()
	local sound = nil
	local soundId = soundKey and AssetsConfig.Sounds[soundKey]
	if type(soundId) == "string" and soundId ~= "" then
		sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Looped = true
		sound.Volume = 0.6
		sound.RollOffMaxDistance = 40
		sound.Parent = targetPart
		sound:Play()
	end
	state.reach = { ik = ik, point = point, swing = swing, sound = sound }
end

local function stopReach(session)
	local reach = session.state.reach
	if not reach then
		return
	end
	session.state.reach = nil
	reach.swing:Cancel()
	reach.ik:Destroy()
	reach.point:Destroy()
	if reach.sound then
		reach.sound:Destroy()
	end
end

local spawnDirt
local dirtyWindow

local function onCleaned(session, player: Player, dirt: BasePart, kind: string)
	local state = session.state
	if player ~= session.player or not JobService.IsActive(session) or not dirt.Parent then
		return
	end
	stopReach(session)
	local position = dirt.Position
	dirt:Destroy()
	state.cleaned += 1
	RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, position, kind, 1)
	if kind == "window" then
		task.delay(WINDOW_REDIRTY, function()
			if JobService.IsActive(session) then
				dirtyWindow(session)
			end
		end)
	else
		spawnDirt(session)
	end
	JobService.UpdateProgress(session, state.cleaned, state.target, hint(state))
end

local function holdHandlers(session, getTarget, sway: Vector3, soundKey: string?)
	return function(player)
		local target = getTarget()
		if player == session.player and JobService.IsActive(session) and target and target.Parent then
			startReach(session, target, sway, soundKey)
		end
	end, function(player)
		if player == session.player then
			stopReach(session)
		end
	end
end

spawnDirt = function(session)
	local kind = KINDS[rng:NextInteger(1, #KINDS)]
	local x = area.Position.X + rng:NextNumber(-area.Size.X / 2, area.Size.X / 2)
	local z = area.Position.Z + rng:NextNumber(-area.Size.Z / 2, area.Size.Z / 2)
	local y = if kind == "stain" then 1.05 else 1.9
	local dirt = ApartmentBuilder.CreateDirt(kind, CFrame.new(x, y, z))
	dirt.Name = "JobDirt"
	local definition = ApartmentConfig.Dirt[kind]
	local began, ended = holdHandlers(session, function()
		return dirt
	end, Vector3.new(0, 0.8, 0), nil)
	HoldPrompt.Create(dirt, {
		action = definition.action,
		object = definition.name,
		hold = definition.holdTime,
		onHoldBegan = began,
		onHoldEnded = ended,
	}, function(player)
		onCleaned(session, player, dirt, kind)
	end)
	JobService.SetGuideTarget(dirt, "🧹 Posprzątaj")
	dirt.Parent = session.folder
end

-- Brudna smuga na losowym czystym oknie
dirtyWindow = function(session)
	local state = session.state
	local clean = {}
	for _, glass in windows do
		if not state.smudges[glass] or not state.smudges[glass].Parent then
			table.insert(clean, glass)
		end
	end
	if #clean == 0 then
		return
	end
	local glass = clean[rng:NextInteger(1, #clean)]
	local smudge = Instance.new("Part")
	smudge.Name = "WindowSmudge"
	smudge.Size = Vector3.new(glass.Size.X - 0.3, glass.Size.Y - 0.3, 0.05)
	smudge.CFrame = glass.CFrame * CFrame.new(0, 0, -0.08)
	smudge.Color = COLORS.smudge
	smudge.Transparency = 0.3
	smudge.Material = Enum.Material.SmoothPlastic
	smudge.Anchored = true
	smudge.CanCollide = false
	smudge.CanTouch = false
	local began, ended = holdHandlers(session, function()
		return smudge
	end, Vector3.new(1, 0, 0), "CleanStain")
	HoldPrompt.Create(smudge, {
		action = "Umyj okno",
		object = "Okno",
		hold = WINDOW_HOLD,
		activation = 10,
		maxDistance = 14,
		onHoldBegan = began,
		onHoldEnded = ended,
	}, function(player)
		onCleaned(session, player, smudge, "window")
	end)
	JobService.SetGuideTarget(smudge, "🧽 Umyj okno")
	smudge.Parent = session.folder
	state.smudges[glass] = smudge
end

function CleanerJob.Init()
	local office = Workspace.Map.JobSites:WaitForChild("Office")
	area = office:WaitForChild("DirtArea")
	for _, child in office:GetChildren() do
		if child.Name == "OfficeWindow" then
			table.insert(windows, child)
		end
	end
end

function CleanerJob.StartShift(session)
	local state = session.state
	state.target = session.levelConfig.items
	state.cleaned = 0
	state.smudges = {}
	for _ = 1, CONFIG.visibleItems do
		spawnDirt(session)
	end
	for _ = 1, DIRTY_WINDOWS do
		dirtyWindow(session)
	end
	attachBroom(session)
	JobService.UpdateProgress(session, 0, state.target, hint(state))
end

function CleanerJob.Cleanup(session)
	stopReach(session)
	if session.state.broom then
		session.state.broom:Destroy()
		session.state.broom = nil
	end
end

function CleanerJob.Evaluate(session): number
	local state = session.state
	return JobService.StarsFromFraction(state.cleaned / state.target)
end

return CleanerJob

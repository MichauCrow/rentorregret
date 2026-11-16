-- Klimat w kamienicy (wszystko tylko u gracza):
-- * lampy migają: na 2. piętrze często, na parterze rzadko, a przy potworze mocno (ostrzeżenie!),
-- * gdy potwór goni w pobliżu: bicie serca i ciemniejące brzegi ekranu (im bliżej, tym mocniej),
-- * dźwięki 3D potworów (kroki, mruczenie, klucze) i cichy szum nocy.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent.ClientState)
local SoundController = require(script.Parent.SoundController)
local UIKit = require(script.Parent.UIKit)

local AmbienceController = {}

local FLICKER = { [0] = 0.02, [1] = 0.08, [2] = 0.2 } -- szansa na mignięcie na sekundę, wg piętra
local MONSTER_FLICKER_RADIUS = 28
local DANGER_RADIUS = 45
local MONSTER_SOUNDS = {
	neighbor = { "NeighborSteps" },
	cat = { "Purr" },
	landlord = { "LandlordSteps", "Keys" },
}

local player = Players.LocalPlayer
local lights = {} -- [PointLight] = { off = czas do końca mignięcia }
local monsters = {} -- [Model] = true
local edges = {}
local ambient = nil
local heartbeatTimer = 0

local function monsterPosition(model: Model): Vector3?
	local root = model.PrimaryPart
	return if root then root.CFrame.Position else nil
end

local function addLight(light: Instance)
	if light:IsA("PointLight") then
		lights[light] = { off = 0, next = math.random() * 3 }
	end
end

local function addMonster(model: Instance)
	if not model:IsA("Model") or not model:GetAttribute("MonsterId") or monsters[model] then
		return
	end
	monsters[model] = true
	local root = model.PrimaryPart
	if root then
		for _, key in MONSTER_SOUNDS[model:GetAttribute("MonsterId")] or {} do
			SoundController.Attach(root, key, true, 55)
		end
	end
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			monsters[model] = nil
		end
	end)
end

-- Ciemne brzegi ekranu (4 paski z przezroczystym gradientem)
local function buildVignette()
	local gui = UIKit.create("ScreenGui", { Name = "Vignette", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 1 })
	local sides = {
		{ size = UDim2.fromScale(0.25, 1), position = UDim2.fromScale(0, 0), rotation = 0 },
		{ size = UDim2.fromScale(0.25, 1), position = UDim2.fromScale(0.75, 0), rotation = 180 },
		{ size = UDim2.fromScale(1, 0.3), position = UDim2.fromScale(0, 0), rotation = 90 },
		{ size = UDim2.fromScale(1, 0.3), position = UDim2.fromScale(0, 0.7), rotation = 270 },
	}
	for _, side in sides do
		local frame = UIKit.create("Frame", {
			Size = side.size,
			Position = side.position,
			BackgroundColor3 = Color3.fromRGB(60, 0, 30),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
		})
		UIKit.create("UIGradient", {
			Rotation = side.rotation,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		}).Parent = frame
		frame.Parent = gui
		table.insert(edges, frame)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function setDanger(amount: number)
	for _, frame in edges do
		frame.BackgroundTransparency = 1 - amount * 0.75
	end
end

local function updateLights(dt: number, character: Model?)
	local origin = character and character.PrimaryPart and character.PrimaryPart.CFrame.Position
	for light, state in lights do
		if not light.Parent then
			lights[light] = nil
			continue
		end
		local base = light:GetAttribute("Base") or light.Brightness
		local part = light.Parent :: BasePart
		local position = part.CFrame.Position
		if origin and (position - origin).Magnitude > 120 then
			continue
		end
		-- Potwór blisko lampy: lampa szaleje
		local nearMonster = false
		for model in monsters do
			local monster = monsterPosition(model)
			if monster and (monster - position).Magnitude < MONSTER_FLICKER_RADIUS then
				nearMonster = true
				break
			end
		end
		if state.off > 0 then
			state.off -= dt
			light.Brightness = base * 0.08
		elseif nearMonster then
			light.Brightness = base * (if math.random() < 0.35 then 0.1 else 0.6 + math.random() * 0.5)
		else
			local chance = FLICKER[light:GetAttribute("Floor") or 0] or 0.05
			if math.random() < chance * dt then
				state.off = 0.05 + math.random() * 0.25
			end
			light.Brightness = base
		end
	end
end

local function updateDanger(dt: number, character: Model?)
	local round = ClientState.round
	local origin = character and character.PrimaryPart and character.PrimaryPart.CFrame.Position
	local danger = 0
	if round and round.status == "inside" and origin then
		for model in monsters do
			if model:GetAttribute("Hostile") then
				local position = monsterPosition(model)
				if position then
					danger = math.max(danger, 1 - (position - origin).Magnitude / DANGER_RADIUS)
				end
			end
		end
	end
	danger = math.clamp(danger, 0, 1)
	setDanger(danger)
	-- Bicie serca: szybciej, gdy potwór bliżej
	if danger > 0 then
		heartbeatTimer -= dt
		if heartbeatTimer <= 0 then
			heartbeatTimer = 1.1 - danger * 0.6
			SoundController.Play("Heartbeat", 1 + danger * 0.3)
		end
	else
		heartbeatTimer = 0
	end
end

local function updateSoundVolumes()
	local enabled = SoundController.SfxEnabled()
	for model in monsters do
		for _, child in (model.PrimaryPart and model.PrimaryPart:GetChildren()) or {} do
			if child:IsA("Sound") then
				child.Volume = if enabled then child:GetAttribute("BaseVolume") or 0.5 else 0
			end
		end
	end
	if ambient then
		ambient.Volume = if enabled and ClientState.round then ambient:GetAttribute("BaseVolume") or 0.3 else 0
	end
end

function AmbienceController.Init()
	buildVignette()
end

function AmbienceController.Start()
	for _, light in CollectionService:GetTagged("Flicker") do
		addLight(light)
	end
	CollectionService:GetInstanceAddedSignal("Flicker"):Connect(addLight)

	local rounds = Workspace:WaitForChild("Rounds")
	for _, descendant in rounds:GetDescendants() do
		addMonster(descendant)
	end
	rounds.DescendantAdded:Connect(function(descendant)
		-- Model potwora trafia do Workspace w całości, ale atrybuty i części mogą dojść chwilę później
		if descendant:IsA("Model") then
			task.defer(addMonster, descendant)
		end
	end)

	ambient = SoundController.Attach(SoundService, "AmbientNight", true)
	-- Szuranie przy przeszukiwaniu mebli
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt:GetAttribute("Kind") == "search" then
			SoundController.Play("Search")
		end
	end)
	ClientState.OnProfile(updateSoundVolumes)
	ClientState.OnRound(function()
		updateSoundVolumes()
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		local step = acc
		acc = 0
		local character = player.Character
		if ClientState.round then
			updateLights(step, character)
		end
		updateDanger(step, character)
	end)
end

return AmbienceController

-- Klimat w kamienicy (wszystko tylko u gracza):
-- * lampy migają (na 2. piętrze często, przy potworze mocno, w finale o 23:55 bez przerwy), Reżyser gasi piętra,
-- * gdy potwór goni w pobliżu: bicie serca, ciemniejące brzegi ekranu, muzyka pościgu, wibracja pada,
-- * dźwięki 3D potworów (kroki, mruczenie, klucze), szum nocy, dźwięki zdarzeń (kroki nad sufitem),
-- * napisy dźwięków z kierunkiem ("👣 Kroki · z lewej · blisko") dla grających bez dźwięku,
-- * latarka mruga, gdy kończy się bateria.
local CollectionService = game:GetService("CollectionService")
local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local NightConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("NightConfig"))
local ClientState = require(script.Parent.ClientState)
local HUDController = require(script.Parent.HUDController)
local SoundController = require(script.Parent.SoundController)
local UIKit = require(script.Parent.UIKit)

local AmbienceController = {}

local FLICKER = { [0] = 0.02, [1] = 0.08, [2] = 0.2 } -- szansa na mignięcie na sekundę, wg piętra
local MONSTER_FLICKER_RADIUS = 28
local DANGER_RADIUS = 45
local CAPTION_RADIUS = 40
local MONSTER_SOUNDS = {
	neighbor = { "NeighborSteps" },
	cat = { "Purr" },
	landlord = { "LandlordSteps", "Keys" },
}
local CAPTION_NAMES = { neighbor = "👣 Kroki", cat = "🐾 Mruczenie", landlord = "🔑 Brzęk kluczy" }

local player = Players.LocalPlayer
local lights = {} -- [PointLight] = { off = czas do końca zgaszenia }
local monsters = {} -- [Model] = true
local edges = {}
local ambient = nil
local chase = nil
local heartbeatTimer = 0
local captionTimer = 0
local eventCaption = nil -- { text, untilTime }

local function monsterPosition(model: Model): Vector3?
	local root = model.PrimaryPart
	return if root then root.CFrame.Position else nil
end

local function characterPosition(): Vector3?
	local character = player.Character
	local root = character and character.PrimaryPart
	return if root then root.CFrame.Position else nil
end

local function addLight(light: Instance)
	if light:IsA("PointLight") then
		lights[light] = { off = 0 }
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

local function updateLights(dt: number, origin: Vector3?)
	local round = ClientState.round
	local finale = round ~= nil and round.finale and not round.rentPaid
	local nightLights = NightConfig.Value(NightConfig.ById(round and round.night), "lights")
	for light, state in lights do
		if not light.Parent then
			lights[light] = nil
			continue
		end
		local base = (light:GetAttribute("Base") or light.Brightness) * nightLights
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
			light.Brightness = base * 0.05
		elseif nearMonster or (finale and math.random() < 0.3) then
			light.Brightness = base * (if math.random() < 0.35 then 0.1 else 0.6 + math.random() * 0.5)
		else
			local chance = (FLICKER[light:GetAttribute("Floor") or 0] or 0.05) * (if finale then 4 else 1)
			if math.random() < chance * dt then
				state.off = 0.05 + math.random() * 0.25
			end
			light.Brightness = base
		end
	end
end

-- Reżyser: gaśnie prąd na piętrze w kamienicy gracza
local function blackout(data)
	local origin = data.origin
	if typeof(origin) ~= "Vector3" then
		return
	end
	local center = origin + Vector3.new(32, 0, 20)
	for light, state in lights do
		if light.Parent and light:GetAttribute("Floor") == data.floor then
			local part = light.Parent :: BasePart
			if (part.CFrame.Position - center).Magnitude < 80 then
				state.off = data.duration or 6
			end
		end
	end
	local round = ClientState.round
	if round and round.floor == data.floor then
		eventCaption = { text = "💡 Zgasło światło...", untilTime = os.clock() + 3 }
	end
end

-- Reżyser: dźwięk w świecie (np. kroki nad sufitem)
local function worldSound(data)
	if typeof(data.position) ~= "Vector3" then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = Workspace.Terrain
	attachment.WorldPosition = data.position
	SoundController.Attach(attachment, data.key or "NeighborSteps", true, 60)
	task.delay(data.duration or 4, function()
		attachment:Destroy()
	end)
	local origin = characterPosition()
	local above = origin and data.position.Y - origin.Y > 6
	eventCaption = { text = if above then "👣 Kroki · nad Tobą" else "👣 Kroki · za ścianą", untilTime = os.clock() + (data.duration or 4) }
end

local function directionText(position: Vector3, origin: Vector3): string
	local camera = Workspace.CurrentCamera
	local parts = {}
	if position.Y - origin.Y > 8 then
		table.insert(parts, "nad Tobą")
	elseif position.Y - origin.Y < -8 then
		table.insert(parts, "pod Tobą")
	elseif camera then
		local relative = camera.CFrame:PointToObjectSpace(position)
		local angle = math.deg(math.atan2(relative.X, -relative.Z))
		if math.abs(angle) < 35 then
			table.insert(parts, "z przodu")
		elseif math.abs(angle) > 145 then
			table.insert(parts, "z tyłu")
		elseif angle > 0 then
			table.insert(parts, "z prawej")
		else
			table.insert(parts, "z lewej")
		end
	end
	local distance = (position - origin).Magnitude
	table.insert(parts, if distance < 15 then "bardzo blisko" elseif distance < 28 then "blisko" else "daleko")
	return table.concat(parts, " · ")
end

-- Napisy dźwięków: najbliższy słyszalny potwór (albo zdarzenie Reżysera)
local function updateCaption(origin: Vector3?)
	local profile = ClientState.profile
	if not ClientState.round or not origin or (profile and profile.settings.captions == false) then
		HUDController.Caption(nil)
		return
	end
	if eventCaption and os.clock() < eventCaption.untilTime then
		HUDController.Caption(eventCaption.text)
		return
	end
	local best, bestDistance = nil, CAPTION_RADIUS
	for model in monsters do
		local position = monsterPosition(model)
		local id = model:GetAttribute("MonsterId")
		local audible = model:GetAttribute("Moving") == true or id == "cat"
		if position and audible then
			local distance = (position - origin).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	if best then
		local position = monsterPosition(best) :: Vector3
		HUDController.Caption((CAPTION_NAMES[best:GetAttribute("MonsterId")] or "👣 Kroki") .. " · " .. directionText(position, origin))
	else
		HUDController.Caption(nil)
	end
end

local function setChaseMusic(on: boolean)
	if not chase then
		return
	end
	local volume = if on and SoundController.SfxEnabled() then chase:GetAttribute("BaseVolume") or 0.4 else 0
	if chase.Volume ~= volume and not chase:GetAttribute("Fading") then
		chase:SetAttribute("Fading", true)
		local tween = TweenService:Create(chase, TweenInfo.new(if on then 0.5 else 2.5), { Volume = volume })
		tween.Completed:Once(function()
			chase:SetAttribute("Fading", nil)
		end)
		tween:Play()
	end
end

local function vibrate(amount: number)
	pcall(function()
		if HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, amount)
		end
	end)
end

local function updateDanger(dt: number, origin: Vector3?)
	local round = ClientState.round
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
	setChaseMusic(danger > 0.2)
	-- Bicie serca (i wibracja pada w jego rytmie): szybciej, gdy potwór bliżej
	if danger > 0 then
		heartbeatTimer -= dt
		if heartbeatTimer <= 0 then
			heartbeatTimer = 1.1 - danger * 0.6
			SoundController.Play("Heartbeat", 1 + danger * 0.3)
			vibrate(danger * 0.6)
			task.delay(0.12, vibrate, 0)
		end
	else
		heartbeatTimer = 0
	end
end

-- Latarka mruga, gdy bateria się kończy (tylko u siebie)
local function updateFlashlight()
	local round = ClientState.round
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local light = head and head:FindFirstChild("Flashlight")
	if not light or not light:IsA("SpotLight") then
		return
	end
	if round and round.flashlight and round.battery / math.max(1, round.batteryMax) < 0.2 then
		light.Brightness = if math.random() < 0.15 then 0.4 else 2.5 + math.random()
	else
		light.Brightness = 3.5
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
			task.delay(1, addMonster, descendant)
		end
	end)

	ambient = SoundController.Attach(SoundService, "AmbientNight", true)
	chase = SoundController.Attach(SoundService, "ChaseMusic", true)
	if chase then
		chase.Volume = 0
	end
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
	ClientState.OnRoundEvent(function(kind, data)
		if type(data) ~= "table" then
			return
		end
		if kind == "blackout" then
			blackout(data)
		elseif kind == "sound" then
			worldSound(data)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		local step = acc
		acc = 0
		local origin = characterPosition()
		if ClientState.round then
			updateLights(step, origin)
			updateFlashlight()
		end
		updateDanger(step, origin)
		captionTimer -= step
		if captionTimer <= 0 then
			captionTimer = 0.4
			updateCaption(origin)
		end
	end)
end

return AmbienceController

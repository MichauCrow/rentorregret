-- Zwierzaki ze sklepu zoologicznego: zakup (limity gatunków), chodzenie za właścicielem (pies na smyczy),
-- tryb "zostań w domu", polecenia (łapa, obrót, głos, skok, kółko) i aport. Wszystko liczone na serwerze.
-- Zwierzaki są tylko dla zabawy: nie dają monet ani przewagi.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local AssetsConfig = require(ReplicatedStorage.Shared.Config.AssetsConfig)
local ApartmentConfig = require(ReplicatedStorage.Shared.Config.ApartmentConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local PetBuilder = require(ServerScriptService.World.PetBuilder)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local ApartmentService = require(Services.ApartmentService)

local PetService = {}

local FOLLOW_TICK = 0.2
local SNAP_DISTANCE = 45
local COMMAND_COOLDOWN = 0.8
local SHOP_ORIGIN = CFrame.new(156, 0, 45) -- przy głównej ulicy, między domem nr 2 a murem miasta
local SHOP_USE_DISTANCE = 25
local FETCH_MIN, FETCH_MAX = 10, 36
local RUN_SPEED = 24
local HOME_SPEED = 5
local PARROT_HOME_HEIGHT = 3.5
-- Miejsca za graczem dla kolejnych zwierzaków: (w bok, do tyłu)
local SLOTS = { { 2.4, 3.2 }, { -2.4, 3.2 }, { 0, 5.2 }, { 3, 6 }, { -3, 6 }, { 0, 7.5 } }

local petsFolder: Folder = nil
local shopCounter: BasePart = nil
local owned = {} -- [player] = { [petId] = pet }; pet = { entry, model, body, height, busy, nextWander }
local lastCommand = {} -- [player] = os.clock()
local rng = Random.new()

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function feetY(player: Player, root: BasePart): number
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	return root.Position.Y - root.Size.Y / 2 - hip
end

-- Wysokość podłogi pod punktem (pomija postacie i zwierzaki); fallback = podana wysokość
local function groundY(position: Vector3, fallback: number): number
	local ignore = { petsFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local result = Workspace:Raycast(Vector3.new(position.X, fallback + 4, position.Z), Vector3.new(0, -10, 0), params)
	return if result then result.Position.Y else fallback
end

local function species(pet)
	return PetConfig.Species[pet.entry.species]
end

local function setBody(pet, cframe: CFrame, duration: number, style: Enum.EasingStyle?)
	if duration <= 0 then
		pet.model:PivotTo(cframe)
		return nil
	end
	local tween = TweenService:Create(pet.body, TweenInfo.new(duration, style or Enum.EasingStyle.Linear), { CFrame = cframe })
	tween:Play()
	return tween
end

-- Punkt na ziemi -> CFrame korzenia zwierzaka
local function bodyAt(pet, ground: CFrame): CFrame
	return ground * CFrame.new(0, pet.height, 0)
end

local function bubble(pet, text: string, color: Color3?)
	local body = pet.body
	if not body or not body.Parent then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(255, 220, 60)
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	task.delay(1.8, function()
		gui:Destroy()
	end)
end

-- times: ile razy pod rząd (szczeknięcie jest krótkie, więc "hau hau" = 2 razy)
local function playSound(pet, key: string, times: number?)
	local soundId = AssetsConfig.Sounds[key]
	if type(soundId) ~= "string" or soundId == "" or not pet.body.Parent then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = AssetsConfig.Volumes[key] or 0.8
	sound.RollOffMaxDistance = 60
	sound.Parent = pet.body
	sound:Play()
	for i = 2, times or 1 do
		task.delay((i - 1) * 0.32, function()
			if sound.Parent then
				sound.PlaybackSpeed = 0.95 + i * 0.05
				sound.TimePosition = 0
				sound:Play()
			end
		end)
	end
	task.delay(3, function()
		sound:Destroy()
	end)
end

-- Ile zwierzaków tego gatunku ma gracz z niższym numerem (drugi pies/kot dostaje inne umaszczenie)
local function variantOf(data, entry): number
	local variant = 1
	for _, other in data.pets do
		if other.species == entry.species and other.id < entry.id then
			variant += 1
		end
	end
	return variant
end

-- Miejsce zwierzaka w mieszkaniu (punkt na podłodze). Chomik stoi w klatce w rogu przy drzwiach.
local function homeGround(player: Player, pet): CFrame?
	local unit = ApartmentService.GetUnit(player)
	if not unit then
		return nil
	end
	local tier = ApartmentConfig.Tiers[unit.tier]
	if pet.entry.species == "hamster" then
		return unit.origin * CFrame.new(tier.width / 2 - 2.6, 1, -tier.depth / 2 + 2.3) * CFrame.Angles(0, math.pi, 0)
	end
	local point = ApartmentService.RandomFloorPoint(player)
	if not point then
		return nil
	end
	local ground = CFrame.new(point) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if species(pet).flying then
		ground *= CFrame.new(0, PARROT_HOME_HEIGHT, 0)
	end
	return ground
end

local function sendHome(player: Player, pet)
	local ground = homeGround(player, pet)
	if ground then
		setBody(pet, bodyAt(pet, ground), 0)
	end
	pet.nextWander = os.clock() + rng:NextNumber(3, 6)
	local leash = pet.model:FindFirstChild("Leash", true)
	if leash then
		leash.Enabled = false
	end
	pet.model:SetAttribute("Home", true)
end

-- Smycz: czerwony pasek od obroży do dłoni gracza (sam wygląd, bez fizyki)
local function updateLeash(player: Player, pet)
	local collar = pet.model:FindFirstChild("Collar")
	if not collar or not species(pet).leash then
		return
	end
	local hook = collar:FindFirstChild("LeashHook")
	if not hook then
		hook = Instance.new("Attachment")
		hook.Name = "LeashHook"
		hook.Parent = collar
	end
	local leash = collar:FindFirstChild("Leash")
	if not leash then
		leash = Instance.new("Beam")
		leash.Name = "Leash"
		leash.Attachment0 = hook
		leash.Color = ColorSequence.new(Color3.fromRGB(230, 40, 70))
		leash.Width0 = 0.16
		leash.Width1 = 0.16
		leash.FaceCamera = true
		leash.Segments = 12
		leash.CurveSize0 = -1
		leash.CurveSize1 = 1
		leash.LightInfluence = 0.3
		leash.Parent = collar
	end
	local character = player.Character
	if not leash.Attachment1 or not character or not leash.Attachment1:IsDescendantOf(character) then
		leash.Attachment1 = character and character:FindFirstChild("RightGripAttachment", true)
	end
	leash.Enabled = not pet.entry.home and leash.Attachment1 ~= nil
end

local function spawnPet(player: Player, data, entry)
	local list = owned[player]
	local config = PetConfig.Species[entry.species]
	if not list or not config then
		return
	end
	local pet = { entry = entry, busy = false, nextWander = 0 }
	local root = getRoot(player)
	local start = CFrame.new(0, -50, 0)
	if root then
		start = CFrame.new(root.Position.X + 3, feetY(player, root), root.Position.Z + 3)
	end
	local model = PetBuilder.Build(entry.species, start, variantOf(data, entry))
	if not model then
		return
	end
	model.Name = "Pet_" .. player.UserId .. "_" .. entry.id
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PetId", entry.id)
	model:SetAttribute("Species", entry.species)
	model:SetAttribute("PetName", entry.name)
	model:SetAttribute("Home", entry.home == true)
	pet.model = model
	pet.body = model.PrimaryPart
	pet.height = model:GetAttribute("BodyHeight") or 1

	-- Imię nad zwierzakiem i podpowiedź z poleceniami (klient pokazuje ją tylko właścicielowi)
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(120, 24)
	tag.StudsOffsetWorldSpace = Vector3.new(0, if entry.species == "hamster" then 3.2 else 2.2, 0)
	tag.MaxDistance = 35
	tag.Parent = pet.body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Text = config.emoji .. " " .. entry.name
	label.Parent = tag
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Parent = label
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PetPrompt"
	prompt.ActionText = "Polecenia"
	prompt.ObjectText = config.emoji .. " " .. entry.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt:SetAttribute("PetId", entry.id)
	prompt.Parent = pet.body

	model.Parent = petsFolder
	list[entry.id] = pet
	if entry.home or not config.follow then
		sendHome(player, pet)
	else
		updateLeash(player, pet)
	end
end

local function despawnAll(player: Player)
	local list = owned[player]
	if list then
		for _, pet in list do
			pet.model:Destroy()
		end
	end
	owned[player] = nil
	lastCommand[player] = nil
end

local function countSpecies(data, speciesId: string): number
	local count = 0
	for _, entry in data.pets do
		if entry.species == speciesId then
			count += 1
		end
	end
	return count
end

-- Imię bez powtórek u jednego gracza
local function pickName(data, config): string
	local free = {}
	for _, name in config.names do
		local used = false
		for _, entry in data.pets do
			if entry.name == name then
				used = true
			end
		end
		if not used then
			table.insert(free, name)
		end
	end
	local pool = if #free > 0 then free else config.names
	return pool[rng:NextInteger(1, #pool)]
end

local function buildCatalog(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local list = {}
	for _, speciesId in PetConfig.Order do
		local config = PetConfig.Species[speciesId]
		table.insert(list, {
			id = speciesId,
			name = config.name,
			emoji = config.emoji,
			price = config.price,
			max = config.max,
			owned = countSpecies(data, speciesId),
		})
	end
	local pets = {}
	for _, entry in data.pets do
		table.insert(pets, { id = entry.id, species = entry.species, name = entry.name, home = entry.home == true })
	end
	return { coins = data.coins, species = list, pets = pets }
end

local function nearShop(player: Player): boolean
	local root = getRoot(player)
	return root ~= nil and (root.Position - shopCounter.Position).Magnitude <= SHOP_USE_DISTANCE
end

local function buy(player: Player, speciesId: any): (boolean, string)
	if not RemoteService.IsString(speciesId, 16) or not PetConfig.Species[speciesId] then
		return false, "Nieznany zwierzak."
	end
	local data = DataService.Get(player)
	if not data or not owned[player] then
		return false, "Chwila, wczytuję dane..."
	end
	if not nearShop(player) then
		return false, "Podejdź do lady w zoo sklepie."
	end
	local config = PetConfig.Species[speciesId]
	if countSpecies(data, speciesId) >= config.max then
		return false, if config.max > 1 then string.format("Masz już %d takie zwierzaki!", config.max) else "Masz już takiego zwierzaka!"
	end
	if not EconomyService.TrySpend(player, config.price, "pet:" .. speciesId) then
		return false, "Za mało monet."
	end
	local entry = { id = data.nextPetId, species = speciesId, name = pickName(data, config), home = not config.follow }
	data.nextPetId += 1
	table.insert(data.pets, entry)
	spawnPet(player, data, entry)
	StateService.Push(player)
	local where = if config.cage then " Klatka stoi w twoim mieszkaniu." else ""
	return true, string.format("%s Nowy przyjaciel: %s!%s", config.emoji, entry.name, where)
end

-- Polecenia -------------------------------------------------------------------

local function spin(pet)
	local base = pet.body.CFrame
	for i = 1, 4 do
		setBody(pet, base * CFrame.Angles(0, math.rad(90 * i), 0), 0.14)
		task.wait(0.14)
	end
	bubble(pet, "🌀 Wiii!")
end

local function hop(pet)
	local base = pet.body.CFrame
	for _ = 1, 2 do
		setBody(pet, base * CFrame.new(0, 1.8, 0), 0.2, Enum.EasingStyle.Quad)
		task.wait(0.2)
		setBody(pet, base, 0.2, Enum.EasingStyle.Quad)
		task.wait(0.22)
	end
end

local function paw(pet)
	local base = pet.body.CFrame
	local leg = pet.model:FindFirstChild("FrontLegR")
	-- Siad (tułów lekko w górę) i podniesiona prawa łapa
	setBody(pet, base * CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(18), 0, 0), 0.2, Enum.EasingStyle.Quad)
	task.wait(0.22)
	local raised = nil
	if leg then
		leg.Transparency = 1
		raised = Instance.new("Part")
		raised.Name = "RaisedPaw"
		raised.Size = Vector3.new(0.4, 0.4, 1.1)
		raised.Color = leg.Color
		raised.Material = Enum.Material.SmoothPlastic
		raised.CFrame = pet.body.CFrame * CFrame.new(0.45, -0.1, -1.6) * CFrame.Angles(math.rad(-15), 0, 0)
		raised.CanCollide = false
		raised.CanTouch = false
		raised.CanQuery = false
		raised.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = pet.body
		weld.Part1 = raised
		weld.Parent = raised
		raised.Parent = pet.model
	end
	bubble(pet, "🐾 Proszę!")
	task.wait(1.6)
	if raised then
		raised:Destroy()
	end
	if leg then
		leg.Transparency = 0
	end
	setBody(pet, base, 0.2, Enum.EasingStyle.Quad)
	task.wait(0.2)
end

local function speak(pet)
	bubble(pet, species(pet).say)
	if pet.entry.species == "dog" then
		playSound(pet, "DogBark", 2)
	end
	task.wait(0.6)
end

-- Chomik wbiega do kołowrotka i kręci nim przez kilka sekund
local function wheel(pet)
	local hamster = pet.model:FindFirstChild("Hamster")
	local wheelPart = pet.model:FindFirstChild("Wheel")
	if not hamster or not wheelPart then
		return
	end
	local ears = {}
	for _, child in pet.model:GetChildren() do
		if child.Name == "HamsterEar" or child.Name == "HamsterNose" then
			table.insert(ears, { part = child, offset = hamster.CFrame:ToObjectSpace(child.CFrame) })
		end
	end
	local homeCFrame = hamster.CFrame
	local inWheel = CFrame.new(wheelPart.Position - Vector3.new(0, 0.32, 0)) * (homeCFrame - homeCFrame.Position)
	hamster.CFrame = inWheel
	for _, ear in ears do
		ear.part.CFrame = inWheel * ear.offset
	end
	bubble(pet, "🎡 Szybciej, szybciej!")
	local base = wheelPart.CFrame
	for i = 1, 24 do
		wheelPart.CFrame = base * CFrame.Angles(math.rad(-30 * i), 0, 0)
		hamster.CFrame = inWheel * CFrame.new(0, math.abs(math.sin(i)) * 0.08, 0)
		for _, ear in ears do
			ear.part.CFrame = hamster.CFrame * ear.offset
		end
		task.wait(0.12)
	end
	wheelPart.CFrame = base
	hamster.CFrame = homeCFrame
	for _, ear in ears do
		ear.part.CFrame = homeCFrame * ear.offset
	end
end

local function toggleStay(player: Player, pet)
	local config = species(pet)
	if not config.follow then
		return
	end
	pet.entry.home = not pet.entry.home
	pet.model:SetAttribute("Home", pet.entry.home)
	if pet.entry.home then
		sendHome(player, pet)
		StateService.Notify(player, string.format("🏠 %s czeka na ciebie w domu.", pet.entry.name), "info")
	else
		local root = getRoot(player)
		if root then
			local ground = CFrame.new(root.Position.X + 2, feetY(player, root), root.Position.Z + 2)
			setBody(pet, bodyAt(pet, ground), 0)
		end
		updateLeash(player, pet)
		bubble(pet, "💖 Idziemy!")
		StateService.Notify(player, string.format("🚶 %s idzie z tobą!", pet.entry.name), "good")
	end
end

-- Aport: piłka leci łukiem przed gracza (siła 0..1 z minigry), pies biegnie, przynosi ją i szczeka
local function fetch(player: Player, pet, power: number)
	local root = getRoot(player)
	if not root then
		return
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local distance = FETCH_MIN + (FETCH_MAX - FETCH_MIN) * math.clamp(power, 0, 1)
	local start = root.Position + Vector3.new(0, 1, 0) + look * 1.5
	local ignore = { petsFolder }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(start, look * distance, params)
	if hit then
		distance = math.max(3, hit.Distance - 2)
	end
	local flatLanding = start + look * distance
	local baseY = feetY(player, root)
	local landing = Vector3.new(flatLanding.X, groundY(flatLanding, baseY) + 0.4, flatLanding.Z)

	local ball = Instance.new("Part")
	ball.Name = "FetchBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.8, 0.8, 0.8)
	ball.Color = Color3.fromRGB(200, 255, 60)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanTouch = false
	ball.CanQuery = false
	ball.CFrame = CFrame.new(start)
	ball.Parent = petsFolder

	-- Lot piłki
	local flight = 0.45 + distance / 45
	local arc = 2 + distance * 0.3
	local elapsed = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local t = math.min(elapsed / flight, 1)
		ball.CFrame = CFrame.new(start:Lerp(landing, t) + Vector3.new(0, arc * 4 * t * (1 - t), 0))
		if t >= 1 then
			connection:Disconnect()
		end
	end)
	bubble(pet, "🎾 !!!")
	task.wait(0.25)

	-- Bieg do piłki
	local from = pet.body.Position
	local target = Vector3.new(landing.X, groundY(landing, baseY), landing.Z)
	local toBall = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	local facing = if toBall.Magnitude > 0.1 then toBall.Unit else look
	local stop = target - facing * 1.6
	local runTime = math.max(0.3, toBall.Magnitude / RUN_SPEED)
	setBody(pet, bodyAt(pet, CFrame.lookAt(stop, stop + facing)), runTime)
	task.wait(math.max(runTime, flight - 0.25) + 0.1)
	if not pet.model.Parent or not ball.Parent then
		ball:Destroy()
		return
	end
	-- Piłka w pysku
	local snout = pet.model:FindFirstChild("Snout") or pet.body
	ball.CFrame = snout.CFrame * CFrame.new(0, -0.1, -0.5)
	ball.Anchored = false
	ball.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = snout
	weld.Part1 = ball
	weld.Parent = ball
	task.wait(0.2)

	-- Powrót do właściciela (dwa podejścia, bo gracz mógł się ruszyć)
	for _ = 1, 2 do
		root = getRoot(player)
		if not root then
			break
		end
		local ownerLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		ownerLook = if ownerLook.Magnitude > 0.1 then ownerLook.Unit else look
		local goal = root.Position + ownerLook * 2.6
		goal = Vector3.new(goal.X, groundY(goal, feetY(player, root)), goal.Z)
		local current = pet.body.Position
		local way = Vector3.new(goal.X - current.X, 0, goal.Z - current.Z)
		if way.Magnitude < 1.5 then
			break
		end
		local time = math.max(0.25, way.Magnitude / RUN_SPEED)
		-- Ostatni krok: pies obraca się przodem do gracza
		setBody(pet, bodyAt(pet, CFrame.lookAt(goal, goal + way.Unit)), time)
		task.wait(time + 0.05)
	end
	root = getRoot(player)
	if root then
		local current = pet.body.Position
		local faceOwner = Vector3.new(root.Position.X - current.X, 0, root.Position.Z - current.Z)
		if faceOwner.Magnitude > 0.1 then
			setBody(pet, CFrame.lookAt(current, current + faceOwner.Unit), 0.15)
			task.wait(0.15)
		end
	end
	-- Upuszcza piłkę i szczeka
	weld:Destroy()
	ball.Anchored = true
	ball.CFrame = CFrame.new(pet.body.Position + pet.body.CFrame.LookVector * 1.4 - Vector3.new(0, pet.height - 0.4, 0))
	playSound(pet, "DogBark", 2)
	bubble(pet, "🎾 HAU! Jeszcze raz!")
	RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, pet.body.Position + Vector3.new(0, 2, 0), "pet", 0)
	task.delay(1.5, function()
		ball:Destroy()
	end)
end

local COMMANDS = {
	spin = spin,
	hop = hop,
	paw = paw,
	speak = speak,
	wheel = wheel,
}

local function onPetAction(player: Player, petId: any, command: any, power: any)
	local list = owned[player]
	if not list or not RemoteService.IsInteger(petId, 1, 1e6) or not RemoteService.IsString(command, 12) then
		return
	end
	local pet = list[petId]
	if not pet or not table.find(species(pet).commands, command) then
		return
	end
	local root = getRoot(player)
	if not root or (root.Position - pet.body.Position).Magnitude > 20 then
		StateService.Notify(player, "Podejdź bliżej do zwierzaka.", "warn")
		return
	end
	local now = os.clock()
	if now - (lastCommand[player] or 0) < COMMAND_COOLDOWN then
		return
	end
	lastCommand[player] = now
	if command == "stay" then
		if not pet.busy then
			toggleStay(player, pet)
		end
		return
	end
	if pet.busy then
		return
	end
	if command == "fetch" then
		if pet.entry.home then
			StateService.Notify(player, "Najpierw zabierz psa ze sobą (\"Chodź ze mną\").", "warn")
			return
		end
		if type(power) ~= "number" or power ~= power then
			return
		end
	end
	pet.busy = true
	task.spawn(function()
		local ok, err = pcall(function()
			if command == "fetch" then
				fetch(player, pet, power)
			else
				COMMANDS[command](pet)
			end
		end)
		if not ok then
			warn("[PetService] " .. tostring(err))
		end
		pet.busy = false
	end)
end

-- Chodzenie za graczem i spacery po mieszkaniu ---------------------------------------

local function tickPlayer(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if not owned[player] then
		if not ApartmentService.GetUnit(player) then
			return
		end
		owned[player] = {}
		for _, entry in data.pets do
			if type(entry) == "table" and PetConfig.Species[entry.species] and type(entry.id) == "number" then
				spawnPet(player, data, entry)
			end
		end
	end
	local root = getRoot(player)
	local followers = {}
	local now = os.clock()
	for _, pet in owned[player] do
		if not pet.busy then
			if pet.entry.home or not species(pet).follow then
				if pet.entry.species ~= "hamster" and now >= pet.nextWander then
					pet.nextWander = now + rng:NextNumber(5, 10)
					local ground = homeGround(player, pet)
					if ground then
						local distance = (ground.Position - pet.body.Position).Magnitude
						local goal = CFrame.lookAt(ground.Position, ground.Position + Vector3.new(ground.Position.X - pet.body.Position.X, 0, ground.Position.Z - pet.body.Position.Z + 0.01))
						if distance > 60 then
							setBody(pet, bodyAt(pet, goal), 0)
						else
							setBody(pet, bodyAt(pet, goal), math.min(4, distance / HOME_SPEED))
						end
					end
				end
			elseif root then
				table.insert(followers, pet)
			end
		end
	end
	if not root then
		return
	end
	table.sort(followers, function(a, b)
		return a.entry.id < b.entry.id
	end)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local right = look:Cross(Vector3.yAxis)
	local feet = feetY(player, root)
	local slot = 0
	for _, pet in followers do
		local goal
		if species(pet).flying then
			-- Papuga lata przy prawym ramieniu
			local position = root.Position + right * 1.4 + Vector3.new(0, 1.7 + math.sin(now * 3) * 0.15, 0) + look * 0.2
			goal = CFrame.lookAt(position, position + look)
		else
			slot += 1
			local offsets = SLOTS[math.min(slot, #SLOTS)]
			local flat = root.Position - look * offsets[2] + right * offsets[1]
			local position = Vector3.new(flat.X, groundY(flat, feet), flat.Z)
			local current = pet.body.Position
			local move = Vector3.new(position.X - current.X, 0, position.Z - current.Z)
			if move.Magnitude < 0.6 and math.abs(current.Y - pet.height - position.Y) < 0.5 then
				goal = nil
			else
				local facing = if move.Magnitude > 0.3 then move.Unit else look
				goal = bodyAt(pet, CFrame.lookAt(position, position + facing))
			end
		end
		if goal then
			if species(pet).flying then
				goal = goal * CFrame.new(0, pet.height, 0)
			end
			if (goal.Position - pet.body.Position).Magnitude > SNAP_DISTANCE then
				setBody(pet, goal, 0)
			else
				setBody(pet, goal, FOLLOW_TICK)
			end
		end
		updateLeash(player, pet)
	end
end

function PetService.Init()
	petsFolder = Instance.new("Folder")
	petsFolder.Name = "Pets"
	petsFolder.Parent = Workspace
	shopCounter = PetBuilder.BuildShop(SHOP_ORIGIN, Workspace:FindFirstChild("Map") or Workspace)

	RemoteService.OnServerInvoke(RemoteNames.Functions.GetPets, 3, function(player)
		return buildCatalog(player)
	end)
	RemoteService.OnServerInvoke(RemoteNames.Functions.BuyPet, 2, function(player, speciesId)
		local ok, message = buy(player, speciesId)
		if ok then
			StateService.Notify(player, message, "good")
		end
		return { ok = ok, message = message, catalog = buildCatalog(player) }
	end)
	RemoteService.OnServerEvent(RemoteNames.Events.PetAction, 4, onPetAction)

	-- Po przeprowadzce zwierzaki z domu (i klatka chomika) jadą do nowego mieszkania
	ApartmentService.OnMoved(function(player)
		local list = owned[player]
		if list then
			for _, pet in list do
				if pet.entry.home or not species(pet).follow then
					sendHome(player, pet)
				end
			end
		end
	end)
end

function PetService.Start()
	Players.PlayerRemoving:Connect(despawnAll)
	task.spawn(function()
		while true do
			task.wait(FOLLOW_TICK)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(tickPlayer, player)
				if not ok then
					warn("[PetService] " .. tostring(err))
				end
			end
		end
	end)
end

-- Do testów (DebugService): usuwa wszystkie zwierzaki gracza
function PetService.DebugReset(player: Player)
	local data = DataService.Get(player)
	if data then
		despawnAll(player)
		data.pets = {}
		data.nextPetId = 1
	end
end

return PetService

-- Ogrodnik: wysoka trawa (kosi się kosiarką pchaną przed sobą) i zwiędłe kwiatki (podlewanie przytrzymaniem).
-- Na czas zmiany postać dostaje kosiarkę przyspawaną do HumanoidRootPart, a IKControl kładzie dłonie na rączce
-- (C0 stawów jest tylko do odczytu, więc ręce ustawia IK, a nie obrót barków).
-- Trawa odrasta, a kwiatki znowu więdną, więc pracy starcza do końca zmiany.
-- Serwer sam sprawdza pozycję gracza; ruch szybszy niż maxSpeed (teleport) nie kosi trawy.
-- Punkty: kępa trawy = 1, kwiatek = 2 (trzeba się zatrzymać i podlać).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local AssetsConfig = require(ReplicatedStorage.Shared.Config.AssetsConfig)
local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local HoldPrompt = require(ServerScriptService.Lib.HoldPrompt)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local JobService = require(Services.JobService)

local GardenerJob = {
	JobId = "gardener",
}

local CONFIG = JobsConfig.Jobs.gardener
local CELL = 4
local GROUND_Y = 0.3
local FLOWER_POINTS = 2
local MOWER_AHEAD = 3.4 -- środek kosiarki przed postacią (studs)
local COLORS = {
	tallGrass = Color3.fromRGB(55, 150, 45),
	mowed = Color3.fromRGB(150, 225, 110),
	mowedAlt = Color3.fromRGB(115, 200, 85),
	mowerBody = Color3.fromRGB(255, 70, 70),
	mowerTrim = Color3.fromRGB(255, 210, 50),
	mowerWheel = Color3.fromRGB(40, 40, 50),
	mowerHandle = Color3.fromRGB(235, 235, 245),
	mowerBag = Color3.fromRGB(80, 200, 255),
	clippings = Color3.fromRGB(120, 230, 80),
	pot = Color3.fromRGB(230, 110, 70),
	potRim = Color3.fromRGB(255, 160, 110),
	stem = Color3.fromRGB(70, 175, 60),
	stemWilted = Color3.fromRGB(130, 130, 70),
	center = Color3.fromRGB(255, 205, 40),
	wilted = Color3.fromRGB(150, 120, 85),
	bloom = { Color3.fromRGB(255, 90, 150), Color3.fromRGB(255, 210, 60), Color3.fromRGB(160, 110, 255) },
}

local area = nil
local rng = Random.new()

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function report(session)
	local state = session.state
	local points = state.mowed + state.watered * FLOWER_POINTS
	local hint = string.format("Skoszone: %d   Podlane: %d", state.mowed, state.watered)
	if points >= state.target then
		hint ..= "\nCel osiągnięty! Dalej = premia"
	end
	JobService.UpdateProgress(session, points, state.target, hint)
end

local function setGrassTall(patch, tall: boolean)
	JobService.SetGuideTarget(patch.part, if tall then "🌱 Skoś trawę" else nil)
	if tall then
		patch.part.Size = Vector3.new(3.6, 1.4, 3.6)
		patch.part.Position = patch.position + Vector3.new(0, GROUND_Y + 0.7, 0)
		patch.part.Color = COLORS.tallGrass
	else
		patch.part.Size = Vector3.new(3.6, 0.15, 3.6)
		patch.part.Position = patch.position + Vector3.new(0, GROUND_Y + 0.08, 0)
		-- Pasy jak na prawdziwym trawniku
		patch.part.Color = if patch.stripe then COLORS.mowedAlt else COLORS.mowed
	end
end

local function mowerPart(model: Model, name: string, size: Vector3, color: Color3, root: BasePart, offset: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

-- Drążek między dwoma punktami (współrzędne względem HumanoidRootPart)
local function mowerBar(model: Model, root: BasePart, from: Vector3, to: Vector3)
	local offset = CFrame.lookAt((from + to) / 2, to)
	return mowerPart(model, "Handle", Vector3.new(0.22, 0.22, (to - from).Magnitude), COLORS.mowerHandle, root, offset)
end

-- Kosiarka przed postacią + ręce wyciągnięte do rączki. Widzą ją wszyscy gracze.
local function attachMower(session)
	local character = session.player.Character
	local root = getRoot(session.player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	-- Odległość do ziemi mierzona promieniem (wzór z HipHeight nie pasuje do każdego awatara)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, Workspace:FindFirstChild("JobObjects") }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	local ground = if hit then root.Position.Y - hit.Position.Y
		elseif humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2
		else 3
	local model = Instance.new("Model")
	model.Name = "Lawnmower"
	local z = -MOWER_AHEAD
	local deck = mowerPart(model, "Deck", Vector3.new(2.6, 0.9, 2.4), COLORS.mowerBody, root, CFrame.new(0, -ground + 0.75, z))
	mowerPart(model, "Hood", Vector3.new(1.8, 0.5, 1.6), COLORS.mowerTrim, root, CFrame.new(0, -ground + 1.45, z))
	mowerPart(model, "Engine", Vector3.new(0.9, 0.5, 0.9), COLORS.mowerWheel, root, CFrame.new(0, -ground + 1.95, z))
	for _, x in { -1.4, 1.4 } do
		for _, dz in { -0.9, 0.9 } do
			local wheel = mowerPart(model, "Wheel", Vector3.new(0.4, 0.9, 0.9), COLORS.mowerWheel, root, CFrame.new(x, -ground + 0.45, z + dz))
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	mowerPart(model, "Bag", Vector3.new(1.6, 1, 1.2), COLORS.mowerBag, root, CFrame.new(0, -ground + 1.1, z + 1.7))
	local grip = Vector3.new(0, 0.3, -1.7)
	for _, x in { -0.8, 0.8 } do
		mowerBar(model, root, Vector3.new(x, -ground + 1.2, z + 1), grip + Vector3.new(x, 0, 0))
	end
	-- Poprzeczka patrzy w stronę +X (w prawo od gracza), więc jej lokalne -Z to prawa strona
	local crossbar = mowerBar(model, root, grip + Vector3.new(-0.95, 0, 0), grip + Vector3.new(0.95, 0, 0))

	-- Ścinki trawy lecą spod kosiarki, gdy gracz idzie
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, -0.2, 1.2)
	attachment.Parent = deck
	local clippings = Instance.new("ParticleEmitter")
	clippings.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	clippings.Color = ColorSequence.new(COLORS.clippings)
	clippings.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) })
	clippings.Lifetime = NumberRange.new(0.4, 0.7)
	clippings.Speed = NumberRange.new(5, 9)
	clippings.SpreadAngle = Vector2.new(50, 50)
	clippings.EmissionDirection = Enum.NormalId.Top
	clippings.Acceleration = Vector3.new(0, -25, 0)
	clippings.Rate = 30
	clippings.Enabled = false
	clippings.Parent = attachment
	-- Warkot silnika kosiarki: głośniej, gdy gracz kosi (idzie), ciszej na postoju
	local engine = nil
	local soundId = AssetsConfig.Sounds.Mower
	if type(soundId) == "string" and soundId ~= "" then
		engine = Instance.new("Sound")
		engine.Name = "MowerEngine"
		engine.SoundId = soundId
		engine.Looped = true
		engine.Volume = (AssetsConfig.Volumes.Mower or 0.4) * 0.5
		engine.RollOffMaxDistance = 45
		engine.Parent = deck
		engine:Play()
	end
	model.Parent = character

	-- Dłonie na rączce (R15). Postacie R6 pchają kosiarkę bez ruchu rąk.
	local arms = {}
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		for _, side in { { name = "Right", z = -0.75 }, { name = "Left", z = 0.75 } } do
			local upper = character:FindFirstChild(side.name .. "UpperArm")
			local hand = character:FindFirstChild(side.name .. "Hand")
			if upper and hand then
				local target = Instance.new("Attachment")
				target.Name = side.name .. "Grip"
				target.Position = Vector3.new(0, 0, side.z)
				target.Parent = crossbar
				local ik = Instance.new("IKControl")
				ik.Name = "MowerGrip" .. side.name
				ik.Type = Enum.IKControlType.Position
				ik.ChainRoot = upper
				ik.EndEffector = hand
				ik.Target = target
				ik.Parent = humanoid
				table.insert(arms, ik)
			end
		end
	end

	session.state.mower = model
	session.state.clippings = clippings
	session.state.engine = engine
	session.state.arms = arms
end

local function detachMower(session)
	local state = session.state
	if state.mower then
		state.mower:Destroy()
		state.mower = nil
		state.clippings = nil
	end
	for _, ik in state.arms or {} do
		ik:Destroy()
	end
	state.arms = nil
end

local function flowerPart(parent: Instance, name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Kwiatek w doniczce: łodyga, dwa listki, żółty środek i 6 płatków. Zwiędły = zwieszona, brązowa główka.
local function spawnFlower(session, position: Vector3)
	local state = session.state
	local pot = Instance.new("Part")
	pot.Name = "FlowerPot"
	pot.Size = Vector3.new(1.4, 1.2, 1.4)
	pot.Position = position + Vector3.new(0, GROUND_Y + 0.6, 0)
	pot.Color = COLORS.pot
	pot.Material = Enum.Material.SmoothPlastic
	pot.Anchored = true
	local rim = flowerPart(pot, "Rim", Vector3.new(1.7, 0.3, 1.7), COLORS.potRim)
	rim.CFrame = CFrame.new(pot.Position + Vector3.new(0, 0.6, 0))
	local base = pot.Position + Vector3.new(0, 0.6, 0)
	local stem = flowerPart(pot, "Stem", Vector3.new(1.6, 0.2, 0.2), COLORS.stem, Enum.PartType.Cylinder)
	stem.CFrame = CFrame.new(base + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local leaves = {}
	for _, side in { -1, 1 } do
		local leaf = flowerPart(pot, "Leaf", Vector3.new(0.7, 0.12, 0.35), COLORS.stem)
		leaf.CFrame = CFrame.new(base + Vector3.new(side * 0.35, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(side * 30))
		table.insert(leaves, leaf)
	end
	local center = flowerPart(pot, "Center", Vector3.new(0.5, 0.5, 0.5), COLORS.center, Enum.PartType.Ball)
	local petals = {}
	for i = 1, 6 do
		petals[i] = flowerPart(pot, "Petal", Vector3.new(0.12, 0.7, 0.7), COLORS.wilted, Enum.PartType.Cylinder)
	end

	-- Główka: górna oś obróconej główki wyznacza kierunek kwiatka, płatki leżą w jej płaszczyźnie
	local function pose(bloomed: boolean, color: Color3)
		local top = base + Vector3.new(0, 1.6, 0)
		local head = if bloomed
			then CFrame.new(top) * CFrame.Angles(math.rad(-35), rng:NextNumber(0, math.pi * 2), 0)
			else CFrame.new(top + Vector3.new(0, -0.35, 0)) * CFrame.Angles(math.rad(-120), 0, 0)
		center.CFrame = head
		center.Color = if bloomed then COLORS.center else COLORS.wilted
		local radius = if bloomed then 0.5 else 0.35
		for i, petal in petals do
			local angle = i / #petals * math.pi * 2
			petal.Size = if bloomed then Vector3.new(0.12, 0.75, 0.75) else Vector3.new(0.12, 0.5, 0.5)
			petal.CFrame = head * CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius) * CFrame.Angles(0, 0, math.rad(90))
			petal.Color = color
		end
		stem.Color = if bloomed then COLORS.stem else COLORS.stemWilted
		for _, leaf in leaves do
			leaf.Color = stem.Color
		end
	end

	local function wilt()
		pose(false, COLORS.wilted)
		JobService.SetGuideTarget(pot, "💧 Podlej kwiatek")
	end

	-- Nowa podpowiedź przy każdym zwiędnięciu (klient ukrywa cudze podpowiedzi przy ich pojawieniu się)
	local function addPrompt()
		local prompt
		prompt = HoldPrompt.Create(pot, { action = "Podlej", object = "Kwiatek", hold = CONFIG.waterHold }, function(player)
			if player ~= session.player or not JobService.IsActive(session) or not prompt.Parent then
				return
			end
			prompt:Destroy()
			JobService.SetGuideTarget(pot, nil)
			pose(true, COLORS.bloom[rng:NextInteger(1, #COLORS.bloom)])
			state.watered += 1
			RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, center.Position, "flower", FLOWER_POINTS)
			report(session)
			task.delay(CONFIG.wiltTime, function()
				if JobService.IsActive(session) and pot.Parent then
					wilt()
					addPrompt()
				end
			end)
		end)
	end

	wilt()
	addPrompt()
	pot.Parent = session.folder
end

function GardenerJob.Init()
	area = Workspace.Map.JobSites:WaitForChild("Garden"):WaitForChild("GardenArea")
end

function GardenerJob.StartShift(session)
	local state = session.state
	state.target = session.levelConfig.patches + session.levelConfig.flowers * FLOWER_POINTS
	state.mowed = 0
	state.watered = 0
	state.patches = {}

	local columns = math.floor(area.Size.X / CELL)
	local rows = math.floor(area.Size.Z / CELL)
	local cells = {}
	for column = 0, columns - 1 do
		for row = 0, rows - 1 do
			table.insert(cells, Vector2.new(column, row))
		end
	end
	shuffle(cells)
	local corner = area.Position - Vector3.new(area.Size.X / 2, 0, area.Size.Z / 2)
	local patchCount = CONFIG.visiblePatches
	local flowerCount = session.levelConfig.flowers

	for index = 1, math.min(#cells, patchCount + flowerCount) do
		local cell = cells[index]
		local position = Vector3.new(corner.X + (cell.X + 0.5) * CELL, 0, corner.Z + (cell.Y + 0.5) * CELL)
		if index <= patchCount then
			local grass = Instance.new("Part")
			grass.Name = "TallGrass"
			grass.Material = Enum.Material.Grass
			grass.Anchored = true
			grass.CanCollide = false
			local patch = { part = grass, position = position, mowed = false, regrowAt = 0, stripe = cell.X % 2 == 0 }
			setGrassTall(patch, true)
			grass.Parent = session.folder
			table.insert(state.patches, patch)
		else
			spawnFlower(session, position)
		end
	end
	attachMower(session)
	report(session)
end

function GardenerJob.Cleanup(session)
	detachMower(session)
end

function GardenerJob.TickShift(session)
	local state = session.state
	local now = os.clock()
	for _, patch in state.patches do
		if patch.mowed and now >= patch.regrowAt then
			patch.mowed = false
			setGrassTall(patch, true)
		end
	end

	local root = getRoot(session.player)
	if not root then
		return
	end
	local position = root.Position
	local moved = 0
	if state.lastPosition then
		moved = (position - state.lastPosition).Magnitude
		local allowed = CONFIG.maxSpeed * (now - state.lastTime) + 2
		if moved > allowed then
			state.lastPosition = position
			state.lastTime = now
			return
		end
	end
	state.lastPosition = position
	state.lastTime = now
	if state.clippings then
		state.clippings.Enabled = moved > 0.3
	end
	if state.engine then
		local full = AssetsConfig.Volumes.Mower or 0.4
		state.engine.Volume = if moved > 0.3 then full else full * 0.5
		state.engine.PlaybackSpeed = if moved > 0.3 then 1.1 else 0.95
	end

	-- Kosi tylko kosiarka przed graczem (jeden pas, jak wcześniej przy koszeniu nogami)
	local mowerPoint = root.CFrame:PointToWorldSpace(Vector3.new(0, 0, -MOWER_AHEAD))
	local changed = false
	for _, patch in state.patches do
		if not patch.mowed then
			local nearMower = Vector3.new(mowerPoint.X - patch.position.X, 0, mowerPoint.Z - patch.position.Z).Magnitude
			if nearMower <= CONFIG.mowRadius then
				patch.mowed = true
				patch.regrowAt = now + CONFIG.regrowTime
				state.mowed += 1
				changed = true
				setGrassTall(patch, false)
				RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(session.player, patch.position + Vector3.new(0, GROUND_Y, 0), "grass", 1)
			end
		end
	end
	if changed then
		report(session)
	end
end

function GardenerJob.Evaluate(session): number
	local state = session.state
	return JobService.StarsFromFraction((state.mowed + state.watered * FLOWER_POINTS) / state.target)
end

return GardenerJob

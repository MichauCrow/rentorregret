-- Generuje mapę z prostych bloków: ulice, kolorowy park z butelkami i kaucjomat.
-- Ustawia też jasne, nasycone oświetlenie (gra dla dzieci: dużo kolorów).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local JobSitesBuilder = require(script.Parent.JobSitesBuilder)

local MapBuilder = {}

local COLORS = {
	street = Color3.fromRGB(75, 80, 105),
	sidewalk = Color3.fromRGB(245, 225, 200),
	line = Color3.fromRGB(255, 240, 120),
	grass = Color3.fromRGB(100, 210, 80),
	trunk = Color3.fromRGB(125, 85, 50),
	leaves = {
		Color3.fromRGB(80, 200, 80),
		Color3.fromRGB(255, 150, 200),
		Color3.fromRGB(140, 225, 60),
		Color3.fromRGB(255, 190, 70),
	},
	flowers = {
		Color3.fromRGB(255, 80, 120),
		Color3.fromRGB(255, 220, 50),
		Color3.fromRGB(160, 100, 255),
		Color3.fromRGB(80, 180, 255),
		Color3.fromRGB(255, 140, 40),
	},
	stem = Color3.fromRGB(60, 160, 60),
	bench = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(70, 160, 255), Color3.fromRGB(255, 200, 40) },
	machine = Color3.fromRGB(40, 200, 130),
	machineTrim = Color3.fromRGB(255, 210, 50),
	machineFront = Color3.fromRGB(245, 250, 255),
	screen = Color3.fromRGB(25, 35, 80),
	slot = Color3.fromRGB(25, 25, 35),
	glow = Color3.fromRGB(120, 255, 170),
	stripes = { Color3.fromRGB(255, 80, 90), Color3.fromRGB(255, 200, 40), Color3.fromRGB(70, 160, 255) },
	base = Color3.fromRGB(190, 220, 255),
	lights = { Color3.fromRGB(255, 80, 120), Color3.fromRGB(255, 220, 50), Color3.fromRGB(80, 220, 255), Color3.fromRGB(150, 255, 100) },
	sign = Color3.fromRGB(110, 60, 200),
	-- Mury miasta: tęczowe cegiełki, białe blanki, kolorowe dachy wież
	walls = {
		Color3.fromRGB(255, 140, 160),
		Color3.fromRGB(255, 190, 110),
		Color3.fromRGB(255, 235, 130),
		Color3.fromRGB(150, 230, 140),
		Color3.fromRGB(130, 200, 255),
		Color3.fromRGB(190, 160, 255),
	},
	merlon = Color3.fromRGB(255, 255, 255),
	towerRoofs = {
		Color3.fromRGB(230, 60, 110),
		Color3.fromRGB(70, 130, 255),
		Color3.fromRGB(150, 80, 230),
		Color3.fromRGB(255, 140, 30),
	},
	gate = Color3.fromRGB(150, 95, 55),
}

-- Granice murów (wszystkie ulice, prace i rzędy mieszkań są w środku)
local WALL_BOUNDS = { minX = -185, maxX = 185, minZ = -150, maxZ = 245 }
local WALL_HEIGHT = 14

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Drzewa w kilku kolorach (zielone, różowe kwitnące, jesienne): pień z korzeniami, kilka konarów
-- i korona z wielu kul różnej wielkości. scale = 1 zwykłe drzewo, więcej = rozrośnięty olbrzym.
local treeCount = 0
local treeRng = Random.new(7)
local function tree(parent: Instance, x: number, z: number, scale: number?)
	treeCount += 1
	local s = scale or 1
	local leafColor = COLORS.leaves[treeCount % #COLORS.leaves + 1]
	local model = Instance.new("Model")
	model.Name = if s > 1.5 then "BigTree" else "Tree"
	local height = 7 * s
	local base = Vector3.new(x, 0, z)
	part(model, "Trunk", Vector3.new(1.6 * s, height, 1.6 * s), base + Vector3.new(0, height / 2, 0), COLORS.trunk, Enum.Material.Wood)
	-- Korzenie wystające z ziemi
	for i = 0, 3 do
		local angle = i * math.pi / 2 + treeRng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local root = part(model, "Root", Vector3.new(0.7 * s, 0.6 * s, 2 * s), Vector3.zero, COLORS.trunk, Enum.Material.Wood)
		root.CFrame = CFrame.lookAt(base + dir * 1.1 * s + Vector3.new(0, 0.25 * s, 0), base + dir * 3 * s) * CFrame.Angles(math.rad(-12), 0, 0)
		root.CanCollide = false
	end
	-- Konary i kule liści na ich końcach
	local top = base + Vector3.new(0, height, 0)
	local branches = if s > 1.5 then 6 else 3
	for i = 1, branches do
		local angle = (i / branches) * math.pi * 2 + treeRng:NextNumber(-0.4, 0.4)
		local reach = treeRng:NextNumber(2.6, 3.6) * s
		local tip = top + Vector3.new(math.cos(angle) * reach, treeRng:NextNumber(0.8, 2.2) * s, math.sin(angle) * reach)
		local from = top - Vector3.new(0, 1.2 * s, 0)
		local branch = part(model, "Branch", Vector3.new(0.6 * s, 0.6 * s, (tip - from).Magnitude), Vector3.zero, COLORS.trunk, Enum.Material.Wood)
		branch.CFrame = CFrame.lookAt((from + tip) / 2, tip)
		branch.CanCollide = false
		local size = treeRng:NextNumber(4.2, 5.6) * s
		local leaves = part(model, "Leaves", Vector3.new(size, size, size), tip + Vector3.new(0, size * 0.25, 0), leafColor, Enum.Material.Grass)
		leaves.Shape = Enum.PartType.Ball
	end
	local crown = 6.5 * s
	local center = part(model, "Leaves", Vector3.new(crown, crown, crown), top + Vector3.new(0, 2.6 * s, 0), leafColor, Enum.Material.Grass)
	center.Shape = Enum.PartType.Ball
	local cap = part(model, "Leaves", Vector3.new(crown * 0.7, crown * 0.7, crown * 0.7), top + Vector3.new(treeRng:NextNumber(-1, 1) * s, 5 * s, treeRng:NextNumber(-1, 1) * s), leafColor:Lerp(Color3.new(1, 1, 1), 0.12), Enum.Material.Grass)
	cap.Shape = Enum.PartType.Ball
	model.Parent = parent
	return model
end

-- Trawniki między domami (z dala od ulic): krzaczki, kwiatki i rzadko butelka kaucyjna w trawie (CanCollectorJob)
local LAWNS = {
	Vector3.new(156, 0, 66), Vector3.new(-68, 0, 46), Vector3.new(82, 0, -8), Vector3.new(88, 0, 124),
	Vector3.new(161, 0, 131), Vector3.new(136, 0, 58), Vector3.new(-14, 0, 124), Vector3.new(70, 0, 58),
	Vector3.new(46, 0, 130), Vector3.new(100, 0, 64), Vector3.new(-20, 0, -62), Vector3.new(16, 0, -62),
}

-- Kwiatek bez kolizji (dekoracja)
local function flower(parent: Instance, x: number, z: number, color: Color3)
	local stem = part(parent, "Stem", Vector3.new(0.2, 1.2, 0.2), Vector3.new(x, 0.9, z), COLORS.stem, Enum.Material.SmoothPlastic)
	stem.CanCollide = false
	stem.CanQuery = false
	local head = part(parent, "Bloom", Vector3.new(0.9, 0.9, 0.9), Vector3.new(x, 1.6, z), color, Enum.Material.SmoothPlastic)
	head.Shape = Enum.PartType.Ball
	head.CanCollide = false
	head.CanQuery = false
end

local function bench(parent: Instance, x: number, z: number, color: Color3)
	part(parent, "BenchSeat", Vector3.new(5, 0.4, 1.6), Vector3.new(x, 1.6, z), color, Enum.Material.SmoothPlastic)
	part(parent, "BenchBack", Vector3.new(5, 1.6, 0.3), Vector3.new(x, 2.6, z - 0.8), color, Enum.Material.SmoothPlastic)
	for _, dx in { -2, 2 } do
		part(parent, "BenchLeg", Vector3.new(0.4, 1.3, 1.2), Vector3.new(x + dx, 0.85, z), COLORS.slot, Enum.Material.Metal)
	end
end

local function surfaceText(target: BasePart, face: Enum.NormalId, text: string)
	local surface = Instance.new("SurfaceGui")
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = surface
end

-- Park naprzeciwko kamienicy: tu pojawiają się butelki
local function buildPark(map: Instance)
	local park = Instance.new("Folder")
	park.Name = "Park"
	part(park, "Grass", Vector3.new(140, 0.3, 52), Vector3.new(0, 0.15, -23), COLORS.grass, Enum.Material.Grass)
	for x = -60, 60, 20 do
		-- Na środku jedno wielkie, rozrośnięte drzewo nad ławką
		tree(park, x, -48, if x == 0 then 2.2 else 1)
	end
	for _, z in { -40, -25, -10 } do
		tree(park, -66, z)
		tree(park, 66, z)
	end
	-- Kolorowe rabaty wzdłuż chodnika (z przerwą na kaucjomat) i ławki pod drzewami
	local index = 0
	for x = -62, 62, 2.5 do
		if math.abs(x) > 7 then
			index += 1
			flower(park, x, -0.5, COLORS.flowers[index % #COLORS.flowers + 1])
		end
	end
	for i, x in { -40, 0, 40 } do
		bench(park, x, -43, COLORS.bench[i])
	end
	-- Niewidoczny obszar, w którym CanCollectorJob losuje butelki
	local area = part(park, "CanArea", Vector3.new(120, 1, 28), Vector3.new(0, 0.5, -26), COLORS.grass, Enum.Material.SmoothPlastic)
	area.Transparency = 1
	area.CanCollide = false
	area.CanQuery = false
	area.CanTouch = false
	park.Parent = map
end

-- Kaucjomat: automat na butelki przy chodniku, front w stronę ulicy (+Z).
-- Animację wrzucania butelek i ekran z licznikiem obsługuje klient (CleanFxController).
-- Przy JobsConfig.Jobs.cans.halloween = true dostaje halloweenowy wystrój (kolory, dynie, nietoperze, pajęczyna).
local HALLOWEEN_THEME = {
	machine = Color3.fromRGB(255, 125, 30),
	machineTrim = Color3.fromRGB(120, 55, 190),
	machineFront = Color3.fromRGB(45, 30, 60),
	screen = Color3.fromRGB(20, 10, 30),
	slot = Color3.fromRGB(15, 10, 20),
	glow = Color3.fromRGB(255, 160, 40),
	stripes = { Color3.fromRGB(120, 55, 190), Color3.fromRGB(130, 230, 70), Color3.fromRGB(30, 20, 40) },
	base = Color3.fromRGB(70, 45, 95),
	lights = { Color3.fromRGB(255, 130, 20), Color3.fromRGB(160, 70, 255), Color3.fromRGB(130, 255, 80), Color3.fromRGB(255, 220, 60) },
	sign = Color3.fromRGB(30, 18, 45),
}

-- Dynia z wyciętą, świecącą buzią (przodem do +Z)
local function jackOLantern(parent: Instance, position: Vector3, size: number)
	local body = part(parent, "Pumpkin", Vector3.new(size, size, size), position, Color3.fromRGB(255, 120, 20), Enum.Material.SmoothPlastic)
	body.Shape = Enum.PartType.Ball
	part(parent, "PumpkinStem", Vector3.new(size * 0.15, size * 0.3, size * 0.15), position + Vector3.new(0, size * 0.55, 0), Color3.fromRGB(70, 140, 40), Enum.Material.Wood)
	local glow = Color3.fromRGB(255, 230, 80)
	local front = position + Vector3.new(0, 0, size * 0.47)
	for _, x in { -0.2, 0.2 } do
		local eye = part(parent, "PumpkinEye", Vector3.new(size * 0.16, size * 0.16, 0.1), front + Vector3.new(x * size, size * 0.12, 0), glow, Enum.Material.Neon)
		eye.CanCollide = false
	end
	local mouth = part(parent, "PumpkinMouth", Vector3.new(size * 0.45, size * 0.1, 0.1), front + Vector3.new(0, -size * 0.15, -0.02), glow, Enum.Material.Neon)
	mouth.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 40)
	light.Range = size * 4
	light.Brightness = 1.2
	light.Parent = body
end

-- Nietoperz na nitce, lekko podskakuje
local function bat(parent: Instance, anchorTop: Vector3, drop: number)
	local black = Color3.fromRGB(25, 20, 30)
	local string_ = part(parent, "BatString", Vector3.new(0.06, drop, 0.06), anchorTop - Vector3.new(0, drop / 2, 0), Color3.fromRGB(220, 220, 220), Enum.Material.SmoothPlastic)
	string_.CanCollide = false
	local center = anchorTop - Vector3.new(0, drop + 0.3, 0)
	local body = part(parent, "Bat", Vector3.new(0.7, 0.7, 0.7), center, black, Enum.Material.SmoothPlastic)
	body.Shape = Enum.PartType.Ball
	body.CanCollide = false
	local pieces = {}
	for _, side in { -1, 1 } do
		local wing = part(parent, "BatWing", Vector3.new(1.1, 0.12, 0.6), center + Vector3.new(side * 0.8, 0.15, 0), black, Enum.Material.SmoothPlastic)
		wing.CFrame = CFrame.new(center + Vector3.new(side * 0.8, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(side * 25))
		wing.CanCollide = false
		table.insert(pieces, wing)
		local eye = part(parent, "BatEye", Vector3.new(0.12, 0.12, 0.05), center + Vector3.new(side * 0.15, 0.1, 0.34), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
		eye.CanCollide = false
		table.insert(pieces, eye)
	end
	-- Skrzydła i oczy przyspawane do ciała, ciało kołysze się góra-dół
	for _, piece in pieces do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = piece
		weld.Parent = piece
		piece.Anchored = false
		piece.Massless = true
	end
	TweenService:Create(body, TweenInfo.new(0.9 + drop * 0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		CFrame = CFrame.new(center + Vector3.new(0, 0.4, 0)),
	}):Play()
end

-- Pajęczyna w rogu: nitki rozchodzące się z jednego punktu i dwa łuki poprzeczne
local function cobweb(parent: Instance, corner: Vector3, dirX: number)
	local white = Color3.fromRGB(235, 235, 245)
	for i = 0, 4 do
		local angle = math.rad(i * 22.5)
		local direction = Vector3.new(math.cos(angle) * dirX, -math.sin(angle), 0)
		local length = 2.2
		local thread = part(parent, "Web", Vector3.new(0.05, 0.05, length), corner + direction * length / 2, white, Enum.Material.SmoothPlastic)
		thread.CFrame = CFrame.lookAt(corner + direction * length / 2, corner + direction * length)
		thread.CanCollide = false
	end
	for _, r in { 0.9, 1.7 } do
		for i = 0, 3 do
			local a1 = math.rad(i * 22.5)
			local a2 = math.rad((i + 1) * 22.5)
			local p1 = corner + Vector3.new(math.cos(a1) * dirX, -math.sin(a1), 0) * r
			local p2 = corner + Vector3.new(math.cos(a2) * dirX, -math.sin(a2), 0) * r
			local thread = part(parent, "Web", Vector3.new(0.05, 0.05, (p2 - p1).Magnitude), (p1 + p2) / 2, white, Enum.Material.SmoothPlastic)
			thread.CFrame = CFrame.lookAt((p1 + p2) / 2, p2)
			thread.CanCollide = false
		end
	end
end

local function buildKaucjomat(map: Instance)
	local halloween = JobsConfig.Jobs.cans.halloween == true
	local theme = if halloween then HALLOWEEN_THEME else COLORS
	local machine = Instance.new("Model")
	machine.Name = "Kaucjomat"
	part(machine, "Base", Vector3.new(9, 0.3, 7), Vector3.new(0, 0.45, -5.5), theme.base, Enum.Material.SmoothPlastic)
	part(machine, "Body", Vector3.new(6, 7, 3.5), Vector3.new(0, 4.1, -6.5), theme.machine, Enum.Material.SmoothPlastic)
	part(machine, "Cap", Vector3.new(6.6, 0.6, 4.1), Vector3.new(0, 7.9, -6.5), theme.machineTrim, Enum.Material.SmoothPlastic)
	-- Kolorowe paski po bokach
	for i, color in theme.stripes do
		for _, side in { -1, 1 } do
			local stripe = part(machine, "Stripe", Vector3.new(0.1, 0.6, 3.5), Vector3.new(side * 3.05, 2 + i * 1.1, -6.5), color, Enum.Material.SmoothPlastic)
			stripe.CanCollide = false
		end
	end

	local sign = part(machine, "Sign", Vector3.new(6.6, 1.6, 0.4), Vector3.new(0, 9.1, -5.6), theme.sign, Enum.Material.SmoothPlastic)
	surfaceText(sign, Enum.NormalId.Back, if halloween then "🎃 KAUCJOMAT 🎃" else "♻ KAUCJOMAT ♻")

	-- Ekran: klient zmienia tekst podczas liczenia butelek
	local screen = part(machine, "Screen", Vector3.new(4, 1.8, 0.1), Vector3.new(0, 6, -4.72), theme.screen, Enum.Material.SmoothPlastic)
	screen.CanCollide = false
	local screenGui = Instance.new("SurfaceGui")
	screenGui.Face = Enum.NormalId.Back
	screenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	screenGui.PixelsPerStud = 60
	screenGui.LightInfluence = 0
	screenGui.Parent = screen
	local screenLabel = Instance.new("TextLabel")
	screenLabel.Name = "Label"
	screenLabel.Size = UDim2.fromScale(1, 1)
	screenLabel.BackgroundTransparency = 1
	screenLabel.Font = Enum.Font.FredokaOne
	screenLabel.TextScaled = true
	screenLabel.TextColor3 = theme.glow
	screenLabel.Text = if halloween then "WRZUĆ BUTELKI! 👻" else "WRZUĆ BUTELKI!"
	screenLabel.Parent = screenGui

	local counter = part(machine, "Counter", Vector3.new(4.6, 2.4, 0.3), Vector3.new(0, 3.6, -4.65), theme.machineFront, Enum.Material.SmoothPlastic)
	local ring = part(machine, "SlotRing", Vector3.new(0.15, 1.9, 1.9), Vector3.new(0, 3.6, -4.48), theme.glow, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(ring.Position) * CFrame.Angles(0, math.rad(90), 0)
	ring.CanCollide = false
	local slot = part(machine, "Slot", Vector3.new(0.2, 1.4, 1.4), Vector3.new(0, 3.6, -4.42), theme.slot, Enum.Material.SmoothPlastic)
	slot.Shape = Enum.PartType.Cylinder
	slot.CFrame = CFrame.new(slot.Position) * CFrame.Angles(0, math.rad(90), 0)
	slot.CanCollide = false
	local tray = part(machine, "Tray", Vector3.new(2.2, 0.5, 0.9), Vector3.new(0, 1.6, -4.4), theme.machineTrim, Enum.Material.SmoothPlastic)
	tray.CanCollide = false

	-- Migające lampki na górze
	local lamps = {}
	for i, x in { -2.6, -0.9, 0.9, 2.6 } do
		local lamp = part(machine, "Lamp", Vector3.new(0.7, 0.7, 0.7), Vector3.new(x, 8.5, -4.8), theme.lights[i], Enum.Material.Neon)
		lamp.Shape = Enum.PartType.Ball
		lamp.CanCollide = false
		table.insert(lamps, lamp)
	end
	task.spawn(function()
		local step = 0
		while machine.Parent do
			step += 1
			for i, lamp in lamps do
				lamp.Color = theme.lights[(i + step) % #theme.lights + 1]
			end
			task.wait(0.6)
		end
	end)

	if halloween then
		local decor = Instance.new("Folder")
		decor.Name = "HalloweenDecor"
		decor.Parent = machine
		jackOLantern(decor, Vector3.new(-2.3, 10.6, -5.6), 1.4)
		jackOLantern(decor, Vector3.new(2.4, 10.5, -5.6), 1.2)
		jackOLantern(decor, Vector3.new(-3.6, 1.35, -3.2), 1.6)
		jackOLantern(decor, Vector3.new(3.5, 1.2, -3), 1.3)
		jackOLantern(decor, Vector3.new(4.3, 1.05, -6.5), 1)
		bat(decor, Vector3.new(-2.4, 8.2, -4.0), 1.4)
		bat(decor, Vector3.new(2.5, 8.2, -4.0), 2.2)
		bat(decor, Vector3.new(0, 12.6, -5.6), 0.6)
		cobweb(decor, Vector3.new(-3, 7.55, -4.7), 1)
		cobweb(decor, Vector3.new(3, 7.55, -4.7), -1)
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "SellAttachment"
	attachment.Position = Vector3.new(0, 0, 1.2)
	attachment.Parent = counter
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellPrompt"
	prompt.ActionText = "Wrzuć butelki"
	prompt.ObjectText = "Kaucjomat"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = attachment

	machine.Parent = map
end

-- Okrągła wieża z pierścieniem blanków, stożkowym dachem z coraz węższych krążków i flagą
local towerCount = 0
local function tower(parent: Instance, x: number, z: number)
	towerCount += 1
	local color = COLORS.walls[towerCount % #COLORS.walls + 1]
	local roof = COLORS.towerRoofs[towerCount % #COLORS.towerRoofs + 1]
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local body = part(parent, "Tower", Vector3.new(22, 12, 12), Vector3.new(x, 11, z), color, Enum.Material.Brick)
	body.Shape = Enum.PartType.Cylinder
	body.CFrame = CFrame.new(x, 11, z) * upright
	local ring = part(parent, "TowerRing", Vector3.new(2, 13.5, 13.5), Vector3.new(x, 23, z), COLORS.merlon, Enum.Material.SmoothPlastic)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(x, 23, z) * upright
	for level = 0, 4 do
		local width = 13 - level * 2.6
		local disc = part(parent, "TowerRoof", Vector3.new(1.6, width, width), Vector3.new(x, 24.8 + level * 1.6, z), roof, Enum.Material.SmoothPlastic)
		disc.Shape = Enum.PartType.Cylinder
		disc.CFrame = CFrame.new(x, 24.8 + level * 1.6, z) * upright
	end
	part(parent, "FlagPole", Vector3.new(0.3, 5, 0.3), Vector3.new(x, 34, z), COLORS.merlon, Enum.Material.SmoothPlastic)
	part(parent, "TowerFlag", Vector3.new(0.15, 1.6, 2.6), Vector3.new(x, 35.6, z + 1.4), COLORS.flowers[towerCount % #COLORS.flowers + 1], Enum.Material.Fabric)
end

-- Odcinek muru z tęczowych segmentów, białymi blankami i proporczykami
local segmentCount = 0
local function wallLine(parent: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local count = math.max(1, math.floor(length / 10))
	local step = length / count
	local direction = (to - from).Unit
	for i = 0, count - 1 do
		segmentCount += 1
		local mid = from + direction * (step * (i + 0.5))
		local frame = CFrame.lookAt(mid, mid + direction)
		local segment = part(parent, "Wall", Vector3.new(4, WALL_HEIGHT, step), Vector3.zero, COLORS.walls[segmentCount % #COLORS.walls + 1], Enum.Material.Brick)
		segment.CFrame = frame * CFrame.new(0, WALL_HEIGHT / 2, 0)
		for _, d in { -step / 4, step / 4 } do
			local merlon = part(parent, "Merlon", Vector3.new(4.4, 2.4, step / 4), Vector3.zero, COLORS.merlon, Enum.Material.SmoothPlastic)
			merlon.CFrame = frame * CFrame.new(0, WALL_HEIGHT + 1.2, d)
		end
		if segmentCount % 3 == 0 then
			local pennant = Instance.new("WedgePart")
			pennant.Name = "Pennant"
			pennant.Size = Vector3.new(0.15, 1.4, 2.2)
			pennant.CFrame = frame * CFrame.new(0, WALL_HEIGHT + 4.2, 1.1) * CFrame.Angles(math.rad(180), 0, 0)
			pennant.Color = COLORS.flowers[segmentCount % #COLORS.flowers + 1]
			pennant.Material = Enum.Material.Fabric
			pennant.Anchored = true
			pennant.CanCollide = false
			pennant.Parent = parent
			local pole = part(parent, "PennantPole", Vector3.new(0.2, 3.2, 0.2), Vector3.zero, COLORS.merlon, Enum.Material.SmoothPlastic)
			pole.CFrame = frame * CFrame.new(0, WALL_HEIGHT + 3.4, 0)
			pole.CanCollide = false
		end
	end
end

-- Brama zamkowa (dekoracja na wewnętrznej stronie muru): kamienny łuk z wrotami, szyld w złotej ramie
-- i dwa wiszące sztandary z kluczem po bokach. Wieże stoją obok bramy, żeby niczego nie zasłaniały.
local GATE_STONE = Color3.fromRGB(245, 238, 225)
local GATE_GOLD = Color3.fromRGB(255, 205, 60)
local BANNER_COLORS = { Color3.fromRGB(215, 50, 90), Color3.fromRGB(60, 110, 230) }
local function castleGate(parent: Instance, x: number, z: number, facing: number)
	local frame = CFrame.new(x, 0, z) * CFrame.Angles(0, facing, 0)
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, collide: boolean?)
		local p = part(parent, name, size, Vector3.zero, color, material)
		p.CFrame = frame * offset
		p.CanCollide = collide == true
		return p
	end
	-- Łuk: dwa filary i nadproże z kamienia
	for _, side in { -1, 1 } do
		piece("GatePillar", Vector3.new(2.4, 14, 1.4), CFrame.new(side * 7.6, 7, -2.5), GATE_STONE, Enum.Material.Limestone, true)
		piece("GatePillarCap", Vector3.new(3, 0.8, 1.8), CFrame.new(side * 7.6, 14.4, -2.5), GATE_STONE, Enum.Material.Limestone)
	end
	piece("GateLintel", Vector3.new(17.6, 3.4, 1.4), CFrame.new(0, 12.9, -2.5), GATE_STONE, Enum.Material.Limestone, true)
	local door = piece("GateDoor", Vector3.new(12.8, 11.2, 0.6), CFrame.new(0, 5.6, -2.2), COLORS.gate, Enum.Material.WoodPlanks, true)
	door.Name = "GateDoor"
	for _, y in { 2.5, 8.5 } do
		piece("GateBand", Vector3.new(12.9, 0.5, 0.7), CFrame.new(0, y, -2.3), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	end
	for _, dx in { -1.2, 1.2 } do
		local ring = piece("GateRing", Vector3.new(0.2, 1.1, 1.1), CFrame.new(dx, 5.2, -2.6) * CFrame.Angles(0, math.rad(90), 0), GATE_GOLD, Enum.Material.Metal)
		ring.Shape = Enum.PartType.Cylinder
	end
	-- Szyld z nazwą w złotej ramie na nadprożu
	local board = piece("GateSign", Vector3.new(15, 2.4, 0.4), CFrame.new(0, 12.9, -3.35), COLORS.sign, Enum.Material.SmoothPlastic)
	surfaceText(board, Enum.NormalId.Front, "🏰 RENT OR REGRET 🏰")
	piece("GateSignFrame", Vector3.new(15.6, 0.3, 0.5), CFrame.new(0, 14.2, -3.35), GATE_GOLD, Enum.Material.Metal)
	piece("GateSignFrame", Vector3.new(15.6, 0.3, 0.5), CFrame.new(0, 11.6, -3.35), GATE_GOLD, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		piece("GateSignFrame", Vector3.new(0.3, 2.9, 0.5), CFrame.new(side * 7.65, 12.9, -3.35), GATE_GOLD, Enum.Material.Metal)
	end
	-- Sztandary na murze po obu stronach bramy
	for index, side in { -1, 1 } do
		local bx = side * 12.5
		piece("BannerRod", Vector3.new(4.6, 0.3, 0.3), CFrame.new(bx, 13.3, -2.6), GATE_GOLD, Enum.Material.Metal)
		for _, ex in { -2.4, 2.4 } do
			local knob = piece("BannerKnob", Vector3.new(0.6, 0.6, 0.6), CFrame.new(bx + ex, 13.3, -2.6), GATE_GOLD, Enum.Material.Metal)
			knob.Shape = Enum.PartType.Ball
		end
		local cloth = piece("Banner", Vector3.new(3.8, 7, 0.15), CFrame.new(bx, 9.6, -2.3), BANNER_COLORS[index], Enum.Material.Fabric)
		piece("BannerStripe", Vector3.new(3.8, 0.4, 0.17), CFrame.new(bx, 12.6, -2.3), GATE_GOLD, Enum.Material.Fabric)
		piece("BannerStripe", Vector3.new(3.8, 0.4, 0.17), CFrame.new(bx, 6.6, -2.3), GATE_GOLD, Enum.Material.Fabric)
		-- Dwa trójkątne "ogonki" na dole
		for _, tx in { -0.95, 0.95 } do
			local tail = Instance.new("WedgePart")
			tail.Name = "BannerTail"
			tail.Size = Vector3.new(0.15, 1.4, 1.9)
			tail.CFrame = frame * CFrame.new(bx + tx, 5.4, -2.3) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(180), 0, 0)
			tail.Color = BANNER_COLORS[index]
			tail.Material = Enum.Material.Fabric
			tail.Anchored = true
			tail.CanCollide = false
			tail.Parent = parent
		end
		local emblem = Instance.new("SurfaceGui")
		emblem.Face = Enum.NormalId.Front
		emblem.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		emblem.PixelsPerStud = 40
		emblem.Parent = cloth
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromScale(1, 0.6)
		icon.Position = UDim2.fromScale(0, 0.2)
		icon.BackgroundTransparency = 1
		icon.TextScaled = true
		icon.Text = if index == 1 then "🔑" else "🏠"
		icon:SetAttribute("NoTranslate", true)
		icon.Parent = emblem
	end
end

local function buildCityWalls(map: Instance)
	local walls = Instance.new("Folder")
	walls.Name = "CityWalls"
	local b = WALL_BOUNDS
	local corners = {
		Vector3.new(b.minX, 0, b.minZ),
		Vector3.new(b.maxX, 0, b.minZ),
		Vector3.new(b.maxX, 0, b.maxZ),
		Vector3.new(b.minX, 0, b.maxZ),
	}
	local GATE_Z = 16
	for i, from in corners do
		local to = corners[i % #corners + 1]
		wallLine(walls, from, to)
		tower(walls, from.X, from.Z)
		-- Dodatkowe wieże co ok. 95 studów (ale nie w miejscu bram, żeby nie zasłaniały szyldu)
		local length = (to - from).Magnitude
		local extra = math.floor(length / 95)
		for k = 1, extra do
			local point = from:Lerp(to, k / (extra + 1))
			local nearGate = (math.abs(point.X - b.minX) < 1 or math.abs(point.X - b.maxX) < 1) and math.abs(point.Z - GATE_Z) < 30
			if not nearGate then
				tower(walls, point.X, point.Z)
			end
		end
	end
	-- Bramy na końcach głównej ulicy (wschód i zachód), z wieżami po bokach
	for _, gateX in { b.minX, b.maxX } do
		castleGate(walls, gateX, GATE_Z, math.rad(if gateX < 0 then -90 else 90))
		tower(walls, gateX, GATE_Z - 22)
		tower(walls, gateX, GATE_Z + 22)
	end
	walls.Parent = map
end

-- Kosze na śmieci do przeszukiwania (minigra i nagrody: CanCollectorJob + TrashSearchController)
local TRASH_BINS = {
	Vector3.new(-40, 0.4, 7), Vector3.new(40, 0.4, 7), Vector3.new(6, 0.3, -40),
	Vector3.new(-30, 0.4, 109), Vector3.new(58, 0.4, 109), Vector3.new(20, 0.4, -97), Vector3.new(10, 0.4, 185),
}
local function buildTrashBins(map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "TrashBins"
	local upright = CFrame.Angles(0, 0, math.rad(90))
	for index, position in TRASH_BINS do
		local bin = Instance.new("Model")
		bin.Name = "SearchBin_" .. index
		local body = part(bin, "Body", Vector3.new(2.6, 2.2, 2.2), position + Vector3.new(0, 1.3, 0), Color3.fromRGB(60, 175, 95), Enum.Material.SmoothPlastic)
		body.Shape = Enum.PartType.Cylinder
		body.CFrame = CFrame.new(body.Position) * upright
		local band = part(bin, "Band", Vector3.new(0.4, 2.3, 2.3), position + Vector3.new(0, 1.9, 0), Color3.fromRGB(255, 210, 50), Enum.Material.SmoothPlastic)
		band.Shape = Enum.PartType.Cylinder
		band.CFrame = CFrame.new(band.Position) * upright
		band.CanCollide = false
		local lid = part(bin, "Lid", Vector3.new(0.35, 2.5, 2.5), position + Vector3.new(0, 2.75, 0), Color3.fromRGB(255, 210, 50), Enum.Material.SmoothPlastic)
		lid.Shape = Enum.PartType.Cylinder
		lid.CFrame = CFrame.new(lid.Position) * upright
		part(bin, "Handle", Vector3.new(0.9, 0.25, 0.25), position + Vector3.new(0, 3.05, 0), Color3.fromRGB(40, 40, 50), Enum.Material.SmoothPlastic).CanCollide = false
		bin.PrimaryPart = body
		bin.Parent = folder
	end
	folder.Parent = map
end

local function buildLawns(map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Lawns"
	local upright = CFrame.Angles(0, 0, math.rad(90))
	for index, center in LAWNS do
		local lawn = part(folder, "Lawn", Vector3.new(0.24, 12, 12), center, COLORS.grass, Enum.Material.Grass)
		lawn.Shape = Enum.PartType.Cylinder
		lawn.CFrame = CFrame.new(center + Vector3.new(0, 0.12, 0)) * upright
		lawn.CanCollide = false
		lawn:SetAttribute("LawnIndex", index)
		for k = 1, 2 do
			local angle = index * 1.7 + k * 2.6
			local bush = part(folder, "Bush", Vector3.new(2.6, 2.2, 2.6), center + Vector3.new(math.cos(angle) * 4, 0.9, math.sin(angle) * 4), COLORS.leaves[(index + k) % 2 + 1]:Lerp(Color3.fromRGB(60, 170, 70), 0.6), Enum.Material.Grass)
			bush.Shape = Enum.PartType.Ball
		end
		for k = 1, 5 do
			local angle = k * 1.25 + index
			flower(folder, center.X + math.cos(angle) * 5.2, center.Z + math.sin(angle) * 5.2, COLORS.flowers[(index + k) % #COLORS.flowers + 1])
		end
	end
	folder.Parent = map
end

-- Drogi wzdłuż murów (wschód i zachód): łączą końce wszystkich ulic. Na rogach (Śródmieście i Wzgórze) ulica
-- skręca łukiem, ulica tylna dochodzi do drogi (skrzyżowanie w kształcie T), a główna przecina ją i biegnie do bramy.
local RING_X = 173 -- oś drogi przy murze (między zoo sklepem a wieżami)
local RING_WIDTH = 12
local STREET_END = 160 -- tu kończą się proste ulice
local function buildRingRoads(map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "RingRoads"
	local radius = RING_X - STREET_END
	local bottom, top = -88, 176 -- ulice dzielnic na końcach drogi
	local function piece(name: string, from: Vector3, to: Vector3, width: number)
		local length = (to - from).Magnitude
		local road = part(folder, name, Vector3.new(width, 0.2, length), Vector3.zero, COLORS.street, Enum.Material.Asphalt)
		road.CFrame = CFrame.lookAt((from + to) / 2, to)
		return road
	end
	local function dash(position: Vector3, toward: Vector3, length: number)
		local line = part(folder, "Line", Vector3.new(0.5, 0.05, length), Vector3.zero, COLORS.line, Enum.Material.SmoothPlastic)
		line.CFrame = CFrame.lookAt(position, toward)
		line.CanCollide = false
	end
	for _, side in { -1, 1 } do
		local x = side * RING_X
		-- Prosty odcinek między łukami
		local y = 0.1
		piece("RingRoad", Vector3.new(x, y, bottom + radius - 0.3), Vector3.new(x, y, top - radius + 0.3), RING_WIDTH)
		for z = bottom + radius + 6, top - radius - 6, 10 do
			if math.abs(z - 16) > 12 and math.abs(z - 100) > 10 then
				dash(Vector3.new(x, 0.22, z), Vector3.new(x, 0.22, z + 1), 4)
			end
		end
		-- Łuki na rogach: ulica dzielnicy (szer. 14) płynnie przechodzi w drogę przy murze (szer. 12)
		for _, corner in { { z = bottom, dz = 1 }, { z = top, dz = -1 } } do
			local center = Vector3.new(side * STREET_END, y, corner.z + corner.dz * radius)
			local fromAngle = math.atan2(corner.z - center.Z, 0)
			local toAngle = math.atan2(0, side * radius)
			local diff = (toAngle - fromAngle + math.pi) % (math.pi * 2) - math.pi
			local segments = 10
			for i = 1, segments do
				local a0 = fromAngle + diff * (i - 1) / segments
				local a1 = fromAngle + diff * i / segments
				local p0 = center + Vector3.new(math.cos(a0), 0, math.sin(a0)) * radius
				local p1 = center + Vector3.new(math.cos(a1), 0, math.sin(a1)) * radius
				local along = (p1 - p0).Unit * 0.35
				local width = 14 - (14 - RING_WIDTH) * (i - 0.5) / segments
				piece("RingCurve", p0 - along, p1 + along, width)
				if i % 2 == 0 then
					local mid = (p0 + p1) / 2 + Vector3.new(0, 0.12, 0)
					dash(mid, mid + (p1 - p0), (p1 - p0).Magnitude * 0.8)
				end
			end
		end
		-- Ulica tylna dochodzi do drogi, główna przecina ją i biegnie do bramy w murze
		piece("StreetLink", Vector3.new(side * (STREET_END - 0.5), y, 100), Vector3.new(side * (RING_X - RING_WIDTH / 2 + 0.5), y, 100), 14)
		piece("StreetLink", Vector3.new(side * (STREET_END - 0.5), y, 16), Vector3.new(side * 183, y, 16), 16)
		dash(Vector3.new(side * 163, 0.22, 16), Vector3.new(side * 164, 0.22, 16), 4)
		dash(Vector3.new(side * 182, 0.22, 16), Vector3.new(side * 183, 0.22, 16), 2)
	end
	folder.Parent = map
end

local function applyLighting()
	Lighting.ClockTime = 13
	-- Ambient oświetla wnętrza (mieszkania): umiarkowany, żeby ciepłe lampy dawały przytulny klimat
	Lighting.Ambient = Color3.fromRGB(78, 72, 88)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 170)
	local correction = Lighting:FindFirstChild("KidsColors") or Instance.new("ColorCorrectionEffect")
	correction.Name = "KidsColors"
	correction.Saturation = 0.3
	correction.Contrast = 0.08
	correction.Brightness = 0.03
	correction.Parent = Lighting
	-- Rozmycie tła utrudnia dzieciom wypatrzenie butelek i celów
	local blur = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if blur then
		blur.Enabled = false
	end
end

function MapBuilder.Build()
	if Workspace:FindFirstChild("Map") then
		return
	end
	applyLighting()
	local map = Instance.new("Folder")
	map.Name = "Map"

	part(map, "Street", Vector3.new(320, 0.2, 16), Vector3.new(0, 0.1, 16), COLORS.street, Enum.Material.Asphalt)
	part(map, "SidewalkNorth", Vector3.new(320, 0.4, 5), Vector3.new(0, 0.2, 26.5), COLORS.sidewalk, Enum.Material.Concrete)
	part(map, "SidewalkSouth", Vector3.new(320, 0.4, 5), Vector3.new(0, 0.2, 5.5), COLORS.sidewalk, Enum.Material.Concrete)
	for x = -150, 150, 10 do
		local line = part(map, "Line", Vector3.new(4, 0.05, 0.5), Vector3.new(x, 0.22, 16), COLORS.line, Enum.Material.SmoothPlastic)
		line.CanCollide = false
	end
	-- Tylna ulica za kamienicą (prace od miesiąca 5)
	part(map, "BackStreet", Vector3.new(320, 0.2, 14), Vector3.new(0, 0.1, 100), COLORS.street, Enum.Material.Asphalt)
	part(map, "BackSidewalk", Vector3.new(320, 0.4, 4), Vector3.new(0, 0.2, 109), COLORS.sidewalk, Enum.Material.Concrete)
	for x = -150, 150, 10 do
		local line = part(map, "Line", Vector3.new(4, 0.05, 0.5), Vector3.new(x, 0.22, 100), COLORS.line, Enum.Material.SmoothPlastic)
		line.CanCollide = false
	end
	-- Ulice dzielnic z lepszymi mieszkaniami: Śródmieście (południe) i Wzgórze (północ)
	for _, district in { { name = "ŚRÓDMIEŚCIE", z = -88, sidewalkZ = -97 }, { name = "WZGÓRZE", z = 176, sidewalkZ = 185 } } do
		part(map, "DistrictStreet", Vector3.new(320, 0.2, 14), Vector3.new(0, 0.1, district.z), COLORS.street, Enum.Material.Asphalt)
		part(map, "DistrictSidewalk", Vector3.new(320, 0.4, 4), Vector3.new(0, 0.2, district.sidewalkZ), COLORS.sidewalk, Enum.Material.Concrete)
		for x = -150, 150, 10 do
			local line = part(map, "Line", Vector3.new(4, 0.05, 0.5), Vector3.new(x, 0.22, district.z), COLORS.line, Enum.Material.SmoothPlastic)
			line.CanCollide = false
		end
		for _, x in { -165, 165 } do
			part(map, "DistrictPost", Vector3.new(0.6, 6, 0.6), Vector3.new(x, 3, district.z - 9), COLORS.trunk, Enum.Material.Wood)
			local board = part(map, "DistrictSign", Vector3.new(10, 2, 0.3), Vector3.new(x, 6.5, district.z - 9), COLORS.sign, Enum.Material.SmoothPlastic)
			surfaceText(board, Enum.NormalId.Front, district.name)
			surfaceText(board, Enum.NormalId.Back, district.name)
		end
	end

	buildRingRoads(map)
	buildPark(map)
	buildLawns(map)
	buildKaucjomat(map)
	buildCityWalls(map)
	buildTrashBins(map)
	JobSitesBuilder.Build(map)

	map.Parent = Workspace
end

return MapBuilder

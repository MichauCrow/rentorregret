-- Buduje mieszkanie z bloków według wymiarów typu (Klitka, Z balkonem, Loft) oraz modele brudu.
-- Układ (lokalnie): front z drzwiami na -Z, łazienka w prawym tylnym rogu, kuchnia przy tylnej ścianie po lewej.
-- Nazwy części (KitchenSink, Toilet, Fridge, LightSwitch, Lamp, FuseBoxSpot...) są używane przez awarie.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ApartmentConfig = require(ReplicatedStorage.Shared.Config.ApartmentConfig)

local ApartmentBuilder = {}

local THICKNESS = 1
local FLOOR_TOP = 1
local DOOR_WIDTH, DOOR_HEIGHT = 5, 9

local COLORS = {
	brick = Color3.fromRGB(200, 105, 85),
	ceiling = Color3.fromRGB(245, 240, 225),
	bathroomFloor = Color3.fromRGB(165, 200, 215),
	door = Color3.fromRGB(120, 80, 50),
	knob = Color3.fromRGB(255, 200, 60),
	window = Color3.fromRGB(150, 210, 255),
	counter = Color3.fromRGB(200, 200, 210),
	metal = Color3.fromRGB(90, 95, 105),
	mattress = Color3.fromRGB(110, 120, 150),
	bedFrame = Color3.fromRGB(140, 95, 60),
	blanket = Color3.fromRGB(90, 160, 220),
	white = Color3.fromRGB(245, 245, 245),
	sign = Color3.fromRGB(45, 35, 85),
	lamp = Color3.fromRGB(255, 240, 200),
	beam = Color3.fromRGB(90, 65, 50),
	railing = Color3.fromRGB(60, 60, 70),
	trash = Color3.fromRGB(60, 95, 50),
	stain = Color3.fromRGB(115, 80, 40),
	plate = Color3.fromRGB(235, 230, 215),
	sauce = Color3.fromRGB(200, 70, 40),
	fridge = Color3.fromRGB(230, 240, 245),
	bug = Color3.fromRGB(40, 30, 25),
	mold = Color3.fromRGB(90, 130, 60),
	-- Wystrój wnętrza
	trim = Color3.fromRGB(250, 246, 236),
	shade = Color3.fromRGB(255, 236, 205),
	bulb = Color3.fromRGB(255, 225, 170),
	lampLight = Color3.fromRGB(255, 200, 145),
	cord = Color3.fromRGB(60, 55, 55),
	cabinet = Color3.fromRGB(242, 238, 230),
	tile = Color3.fromRGB(205, 232, 245),
	frame = Color3.fromRGB(120, 85, 60),
	mirror = Color3.fromRGB(200, 225, 240),
	curtains = { Color3.fromRGB(230, 120, 90), Color3.fromRGB(90, 140, 220), Color3.fromRGB(130, 95, 180) },
	paintings = {
		{ Color3.fromRGB(120, 200, 255), Color3.fromRGB(110, 200, 110), Color3.fromRGB(255, 220, 90) },
		{ Color3.fromRGB(255, 160, 120), Color3.fromRGB(255, 220, 150), Color3.fromRGB(200, 90, 120) },
	},
}

local rng = Random.new()

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Ciepłe, przytłumione światło (klimat jak przy wyłączonych lampach). Awarię światła robi dużo
-- ciemniejszą klient (ApartmentLightController przyciemnia wnętrze, gdy lampy są wyłączone).
local function addLight(parent: BasePart, range: number)
	local light = Instance.new("PointLight")
	light.Range = range * 0.8
	light.Brightness = 0.3
	light.Color = COLORS.lampLight
	light.Shadows = true
	light.Parent = parent
end

-- Elewacje kamienicy: kolejne mieszkania w rzędzie mają różne kolory (liczone z pozycji, więc dobudowane
-- piętra pasują do parteru). Okładziny są tylko od zewnątrz: wnętrze i malowanie ścian się nie zmieniają.
local FACADES = {
	{ color = Color3.fromRGB(196, 98, 78), material = Enum.Material.Brick },
	{ color = Color3.fromRGB(240, 226, 196), material = Enum.Material.SmoothPlastic },
	{ color = Color3.fromRGB(176, 205, 178), material = Enum.Material.SmoothPlastic },
	{ color = Color3.fromRGB(222, 150, 105), material = Enum.Material.Brick },
	{ color = Color3.fromRGB(178, 204, 230), material = Enum.Material.SmoothPlastic },
}
local DOOR_COLORS = {
	Color3.fromRGB(40, 95, 75),
	Color3.fromRGB(45, 65, 115),
	Color3.fromRGB(135, 45, 50),
	Color3.fromRGB(62, 62, 70),
	Color3.fromRGB(150, 100, 60),
}
local STONE = Color3.fromRGB(242, 238, 228)
local DARK = Color3.fromRGB(62, 60, 66)
local FLOWERS = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 215, 60), Color3.fromRGB(170, 110, 255), Color3.fromRGB(255, 255, 255) }

local function facadeFor(origin: CFrame)
	local p = origin.Position
	local index = (math.floor(p.X / 10 + 0.5) + math.floor(p.Z / 10 + 0.5) * 3) % #FACADES + 1
	return FACADES[index], index
end

-- Ozdoba bez kolizji
local function deco(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): BasePart
	local p = part(parent, name, size, cframe, color, material)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	return p
end

-- Okładzina boków i tyłu od zewnątrz (od bottomY do topY); list = opcjonalna lista na części (etapy budowy)
local function cladding(parent: Instance, at, width: number, depth: number, bottomY: number, topY: number, facade, list)
	local h = topY - bottomY
	local mid = (bottomY + topY) / 2
	local parts = {
		deco(parent, "Cladding", Vector3.new(0.12, h, depth + 0.24), at(-width / 2 - 0.06, mid, 0), facade.color, facade.material),
		deco(parent, "Cladding", Vector3.new(0.12, h, depth + 0.24), at(width / 2 + 0.06, mid, 0), facade.color, facade.material),
		deco(parent, "Cladding", Vector3.new(width, h, 0.12), at(0, mid, depth / 2 + 0.06), facade.color, facade.material),
	}
	for _, p in parts do
		if list then
			table.insert(list, p)
		end
	end
end

-- Okno od ulicy: kamienna opaska, krzyż szprosów, parapet ze skrzynką kwiatów i (gdy jest miejsce) okiennice.
-- faceZ = zewnętrzne lico ściany frontowej
local function streetWindow(parent: Instance, at, cx: number, cy: number, w: number, h: number, faceZ: number, shutterColor: Color3?, list)
	local function add(p: BasePart)
		if list then
			table.insert(list, p)
		end
	end
	local z = faceZ - 0.12
	for _, dy in { -h / 2, h / 2 } do
		add(deco(parent, "WindowTrim", Vector3.new(w + 0.6, 0.3, 0.25), at(cx, cy + dy, z), STONE))
	end
	for _, dx in { -w / 2, w / 2 } do
		add(deco(parent, "WindowTrim", Vector3.new(0.3, h + 0.6, 0.25), at(cx + dx, cy, z), STONE))
	end
	add(deco(parent, "WindowBar", Vector3.new(0.16, h, 0.16), at(cx, cy, z), STONE))
	add(deco(parent, "WindowBar", Vector3.new(w, 0.16, 0.16), at(cx, cy + h * 0.15, z), STONE))
	add(deco(parent, "WindowSill", Vector3.new(w + 1, 0.25, 0.7), at(cx, cy - h / 2 - 0.3, faceZ - 0.35), STONE))
	add(deco(parent, "FlowerBox", Vector3.new(w - 0.2, 0.6, 0.6), at(cx, cy - h / 2 - 0.75, faceZ - 0.4), Color3.fromRGB(120, 80, 55), Enum.Material.Wood))
	for i = 0, 4 do
		local fx = cx - (w - 0.8) / 2 + i * (w - 0.8) / 4
		add(deco(parent, "FlowerLeaves", Vector3.new(0.6, 0.6, 0.6), at(fx, cy - h / 2 - 0.3, faceZ - 0.45), Color3.fromRGB(70, 160, 70), Enum.Material.Grass, Enum.PartType.Ball))
		add(deco(parent, "Flower", Vector3.new(0.35, 0.35, 0.35), at(fx + 0.12, cy - h / 2 - 0.02, faceZ - 0.55), FLOWERS[i % #FLOWERS + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball))
	end
	if shutterColor then
		for _, side in { -1, 1 } do
			local sx = cx + side * (w / 2 + 0.95)
			add(deco(parent, "Shutter", Vector3.new(1.3, h + 0.4, 0.15), at(sx, cy, faceZ - 0.1), shutterColor, Enum.Material.WoodPlanks))
			for _, dy in { -h / 4, h / 4 } do
				add(deco(parent, "ShutterSlat", Vector3.new(1, 0.12, 0.05), at(sx, cy + dy, faceZ - 0.2), shutterColor:Lerp(Color3.new(0, 0, 0), 0.25)))
			end
		end
	end
end

-- Dach z attyką (na parterze bez pięter albo na najwyższym piętrze): ciemna pokrywa, murek z kamienną obróbką,
-- komin i wywietrznik. membraneLift podnosi pokrywę nad gzyms piętra.
local function roofCap(parent: Instance, at, width: number, depth: number, topY: number, facade, membraneLift: number, list)
	local model = Instance.new("Model")
	model.Name = "RoofCap"
	local hw, hd = width / 2 + 0.12, depth / 2 + 0.12
	local parts = { deco(model, "RoofMembrane", Vector3.new(width - 0.8, 0.1, depth - 0.8), at(0, topY + membraneLift + 0.05, 0), DARK, Enum.Material.Concrete) }
	for _, side in { -1, 1 } do
		table.insert(parts, deco(model, "Parapet", Vector3.new(0.5, 0.9, hd * 2), at(side * (hw - 0.25), topY + membraneLift + 0.45, 0), facade.color, facade.material))
		table.insert(parts, deco(model, "Parapet", Vector3.new(hw * 2, 0.9, 0.5), at(0, topY + membraneLift + 0.45, side * (hd - 0.25)), facade.color, facade.material))
		table.insert(parts, deco(model, "Coping", Vector3.new(0.75, 0.18, hd * 2 + 0.25), at(side * (hw - 0.25), topY + membraneLift + 0.99, 0), STONE))
		table.insert(parts, deco(model, "Coping", Vector3.new(hw * 2 + 0.25, 0.18, 0.75), at(0, topY + membraneLift + 0.99, side * (hd - 0.25)), STONE))
	end
	table.insert(parts, deco(model, "Chimney", Vector3.new(1.6, 2.6, 1.6), at(width / 2 - 3, topY + membraneLift + 1.3, depth / 4), facade.color, facade.material))
	table.insert(parts, deco(model, "ChimneyCap", Vector3.new(2, 0.3, 2), at(width / 2 - 3, topY + membraneLift + 2.75, depth / 4), STONE))
	table.insert(parts, deco(model, "RoofVent", Vector3.new(1.2, 0.8, 1.2), at(-width / 4, topY + membraneLift + 0.5, depth / 5), Color3.fromRGB(190, 195, 200), Enum.Material.Metal))
	for _, p in parts do
		if list then
			table.insert(list, p)
		end
	end
	model.Parent = parent
	return model
end

-- tier = ApartmentConfig.Tiers[tierIndex]. Zwraca { model, door, enterPrompt, exitPrompt, signLabel, dirtFolder }
function ApartmentBuilder.Build(index: number, origin: CFrame, parent: Instance, tier, tierIndex: number)
	local width, depth, height = tier.width, tier.depth, tier.height
	local hw, hd = width / 2, depth / 2
	local model = Instance.new("Model")
	model.Name = string.format("Apartment_%d_%d", tierIndex, index)
	model:SetAttribute("SlotIndex", index)
	model:SetAttribute("Tier", tierIndex)
	model:SetAttribute("OwnerUserId", 0)

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local wallY = FLOOR_TOP + height / 2
	local frontZ = -hd + THICKNESS / 2
	local sideWidth = (width - DOOR_WIDTH) / 2
	local topY = FLOOR_TOP + DOOR_HEIGHT + (height - DOOR_HEIGHT) / 2

	-- Podłoga i sufit
	local floor = part(model, "Floor", Vector3.new(width, 1, depth), at(0, 0.5, 0), tier.floorColor, Enum.Material.WoodPlanks)
	model.PrimaryPart = floor
	part(model, "BathroomFloor", Vector3.new(6.75, 0.1, 6.75), at(hw - 4.375, 1.05, hd - 4.375), COLORS.bathroomFloor, Enum.Material.Slate)
	part(model, "Ceiling", Vector3.new(width, 1, depth), at(0, FLOOR_TOP + height + 0.5, 0), COLORS.ceiling)

	-- Ściany zewnętrzne
	part(model, "WallBack", Vector3.new(width, height, THICKNESS), at(0, wallY, hd - THICKNESS / 2), tier.wallColor)
	part(model, "WallLeft", Vector3.new(THICKNESS, height, depth), at(-hw + THICKNESS / 2, wallY, 0), tier.wallColor)
	part(model, "WallRight", Vector3.new(THICKNESS, height, depth), at(hw - THICKNESS / 2, wallY, 0), tier.wallColor)
	part(model, "WallFrontL", Vector3.new(sideWidth, height, THICKNESS), at(-(DOOR_WIDTH / 2 + sideWidth / 2), wallY, frontZ), COLORS.brick, Enum.Material.Brick)
	part(model, "WallFrontR", Vector3.new(sideWidth, height, THICKNESS), at(DOOR_WIDTH / 2 + sideWidth / 2, wallY, frontZ), COLORS.brick, Enum.Material.Brick)
	part(model, "WallFrontTop", Vector3.new(DOOR_WIDTH, height - DOOR_HEIGHT, THICKNESS), at(0, topY, frontZ), COLORS.brick, Enum.Material.Brick)
	local windows = tier.windowsPerSide
	local windowWidth = math.min(5, sideWidth / (windows + 0.5))
	local windowHeight = if tier.loft then 7 else 4
	for i = 1, windows do
		local x = DOOR_WIDTH / 2 + sideWidth * (i / (windows + 1))
		for _, side in { -1, 1 } do
			local window = part(model, "Window", Vector3.new(windowWidth, windowHeight, THICKNESS + 0.1), at(side * x, FLOOR_TOP + 6, frontZ), COLORS.window, Enum.Material.Glass)
			window.Transparency = 0.4
		end
	end

	-- Drzwi wejściowe
	local door = part(model, "Door", Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, 0.6), at(0, FLOOR_TOP + DOOR_HEIGHT / 2, frontZ), COLORS.door, Enum.Material.Wood)
	local knob = part(model, "Knob", Vector3.new(0.6, 0.6, 0.6), at(1.8, FLOOR_TOP + 4.5, frontZ - 0.45), COLORS.knob, Enum.Material.Metal)
	knob.Shape = Enum.PartType.Ball
	knob.CanCollide = false

	-- Osobne podpowiedzi po obu stronach drzwi (front drzwi = -Z = ulica)
	local function doorPrompt(name: string, offsetZ: number, actionText: string)
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Position = Vector3.new(0, -1, offsetZ)
		attachment.Parent = door
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = actionText
		prompt.ObjectText = tier.name .. " nr " .. index
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = attachment
		return prompt
	end
	local enterPrompt = doorPrompt("OutsideAttachment", -1.5, "Wejdź")
	local exitPrompt = doorPrompt("InsideAttachment", 1.5, "Wyjdź")

	-- Tabliczka nad drzwiami
	local sign = part(model, "Sign", Vector3.new(9, 1.8, 0.3), at(0, FLOOR_TOP + DOOR_HEIGHT + 1.5, -hd - 0.15), COLORS.sign)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.new(1, 1, 1)
	signLabel.Text = "WOLNE"
	signLabel.Parent = surface

	-- Elewacja od ulicy: kolor kamienicy, cokół, kamienne narożniki, gzyms, okna z opaskami i kwiatami,
	-- daszek nad drzwiami z lampkami, stopień i donice; na dachu attyka z kominem (chowana, gdy są piętra)
	local facade, facadeIndex = facadeFor(origin)
	for _, name in { "WallFrontL", "WallFrontR", "WallFrontTop" } do
		local wall = model:FindFirstChild(name)
		wall.Color = facade.color
		wall.Material = facade.material
	end
	local doorColor = DOOR_COLORS[facadeIndex % #DOOR_COLORS + 1]
	door.Color = doorColor
	local roofY = FLOOR_TOP + height + 1
	cladding(model, at, width, depth, 0, roofY, facade)
	for _, side in { -1, 1 } do
		deco(model, "Plinth", Vector3.new(sideWidth, 1.3, 0.3), at(side * (DOOR_WIDTH / 2 + sideWidth / 2), 0.65, -hd - 0.15), DARK, Enum.Material.Slate)
		deco(model, "Plinth", Vector3.new(0.3, 1.3, depth + 0.6), at(side * (hw + 0.27), 0.65, 0), DARK, Enum.Material.Slate)
		deco(model, "Cornice", Vector3.new(0.45, 0.55, depth + 0.8), at(side * (hw + 0.34), FLOOR_TOP + height + 0.5, 0), STONE)
	end
	deco(model, "Plinth", Vector3.new(width + 0.84, 1.3, 0.3), at(0, 0.65, hd + 0.27), DARK, Enum.Material.Slate)
	deco(model, "Cornice", Vector3.new(width + 1.2, 0.55, 0.45), at(0, FLOOR_TOP + height + 0.5, -hd - 0.22), STONE)
	deco(model, "Cornice", Vector3.new(width + 1.2, 0.55, 0.45), at(0, FLOOR_TOP + height + 0.5, hd + 0.34), STONE)
	for _, side in { -1, 1 } do
		for row = 0, math.floor((height - 0.6) / 1.1) - 1 do
			local long = row % 2 == 0
			local w = if long then 1.5 else 1
			deco(model, "Quoin", Vector3.new(w, 0.9, 0.25), at(side * (hw - w / 2), 1.85 + row * 1.1, -hd - 0.12), STONE, Enum.Material.Concrete)
		end
	end
	-- Okna: okiennice tylko wtedy, gdy obok okien jest miejsce
	local spacing = sideWidth / (windows + 1)
	local firstX = DOOR_WIDTH / 2 + spacing
	local lastX = DOOR_WIDTH / 2 + sideWidth * (windows / (windows + 1))
	local roomForShutters = firstX - windowWidth / 2 - (DOOR_WIDTH / 2 + 0.5) >= 1.7 and hw - 1.5 - (lastX + windowWidth / 2) >= 1.7 and (windows == 1 or spacing - windowWidth >= 3.4)
	for i = 1, windows do
		local x = DOOR_WIDTH / 2 + sideWidth * (i / (windows + 1))
		for _, side in { -1, 1 } do
			streetWindow(model, at, side * x, FLOOR_TOP + 6, windowWidth, windowHeight, -hd, if roomForShutters then doorColor else nil)
		end
	end
	-- Drzwi: kamienna opaska, daszek, lampki po bokach, stopień i donice
	deco(model, "DoorSurround", Vector3.new(DOOR_WIDTH + 1.2, 0.5, 0.3), at(0, FLOOR_TOP + DOOR_HEIGHT + 0.25, -hd - 0.15), STONE)
	for _, side in { -1, 1 } do
		deco(model, "DoorSurround", Vector3.new(0.5, DOOR_HEIGHT, 0.3), at(side * (DOOR_WIDTH / 2 + 0.25), FLOOR_TOP + DOOR_HEIGHT / 2, -hd - 0.15), STONE)
		local lampX = side * (DOOR_WIDTH / 2 + 1.1)
		deco(model, "WallLamp", Vector3.new(0.45, 0.9, 0.4), at(lampX, FLOOR_TOP + 7, -hd - 0.22), DARK, Enum.Material.Metal)
		local glow = deco(model, "WallLampGlow", Vector3.new(0.3, 0.5, 0.06), at(lampX, FLOOR_TOP + 7, -hd - 0.44), COLORS.bulb, Enum.Material.Neon)
		local lampLight = Instance.new("PointLight")
		lampLight.Range = 10
		lampLight.Brightness = 0.6
		lampLight.Color = COLORS.lampLight
		lampLight.Parent = glow
		local potX = side * (DOOR_WIDTH / 2 + 2.4)
		part(model, "DoorPlanter", Vector3.new(1.4, 1.1, 1.1), at(potX, 0.55, -hd - 0.8), DARK, Enum.Material.Concrete)
		deco(model, "DoorShrub", Vector3.new(1.5, 1.5, 1.5), at(potX, 1.6, -hd - 0.8), Color3.fromRGB(60, 150, 70), Enum.Material.Grass, Enum.PartType.Ball)
	end
	deco(model, "DoorCanopy", Vector3.new(DOOR_WIDTH + 2.4, 0.25, 2), at(0, FLOOR_TOP + DOOR_HEIGHT + 0.3, -hd - 1), DARK, Enum.Material.Metal)
	part(model, "DoorStep", Vector3.new(DOOR_WIDTH + 1.6, 0.5, 1.4), at(0, 0.25, -hd - 0.7), STONE, Enum.Material.Concrete)
	roofCap(model, at, width, depth, roofY, facade, 0)

	-- Łazienka (prawy tylny róg): ściany z przejściem
	part(model, "BathWallFrontL", Vector3.new(2, height, 0.5), at(hw - 7, wallY, hd - 8), tier.wallColor)
	part(model, "BathWallFrontR", Vector3.new(2, height, 0.5), at(hw - 2, wallY, hd - 8), tier.wallColor)
	part(model, "BathWallFrontTop", Vector3.new(3, height - DOOR_HEIGHT, 0.5), at(hw - 4.5, topY, hd - 8), tier.wallColor)
	part(model, "BathWallSide", Vector3.new(0.5, height, 7), at(hw - 8, wallY, hd - 4.5), tier.wallColor)
	-- Toaleta: "Toilet" (podstawa muszli) to część używana przez awarie; reszta to wygląd
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local function detail(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
		local p = part(model, name, size, cframe, color, material)
		p.CanCollide = false
		if shape then
			p.Shape = shape
		end
		return p
	end
	local tx, tz = hw - 2.5, hd - 2.6
	part(model, "Toilet", Vector3.new(1.4, 1.4, 1.8), at(tx, FLOOR_TOP + 0.7, tz), COLORS.white)
	detail("ToiletRim", Vector3.new(0.45, 2.1, 2.1), at(tx, FLOOR_TOP + 1.55, tz - 0.25) * upright, COLORS.white, nil, Enum.PartType.Cylinder)
	detail("ToiletWater", Vector3.new(0.06, 1.45, 1.45), at(tx, FLOOR_TOP + 1.79, tz - 0.25) * upright, Color3.fromRGB(170, 215, 240), Enum.Material.Glass, Enum.PartType.Cylinder)
	detail("ToiletTank", Vector3.new(2.1, 1.7, 0.75), at(tx, FLOOR_TOP + 2.4, hd - 1.45), COLORS.white)
	detail("ToiletTankLid", Vector3.new(2.25, 0.15, 0.85), at(tx, FLOOR_TOP + 3.32, hd - 1.45), COLORS.white)
	detail("FlushButton", Vector3.new(0.12, 0.35, 0.35), at(tx, FLOOR_TOP + 3.43, hd - 1.45) * upright, COLORS.metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	detail("ToiletLid", Vector3.new(1.9, 1.7, 0.12), at(tx, FLOOR_TOP + 2.55, hd - 1.95) * CFrame.Angles(math.rad(-8), 0, 0), COLORS.white)

	-- Umywalka na nodze z kranikiem (pod lustrem)
	local sx, sz = hw - 6, hd - 1.85
	part(model, "BathSink", Vector3.new(2.6, 0.7, 0.7), at(sx, FLOOR_TOP + 1.3, sz) * upright, COLORS.white).Shape = Enum.PartType.Cylinder
	detail("SinkBasin", Vector3.new(2.2, 0.55, 1.5), at(sx, FLOOR_TOP + 2.85, sz), COLORS.white)
	detail("SinkBowl", Vector3.new(1.7, 0.06, 1.0), at(sx, FLOOR_TOP + 3.14, sz + 0.05), Color3.fromRGB(190, 215, 230))
	detail("SinkTap", Vector3.new(0.55, 0.18, 0.18), at(sx, FLOOR_TOP + 3.4, hd - 1.25) * upright, COLORS.metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	detail("SinkSpout", Vector3.new(0.14, 0.12, 0.5), at(sx, FLOOR_TOP + 3.62, hd - 1.45), COLORS.metal, Enum.Material.Metal)

	-- Kuchnia: blat ze zlewem i lodówka
	part(model, "Counter", Vector3.new(8.5, 3.5, 2), at(-hw + 5, FLOOR_TOP + 1.75, hd - 2), COLORS.counter)
	part(model, "KitchenSink", Vector3.new(2.5, 0.15, 1.4), at(-hw + 6, FLOOR_TOP + 3.55, hd - 2), COLORS.metal, Enum.Material.Metal)
	-- Kran kuchenny: pionowa rurka, wylewka nad zlewem i dwa pokrętła
	local faucetX = -hw + 6
	local tap = part(model, "KitchenTap", Vector3.new(1.1, 0.2, 0.2), at(faucetX, FLOOR_TOP + 4.1, hd - 1.2) * CFrame.Angles(0, 0, math.rad(90)), COLORS.metal, Enum.Material.Metal)
	tap.Shape = Enum.PartType.Cylinder
	tap.CanCollide = false
	part(model, "KitchenSpout", Vector3.new(0.16, 0.16, 0.8), at(faucetX, FLOOR_TOP + 4.6, hd - 1.55), COLORS.metal, Enum.Material.Metal).CanCollide = false
	for _, dx in { -0.45, 0.45 } do
		part(model, "KitchenTapKnob", Vector3.new(0.25, 0.2, 0.25), at(faucetX + dx, FLOOR_TOP + 3.75, hd - 1.2), if dx < 0 then Color3.fromRGB(230, 70, 70) else Color3.fromRGB(70, 140, 230)).CanCollide = false
	end
	part(model, "Fridge", Vector3.new(2.6, 5, 2), at(-hw + 11, FLOOR_TOP + 2.5, hd - 2), COLORS.fridge, Enum.Material.SmoothPlastic)

	-- Włącznik i miejsce na skrzynkę bezpieczników: lewa ściana, z dala od drzwi
	part(model, "LightSwitch", Vector3.new(0.2, 1.2, 0.8), at(-hw + 0.6, FLOOR_TOP + 4, 1), COLORS.white)
	local fuseSpot = part(model, "FuseBoxSpot", Vector3.new(0.4, 2.4, 1.8), at(-hw + 0.7, FLOOR_TOP + 4.5, 5), COLORS.metal)
	fuseSpot.Transparency = 1
	fuseSpot.CanCollide = false
	fuseSpot.CanQuery = false
	fuseSpot.CanTouch = false

	-- Łóżko (w Klitce stary materac)
	if tier.bed == "mattress" then
		part(model, "Mattress", Vector3.new(5, 1.2, 8), at(-hw + 3, FLOOR_TOP + 0.6, -hd + 6), COLORS.mattress, Enum.Material.Fabric)
		part(model, "Pillow", Vector3.new(3.5, 0.6, 1.5), at(-hw + 3, FLOOR_TOP + 1.5, -hd + 2.8), COLORS.white, Enum.Material.Fabric)
	else
		part(model, "BedFrame", Vector3.new(5.4, 1, 8.4), at(-hw + 3, FLOOR_TOP + 0.5, -hd + 6), COLORS.bedFrame, Enum.Material.Wood)
		part(model, "Mattress", Vector3.new(5, 0.8, 8), at(-hw + 3, FLOOR_TOP + 1.4, -hd + 6), COLORS.blanket, Enum.Material.Fabric)
		part(model, "Headboard", Vector3.new(5.4, 2.5, 0.4), at(-hw + 3, FLOOR_TOP + 1.25, -hd + 1.8), COLORS.bedFrame, Enum.Material.Wood)
		part(model, "Pillow", Vector3.new(3.5, 0.6, 1.5), at(-hw + 3, FLOOR_TOP + 2.1, -hd + 2.8), COLORS.white, Enum.Material.Fabric)
	end

	-- Balkon za tylną ścianą (Mieszkanie z balkonem)
	if tier.balcony then
		local balconyX = 2
		part(model, "BalconyFloor", Vector3.new(12, 0.6, 4), at(balconyX, 0.7, hd + 2), COLORS.counter, Enum.Material.Concrete)
		part(model, "BalconyRail", Vector3.new(12, 2.5, 0.3), at(balconyX, 2.25, hd + 3.85), COLORS.railing, Enum.Material.Metal)
		part(model, "BalconyRailL", Vector3.new(0.3, 2.5, 4), at(balconyX - 6, 2.25, hd + 2), COLORS.railing, Enum.Material.Metal)
		part(model, "BalconyRailR", Vector3.new(0.3, 2.5, 4), at(balconyX + 6, 2.25, hd + 2), COLORS.railing, Enum.Material.Metal)
		local glass = part(model, "BalconyDoor", Vector3.new(4, 7, 0.1), at(balconyX, FLOOR_TOP + 3.5, hd - THICKNESS - 0.06), COLORS.window, Enum.Material.Glass)
		glass.Transparency = 0.3
		glass.CanCollide = false
	end

	-- Belki pod sufitem (Loft)
	if tier.loft then
		for _, z in { -hd / 2, 0, hd / 2 } do
			local beam = part(model, "Beam", Vector3.new(width - 2, 0.8, 0.8), at(0, FLOOR_TOP + height - 0.6, z), COLORS.beam, Enum.Material.Wood)
			beam.CanCollide = false
		end
	end

	-- Oświetlenie: lampy wiszące z abażurem. Część "Lamp"/"LampExtra"/"BathLamp" to żarówka
	-- (FailureService przełącza jej materiał Neon i PointLight przy awarii światła)
	local ceilingY = FLOOR_TOP + height
	local function pendant(name: string, x: number, z: number, range: number)
		local cord = part(model, "LampCord", Vector3.new(0.12, 1.2, 0.12), at(x, ceilingY - 0.6, z), COLORS.cord)
		cord.CanCollide = false
		local shade = part(model, "LampShade", Vector3.new(1.1, 2.4, 2.4), at(x, ceilingY - 1.55, z) * CFrame.Angles(0, 0, math.rad(90)), COLORS.shade, Enum.Material.Fabric)
		shade.Shape = Enum.PartType.Cylinder
		shade.CanCollide = false
		shade.CastShadow = false
		local bulb = part(model, name, Vector3.new(0.7, 0.7, 0.7), at(x, ceilingY - 2.25, z), COLORS.bulb, Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Ball
		bulb.CanCollide = false
		bulb.CastShadow = false
		addLight(bulb, range)
	end
	pendant("Lamp", 0, -1, 22)
	local bathLamp = part(model, "BathLamp", Vector3.new(0.7, 0.7, 0.7), at(hw - 4.4, ceilingY - 0.5, hd - 4.4), COLORS.bulb, Enum.Material.Neon)
	bathLamp.Shape = Enum.PartType.Ball
	bathLamp.CanCollide = false
	addLight(bathLamp, 10)
	if width > 30 then
		for _, position in { Vector3.new(-hw / 2, 0, 3), Vector3.new(hw / 2 - 4, 0, -hd / 2) } do
			pendant("LampExtra", position.X, position.Z, 20)
		end
	end

	-- Wystrój: listwy przy podłodze, zasłony, szafki i kafelki w kuchni, lustro, obrazy i zegar
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	local function deco(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
		local p = part(decor, name, size, cframe, color, material)
		p.CanCollide = false
		p.CanQuery = false
		if shape then
			p.Shape = shape
		end
		return p
	end
	local inner = THICKNESS
	deco("Baseboard", Vector3.new(width - 2 * inner, 0.45, 0.15), at(0, FLOOR_TOP + 0.22, hd - inner - 0.07), COLORS.trim)
	deco("Baseboard", Vector3.new(0.15, 0.45, depth - 2 * inner), at(-hw + inner + 0.07, FLOOR_TOP + 0.22, 0), COLORS.trim)
	deco("Baseboard", Vector3.new(0.15, 0.45, depth - 2 * inner), at(hw - inner - 0.07, FLOOR_TOP + 0.22, 0), COLORS.trim)
	-- Listwa pod sufitem
	deco("CeilingTrim", Vector3.new(width - 2 * inner, 0.35, 0.2), at(0, ceilingY - 0.18, hd - inner - 0.1), COLORS.trim)
	deco("CeilingTrim", Vector3.new(0.2, 0.35, depth - 2 * inner), at(-hw + inner + 0.1, ceilingY - 0.18, 0), COLORS.trim)
	deco("CeilingTrim", Vector3.new(0.2, 0.35, depth - 2 * inner), at(hw - inner - 0.1, ceilingY - 0.18, 0), COLORS.trim)

	local curtain = COLORS.curtains[(tierIndex - 1) % #COLORS.curtains + 1]
	for i = 1, windows do
		local x = DOOR_WIDTH / 2 + sideWidth * (i / (windows + 1))
		for _, side in { -1, 1 } do
			local cx = side * x
			local z = -hd + inner + 0.25
			for _, edge in { -1, 1 } do
				deco("Curtain", Vector3.new(0.9, windowHeight + 1.4, 0.15), at(cx + edge * (windowWidth / 2 + 0.3), FLOOR_TOP + 6 - 0.2, z), curtain, Enum.Material.Fabric)
			end
			deco("CurtainRod", Vector3.new(windowWidth + 2.4, 0.15, 0.15), at(cx, FLOOR_TOP + 6 + windowHeight / 2 + 0.6, z - 0.05), COLORS.frame, Enum.Material.Wood)
		end
	end

	-- Kuchnia: szafki nad blatem i kafelki
	deco("Cabinets", Vector3.new(8.5, 2.2, 1.3), at(-hw + 5, FLOOR_TOP + 7.6, hd - inner - 0.65), COLORS.cabinet)
	for k = 0, 2 do
		deco("CabinetKnob", Vector3.new(0.25, 0.25, 0.1), at(-hw + 2.2 + k * 2.8, FLOOR_TOP + 6.8, hd - inner - 1.35), COLORS.knob, Enum.Material.Metal)
	end
	deco("Backsplash", Vector3.new(8.5, 2.6, 0.08), at(-hw + 5, FLOOR_TOP + 4.95, hd - inner - 0.04), COLORS.tile, Enum.Material.Slate)
	-- Łazienka: lustro nad umywalką
	deco("MirrorFrame", Vector3.new(2.2, 2.4, 0.1), at(hw - 6, FLOOR_TOP + 5.6, hd - inner - 0.05), COLORS.trim)
	local mirror = deco("Mirror", Vector3.new(1.9, 2.1, 0.05), at(hw - 6, FLOOR_TOP + 5.6, hd - inner - 0.12), COLORS.mirror, Enum.Material.Glass)
	mirror.Reflectance = 0.5

	-- Obrazy wysoko na ścianach (nad meblami), w ramkach z kolorowymi "pejzażami"
	local function painting(cframe: CFrame, colors)
		deco("PaintingFrame", Vector3.new(3.2, 2.4, 0.15), cframe, COLORS.frame, Enum.Material.Wood)
		deco("PaintingSky", Vector3.new(2.8, 1.2, 0.05), cframe * CFrame.new(0, 0.45, -0.1), colors[1])
		deco("PaintingHill", Vector3.new(2.8, 0.85, 0.05), cframe * CFrame.new(0, -0.55, -0.1), colors[2])
		deco("PaintingSun", Vector3.new(0.05, 0.6, 0.6), cframe * CFrame.new(0.8, 0.5, -0.13) * CFrame.Angles(0, math.rad(90), 0), colors[3], nil, Enum.PartType.Cylinder)
	end
	local backFree = ((-hw + 12.5) + (hw - 8)) / 2
	painting(at(backFree, FLOOR_TOP + 8.4, hd - inner - 0.08), COLORS.paintings[1])
	painting(at(-hw + inner + 0.08, FLOOR_TOP + 8.4, -hd + 6) * CFrame.Angles(0, math.rad(-90), 0), COLORS.paintings[2])
	-- Zegar na prawej ścianie
	local clockCenter = at(hw - inner - 0.08, FLOOR_TOP + 8.6, -1)
	deco("Clock", Vector3.new(0.15, 1.8, 1.8), clockCenter, COLORS.trim, nil, Enum.PartType.Cylinder)
	deco("ClockRim", Vector3.new(0.1, 2, 2), clockCenter * CFrame.new(0.04, 0, 0), COLORS.frame, nil, Enum.PartType.Cylinder)
	deco("ClockHand", Vector3.new(0.05, 0.7, 0.08), clockCenter * CFrame.new(-0.1, 0.3, 0), COLORS.cord)
	deco("ClockHand", Vector3.new(0.05, 0.08, 0.55), clockCenter * CFrame.new(-0.1, 0, 0.25), COLORS.cord)

	-- Okładziny do malowania: cienkie płyty na tych stronach ścian, których nie da się pomalować całych
	-- (front z cegły od środka, ścianki łazienki od strony pokoju, ściany przy toalecie od strony łazienki).
	-- "PaintLinerMain" maluje się kolorem pokoju, "PaintLinerBath" kolorem łazienki.
	local function liner(name: string, size: Vector3, cframe: CFrame)
		if size.X <= 0.05 and size.Z <= 0.05 or size.Y <= 0.05 then
			return
		end
		local p = part(model, name, size, cframe, tier.wallColor)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
	end
	local linerZ = -hd + THICKNESS + 0.02
	-- Front od środka: pas pod oknami, pas nad oknami i kawałki między oknami (okna zostają przezroczyste)
	local windowBottom = FLOOR_TOP + 6 - windowHeight / 2
	local windowTop = FLOOR_TOP + 6 + windowHeight / 2
	local function frontLiner(fromX: number, toX: number, holes)
		local function rect(x0: number, x1: number, y0: number, y1: number)
			if x1 - x0 > 0.05 and y1 - y0 > 0.05 then
				liner("PaintLinerMain", Vector3.new(x1 - x0, y1 - y0, 0.04), at((x0 + x1) / 2, (y0 + y1) / 2, linerZ))
			end
		end
		rect(fromX, toX, FLOOR_TOP, windowBottom)
		rect(fromX, toX, windowTop, FLOOR_TOP + height)
		local cursor = fromX
		for _, hole in holes do
			rect(cursor, hole[1], windowBottom, windowTop)
			cursor = hole[2]
		end
		rect(cursor, toX, windowBottom, windowTop)
	end
	local leftHoles, rightHoles = {}, {}
	for i = 1, windows do
		local x = DOOR_WIDTH / 2 + sideWidth * (i / (windows + 1))
		table.insert(rightHoles, { x - windowWidth / 2, x + windowWidth / 2 })
		table.insert(leftHoles, 1, { -x - windowWidth / 2, -x + windowWidth / 2 })
	end
	frontLiner(-hw + THICKNESS, -DOOR_WIDTH / 2, leftHoles)
	frontLiner(DOOR_WIDTH / 2, hw - THICKNESS, rightHoles)
	liner("PaintLinerMain", Vector3.new(DOOR_WIDTH, height - DOOR_HEIGHT, 0.04), at(0, topY, linerZ))
	-- Ścianki łazienki od strony pokoju
	liner("PaintLinerMain", Vector3.new(2, height, 0.04), at(hw - 7, wallY, hd - 8.27))
	liner("PaintLinerMain", Vector3.new(2, height, 0.04), at(hw - 2, wallY, hd - 8.27))
	liner("PaintLinerMain", Vector3.new(3, height - DOOR_HEIGHT, 0.04), at(hw - 4.5, topY, hd - 8.27))
	liner("PaintLinerMain", Vector3.new(0.04, height, 7.5), at(hw - 8.27, wallY, hd - 4.75))
	-- Ściany przy toalecie i umywalce od strony łazienki
	liner("PaintLinerBath", Vector3.new(6.75, height, 0.04), at(hw - 4.375, wallY, hd - THICKNESS - 0.02))
	liner("PaintLinerBath", Vector3.new(0.04, height, 6.75), at(hw - THICKNESS - 0.02, wallY, hd - 4.375))

	local dirtFolder = Instance.new("Folder")
	dirtFolder.Name = "Dirt"
	dirtFolder.Parent = model

	model.Parent = parent
	return {
		model = model,
		door = door,
		enterPrompt = enterPrompt,
		exitPrompt = exitPrompt,
		signLabel = signLabel,
		dirtFolder = dirtFolder,
	}
end

-- Dobudowane piętro nr k nad mieszkaniem: pokój z oknami w ramach i zasłonami, obrazami, dywanem i lampą.
-- Drabina prowadzi z piętra niżej przez właz z barierkami (każde piętro ma własną drabinę, przesuniętą względem
-- poprzedniej). isTop zostaje dla zgodności wywołań (drabina zawsze wystaje nad podłogę).
-- Zwraca { model, stages = { walls, windows, decor } (części wg etapów budowy), upPrompt, downPrompt }.
local ROOM_DECOR = {
	floor = Color3.fromRGB(170, 120, 80),
	rug = { Color3.fromRGB(90, 150, 220), Color3.fromRGB(220, 110, 140), Color3.fromRGB(120, 190, 120), Color3.fromRGB(240, 180, 80) },
	glass = Color3.fromRGB(170, 215, 255),
	frame = Color3.fromRGB(250, 250, 250),
}
function ApartmentBuilder.BuildRoom(origin: CFrame, tier, k: number, parent: Instance, isTop: boolean?)
	local width, depth, height = tier.width, tier.depth, tier.height
	local hw, hd = width / 2, depth / 2
	local floorTop = ApartmentConfig.RoomFloorTop(tier, k)
	local belowTop = ApartmentConfig.RoomFloorTop(tier, k - 1)
	local ladder = ApartmentConfig.LadderPoint(tier, k)
	local wallColor = ApartmentConfig.Paint.ROOM_DEFAULT
	local model = Instance.new("Model")
	model.Name = "Room_" .. k
	model:SetAttribute("RoomIndex", k)
	local stages = { walls = {}, windows = {}, decor = {} }
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local function add(stage: string, p: BasePart, solid: boolean?): BasePart
		if not solid then
			p.CanCollide = false
		end
		table.insert(stages[stage], p)
		return p
	end
	local wallY = floorTop + height / 2
	local ceilingY = floorTop + height
	local inner = THICKNESS

	-- Etap 1: podłoga, ściany, sufit i gzyms między piętrami
	add("walls", part(model, "RoomFloor", Vector3.new(width - 2, 0.12, depth - 2), at(0, floorTop + 0.06, 0), ROOM_DECOR.floor, Enum.Material.WoodPlanks), true)
	add("walls", part(model, "WallBack", Vector3.new(width, height, THICKNESS), at(0, wallY, hd - THICKNESS / 2), wallColor), true)
	add("walls", part(model, "WallLeft", Vector3.new(THICKNESS, height, depth), at(-hw + THICKNESS / 2, wallY, 0), wallColor), true)
	add("walls", part(model, "WallRight", Vector3.new(THICKNESS, height, depth), at(hw - THICKNESS / 2, wallY, 0), wallColor), true)
	add("walls", part(model, "WallFront", Vector3.new(width, height, THICKNESS), at(0, wallY, -hd + THICKNESS / 2), wallColor), true)
	local facade = facadeFor(origin)
	add("walls", part(model, "Facade", Vector3.new(width, height, 0.2), at(0, wallY, -hd - 0.1), facade.color, facade.material))
	cladding(model, at, width, depth, floorTop, ceilingY + 1, facade, stages.walls)
	if isTop then
		roofCap(model, at, width, depth, ceilingY + 1, facade, 0.6, stages.walls)
	end
	add("walls", part(model, "Ceiling", Vector3.new(width, 1, depth), at(0, ceilingY + 0.5, 0), COLORS.ceiling), true)
	add("walls", part(model, "Cornice", Vector3.new(width + 1, 0.6, depth + 1), at(0, ceilingY + 1.3, 0), COLORS.trim))

	-- Etap 2: okna z ramą, szprosami, parapetem i zasłonami (dwa od ulicy, jedno z tyłu)
	local function window(name: string, cx: number, z: number, w: number, facing: number)
		local h = 4.4
		local y = floorTop + 6
		-- Od ulicy szyba wystaje przed elewację, a na zewnątrz dostaje opaskę, parapet i skrzynkę z kwiatami
		local glass = add("windows", part(model, name, Vector3.new(w, h, THICKNESS + (if facing == 1 then 0.4 else 0.3)), at(cx, y, z - (if facing == 1 then 0.05 else 0)), ROOM_DECOR.glass, Enum.Material.SmoothPlastic))
		glass.Transparency = 0.55
		if facing == 1 then
			streetWindow(model, at, cx, y, w, h, -hd - 0.2, nil, stages.windows)
		end
		local inside = z + facing * (THICKNESS / 2 + 0.2)
		for _, dy in { -h / 2, h / 2 } do
			add("windows", part(model, "WindowFrame", Vector3.new(w + 0.4, 0.3, 0.3), at(cx, y + dy, inside), ROOM_DECOR.frame))
		end
		for _, dx in { -w / 2, w / 2 } do
			add("windows", part(model, "WindowFrame", Vector3.new(0.3, h + 0.3, 0.3), at(cx + dx, y, inside), ROOM_DECOR.frame))
		end
		add("windows", part(model, "WindowBar", Vector3.new(0.18, h, 0.2), at(cx, y, inside), ROOM_DECOR.frame))
		add("windows", part(model, "WindowBar", Vector3.new(w, 0.18, 0.2), at(cx, y, inside), ROOM_DECOR.frame))
		add("windows", part(model, "WindowSill", Vector3.new(w + 0.8, 0.25, 0.8), at(cx, y - h / 2 - 0.25, inside + facing * 0.3), ROOM_DECOR.frame))
		local curtain = COLORS.curtains[(k - 1) % #COLORS.curtains + 1]
		for _, edge in { -1, 1 } do
			add("decor", part(model, "Curtain", Vector3.new(0.9, h + 1.6, 0.15), at(cx + edge * (w / 2 + 0.55), y - 0.2, inside + facing * 0.35), curtain, Enum.Material.Fabric))
		end
		add("decor", part(model, "CurtainRod", Vector3.new(w + 2.6, 0.15, 0.15), at(cx, y + h / 2 + 0.7, inside + facing * 0.4), COLORS.frame, Enum.Material.Wood))
	end
	window("Window", -hw / 2, -hd + 0.5, 5, 1)
	window("Window", hw / 2 - 2, -hd + 0.5, 5, 1)
	window("Window", -hw / 2 + 1, hd - 0.5, 5, -1)

	-- Etap 3: lampa, listwy, dywan, obrazy, szyb z drabiną i właz z barierkami
	add("decor", part(model, "LampCord", Vector3.new(0.12, 1.1, 0.12), at(-2, ceilingY - 0.55, -1), COLORS.cord))
	local shade = add("decor", part(model, "LampShade", Vector3.new(1.1, 2.4, 2.4), at(-2, ceilingY - 1.5, -1) * CFrame.Angles(0, 0, math.rad(90)), COLORS.shade, Enum.Material.Fabric))
	shade.Shape = Enum.PartType.Cylinder
	shade.CastShadow = false
	local bulb = add("decor", part(model, "RoomLamp", Vector3.new(0.7, 0.7, 0.7), at(-2, ceilingY - 2.2, -1), COLORS.bulb, Enum.Material.Neon))
	bulb.Shape = Enum.PartType.Ball
	bulb.CastShadow = false
	addLight(bulb, 26)
	for _, spec in {
		{ Vector3.new(width - 2, 0.45, 0.15), Vector3.new(0, 0.34, hd - inner - 0.07) },
		{ Vector3.new(width - 2, 0.45, 0.15), Vector3.new(0, 0.34, -hd + inner + 0.07) },
		{ Vector3.new(0.15, 0.45, depth - 2), Vector3.new(-hw + inner + 0.07, 0.34, 0) },
		{ Vector3.new(0.15, 0.45, depth - 2), Vector3.new(hw - inner - 0.07, 0.34, 0) },
		{ Vector3.new(width - 2, 0.35, 0.2), Vector3.new(0, height - 0.18, hd - inner - 0.1) },
		{ Vector3.new(width - 2, 0.35, 0.2), Vector3.new(0, height - 0.18, -hd + inner + 0.1) },
		{ Vector3.new(0.2, 0.35, depth - 2), Vector3.new(-hw + inner + 0.1, height - 0.18, 0) },
		{ Vector3.new(0.2, 0.35, depth - 2), Vector3.new(hw - inner - 0.1, height - 0.18, 0) },
	} do
		add("decor", part(model, "Trim", spec[1], at(spec[2].X, floorTop + spec[2].Y, spec[2].Z), COLORS.trim))
	end
	-- Dywan na środku (dekoracja, meble mogą na nim stać)
	local rugColor = ROOM_DECOR.rug[(k - 1) % #ROOM_DECOR.rug + 1]
	local rug = add("decor", part(model, "RoomRug", Vector3.new(0.08, 8, 8), at(-2, floorTop + 0.16, -1) * CFrame.Angles(0, 0, math.rad(90)), rugColor, Enum.Material.Fabric))
	rug.Shape = Enum.PartType.Cylinder
	local rugRing = add("decor", part(model, "RoomRugRing", Vector3.new(0.07, 8.8, 8.8), at(-2, floorTop + 0.15, -1) * CFrame.Angles(0, 0, math.rad(90)), COLORS.trim, Enum.Material.Fabric))
	rugRing.Shape = Enum.PartType.Cylinder
	-- Obrazy na lewej i prawej ścianie
	local function painting(cframe: CFrame, colors)
		add("decor", part(model, "PaintingFrame", Vector3.new(3.2, 2.4, 0.15), cframe, COLORS.frame, Enum.Material.Wood))
		add("decor", part(model, "PaintingSky", Vector3.new(2.8, 1.2, 0.05), cframe * CFrame.new(0, 0.45, -0.1), colors[1]))
		add("decor", part(model, "PaintingHill", Vector3.new(2.8, 0.85, 0.05), cframe * CFrame.new(0, -0.55, -0.1), colors[2]))
		local sun = add("decor", part(model, "PaintingSun", Vector3.new(0.05, 0.6, 0.6), cframe * CFrame.new(0.8, 0.5, -0.13) * CFrame.Angles(0, math.rad(90), 0), colors[3]))
		sun.Shape = Enum.PartType.Cylinder
	end
	painting(at(-hw + inner + 0.08, floorTop + 7.5, 3) * CFrame.Angles(0, math.rad(-90), 0), COLORS.paintings[(k % 2) + 1])
	painting(at(hw - inner - 0.08, floorTop + 7.5, -hd / 2) * CFrame.Angles(0, math.rad(90), 0), COLORS.paintings[((k + 1) % 2) + 1])

	-- Drabina z piętra niżej, wystaje nad podłogę tego piętra
	local railTop = floorTop + 3
	local railHeight = railTop - belowTop
	for _, dz in { -0.85, 0.85 } do
		add("decor", part(model, "LadderRail", Vector3.new(0.25, railHeight, 0.25), at(ladder.X, belowTop + railHeight / 2, ladder.Z + dz), COLORS.frame, Enum.Material.Wood))
	end
	for y = belowTop + 1, railTop - 0.4, 1.2 do
		add("decor", part(model, "LadderRung", Vector3.new(0.2, 0.2, 1.7), at(ladder.X, y, ladder.Z), COLORS.frame, Enum.Material.Wood))
	end
	-- Właz: ciemny otwór w suficie piętra niżej i rama z barierkami z trzech stron (otwarta od strony wejścia, -X)
	local hatchX = ladder.X - 0.3
	add("decor", part(model, "HatchBelow", Vector3.new(2.4, 0.08, 2.8), at(hatchX, floorTop - 1 - 0.04, ladder.Z), Color3.fromRGB(30, 25, 28)))
	add("decor", part(model, "HatchFrame", Vector3.new(2.8, 0.1, 3.2), at(hatchX, floorTop + 0.17, ladder.Z), COLORS.frame, Enum.Material.Wood))
	add("decor", part(model, "HatchHole", Vector3.new(2.4, 0.11, 2.8), at(hatchX, floorTop + 0.18, ladder.Z), Color3.fromRGB(30, 25, 28)))
	for _, side in { -1, 1 } do
		local z = ladder.Z + side * 1.55
		add("decor", part(model, "HatchRail", Vector3.new(2.6, 0.2, 0.2), at(hatchX, floorTop + 3, z), COLORS.frame, Enum.Material.Wood))
		add("decor", part(model, "HatchRail", Vector3.new(2.6, 0.15, 0.15), at(hatchX, floorTop + 1.6, z), COLORS.frame, Enum.Material.Wood))
		for _, dx in { -1.25, 0, 1.25 } do
			add("decor", part(model, "HatchPost", Vector3.new(0.2, 3, 0.2), at(hatchX + dx, floorTop + 1.5, z), COLORS.frame, Enum.Material.Wood))
		end
	end
	add("decor", part(model, "HatchRail", Vector3.new(0.2, 0.2, 3.1), at(hatchX + 1.35, floorTop + 3, ladder.Z), COLORS.frame, Enum.Material.Wood))
	add("decor", part(model, "HatchRail", Vector3.new(0.15, 0.15, 3.1), at(hatchX + 1.35, floorTop + 1.6, ladder.Z), COLORS.frame, Enum.Material.Wood))

	-- Podpowiedzi przy dolnym ("Na górę") i górnym ("Na dół") końcu drabiny
	local function ladderPrompt(name: string, y: number, actionText: string, objectText: string, key: Enum.KeyCode): ProximityPrompt
		local point = part(model, name, Vector3.new(0.4, 0.4, 0.4), at(ladder.X - 0.6, y, ladder.Z), COLORS.frame)
		point.Transparency = 1
		point.CanCollide = false
		point.CanQuery = false
		point.CanTouch = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = actionText
		prompt.ObjectText = objectText
		prompt.KeyboardKeyCode = key
		prompt.GamepadKeyCode = if key == Enum.KeyCode.F then Enum.KeyCode.ButtonY else Enum.KeyCode.ButtonX
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = point
		return prompt
	end
	local room = ApartmentConfig.Rooms[k]
	local below = ApartmentConfig.Rooms[k - 1]
	local upPrompt = ladderPrompt("LadderUp", belowTop + 3, "Na górę", if room then room.name else "", Enum.KeyCode.E)
	local downPrompt = ladderPrompt("LadderDown", floorTop + 3, "Na dół", if below then below.name else "Mieszkanie", Enum.KeyCode.E)

	model.Parent = parent
	return { model = model, stages = stages, upPrompt = upPrompt, downPrompt = downPrompt }
end

-- Tworzy model brudu w podanym miejscu (cframe = środek obiektu)
function ApartmentBuilder.CreateDirt(kind: string, cframe: CFrame): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic

	if kind == "trash" then
		-- Czarny worek na śmieci: pełny dół, węższa góra, ściągnięta szyjka i żółte uszy ściągacza
		local bagColor = Color3.fromRGB(28, 28, 34)
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1.9, 1.9, 1.9)
		p.Color = bagColor
		p.Reflectance = 0.12
		p.CFrame = cframe * CFrame.new(0, -0.15, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local pieces = {
			part(p, "Top", Vector3.new(1.4, 1.4, 1.4), p.CFrame * CFrame.new(0, 0.6, 0), bagColor, Enum.Material.SmoothPlastic),
			part(p, "Neck", Vector3.new(0.45, 0.5, 0.45), p.CFrame * CFrame.new(0, 1.35, 0), bagColor, Enum.Material.SmoothPlastic),
			part(p, "TieL", Vector3.new(0.5, 0.18, 0.2), p.CFrame * CFrame.new(-0.3, 1.65, 0) * CFrame.Angles(0, 0, math.rad(30)), Color3.fromRGB(255, 205, 40), Enum.Material.SmoothPlastic),
			part(p, "TieR", Vector3.new(0.5, 0.18, 0.2), p.CFrame * CFrame.new(0.3, 1.65, 0) * CFrame.Angles(0, 0, math.rad(-30)), Color3.fromRGB(255, 205, 40), Enum.Material.SmoothPlastic),
		}
		pieces[1].Shape = Enum.PartType.Ball
		for _, piece in pieces do
			piece.Reflectance = if piece.Name:sub(1, 3) == "Tie" then 0 else 0.12
			piece.CanCollide = false
			piece.CanTouch = false
		end
	elseif kind == "stain" then
		local diameter = rng:NextNumber(2.4, 3.6)
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.1, diameter, diameter)
		p.Color = COLORS.stain
		p.Transparency = 0.15
		p.CastShadow = false
		p.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	elseif kind == "bug" then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(0.7, 0.5, 0.9)
		p.Color = COLORS.bug
		p.CFrame = cframe * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		for _, x in { -0.25, 0.25 } do
			local eye = part(p, "Eye", Vector3.new(0.12, 0.12, 0.12), p.CFrame * CFrame.new(x, 0.15, -0.4), Color3.new(1, 1, 1))
			eye.Shape = Enum.PartType.Ball
			eye.CanCollide = false
			eye.CanTouch = false
		end
	elseif kind == "mold" then
		local diameter = rng:NextNumber(3, 4.5)
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.08, diameter, diameter)
		p.Color = COLORS.mold
		p.Material = Enum.Material.Sand
		p.CastShadow = false
		p.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	else -- dishes
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.9, 1.6, 1.6)
		p.Color = COLORS.plate
		p.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
		local sauce = part(p, "Sauce", Vector3.new(0.1, 1, 1), cframe * CFrame.new(0, 0.46, 0) * CFrame.Angles(0, 0, math.rad(90)), COLORS.sauce)
		sauce.Shape = Enum.PartType.Cylinder
		sauce.CanCollide = false
		sauce.CanTouch = false
	end
	return p
end

return ApartmentBuilder

-- Miejsca pracy: market, biuro, ogród, pizzeria i domy do dostaw.
-- Każde miejsce ma StartPart > StartAttachment > StartPrompt (obsługa: JobService).
-- Budynki budowane lokalnie z frontem na -Z; obrót origin ustawia je przodem do ulicy.
-- Bryły lokali i domków (przeszklone fronty, drzwi rozsuwane, płaskie dachy) buduje ModernBuilder.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ModernBuilder = require(script.Parent.ModernBuilder)
local ScooterBuilder = require(script.Parent.ScooterBuilder)

local JobSitesBuilder = {}

local COLORS = {
	floor = Color3.fromRGB(240, 230, 215),
	sign = Color3.fromRGB(110, 60, 200),
	signStroke = Color3.fromRGB(40, 20, 70),
	signBoard = Color3.fromRGB(34, 37, 44),
	market = Color3.fromRGB(90, 210, 120),
	office = Color3.fromRGB(100, 170, 255),
	pizzeria = Color3.fromRGB(255, 150, 60),
	dogHotel = Color3.fromRGB(255, 190, 90),
	garage = Color3.fromRGB(110, 200, 230),
	cafe = Color3.fromRGB(200, 120, 255),
	-- Kolory podświetlanych napisów na szyldach (na zmianę, żeby każdy budynek był inny)
	signs = {
		Color3.fromRGB(255, 215, 70),
		Color3.fromRGB(255, 120, 180),
		Color3.fromRGB(90, 210, 255),
		Color3.fromRGB(255, 160, 60),
		Color3.fromRGB(120, 235, 140),
	},
	scrapGround = Color3.fromRGB(140, 120, 90),
	scrap = Color3.fromRGB(120, 85, 60),
	metal = Color3.fromRGB(90, 95, 105),
	fencePost = Color3.fromRGB(150, 155, 165),
	wire = Color3.fromRGB(190, 195, 205),
	hazard = Color3.fromRGB(255, 200, 30),
	black = Color3.fromRGB(30, 30, 35),
	beaconOn = Color3.fromRGB(255, 120, 20),
	beaconOff = Color3.fromRGB(120, 60, 20),
	screen = Color3.fromRGB(80, 200, 255),
	kennel = Color3.fromRGB(200, 120, 80),
	shelf = Color3.fromRGB(170, 120, 80),
	counter = Color3.fromRGB(235, 220, 180),
	desk = Color3.fromRGB(130, 95, 70),
	oven = Color3.fromRGB(150, 50, 40),
	soil = Color3.fromRGB(80, 150, 65),
	fence = Color3.fromRGB(240, 235, 220),
	hedge = Color3.fromRGB(50, 165, 70),
	hedgeDark = Color3.fromRGB(35, 135, 55),
	hedgeFlowers = {
		Color3.fromRGB(255, 90, 140),
		Color3.fromRGB(255, 220, 60),
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(170, 110, 255),
	},
	post = Color3.fromRGB(120, 80, 50),
	houses = {
		Color3.fromRGB(255, 220, 90),
		Color3.fromRGB(130, 200, 255),
		Color3.fromRGB(255, 150, 190),
		Color3.fromRGB(160, 240, 130),
		Color3.fromRGB(210, 170, 255),
	},
}
local signIndex = 0

local HOUSES = {
	{ x = -125, z = 42, front = "north" },
	{ x = 125, z = 42, front = "north" },
	{ x = -125, z = -20, front = "south" },
	{ x = 125, z = -20, front = "south" },
	{ x = -60, z = -72, front = "south" },
	{ x = 0, z = -72, front = "south" },
	{ x = 60, z = -72, front = "south" },
	{ x = -90, z = 85, front = "north" },
	{ x = 90, z = 85, front = "north" },
}

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

-- Szyld: grafitowa tablica z podświetlonym, kolorowym napisem i świecącą listą pod spodem
local function sign(parent: Instance, size: Vector3, cframe: CFrame, text: string)
	signIndex = signIndex % #COLORS.signs + 1
	local color = COLORS.signs[signIndex]
	local board = part(parent, "Sign", size, cframe, COLORS.signBoard)
	local edge = part(parent, "SignGlow", Vector3.new(size.X, 0.12, 0.1), cframe * CFrame.new(0, -size.Y / 2 + 0.06, -size.Z / 2 - 0.05), color, Enum.Material.Neon)
	edge.CanCollide = false
	edge.CanQuery = false
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.LightInfluence = 0
	surface.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.94, 0.86)
	label.Position = UDim2.fromScale(0.03, 0.05)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = surface
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(15, 15, 20)
	stroke.Thickness = 2
	stroke.Parent = label
	return board
end

-- Punkt startu pracy: podpowiedź po stronie -Z części (od strony wejścia)
local function startPoint(startPart: BasePart, jobId: string, actionText: string, objectText: string)
	startPart.Name = "StartPart"
	local attachment = Instance.new("Attachment")
	attachment.Name = "StartAttachment"
	attachment.Position = Vector3.new(0, 0, -startPart.Size.Z / 2 - 0.6)
	attachment.Parent = startPart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StartPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("JobId", jobId)
	prompt.Parent = attachment
end

-- Ozdoba bez kolizji
local function deco(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local p = part(parent, name, size, cframe, color, material)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	return p
end

-- Nowoczesny lokal (ModernBuilder.Shell): przeszklony front z drzwiami rozsuwanymi, kolor akcentu na pasie nad witryną.
-- Zwraca model, funkcję at(x, y, z) i info { fasciaBottom, top, roofTop }.
local function building(parent: Instance, name: string, origin: CFrame, width: number, depth: number, height: number, accent: Color3, rooftop: boolean?)
	local model = Instance.new("Model")
	model.Name = name
	local at, info = ModernBuilder.Shell(model, origin, { width = width, depth = depth, height = height, accent = accent, rooftop = rooftop })
	model.Parent = parent
	return model, at, info
end

local function buildMarket(sites: Instance)
	local model, at = building(sites, "Market", CFrame.new(-90, 0, 40), 24, 20, 12, COLORS.market, true)
	sign(model, Vector3.new(14, 2.4, 0.4), at(0, 11.5, -10.3), "KOSZYCZEK")
	part(model, "ShelfL", Vector3.new(2, 5, 10), at(-7, 3.5, 4), COLORS.shelf, Enum.Material.Wood)
	part(model, "ShelfR", Vector3.new(2, 5, 10), at(7, 3.5, 4), COLORS.shelf, Enum.Material.Wood)
	local register = part(model, "Register", Vector3.new(6, 3.5, 2), at(0, 2.75, -4), COLORS.counter, Enum.Material.Wood)
	part(model, "Screen", Vector3.new(1.5, 1.2, 0.3), at(1.5, 5.1, -4), Color3.fromRGB(40, 40, 50))
	startPoint(register, "cashier", "Praca: Kasjer", "Kasa w markecie")
end

-- Roślina w donicy (wnętrza)
local function pottedPlant(parent: Instance, cframe: CFrame, scale: number)
	deco(parent, "Pot", Vector3.new(1.4 * scale, 1.4 * scale, 1.4 * scale), cframe * CFrame.new(0, 0.7 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	for i, offset in { Vector3.new(0, 2.1, 0), Vector3.new(0.45, 1.7, 0.3), Vector3.new(-0.4, 1.8, -0.3) } do
		local size = (if i == 1 then 1.6 else 1.2) * scale
		deco(parent, "PlantLeaves", Vector3.new(size, size, size), cframe * CFrame.new(offset * scale), if i == 1 then ModernBuilder.COLORS.shrub else ModernBuilder.COLORS.shrubDark, Enum.Material.Grass, Enum.PartType.Ball)
	end
end

-- Biurowiec: przeszklony parter z recepcją, stanowiskami z monitorami i kącikiem z kanapą, nad nim dwa szklane piętra
local function buildOffice(sites: Instance)
	local model, at, info = building(sites, "Office", CFrame.new(90, 0, 40), 28, 22, 12, COLORS.office)
	sign(model, Vector3.new(12, 2.4, 0.4), at(0, 11.5, -11.3), "BIURO")
	ModernBuilder.Tower(model, at, info.roofTop, 24, 18, 2, COLORS.office)
	local white = Color3.fromRGB(250, 250, 250)
	local metal = ModernBuilder.COLORS.frame
	for _, x in { -9, -3, 3, 9 } do
		-- Biurko z monitorem, klawiaturą i krzesłem obrotowym
		part(model, "Desk", Vector3.new(4, 0.25, 2), at(x, 3.4, 9), white)
		for _, dx in { -1.85, 1.85 } do
			deco(model, "DeskLeg", Vector3.new(0.2, 2.15, 1.8), at(x + dx, 2.15, 9), metal, Enum.Material.Metal)
		end
		deco(model, "Monitor", Vector3.new(2, 1.25, 0.12), at(x, 4.6, 9.6), Color3.fromRGB(30, 30, 35))
		deco(model, "MonitorScreen", Vector3.new(1.8, 1.05, 0.04), at(x, 4.6, 9.53), COLORS.screen, Enum.Material.Neon)
		deco(model, "MonitorStand", Vector3.new(0.2, 0.6, 0.2), at(x, 3.85, 9.65), metal, Enum.Material.Metal)
		deco(model, "Keyboard", Vector3.new(1.4, 0.08, 0.45), at(x, 3.56, 8.6), Color3.fromRGB(60, 60, 68))
		deco(model, "ChairSeat", Vector3.new(1.5, 0.3, 1.5), at(x, 2.5, 7), COLORS.office)
		deco(model, "ChairBack", Vector3.new(1.5, 1.6, 0.25), at(x, 3.5, 6.2), COLORS.office)
		deco(model, "ChairPole", Vector3.new(0.2, 1.2, 0.2), at(x, 1.75, 7), metal, Enum.Material.Metal)
		deco(model, "ChairBase", Vector3.new(1.4, 0.15, 1.4), at(x, 1.1, 7), metal, Enum.Material.Metal)
		-- Okna na tylnej ścianie (Sprzątacz myje je w trakcie zmiany)
		part(model, "WindowFrame", Vector3.new(4.4, 3.4, 0.2), at(x, 7.5, 9.95), metal, Enum.Material.Metal)
		local glass = part(model, "OfficeWindow", Vector3.new(3.8, 2.8, 0.1), at(x, 7.5, 9.82), Color3.fromRGB(150, 210, 255), Enum.Material.Glass)
		glass.Reflectance = 0.25
		glass.CanCollide = false
		deco(model, "WindowSill", Vector3.new(4.6, 0.15, 0.4), at(x, 5.95, 9.75), white)
	end
	-- Recepcja: biała lada z kolorowym pasem i monitorem
	local reception = part(model, "Reception", Vector3.new(5, 3, 2), at(-9, 2.5, -8), white)
	deco(model, "ReceptionTop", Vector3.new(5.4, 0.2, 2.4), at(-9, 4.1, -8), Color3.fromRGB(200, 150, 100), Enum.Material.Wood)
	deco(model, "ReceptionStripe", Vector3.new(5.02, 0.35, 0.05), at(-9, 3.2, -9.02), COLORS.office, Enum.Material.Neon)
	deco(model, "ReceptionMonitor", Vector3.new(1.6, 1, 0.1), at(-8, 4.75, -7.6), Color3.fromRGB(30, 30, 35))
	startPoint(reception, "cleaner", "Praca: Sprzątacz", "Recepcja biura")
	-- Kącik z kanapą i stolikiem, rośliny i dystrybutor wody
	deco(model, "Sofa", Vector3.new(4.6, 1, 1.8), at(8, 1.5, -8.6), Color3.fromRGB(70, 75, 90), Enum.Material.Fabric)
	deco(model, "SofaBack", Vector3.new(4.6, 1.6, 0.5), at(8, 2.3, -9.45), Color3.fromRGB(70, 75, 90), Enum.Material.Fabric)
	for _, dx in { -2.45, 2.45 } do
		deco(model, "SofaArm", Vector3.new(0.4, 1.4, 1.8), at(8 + dx, 1.9, -8.6), Color3.fromRGB(60, 65, 80), Enum.Material.Fabric)
	end
	deco(model, "CoffeeTable", Vector3.new(2.6, 0.2, 1.2), at(8, 2, -6.6), white)
	deco(model, "CoffeeTableBase", Vector3.new(1.6, 1, 0.6), at(8, 1.5, -6.6), metal, Enum.Material.Metal)
	for _, spot in { Vector3.new(-12.2, 1, -5.5), Vector3.new(12.2, 1, -9.1), Vector3.new(12.2, 1, 9.3), Vector3.new(-12.2, 1, 9.3) } do
		pottedPlant(model, at(spot.X, spot.Y, spot.Z), 1)
	end
	deco(model, "WaterCooler", Vector3.new(1.1, 2.6, 1.1), at(12.3, 2.3, -3), white)
	local bottle = deco(model, "WaterBottle", Vector3.new(1.3, 0.9, 0.9), at(12.3, 4.25, -3) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 190, 255), Enum.Material.Glass, Enum.PartType.Cylinder)
	bottle.Transparency = 0.3
	-- Obszar, w którym pojawia się brud do sprzątania
	local area = part(model, "DirtArea", Vector3.new(24, 1, 14), at(0, 1.5, 0), COLORS.floor)
	area.Transparency = 1
	area.CanCollide = false
	area.CanQuery = false
	area.CanTouch = false
end

local function buildGarden(sites: Instance)
	local model = Instance.new("Model")
	model.Name = "Garden"
	local center = Vector3.new(-100, 0, -25)
	part(model, "Ground", Vector3.new(30, 0.3, 40), CFrame.new(center + Vector3.new(0, 0.15, 0)), COLORS.soil, Enum.Material.Grass)
	-- Strzyżony żywopłot z kwiatkami, kule z bukszpanu na rogach i łuk z kwiatów nad bramą (od ulicy, +Z)
	local hedgeFlower = 0
	local function hedge(name: string, from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		local mid = (from + to) / 2
		local cframe = CFrame.lookAt(center + mid, center + to)
		part(model, name, Vector3.new(1.8, 3.2, length), cframe * CFrame.new(0, 1.75, 0), COLORS.hedge, Enum.Material.Grass)
		local top = part(model, name .. "Top", Vector3.new(1.4, 0.4, length), cframe * CFrame.new(0, 3.5, 0), COLORS.hedgeDark, Enum.Material.Grass)
		top.CanCollide = false
		for d = -length / 2 + 1, length / 2 - 1, 2.2 do
			for _, side in { -0.95, 0.95 } do
				hedgeFlower += 1
				local bloom = part(model, "HedgeFlower", Vector3.new(0.45, 0.45, 0.45), cframe * CFrame.new(side, 1.2 + (hedgeFlower % 3) * 0.7, d), COLORS.hedgeFlowers[hedgeFlower % #COLORS.hedgeFlowers + 1])
				bloom.Shape = Enum.PartType.Ball
				bloom.CanCollide = false
				bloom.CanQuery = false
			end
		end
	end
	hedge("HedgeS", Vector3.new(-15, 0, -20), Vector3.new(15, 0, -20))
	hedge("HedgeW", Vector3.new(-15, 0, -20), Vector3.new(-15, 0, 20))
	hedge("HedgeE", Vector3.new(15, 0, -20), Vector3.new(15, 0, 20))
	hedge("HedgeNL", Vector3.new(-15, 0, 20), Vector3.new(-4, 0, 20))
	hedge("HedgeNR", Vector3.new(4, 0, 20), Vector3.new(15, 0, 20))
	for _, corner in { Vector3.new(-15, 0, -20), Vector3.new(15, 0, -20), Vector3.new(-15, 0, 20), Vector3.new(15, 0, 20), Vector3.new(-4, 0, 20), Vector3.new(4, 0, 20) } do
		local ball = part(model, "Topiary", Vector3.new(3, 3, 3), CFrame.new(center + corner + Vector3.new(0, 4.6, 0)), COLORS.hedgeDark, Enum.Material.Grass)
		ball.Shape = Enum.PartType.Ball
	end
	-- Łuk nad bramą: półkole z kolorowych kwiatów
	for i = 0, 12 do
		local angle = math.pi * i / 12
		local bloom = part(model, "ArchFlower", Vector3.new(0.9, 0.9, 0.9), CFrame.new(center + Vector3.new(math.cos(angle) * 4, 6 + math.sin(angle) * 3.5, 20)), COLORS.hedgeFlowers[i % #COLORS.hedgeFlowers + 1])
		bloom.Shape = Enum.PartType.Ball
		bloom.CanCollide = false
	end
	local post = part(model, "Post", Vector3.new(1, 5, 1), CFrame.new(center + Vector3.new(-8, 2.5, 22.5)), COLORS.post, Enum.Material.Wood)
	sign(model, Vector3.new(6, 2, 0.3), CFrame.new(center + Vector3.new(-8, 5.5, 22.9)) * CFrame.Angles(0, math.pi, 0), "OGRÓD")
	-- Post stoi przodem (-Z) do ogrodu; podpowiedź ma być od strony ulicy (+Z), więc obracamy go
	post.CFrame = post.CFrame * CFrame.Angles(0, math.pi, 0)
	startPoint(post, "gardener", "Praca: Ogrodnik", "Ogród")
	local area = part(model, "GardenArea", Vector3.new(26, 1, 34), CFrame.new(center + Vector3.new(0, 0.5, -1)), COLORS.soil)
	area.Transparency = 1
	area.CanCollide = false
	area.CanQuery = false
	area.CanTouch = false
	model.Parent = sites
end

local menuBoard -- tablica z menu (definicja niżej, przy pizzerii)

local KEBAB = {
	wood = Color3.fromRGB(185, 115, 65),
	dark = Color3.fromRGB(40, 38, 44),
	accent = Color3.fromRGB(255, 120, 30),
	awning = { Color3.fromRGB(215, 45, 40), Color3.fromRGB(250, 250, 250) },
	meat = Color3.fromRGB(165, 95, 50),
	meatDark = Color3.fromRGB(120, 65, 35),
	heater = Color3.fromRGB(255, 120, 40),
	concrete = Color3.fromRGB(200, 198, 192),
}

-- Budka z kebabem obok ogrodu: drewniano-grafitowy kiosk z okienkiem i ladom (start pracy, tu leżą kebaby),
-- obracający się rożen widoczny w okienku, pasiasta markiza, podświetlany szyld, stoliki na stojąco
-- i stojak z rowerami dostawców (KebabJob chowa rower, na który ktoś wsiadł, i pokazuje go po odstawieniu)
local function buildKebabStand(sites: Instance)
	local origin = CFrame.new(-79, 0, -12) * CFrame.Angles(0, math.pi, 0) -- okienko w stronę ulicy (+Z)
	local model = Instance.new("Model")
	model.Name = "KebabStand"
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local metal = ModernBuilder.COLORS.frame
	local width, depth, height = 9, 7, 8
	local floorTop = 0.6
	part(model, "Platform", Vector3.new(width + 1.2, floorTop, depth + 1.2), at(0, floorTop / 2, 0), KEBAB.concrete, Enum.Material.Concrete)
	-- Ściany: dolna część w drewnie, górna grafitowa; z przodu okienko między słupkami
	local wallY = floorTop + height / 2
	part(model, "WallBack", Vector3.new(width, height, 0.5), at(0, wallY, depth / 2 - 0.25), KEBAB.wood, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		part(model, "WallSide", Vector3.new(0.5, height, depth - 1), at(side * (width / 2 - 0.25), wallY, 0), KEBAB.wood, Enum.Material.WoodPlanks)
		part(model, "WindowPost", Vector3.new(0.6, height, 0.6), at(side * (width / 2 - 0.3), wallY, -depth / 2 + 0.3), KEBAB.dark, Enum.Material.Metal)
	end
	local sillTop = floorTop + 3.4
	local windowTop = floorTop + 6.2
	part(model, "WallFront", Vector3.new(width - 1.2, sillTop - floorTop, 0.5), at(0, (floorTop + sillTop) / 2, -depth / 2 + 0.25), KEBAB.wood, Enum.Material.WoodPlanks)
	part(model, "WallHeader", Vector3.new(width - 1.2, floorTop + height - windowTop, 0.5), at(0, (windowTop + floorTop + height) / 2, -depth / 2 + 0.25), KEBAB.dark, Enum.Material.SmoothPlastic)
	deco(model, "AccentStripe", Vector3.new(width + 0.1, 0.3, depth + 0.1), at(0, sillTop - 0.6, 0), KEBAB.accent, Enum.Material.SmoothPlastic)
	-- Lada przy okienku (StartPart): tu leżą gotowe kebaby
	local counter = part(model, "Counter", Vector3.new(width - 1.4, 0.35, 1.5), at(0, sillTop + 0.18, -depth / 2 - 0.45), Color3.fromRGB(240, 240, 240), Enum.Material.Marble)
	startPoint(counter, "kebab", "Praca: Dowóz kebabów", "Budka z kebabem")
	for _, side in { -1, 1 } do
		deco(model, "CounterBracket", Vector3.new(0.2, 0.9, 1.2), at(side * 3, sillTop - 0.45, -depth / 2 - 0.4), metal, Enum.Material.Metal)
	end
	-- Dach z okapem i pasiasta markiza nad okienkiem
	part(model, "Roof", Vector3.new(width + 1, 0.5, depth + 1), at(0, floorTop + height + 0.25, 0), KEBAB.dark, Enum.Material.SmoothPlastic)
	local stripes = 8
	for i = 1, stripes do
		local x = -width / 2 + (i - 0.5) * width / stripes
		local stripe = deco(model, "Awning", Vector3.new(width / stripes, 0.15, 2.6), at(x, windowTop + 0.7, -depth / 2 - 1.1) * CFrame.Angles(math.rad(-22), 0, 0), KEBAB.awning[i % 2 + 1], Enum.Material.Fabric)
		stripe.CastShadow = true
	end
	sign(model, Vector3.new(width - 0.6, 1.6, 0.3), at(0, floorTop + height + 1.4, -depth / 2 + 0.3), "🥙 KEBAB EXPRESS")
	for _, side in { -1, 1 } do
		deco(model, "SignPost", Vector3.new(0.2, 0.9, 0.2), at(side * 3.6, floorTop + height + 0.5, -depth / 2 + 0.3), metal, Enum.Material.Metal)
	end

	-- W środku: rożen z mięsem przed grzałką (obraca się), menu, lodówka z napojami, lampa
	deco(model, "Floor", Vector3.new(width - 1, 0.05, depth - 1), at(0, floorTop + 0.03, 0), Color3.fromRGB(70, 70, 75))
	deco(model, "Heater", Vector3.new(1.8, 3.2, 0.3), at(-2, floorTop + 4.6, 1.6), KEBAB.heater, Enum.Material.Neon)
	deco(model, "SpitStand", Vector3.new(1.6, 2.6, 1.4), at(-2, floorTop + 1.3, 0.6), Color3.fromRGB(205, 210, 218), Enum.Material.Metal)
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local spitBase = at(-2, floorTop + 4.6, 0.6)
	local meat = deco(model, "DonerMeat", Vector3.new(2.6, 1.5, 1.5), spitBase * upright, KEBAB.meat, Enum.Material.Sand, Enum.PartType.Cylinder)
	deco(model, "DonerTop", Vector3.new(0.5, 1.2, 1.2), spitBase * CFrame.new(0, 1.5, 0) * upright, KEBAB.meatDark, Enum.Material.Sand, Enum.PartType.Cylinder)
	deco(model, "Spit", Vector3.new(4, 0.15, 0.15), spitBase * CFrame.new(0, 0.3, 0) * upright, metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	local heat = Instance.new("PointLight")
	heat.Color = KEBAB.heater
	heat.Range = 9
	heat.Brightness = 1.2
	heat.Parent = meat
	task.spawn(function()
		local angle = 0
		while model.Parent ~= nil or angle == 0 do
			angle += 0.12
			meat.CFrame = spitBase * CFrame.Angles(0, angle, 0) * upright
			task.wait(0.1)
		end
	end)
	menuBoard(model, at(1.6, floorTop + 5.4, depth / 2 - 0.6), { "🥙 KEBAB", "Kebab w bułce", "Rollo", "🍟 Frytki" })
	local fridge = deco(model, "DrinkFridge", Vector3.new(1.6, 3.6, 1.2), at(3.2, floorTop + 1.8, 2.2), Color3.fromRGB(120, 200, 255), Enum.Material.Glass)
	fridge.Transparency = 0.3
	for row = 0, 2 do
		for col = 0, 2 do
			deco(model, "Can", Vector3.new(0.3, 0.5, 0.3), at(2.75 + col * 0.45, floorTop + 0.8 + row * 1.1, 2.2), ModernBuilder.COLORS.flowers[(row + col) % 4 + 1])
		end
	end
	local lamp = deco(model, "KioskLamp", Vector3.new(4, 0.1, 1), at(0, floorTop + height - 0.1, -0.5), Color3.fromRGB(255, 240, 210), Enum.Material.Neon)
	local lampLight = Instance.new("PointLight")
	lampLight.Range = 12
	lampLight.Brightness = 1
	lampLight.Parent = lamp

	-- Przed budką (od strony ogrodu): stolik na stojąco i kwiaty w donicy
	for _, spot in { Vector2.new(5, -9.6) } do
		local ground = at(spot.X, 0, spot.Y)
		deco(model, "StandTable", Vector3.new(0.2, 2, 2), ground * CFrame.new(0, 3.6, 0) * upright, Color3.fromRGB(250, 250, 250), Enum.Material.Marble, Enum.PartType.Cylinder)
		part(model, "StandTableLeg", Vector3.new(0.3, 3.5, 0.3), ground * CFrame.new(0, 1.8, 0), metal, Enum.Material.Metal)
		deco(model, "StandTableFoot", Vector3.new(0.1, 1.2, 1.2), ground * CFrame.new(0, 0.05, 0) * upright, metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	ModernBuilder.Planter(model, at(3.6, 0, -5.8) * CFrame.Angles(0, math.rad(90), 0), 3)

	-- Stojak z rowerami dostawców przed budką (od strony ulicy i parku), rowery przodem do ulicy
	for i, x in { -6.5, -9, -11.5 } do
		local bike = ScooterBuilder.Bike(at(x, 0, -7.6), true)
		bike.Name = "ParkedBike"
		bike:SetAttribute("SpotIndex", i)
		bike.Parent = model
	end
	part(model, "BikeRack", Vector3.new(7.4, 0.18, 0.18), at(-9, 1.25, -10.8), metal, Enum.Material.Metal)
	for _, x in { -5.4, -12.6 } do
		part(model, "BikeRackPost", Vector3.new(0.2, 1.3, 0.2), at(x, 0.65, -10.8), metal, Enum.Material.Metal)
	end
	deco(model, "BikeLane", Vector3.new(8, 0.05, 6.4), at(-9, 0.03, -7.6), Color3.fromRGB(70, 140, 220))
	sign(model, Vector3.new(3, 0.9, 0.2), at(-9, 2.3, -10.9), "🚲 ROWERY")
	model.Parent = sites
end

local PIZZA = {
	tileDark = Color3.fromRGB(45, 48, 55),
	brick = Color3.fromRGB(185, 85, 60),
	deck = Color3.fromRGB(175, 125, 85),
	umbrellas = { Color3.fromRGB(220, 50, 50), Color3.fromRGB(60, 170, 80) },
	cheese = Color3.fromRGB(255, 205, 70),
	crust = Color3.fromRGB(215, 140, 60),
	pepperoni = Color3.fromRGB(200, 45, 40),
	basil = Color3.fromRGB(60, 160, 60),
	glow = Color3.fromRGB(255, 140, 30),
	bulb = Color3.fromRGB(255, 225, 140),
}

-- Tablica z menu na ścianie: tytuł i kilka pozycji (cframe: przodem do sali)
menuBoard = function(parent: Instance, cframe: CFrame, lines: { string })
	local board = deco(parent, "MenuBoard", Vector3.new(5, 3.4, 0.15), cframe, Color3.fromRGB(30, 32, 38))
	deco(parent, "MenuFrame", Vector3.new(5.3, 3.7, 0.1), cframe * CFrame.new(0, 0, 0.1), Color3.fromRGB(200, 150, 100), Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui
	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.9, if i == 1 then 0.3 else 0.22)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = if i == 1 then PIZZA.cheese else Color3.new(1, 1, 1)
		label.Text = line
		label.LayoutOrder = i
		label.Parent = gui
	end
end

-- Girlanda żarówek między dwoma punktami, lekko zwisająca
local function stringLights(parent: Instance, from: Vector3, to: Vector3, sag: number)
	local count = math.max(3, math.floor((to - from).Magnitude / 1.6))
	local previous = from
	for i = 1, count do
		local t = i / count
		local point = from:Lerp(to, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		local wire = deco(parent, "LightWire", Vector3.new(0.05, 0.05, (point - previous).Magnitude), CFrame.lookAt((previous + point) / 2, point), Color3.fromRGB(40, 40, 45))
		wire.CastShadow = false
		if i < count then
			local bulb = deco(parent, "LightBulb", Vector3.new(0.35, 0.35, 0.35), CFrame.new(point - Vector3.new(0, 0.2, 0)), PIZZA.bulb, Enum.Material.Neon, Enum.PartType.Ball)
			bulb.CastShadow = false
		end
		previous = point
	end
end

-- Ozdobny pojemnik ze składnikiem (otwarty u góry, w środku kolorowa zawartość)
local function ingredientBin(parent: Instance, cframe: CFrame, color: Color3)
	deco(parent, "IngredientBin", Vector3.new(1.15, 0.5, 0.9), cframe, Color3.fromRGB(215, 220, 228), Enum.Material.Metal)
	deco(parent, "IngredientFill", Vector3.new(0.95, 0.12, 0.72), cframe * CFrame.new(0, 0.22, 0), color, Enum.Material.SmoothPlastic)
end

-- Pizzeria: sala z szachownicą i ladą (start pracy), za ladą kuchnia: stół do robienia pizzy ze składnikami (PrepTable),
-- stanowisko z mąką i ciastem, stół do pakowania z pudełkami, piec opalany drewnem z płomieniem i ekran zamówień;
-- przed wejściem taras z parasolami, girlandami żarówek i donicami, na dachu wielki kawałek pizzy, z boku skutery
local function buildPizzeria(sites: Instance)
	local origin = CFrame.new(100, 0, -24) * CFrame.Angles(0, math.pi, 0) -- front w stronę ulicy (+Z)
	local model, at, info = building(sites, "Pizzeria", origin, 22, 24, 11, COLORS.pizzeria)
	sign(model, Vector3.new(14, 2.4, 0.4), at(0, 10.6, -12.3), "PIZZA PĘDZI")
	local metal = ModernBuilder.COLORS.frame
	local steel = Color3.fromRGB(205, 210, 218)

	for ix = 0, 9 do
		for iz = 0, 10 do
			if (ix + iz) % 2 == 0 then
				deco(model, "FloorTile", Vector3.new(2, 0.04, 2), at(-9 + ix * 2, 1.02, -10 + iz * 2), PIZZA.tileDark)
			end
		end
	end

	-- Lada (start pracy) z blatem, pasem w kolorze lokalu i kasą
	local counter = part(model, "Counter", Vector3.new(8, 3.5, 2), at(0, 2.75, -5), COLORS.counter, Enum.Material.Wood)
	deco(model, "CounterTop", Vector3.new(8.4, 0.2, 2.4), at(0, 4.6, -5), Color3.fromRGB(245, 245, 245), Enum.Material.Marble)
	deco(model, "CounterStripe", Vector3.new(8.02, 0.4, 0.05), at(0, 3.6, -6.02), COLORS.pizzeria, Enum.Material.Neon)
	deco(model, "Register", Vector3.new(1.2, 0.8, 0.9), at(-3, 5.1, -4.8), Color3.fromRGB(40, 40, 48))
	deco(model, "RegisterScreen", Vector3.new(1, 0.5, 0.05), at(-3, 5.2, -5.27), COLORS.screen, Enum.Material.Neon)
	startPoint(counter, "pizza", "Praca: Pizzeria", "Pizzeria")

	-- Kuchnia: stół do robienia pizzy (PizzaJob: tu zaczyna się minigra) z pojemnikami na składniki
	local prep = part(model, "PrepTable", Vector3.new(9, 3.4, 2.6), at(0, 2.7, 2), steel, Enum.Material.Metal)
	deco(model, "PrepTop", Vector3.new(9.4, 0.2, 3), at(0, 4.5, 2), Color3.fromRGB(245, 245, 245), Enum.Material.Marble)
	for i, color in { Color3.fromRGB(205, 45, 35), Color3.fromRGB(255, 215, 90), Color3.fromRGB(170, 40, 45), Color3.fromRGB(225, 205, 170), Color3.fromRGB(70, 170, 60), Color3.fromRGB(255, 190, 60), Color3.fromRGB(50, 50, 45) } do
		ingredientBin(model, at(-3.9 + (i - 1) * 1.3, 4.85, 3), color)
	end
	deco(model, "PizzaBoard", Vector3.new(0.12, 2.6, 2.6), at(0, 4.66, 1.5) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 140, 90), Enum.Material.Wood, Enum.PartType.Cylinder)
	deco(model, "DoughBall", Vector3.new(1, 1, 1), at(-3, 5, 1.4), Color3.fromRGB(250, 235, 200), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	deco(model, "RollingPin", Vector3.new(1.8, 0.3, 0.3), at(2.8, 4.75, 1.3) * CFrame.Angles(0, math.rad(20), 0), Color3.fromRGB(200, 150, 100), Enum.Material.Wood, Enum.PartType.Cylinder)
	-- Ekran zamówień nad stołem
	local screen = deco(model, "OrderScreen", Vector3.new(6, 1.6, 0.2), at(0, 8.4, 2.6), Color3.fromRGB(25, 28, 35))
	local screenGui = Instance.new("SurfaceGui")
	screenGui.Face = Enum.NormalId.Front
	screenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	screenGui.PixelsPerStud = 50
	screenGui.LightInfluence = 0
	screenGui.Parent = screen
	local screenText = Instance.new("TextLabel")
	screenText.Size = UDim2.fromScale(1, 1)
	screenText.BackgroundTransparency = 1
	screenText.Font = Enum.Font.FredokaOne
	screenText.TextScaled = true
	screenText.TextColor3 = Color3.fromRGB(120, 255, 160)
	screenText.Text = "🧾 ZAMÓWIENIA"
	screenText.Parent = screenGui
	for _, x in { -2.5, 2.5 } do
		deco(model, "ScreenCable", Vector3.new(0.06, 1.9, 0.06), at(x, 10.1, 2.6), metal)
	end
	-- Stanowisko z mąką (lewo) i stół do pakowania z pudełkami (prawo)
	part(model, "DoughTable", Vector3.new(3, 3.4, 2.6), at(-7.8, 2.7, 2), steel, Enum.Material.Metal)
	for i, offset in { Vector3.new(-0.6, 0, 0.3), Vector3.new(0.6, 0, -0.2) } do
		local sack = deco(model, "FlourSack", Vector3.new(1.1, 1.4, 0.8), at(-7.8 + offset.X, 5.1, 2 + offset.Z) * CFrame.Angles(0, math.rad(i * 15), 0), Color3.fromRGB(245, 240, 225), Enum.Material.Fabric)
		sack.Name = "FlourSack"
	end
	part(model, "PackTable", Vector3.new(3, 3.4, 2.6), at(7.8, 2.7, 2), steel, Enum.Material.Metal)
	for level = 0, 5 do
		deco(model, "PizzaBoxStack", Vector3.new(2.2, 0.32, 2.2), at(7.8 + (level % 2) * 0.08, 4.58 + level * 0.33, 2), Color3.fromRGB(225, 160, 80), Enum.Material.Cardboard)
	end

	-- Piec: ceglana podstawa, kopuła, świecący otwór z ogniem i komin przez dach
	part(model, "Oven", Vector3.new(6, 2.5, 3), at(0, 2.25, 9.6), PIZZA.brick, Enum.Material.Brick)
	deco(model, "OvenDome", Vector3.new(4.6, 4.6, 4.6), at(0, 3.6, 10.1), PIZZA.brick, Enum.Material.Brick, Enum.PartType.Ball)
	deco(model, "OvenMouth", Vector3.new(2.4, 1.6, 0.12), at(0, 4.1, 7.78), Color3.fromRGB(25, 20, 20))
	local glow = deco(model, "OvenGlow", Vector3.new(1.9, 1, 0.06), at(0, 3.95, 7.7), PIZZA.glow, Enum.Material.Neon)
	local fire = Instance.new("Fire")
	fire.Size = 1.6
	fire.Heat = 2
	fire.Parent = glow
	local ovenLight = Instance.new("PointLight")
	ovenLight.Color = PIZZA.glow
	ovenLight.Range = 10
	ovenLight.Brightness = 1.5
	ovenLight.Parent = glow
	deco(model, "Chimney", Vector3.new(9.5, 1, 1), at(0, 10.6, 10.6) * CFrame.Angles(0, 0, math.rad(90)), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	deco(model, "ChimneyCap", Vector3.new(0.3, 1.5, 1.5), at(0, 15.4, 10.6) * CFrame.Angles(0, 0, math.rad(90)), metal, Enum.Material.Metal, Enum.PartType.Cylinder)

	-- Menu na tylnej ścianie (po bokach pieca)
	menuBoard(model, at(-6.5, 7.4, 10.9), { "🍕 MENU", "Margherita", "Pepperoni", "🥗 Wege" })
	menuBoard(model, at(6.5, 7.4, 10.9), { "🥤 NAPOJE", "Lemoniada", "Sok", "Woda" })

	-- Lampy wiszące nad ladą
	for i, x in { -3, 0, 3 } do
		deco(model, "PendantCord", Vector3.new(0.08, 2.6, 0.08), at(x, info.top - 1.3, -5), metal)
		deco(model, "PendantShade", Vector3.new(0.9, 1.3, 1.3), at(x, info.top - 2.9, -5) * CFrame.Angles(0, 0, math.rad(90)), COLORS.pizzeria, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		local bulb = deco(model, "PendantBulb", Vector3.new(0.55, 0.55, 0.55), at(x, info.top - 3.4, -5), PIZZA.bulb, Enum.Material.Neon, Enum.PartType.Ball)
		if i == 2 then
			local light = Instance.new("PointLight")
			light.Color = PIZZA.bulb
			light.Range = 12
			light.Brightness = 1
			light.Parent = bulb
		end
	end

	-- Stolik z dwoma stołkami (cframe = środek na podłodze), opcjonalnie z parasolem
	local function bistroTable(ground: CFrame, umbrella: Color3?)
		local upright = CFrame.Angles(0, 0, math.rad(90))
		deco(model, "TableTop", Vector3.new(0.2, 2.6, 2.6), ground * CFrame.new(0, 2.6, 0) * upright, Color3.fromRGB(250, 250, 250), Enum.Material.Marble, Enum.PartType.Cylinder)
		deco(model, "TableLeg", Vector3.new(0.25, 2.5, 0.25), ground * CFrame.new(0, 1.3, 0), metal, Enum.Material.Metal)
		deco(model, "TableFoot", Vector3.new(0.12, 1.4, 1.4), ground * CFrame.new(0, 0.06, 0) * upright, metal, Enum.Material.Metal, Enum.PartType.Cylinder)
		for _, side in { -1, 1 } do
			deco(model, "Stool", Vector3.new(0.25, 1.2, 1.2), ground * CFrame.new(side * 1.9, 1.75, 0) * upright, COLORS.pizzeria, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			deco(model, "StoolLeg", Vector3.new(0.2, 1.65, 0.2), ground * CFrame.new(side * 1.9, 0.85, 0), metal, Enum.Material.Metal)
		end
		if umbrella then
			deco(model, "UmbrellaPole", Vector3.new(0.18, 4.4, 0.18), ground * CFrame.new(0, 4.9, 0), Color3.fromRGB(240, 240, 240), Enum.Material.Metal)
			deco(model, "Umbrella", Vector3.new(0.3, 5.4, 5.4), ground * CFrame.new(0, 6.9, 0) * upright, umbrella, Enum.Material.Fabric, Enum.PartType.Cylinder)
			deco(model, "UmbrellaTop", Vector3.new(0.35, 3.4, 3.4), ground * CFrame.new(0, 7.15, 0) * upright, Color3.fromRGB(250, 250, 250), Enum.Material.Fabric, Enum.PartType.Cylinder)
			deco(model, "UmbrellaTip", Vector3.new(0.5, 0.5, 0.5), ground * CFrame.new(0, 7.45, 0), umbrella, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
	for _, x in { -7, 7 } do
		bistroTable(at(x, 1, -9))
	end
	-- Lampy nad stołem kuchennym
	for _, x in { -2.5, 2.5 } do
		deco(model, "KitchenLamp", Vector3.new(1.6, 0.3, 0.8), at(x, info.top - 1.4, 1.8), metal, Enum.Material.Metal)
		local tube = deco(model, "KitchenLampGlow", Vector3.new(1.4, 0.08, 0.6), at(x, info.top - 1.58, 1.8), PIZZA.bulb, Enum.Material.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 12
		light.Brightness = 1.4
		light.Color = PIZZA.bulb
		light.Parent = tube
	end

	-- Taras: drewniany podłogowy pomost, stoliki z parasolami, donice z przerwą na wejście i girlandy żarówek
	part(model, "Deck", Vector3.new(22, 0.4, 7), at(0, 0.2, -15.5), PIZZA.deck, Enum.Material.WoodPlanks)
	for i, x in { -7.2, 7.2 } do
		bistroTable(at(x, 0.4, -15.4), PIZZA.umbrellas[i])
		ModernBuilder.Planter(model, at(x, 0.4, -18.3), 7)
	end
	for _, side in { -1, 1 } do
		part(model, "LightPost", Vector3.new(0.3, 7, 0.3), at(side * 10.9, 3.9, -18.7), metal, Enum.Material.Metal)
		stringLights(model, (at(side * 10.2, info.fasciaBottom - 0.6, -12.4)).Position, (at(side * 10.9, 7.2, -18.7)).Position, 0.6)
	end
	stringLights(model, (at(-10.9, 7.2, -18.7)).Position, (at(10.9, 7.2, -18.7)).Position, 1.2)
	for _, side in { -1, 1 } do
		local glowPost = deco(model, "LightPostCap", Vector3.new(0.5, 0.3, 0.5), at(side * 10.9, 7.5, -18.7), PIZZA.bulb, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = PIZZA.bulb
		light.Range = 14
		light.Brightness = 0.9
		light.Parent = glowPost
	end

	-- Na dachu: wielki kawałek pizzy (dwa kliny sera, skórka, plasterki pepperoni i listki bazylii) na słupkach
	local sliceY, sliceH, half = info.roofTop + 4.4, 6, 3
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "PizzaSlice"
		wedge.Size = Vector3.new(0.6, sliceH, half)
		wedge.CFrame = at(side * half / 2, sliceY, -6) * CFrame.Angles(0, side * math.rad(-90), 0) * CFrame.Angles(0, 0, math.pi)
		wedge.Color = PIZZA.cheese
		wedge.Material = Enum.Material.SmoothPlastic
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.Parent = model
		deco(model, "SlicePost", Vector3.new(0.4, 3.6, 0.4), at(side * 0.6, info.roofTop + 1.8, -5.5), metal, Enum.Material.Metal)
	end
	local crust = deco(model, "SliceCrust", Vector3.new(half * 2 + 0.6, 1.1, 1.1), at(0, sliceY + sliceH / 2 + 0.3, -6), PIZZA.crust, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local sliceLight = Instance.new("PointLight")
	sliceLight.Color = PIZZA.cheese
	sliceLight.Range = 12
	sliceLight.Brightness = 1
	sliceLight.Parent = crust
	local facing = CFrame.Angles(0, math.rad(90), 0)
	for _, topping in { { -1.3, 2.1, 1.1 }, { 1.2, 1.7, 1 }, { -0.1, 0.4, 0.95 }, { 0.1, -1.4, 0.75 } } do
		deco(model, "Pepperoni", Vector3.new(0.1, topping[3], topping[3]), at(topping[1], sliceY + topping[2], -6.36) * facing, PIZZA.pepperoni, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	for _, leaf in { { 0.6, 2.6 }, { -0.9, 0.9 } } do
		deco(model, "Basil", Vector3.new(0.6, 0.35, 0.08), at(leaf[1], sliceY + leaf[2], -6.36) * CFrame.Angles(0, 0, math.rad(30)), PIZZA.basil)
	end

	-- Parking skuterów dostawców z boku tarasu: PizzaJob chowa skuter, na który ktoś wsiadł, i pokazuje go po zaparkowaniu
	for i, z in { -12.5, -15.5, -18.5 } do
		local moped = ScooterBuilder.Moped(at(-13.6, 0, z) * CFrame.Angles(0, math.rad(if i == 2 then -6 else 6), 0), true)
		moped.Name = "ParkedMoped"
		moped:SetAttribute("SpotIndex", i)
		moped.Parent = model
	end
	for _, z in { -11, -14, -17, -20 } do
		deco(model, "ParkingLine", Vector3.new(3, 0.05, 0.2), at(-13.6, 0.03, z), Color3.fromRGB(250, 250, 250))
	end
end

local function invisibleArea(parent: Instance, name: string, size: Vector3, cframe: CFrame)
	local area = part(parent, name, size, cframe, COLORS.floor)
	area.Transparency = 1
	area.CanCollide = false
	area.CanQuery = false
	area.CanTouch = false
	return area
end

-- Psi park przy hotelu: płotek z bramą-łukiem z kwiatów, alejki, fontanna ze złotą kością, staw z kaczuszkami,
-- tor agility, rabaty, ławki, latarnie, duże drzewa i kącik dla psów. Środek zostaje wolny na spacer i minigry.
-- Folder "ParkObstacles" to niewidoczne strefy (atrybut Radius), w których PetsitterJob nie stawia flag ani smaczków.
local PARK = {
	grass = Color3.fromRGB(95, 205, 85),
	path = Color3.fromRGB(240, 222, 185),
	pathEdge = Color3.fromRGB(205, 185, 150),
	stone = Color3.fromRGB(235, 230, 220),
	water = Color3.fromRGB(80, 180, 255),
	gold = Color3.fromRGB(255, 205, 60),
	picket = Color3.fromRGB(250, 250, 250),
	lamp = Color3.fromRGB(255, 225, 160),
	pole = Color3.fromRGB(45, 45, 55),
	trunk = Color3.fromRGB(125, 85, 50),
	leaves = { Color3.fromRGB(80, 200, 80), Color3.fromRGB(255, 150, 200), Color3.fromRGB(140, 225, 60) },
	agility = { Color3.fromRGB(255, 80, 90), Color3.fromRGB(255, 210, 50), Color3.fromRGB(70, 160, 255), Color3.fromRGB(90, 220, 110) },
}

local function buildDogPark(model: Model, center: Vector3)
	local park = Instance.new("Folder")
	park.Name = "DogPark"
	local obstacles = Instance.new("Folder")
	obstacles.Name = "ParkObstacles"
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(center + Vector3.new(x, y, z))
	end
	local function deco(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
		local p = part(park, name, size, cframe, color, material)
		p.CanCollide = false
		if shape then
			p.Shape = shape
		end
		return p
	end
	local function solid(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
		local p = deco(name, size, cframe, color, material, shape)
		p.CanCollide = true
		return p
	end
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local function disc(name: string, diameter: number, y: number, x: number, z: number, color: Color3, material: Enum.Material?, thickness: number?)
		return deco(name, Vector3.new(thickness or 0.1, diameter, diameter), at(x, y, z) * upright, color, material, Enum.PartType.Cylinder)
	end
	local function noSpawn(x: number, z: number, radius: number)
		local marker = Instance.new("Part")
		marker.Name = "NoSpawn"
		marker.Size = Vector3.new(1, 1, 1)
		marker.CFrame = at(x, 0.5, z)
		marker.Transparency = 1
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker:SetAttribute("Radius", radius)
		marker.Parent = obstacles
	end

	-- Trawnik
	part(park, "Lawn", Vector3.new(60, 0.3, 40), at(0, 0.15, 0), PARK.grass, Enum.Material.Grass)

	-- Białe sztachety dookoła (kolizja: niewidoczna ścianka), wejścia od ulicy (południe) i od hotelu (zachód)
	local function fence(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		local frame = CFrame.lookAt(center + (from + to) / 2, center + to)
		local wall = part(park, "FenceWall", Vector3.new(0.3, 3, length), frame * CFrame.new(0, 1.5, 0), PARK.picket)
		wall.Transparency = 1
		for d = -length / 2 + 0.3, length / 2 - 0.2, 0.9 do
			deco("Picket", Vector3.new(0.18, 2.4, 0.4), frame * CFrame.new(0, 1.5, d), PARK.picket)
			local tip = Instance.new("WedgePart")
			tip.Name = "PicketTip"
			tip.Size = Vector3.new(0.18, 0.35, 0.4)
			tip.CFrame = frame * CFrame.new(0, 2.88, d)
			tip.Color = PARK.picket
			tip.Material = Enum.Material.SmoothPlastic
			tip.Anchored = true
			tip.CanCollide = false
			tip.Parent = park
		end
		for _, y in { 1, 2.1 } do
			deco("FenceRail", Vector3.new(0.12, 0.25, length), frame * CFrame.new(-0.15, y, 0), PARK.picket)
		end
	end
	fence(Vector3.new(-30.5, 0, 20.5), Vector3.new(30.5, 0, 20.5))
	fence(Vector3.new(30.5, 0, -20.5), Vector3.new(30.5, 0, 20.5))
	fence(Vector3.new(-30.5, 0, -20.5), Vector3.new(-4.5, 0, -20.5))
	fence(Vector3.new(4.5, 0, -20.5), Vector3.new(30.5, 0, -20.5))
	fence(Vector3.new(-30.5, 0, -20.5), Vector3.new(-30.5, 0, -14))
	fence(Vector3.new(-30.5, 0, -6), Vector3.new(-30.5, 0, 20.5))

	-- Brama wejściowa: kamienne filary z donicami, łuk z kwiatów i szyld
	for _, x in { -4.6, 4.6 } do
		solid("GatePillar", Vector3.new(1.4, 6, 1.4), at(x, 3.3, -20.5), PARK.stone, Enum.Material.Limestone)
		deco("PillarPot", Vector3.new(1.6, 0.8, 1.6), at(x, 6.7, -20.5), Color3.fromRGB(200, 110, 70), Enum.Material.Slate)
		deco("PillarFlowers", Vector3.new(1.8, 1.4, 1.8), at(x, 7.6, -20.5), PARK.leaves[2], Enum.Material.Grass, Enum.PartType.Ball)
	end
	for i = 0, 16 do
		local angle = math.pi * i / 16
		deco("ArchFlower", Vector3.new(1, 1, 1), at(math.cos(angle) * 4.6, 6.6 + math.sin(angle) * 3.4, -20.5), COLORS.hedgeFlowers[i % #COLORS.hedgeFlowers + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		deco("ArchLeaf", Vector3.new(0.8, 0.8, 0.8), at(math.cos(angle) * 4.6, 6.6 + math.sin(angle) * 3.4, -20.2), COLORS.hedge, Enum.Material.Grass, Enum.PartType.Ball)
	end
	-- Szyld nad bramą (napis od strony ulicy, -Z) i ten sam od strony parku
	local parkSign = sign(park, Vector3.new(6, 1.3, 0.3), at(0, 8.6, -20.9), "🐾 PSI PARK")
	parkSign.CanCollide = false
	local backSign = sign(park, Vector3.new(6, 1.3, 0.3), at(0, 8.6, -20.6) * CFrame.Angles(0, math.pi, 0), "🐾 PSI PARK")
	backSign.CanCollide = false

	-- Alejki: od bramy do fontanny, krąg przy fontannie i owalna pętla dookoła
	local function pathSegment(from: Vector3, to: Vector3, width: number)
		local length = (to - from).Magnitude
		local frame = CFrame.lookAt(center + (from + to) / 2, center + to)
		deco("PathEdge", Vector3.new(width + 0.5, 0.06, length + 0.5), frame * CFrame.new(0, 0.32, 0), PARK.pathEdge, Enum.Material.Pavement)
		deco("Path", Vector3.new(width, 0.08, length + 0.4), frame * CFrame.new(0, 0.34, 0), PARK.path, Enum.Material.Pavement)
	end
	pathSegment(Vector3.new(0, 0, -21), Vector3.new(0, 0, -7.5), 4)
	local function loop(a: number, b: number, segments: number, width: number)
		for i = 0, segments - 1 do
			local t0 = i / segments * math.pi * 2
			local t1 = (i + 1) / segments * math.pi * 2
			pathSegment(Vector3.new(math.cos(t0) * a, 0, math.sin(t0) * b), Vector3.new(math.cos(t1) * a, 0, math.sin(t1) * b), width)
		end
	end
	loop(7.5, 7.5, 20, 2.6)
	loop(24, 14.5, 40, 2.4)
	pathSegment(Vector3.new(-30.5, 0, -10), Vector3.new(-23.5, 0, -8), 3)

	-- Fontanna: kamienna misa z wodą, kolumna, górna czasza i złota kość na szczycie, tryskająca woda
	solid("FountainBasin", Vector3.new(1.2, 9, 9), at(0, 0.9, 0) * upright, PARK.stone, Enum.Material.Limestone, Enum.PartType.Cylinder)
	local water = disc("FountainWater", 8, 1.45, 0, 0, PARK.water, Enum.Material.SmoothPlastic, 0.15)
	water.Transparency = 0.2
	water.Reflectance = 0.25
	solid("FountainColumn", Vector3.new(3, 1.6, 1.6), at(0, 2.6, 0) * upright, PARK.stone, Enum.Material.Limestone, Enum.PartType.Cylinder)
	deco("FountainBowl", Vector3.new(0.6, 4.4, 4.4), at(0, 4.2, 0) * upright, PARK.stone, Enum.Material.Limestone, Enum.PartType.Cylinder)
	local bowlWater = disc("FountainBowlWater", 3.8, 4.52, 0, 0, PARK.water, Enum.Material.SmoothPlastic, 0.1)
	bowlWater.Transparency = 0.2
	deco("BoneBar", Vector3.new(2, 0.5, 0.5), at(0, 5.6, 0), PARK.gold, Enum.Material.Metal).Reflectance = 0.2
	for _, x in { -1, 1 } do
		for _, z in { -0.25, 0.25 } do
			deco("BoneKnob", Vector3.new(0.7, 0.7, 0.7), at(x, 5.6, z), PARK.gold, Enum.Material.Metal, Enum.PartType.Ball).Reflectance = 0.2
		end
	end
	local spout = deco("Spout", Vector3.new(0.4, 0.4, 0.4), at(0, 6.2, 0), PARK.gold, Enum.Material.Metal)
	spout.Transparency = 1
	local jets = Instance.new("ParticleEmitter")
	jets.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	jets.Color = ColorSequence.new(Color3.fromRGB(190, 235, 255))
	jets.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.15) })
	jets.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.8) })
	jets.Lifetime = NumberRange.new(0.9, 1.2)
	jets.Speed = NumberRange.new(7, 9)
	jets.SpreadAngle = Vector2.new(18, 18)
	jets.Acceleration = Vector3.new(0, -18, 0)
	jets.Rate = 70
	jets.LightEmission = 0.4
	jets.Parent = spout
	noSpawn(0, 0, 5.5)

	-- Staw z kamieniami, liliami i kaczuszkami (lewy tylny róg)
	local pondX, pondZ = -20, 11
	local pond = disc("Pond", 10, 0.33, pondX, pondZ, PARK.water, Enum.Material.SmoothPlastic, 0.12)
	pond.Transparency = 0.15
	pond.Reflectance = 0.3
	for i = 0, 13 do
		local angle = i / 14 * math.pi * 2
		local size = 0.9 + (i % 3) * 0.3
		deco("PondStone", Vector3.new(size, size * 0.6, size), at(pondX + math.cos(angle) * 5.2, 0.45, pondZ + math.sin(angle) * 5.2), Color3.fromRGB(165, 165, 175), Enum.Material.Slate, Enum.PartType.Ball)
	end
	for _, pad in { { -1.8, 1.2 }, { 1.5, -1.5 }, { 2.2, 1.8 } } do
		disc("LilyPad", 1.4, 0.42, pondX + pad[1], pondZ + pad[2], Color3.fromRGB(70, 175, 70), Enum.Material.SmoothPlastic, 0.05)
		deco("LilyFlower", Vector3.new(0.45, 0.45, 0.45), at(pondX + pad[1] + 0.2, 0.55, pondZ + pad[2]), Color3.fromRGB(255, 150, 200), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	for index, duck in { { -0.5, -1.2, 30 }, { 1.2, 0.6, -120 } } do
		local frame = at(pondX + duck[1], 0.75, pondZ + duck[2]) * CFrame.Angles(0, math.rad(duck[3]), 0)
		local body = deco("Duck", Vector3.new(0.9, 0.7, 1.2), frame, Color3.fromRGB(255, 220, 50), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		deco("DuckHead", Vector3.new(0.55, 0.55, 0.55), frame * CFrame.new(0, 0.5, -0.45), body.Color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		deco("DuckBeak", Vector3.new(0.3, 0.15, 0.3), frame * CFrame.new(0, 0.45, -0.8), Color3.fromRGB(255, 140, 40))
		-- Kaczuszki powoli kołyszą się na wodzie
		TweenService:Create(body, TweenInfo.new(1.6 + index * 0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = frame * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(6)) }):Play()
	end
	noSpawn(pondX, pondZ, 6.5)

	-- Tor agility przy płocie (północ): płotki, slalom, tunel i równoważnia
	for i, x in { -4, 1.5 } do
		for _, dz in { -1.4, 1.4 } do
			deco("HurdlePost", Vector3.new(0.3, 2.2, 0.3), at(x, 1.4, 15.5 + dz), PARK.picket)
		end
		for s = 0, 3 do
			deco("HurdleBar", Vector3.new(0.25, 0.25, 0.7), at(x, 1.6, 15.5 - 1.05 + s * 0.7), if s % 2 == 0 then PARK.agility[i] else PARK.picket)
		end
	end
	for i = 0, 5 do
		deco("WeavePole", Vector3.new(0.25, 3, 0.25), at(6 + i * 1.3, 1.8, 15.5), if i % 2 == 0 then PARK.agility[1] else PARK.agility[2])
	end
	local tunnel = deco("Tunnel", Vector3.new(5, 2.6, 2.6), at(17, 1.6, 15.5) * CFrame.Angles(0, 0, 0), PARK.agility[3], Enum.Material.Fabric, Enum.PartType.Cylinder)
	tunnel.Transparency = 0.1
	for _, x in { 14.4, 19.6 } do
		deco("TunnelRing", Vector3.new(0.3, 2.9, 2.9), at(x, 1.6, 15.5), PARK.agility[2], Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	deco("TunnelHole", Vector3.new(0.32, 2, 2), at(14.4, 1.6, 15.5), Color3.fromRGB(30, 30, 50), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	for _, side in { -1, 1 } do
		local ramp = Instance.new("WedgePart")
		ramp.Name = "Ramp"
		ramp.Size = Vector3.new(1.4, 1.4, 2.6)
		ramp.CFrame = at(24.5 + side * 2.6, 1, 15.5) * CFrame.Angles(0, math.rad(side * -90), 0)
		ramp.Color = PARK.agility[4]
		ramp.Anchored = true
		ramp.CanCollide = false
		ramp.Parent = park
	end
	deco("Balance", Vector3.new(2.6, 0.3, 1.4), at(24.5, 1.55, 15.5), PARK.agility[1], Enum.Material.Wood)
	noSpawn(-1, 15.5, 4)
	noSpawn(9, 15.5, 4.5)
	noSpawn(18, 15.5, 4)
	noSpawn(24.5, 15.5, 4)

	-- Rabaty z kolorowymi kwiatami
	local bloomIndex = 0
	for _, bed in { { -21, -11 }, { 21, -11 }, { 21, 4 } } do
		disc("FlowerBedSoil", 5.6, 0.36, bed[1], bed[2], Color3.fromRGB(120, 85, 55), Enum.Material.Ground, 0.12)
		disc("FlowerBedEdge", 6.2, 0.34, bed[1], bed[2], PARK.stone, Enum.Material.Limestone, 0.14)
		for ring = 0, 1 do
			local count = if ring == 0 then 5 else 10
			for i = 0, count - 1 do
				bloomIndex += 1
				local angle = i / count * math.pi * 2
				local radius = 0.9 + ring * 1.4
				local bx, bz = bed[1] + math.cos(angle) * radius, bed[2] + math.sin(angle) * radius
				deco("Stem", Vector3.new(0.15, 0.9, 0.15), at(bx, 0.85, bz), COLORS.hedge)
				deco("Bloom", Vector3.new(0.7, 0.7, 0.7), at(bx, 1.4, bz), COLORS.hedgeFlowers[bloomIndex % #COLORS.hedgeFlowers + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			end
		end
		noSpawn(bed[1], bed[2], 3.5)
	end

	-- Duże drzewa w rogach i przy bokach (korona z kilku kul)
	local treeIndex = 0
	for _, spot in { { -28, -18 }, { 28, -18 }, { -28, 18.5 }, { 28, 18.5 }, { -28.5, 2 }, { 28.5, -5 } } do
		treeIndex += 1
		local x, z = spot[1], spot[2]
		local leaf = PARK.leaves[treeIndex % #PARK.leaves + 1]
		solid("Trunk", Vector3.new(1.6, 9, 1.6), at(x, 4.8, z), PARK.trunk, Enum.Material.Wood)
		deco("Leaves", Vector3.new(8, 8, 8), at(x, 11, z), leaf, Enum.Material.Grass, Enum.PartType.Ball)
		for i = 0, 3 do
			local angle = i * math.pi / 2 + treeIndex
			deco("Leaves", Vector3.new(5, 5, 5), at(x + math.cos(angle) * 3.5, 9.5 + (i % 2), z + math.sin(angle) * 3.5), leaf, Enum.Material.Grass, Enum.PartType.Ball)
		end
		deco("Leaves", Vector3.new(5, 5, 5), at(x, 14.5, z), leaf:Lerp(Color3.new(1, 1, 1), 0.12), Enum.Material.Grass, Enum.PartType.Ball)
		noSpawn(x, z, 2)
	end

	-- Ławki przy alejkach i latarnie
	local function bench(x: number, z: number, yaw: number, color: Color3)
		local frame = at(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
		solid("BenchSeat", Vector3.new(4.4, 0.35, 1.5), frame * CFrame.new(0, 1.55, 0), color, Enum.Material.Wood)
		deco("BenchBack", Vector3.new(4.4, 1.4, 0.25), frame * CFrame.new(0, 2.5, 0.7) * CFrame.Angles(math.rad(-10), 0, 0), color, Enum.Material.Wood)
		for _, dx in { -1.8, 1.8 } do
			deco("BenchLeg", Vector3.new(0.3, 1.4, 1.3), frame * CFrame.new(dx, 0.8, 0), PARK.pole, Enum.Material.Metal)
		end
	end
	bench(-6.5, -14, 90, PARK.agility[1])
	bench(6.5, -14, -90, PARK.agility[3])
	bench(-11, 4, 70, PARK.agility[2])
	bench(11, 4, -70, PARK.agility[4])
	noSpawn(-6.5, -14, 2.5)
	noSpawn(6.5, -14, 2.5)
	noSpawn(-11, 4, 2.5)
	noSpawn(11, 4, 2.5)
	for _, spot in { { -3.2, -18 }, { 3.2, -18 }, { -9, -5 }, { 9, -5 }, { -9, 7 }, { 9, 7 }, { -24, -6 }, { 24, 10 } } do
		solid("LampPole", Vector3.new(0.35, 6, 0.35), at(spot[1], 3.3, spot[2]), PARK.pole, Enum.Material.Metal)
		deco("LampCap", Vector3.new(1.1, 0.3, 1.1), at(spot[1], 6.9, spot[2]), PARK.pole, Enum.Material.Metal)
		local globe = deco("LampGlobe", Vector3.new(1, 1, 1), at(spot[1], 6.4, spot[2]), PARK.lamp, Enum.Material.Neon, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Range = 14
		light.Brightness = 0.8
		light.Color = PARK.lamp
		light.Parent = globe
		noSpawn(spot[1], spot[2], 1.2)
	end

	-- Kącik dla psów przy wejściu: miska z wodą i kranikiem, budka, hydrant i stojak z woreczkami
	disc("WaterBowl", 1.8, 0.55, 9, -17.5, Color3.fromRGB(70, 150, 255), Enum.Material.SmoothPlastic, 0.5)
	local bowlWater2 = disc("BowlWater", 1.4, 0.82, 9, -17.5, PARK.water, Enum.Material.SmoothPlastic, 0.05)
	bowlWater2.Transparency = 0.2
	deco("Tap", Vector3.new(0.3, 2.2, 0.3), at(10.3, 1.4, -17.5), PARK.pole, Enum.Material.Metal)
	deco("TapSpout", Vector3.new(0.8, 0.2, 0.2), at(9.9, 2.4, -17.5), PARK.pole, Enum.Material.Metal)
	solid("Hydrant", Vector3.new(0.9, 1.6, 0.9), at(13, 1.1, -17), Color3.fromRGB(230, 50, 50), Enum.Material.SmoothPlastic)
	deco("HydrantCap", Vector3.new(1, 1, 1), at(13, 2, -17), Color3.fromRGB(230, 50, 50), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	deco("BagPole", Vector3.new(0.25, 3, 0.25), at(-9, 1.8, -17.5), PARK.pole, Enum.Material.Metal)
	local bags = deco("BagBox", Vector3.new(0.9, 1, 0.6), at(-9, 3, -17.2), Color3.fromRGB(70, 180, 90))
	bags.Name = "BagBox"
	local house = Vector3.new(-24, 0, -12.5)
	solid("DogHouse", Vector3.new(3.4, 2.6, 3), at(house.X, 1.6, house.Z), Color3.fromRGB(230, 120, 80), Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		local roof = deco("DogHouseRoof", Vector3.new(2.2, 0.3, 3.4), at(house.X + side * 0.95, 3.5, house.Z) * CFrame.Angles(0, 0, math.rad(side * -35)), Color3.fromRGB(70, 130, 230), Enum.Material.SmoothPlastic)
		roof.Name = "DogHouseRoof"
	end
	deco("DogHouseDoor", Vector3.new(1.4, 1.6, 0.1), at(house.X, 1.1, house.Z - 1.52), Color3.fromRGB(40, 30, 30))
	noSpawn(9, -17.5, 2.5)
	noSpawn(-9, -17.5, 1.5)
	noSpawn(house.X, house.Z, 3)

	park.Parent = model
	obstacles.Parent = model
end

-- Hotel dla psów "Merdaj" i psi park z wybiegiem (Opiekun zwierząt)
local function buildDogHotel(sites: Instance)
	local model, at = building(sites, "DogHotel", CFrame.new(-110, 0, 120), 22, 16, 11, COLORS.dogHotel)
	sign(model, Vector3.new(12, 2.4, 0.4), at(0, 10.5, -8.3), "MERDAJ")
	local counter = part(model, "Counter", Vector3.new(6, 3.5, 2), at(0, 2.75, -3), COLORS.counter, Enum.Material.Wood)
	startPoint(counter, "petsitter", "Praca: Opiekun zwierząt", "Hotel dla psów")
	for _, x in { -7, 7 } do
		part(model, "Kennel", Vector3.new(4, 3, 4), at(x, 2.5, 5), COLORS.kennel, Enum.Material.Wood)
	end
	local center = Vector3.new(-50, 0, 135)
	buildDogPark(model, center)
	invisibleArea(model, "WalkArea", Vector3.new(54, 1, 34), CFrame.new(center + Vector3.new(0, 0.5, 0)))
end

-- Warsztat "Śrubka" (Mechanik)
local function buildGarage(sites: Instance)
	local model, at = building(sites, "Garage", CFrame.new(10, 0, 122), 30, 22, 12, COLORS.garage)
	sign(model, Vector3.new(16, 2.4, 0.4), at(0, 11.5, -11.3), "WARSZTAT ŚRUBKA")
	local bench = part(model, "Workbench", Vector3.new(5, 3, 2), at(-11, 2.5, -8), COLORS.metal, Enum.Material.Metal)
	startPoint(bench, "mechanic", "Praca: Mechanik", "Warsztat")
	local spot = part(model, "CarSpot", Vector3.new(1, 1, 1), at(3, 0, 3), COLORS.floor)
	spot.Transparency = 1
	spot.CanCollide = false
	spot.CanQuery = false
end

-- Kafejka "Bajt" (Freelancer)
local function buildCafe(sites: Instance)
	local model, at = building(sites, "Cafe", CFrame.new(65, 0, 120), 22, 16, 11, COLORS.cafe)
	sign(model, Vector3.new(14, 2.4, 0.4), at(0, 10.5, -8.3), "KAFEJKA BAJT")
	for _, x in { -7, 7 } do
		part(model, "Desk", Vector3.new(5, 3, 2), at(x, 2.5, 3), COLORS.desk, Enum.Material.Wood)
	end
	local desk = part(model, "MainDesk", Vector3.new(6, 3, 2), at(0, 2.5, 3), COLORS.desk, Enum.Material.Wood)
	part(model, "Monitor", Vector3.new(3, 2, 0.3), at(0, 5, 3.6), COLORS.metal)
	local screen = part(model, "Screen", Vector3.new(2.6, 1.6, 0.05), at(0, 5, 3.42), COLORS.screen, Enum.Material.Neon)
	screen.CanCollide = false
	startPoint(desk, "freelancer", "Praca: Freelancer", "Komputer")
end

-- Siatka złomowiska: słupki, poziome pręty i pionowe druty (kratka), drut kolczasty na górze.
-- Kolizję daje niewidoczna ściana, druty są tylko ozdobą.
local function meshFence(parent: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt((from + to) / 2, to)
	local wall = part(parent, "FenceWall", Vector3.new(0.4, 7, length), frame * CFrame.new(0, 3.5, 0), COLORS.metal)
	wall.Transparency = 1
	local function deco(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?)
		local p = part(parent, name, size, cframe, color, material or Enum.Material.Metal)
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		return p
	end
	for d = -length / 2, length / 2 + 0.01, 5 do
		local post = deco("FencePost", Vector3.new(6.4, 0.4, 0.4), frame * CFrame.new(0, 3.2, d) * CFrame.Angles(0, 0, math.rad(90)), COLORS.fencePost)
		post.Shape = Enum.PartType.Cylinder
	end
	for y = 0.6, 6.01, 1.08 do
		deco("FenceRail", Vector3.new(0.08, 0.08, length), frame * CFrame.new(0, y, 0), COLORS.wire)
	end
	for d = -length / 2 + 0.5, length / 2 - 0.5, 0.9 do
		deco("FenceWire", Vector3.new(0.06, 5.6, 0.06), frame * CFrame.new(0, 3.3, d), COLORS.wire)
	end
	deco("BarbedWire", Vector3.new(0.1, 0.1, length), frame * CFrame.new(-0.3, 6.6, 0), COLORS.wire)
	deco("BarbedWire", Vector3.new(0.1, 0.1, length), frame * CFrame.new(-0.6, 7, 0), COLORS.wire)
end

-- Skrzydło bramy: zakotwiczony korzeń (kolizja) + przyspawana rama z drutami w żółto-czarne pasy
local function gateWing(parent: Instance, cframe: CFrame, width: number): BasePart
	local root = part(parent, "GateWing", Vector3.new(width, 6.4, 0.4), cframe, COLORS.metal)
	root.Transparency = 1
	local function welded(name: string, size: Vector3, offset: CFrame, color: Color3)
		local p = part(parent, name, size, cframe * offset, color, Enum.Material.Metal)
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		return p
	end
	for i, y in { -3, 3 } do
		for s = 0, math.floor(width) - 1 do
			welded("GateStripe", Vector3.new(1, 0.4, 0.3), CFrame.new(-width / 2 + 0.5 + s, y, 0), if (s + i) % 2 == 0 then COLORS.hazard else COLORS.black)
		end
	end
	for _, x in { -width / 2 + 0.2, width / 2 - 0.2 } do
		welded("GateSide", Vector3.new(0.4, 6.4, 0.3), CFrame.new(x, 0, 0), COLORS.hazard)
	end
	for x = -width / 2 + 0.7, width / 2 - 0.6, 0.6 do
		welded("GateWire", Vector3.new(0.06, 5.6, 0.06), CFrame.new(x, 0, 0), COLORS.wire)
	end
	welded("GateRail", Vector3.new(width, 0.08, 0.08), CFrame.new(0, 0, 0), COLORS.wire)
	return root
end

-- Skupujący: ludzik z klocków z kubłem przed sobą (przodem do -Z). Kubeł = miejsce sprzedaży.
local function scrapBuyer(parent: Instance, cframe: CFrame)
	local model = Instance.new("Model")
	model.Name = "ScrapBuyer"
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	local skin = Color3.fromRGB(255, 205, 150)
	for _, x in { -0.5, 0.5 } do
		part(model, "Leg", Vector3.new(1, 2, 1), at(x, 1, 0), Color3.fromRGB(60, 90, 200))
		part(model, "Boot", Vector3.new(1.05, 0.5, 1.2), at(x, 0.25, -0.1), COLORS.black)
	end
	local torso = part(model, "Torso", Vector3.new(2, 2, 1), at(0, 3, 0), Color3.fromRGB(255, 140, 40))
	part(model, "Vest", Vector3.new(2.05, 0.35, 1.05), at(0, 3.3, 0), COLORS.hazard)
	for _, x in { -1.5, 1.5 } do
		-- Ręce wyciągnięte do przodu, trzymają kubeł
		part(model, "Arm", Vector3.new(1, 1, 2.2), at(x * 0.95, 3.6, -0.9), Color3.fromRGB(255, 140, 40))
		part(model, "Hand", Vector3.new(0.9, 0.9, 0.6), at(x * 0.95, 3.6, -2.2), skin)
	end
	local head = part(model, "Head", Vector3.new(2, 1, 1), at(0, 4.5, 0), skin)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	part(model, "Cap", Vector3.new(1.5, 0.5, 1.5), at(0, 5.3, 0), Color3.fromRGB(40, 170, 90))
	part(model, "CapBrim", Vector3.new(1.5, 0.15, 0.8), at(0, 5.1, -0.9), Color3.fromRGB(40, 170, 90))
	local bucket = part(model, "Bucket", Vector3.new(1.8, 2, 2), at(0, 2.9, -2.6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 150, 255), Enum.Material.SmoothPlastic)
	bucket.Shape = Enum.PartType.Cylinder
	local inside = part(model, "BucketInside", Vector3.new(0.1, 1.7, 1.7), at(0, 3.82, -2.6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 40, 50))
	inside.Shape = Enum.PartType.Cylinder
	inside.CanCollide = false
	part(model, "BucketHandle", Vector3.new(2.1, 0.12, 0.12), at(0, 4.1, -2.6), COLORS.wire, Enum.Material.Metal).CanCollide = false
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.fromOffset(170, 44)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	bubble.Parent = head
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 220, 60)
	text.Text = "Pan Złomek 💰"
	text.Parent = bubble
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = text
	model.PrimaryPart = torso
	model.Parent = parent
end

-- Kolorowy złom: stare auto w wyblakłym kolorze
local function junkCar(parent: Instance, cframe: CFrame, color: Color3)
	part(parent, "JunkCarBody", Vector3.new(5, 2, 9), cframe * CFrame.new(0, 1.4, 0), color, Enum.Material.CorrodedMetal)
	part(parent, "JunkCarCabin", Vector3.new(4.4, 1.6, 4.5), cframe * CFrame.new(0, 3.2, 0.6) * CFrame.Angles(0, 0, math.rad(4)), color, Enum.Material.CorrodedMetal)
	for _, x in { -2.5, 2.5 } do
		for _, z in { -3, 3 } do
			local wheel = part(parent, "JunkTire", Vector3.new(0.8, 1.8, 1.8), cframe * CFrame.new(x, 0.9, z), COLORS.black, Enum.Material.Rubber)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
end

-- Złomowisko (Łowca złomu PRO): plac za siatką, brama rozsuwa się przed graczem,
-- budka startu i Pan Złomek z kubłem (sprzedaż) przy ulicy
local function buildScrapyard(sites: Instance)
	local model = Instance.new("Model")
	model.Name = "Scrapyard"
	local center = Vector3.new(130, 0, 140)
	part(model, "Ground", Vector3.new(50, 0.3, 44), CFrame.new(center + Vector3.new(0, 0.15, 0)), COLORS.scrapGround, Enum.Material.Ground)
	local front = center.Z - 22
	meshFence(model, Vector3.new(105, 0, center.Z + 22), Vector3.new(155, 0, center.Z + 22))
	meshFence(model, Vector3.new(105, 0, front), Vector3.new(105, 0, center.Z + 22))
	meshFence(model, Vector3.new(155, 0, front), Vector3.new(155, 0, center.Z + 22))
	meshFence(model, Vector3.new(105, 0, front), Vector3.new(124.5, 0, front))
	meshFence(model, Vector3.new(135.5, 0, front), Vector3.new(155, 0, front))

	-- Brama: dwa skrzydła odjeżdżają na boki, gdy ktoś podejdzie
	local closedL = CFrame.new(127.5, 3.2, front)
	local closedR = CFrame.new(132.5, 3.2, front)
	local openL = CFrame.new(121, 3.2, front + 0.7)
	local openR = CFrame.new(139, 3.2, front + 0.7)
	local wingL = gateWing(model, closedL, 5)
	local wingR = gateWing(model, closedR, 5)
	for _, x in { 124.6, 135.4 } do
		part(model, "GatePost", Vector3.new(0.8, 8, 0.8), CFrame.new(x, 4, front), COLORS.hazard, Enum.Material.Metal)
		local beacon = part(model, "GateBeacon", Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, 8.5, front), COLORS.beaconOff, Enum.Material.Neon)
		beacon.Shape = Enum.PartType.Ball
	end
	local arch = part(model, "GateArch", Vector3.new(12, 2, 0.4), CFrame.new(130, 9.2, front - 0.1), COLORS.signs[4])
	local archGui = Instance.new("SurfaceGui")
	archGui.Face = Enum.NormalId.Front
	archGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	archGui.PixelsPerStud = 50
	archGui.Parent = arch
	local archText = Instance.new("TextLabel")
	archText.Size = UDim2.fromScale(1, 1)
	archText.BackgroundTransparency = 1
	archText.Font = Enum.Font.FredokaOne
	archText.TextScaled = true
	archText.TextColor3 = Color3.new(1, 1, 1)
	archText.Text = "♻ ZŁOMOWISKO ♻"
	archText.Parent = archGui
	local archStroke = Instance.new("UIStroke")
	archStroke.Color = COLORS.signStroke
	archStroke.Thickness = 3
	archStroke.Parent = archText

	local gateCenter = Vector3.new(130, 3, front)
	local gateOpen = false
	task.spawn(function()
		local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		while true do
			local near = false
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - gateCenter).Magnitude <= 16 then
					near = true
					break
				end
			end
			if near ~= gateOpen then
				gateOpen = near
				TweenService:Create(wingL, info, { CFrame = if near then openL else closedL }):Play()
				TweenService:Create(wingR, info, { CFrame = if near then openR else closedR }):Play()
			end
			for _, beacon in model:GetChildren() do
				if beacon.Name == "GateBeacon" then
					beacon.Color = if near and os.clock() % 0.6 < 0.3 then COLORS.beaconOn else COLORS.beaconOff
				end
			end
			task.wait(0.15)
		end
	end)

	-- Kolorowe graty na skraju placu (środek zostaje na sterty do przeszukania)
	junkCar(model, CFrame.new(110, 0.3, 156) * CFrame.Angles(0, math.rad(80), 0), Color3.fromRGB(230, 90, 90))
	junkCar(model, CFrame.new(150, 0.3, 150) * CFrame.Angles(0, math.rad(10), 0), Color3.fromRGB(90, 160, 230))
	junkCar(model, CFrame.new(109, 0.3, 128) * CFrame.Angles(0, math.rad(-5), 0), Color3.fromRGB(240, 200, 60))
	for i, position in { Vector3.new(151, 0.3, 128), Vector3.new(148.5, 0.3, 125) } do
		for level = 0, 3 - i do
			local tire = part(model, "TireStack", Vector3.new(0.9, 2.4, 2.4), CFrame.new(position + Vector3.new(0, 0.45 + level * 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90)), COLORS.black, Enum.Material.Rubber)
			tire.Shape = Enum.PartType.Cylinder
		end
	end
	part(model, "Container", Vector3.new(14, 6, 5.5), CFrame.new(132, 3.3, 158.5), Color3.fromRGB(220, 60, 80), Enum.Material.CorrodedMetal)
	part(model, "ContainerStripe", Vector3.new(14.1, 0.6, 5.6), CFrame.new(132, 5.6, 158.5), COLORS.hazard, Enum.Material.Metal)
	-- Żuraw z magnesem
	part(model, "CraneTower", Vector3.new(1.6, 18, 1.6), CFrame.new(152, 9.3, 158), COLORS.hazard, Enum.Material.Metal)
	part(model, "CraneArm", Vector3.new(16, 1.2, 1.2), CFrame.new(146, 18, 158), COLORS.hazard, Enum.Material.Metal)
	part(model, "CraneCable", Vector3.new(0.15, 7, 0.15), CFrame.new(139, 14.5, 158), COLORS.black, Enum.Material.Metal).CanCollide = false
	local magnet = part(model, "CraneMagnet", Vector3.new(0.8, 3, 3), CFrame.new(139, 10.6, 158) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	magnet.Shape = Enum.PartType.Cylinder
	magnet.CanCollide = false

	-- Budka startu z boku bramy i Pan Złomek obok
	local stand = part(model, "Stand", Vector3.new(6, 3, 2), CFrame.new(144, 2.5, 114), COLORS.counter, Enum.Material.Wood)
	part(model, "StandRoof", Vector3.new(7, 0.4, 3), CFrame.new(144, 6.4, 114.3), COLORS.signs[2], Enum.Material.SmoothPlastic)
	for _, x in { 141, 147 } do
		part(model, "StandPole", Vector3.new(0.3, 3.4, 0.3), CFrame.new(x, 4.6, 114.8), COLORS.wire, Enum.Material.Metal)
	end
	sign(model, Vector3.new(6, 1.2, 0.3), CFrame.new(144, 5.6, 113.6), "PRACA")
	startPoint(stand, "scrapPro", "Praca: Łowca złomu PRO", "Złomowisko")
	scrapBuyer(model, CFrame.new(151, 0.3, 114))
	invisibleArea(model, "ScrapArea", Vector3.new(32, 1, 24), CFrame.new(center + Vector3.new(0, 0.5, 2)))
	model.Parent = sites
end

local function buildHouses(sites: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Houses"
	for index, info in HOUSES do
		local origin = CFrame.new(info.x, 0, info.z)
		if info.front == "south" then
			origin *= CFrame.Angles(0, math.pi, 0)
		end
		local model = Instance.new("Model")
		model.Name = "House_" .. index
		model:SetAttribute("HouseNumber", index)
		local body = ModernBuilder.House(model, origin, index, COLORS.houses[(index - 1) % #COLORS.houses + 1])
		-- Punkt dostawy 2 study przed drzwiami (PizzaJob, RareContractService)
		local doorPoint = Instance.new("Attachment")
		doorPoint.Name = "DoorAttachment"
		doorPoint.Position = body.CFrame:PointToObjectSpace((origin * CFrame.new(0, 3, -7)).Position)
		doorPoint.Parent = body
		model.Parent = folder
	end
	folder.Parent = sites
end

function JobSitesBuilder.Build(map: Instance)
	local sites = Instance.new("Folder")
	sites.Name = "JobSites"
	buildMarket(sites)
	buildOffice(sites)
	buildGarden(sites)
	buildKebabStand(sites)
	buildPizzeria(sites)
	buildDogHotel(sites)
	buildGarage(sites)
	buildCafe(sites)
	buildScrapyard(sites)
	buildHouses(sites)
	sites.Parent = map
end

return JobSitesBuilder

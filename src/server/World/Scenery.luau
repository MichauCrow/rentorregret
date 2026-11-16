-- Wspólne ozdoby świata dla holu i kamienicy z rundy: bogata fasada (okna z okiennicami, gzymsy, balkon,
-- dach z lukarnami i kominami), latarnie, drzewa, płoty, sąsiednie domy w tle, ulica i drobiazgi na podwórku.
-- Prawie wszystko to ozdoby bez kolizji (Parts.Deco); kolizję mają tylko rzeczy, o które można się oprzeć.
local Parts = require(script.Parent.Parts)

local Scenery = {}

local M = Enum.Material
local C = {
	trim = Color3.fromRGB(226, 214, 190),
	stone = Color3.fromRGB(118, 110, 106),
	roof = Color3.fromRGB(52, 44, 54),
	metal = Color3.fromRGB(44, 46, 54),
	pipe = Color3.fromRGB(70, 82, 86),
	wood = Color3.fromRGB(120, 80, 50),
	darkWood = Color3.fromRGB(74, 50, 36),
	windowLit = Color3.fromRGB(255, 205, 120),
	windowDark = Color3.fromRGB(30, 42, 82),
	shutters = { Color3.fromRGB(58, 84, 70), Color3.fromRGB(96, 62, 48), Color3.fromRGB(64, 70, 104) },
	flowers = { Color3.fromRGB(230, 90, 110), Color3.fromRGB(245, 200, 80), Color3.fromRGB(190, 120, 220), Color3.fromRGB(250, 240, 240) },
	leaves = Color3.fromRGB(52, 96, 58),
	autumn = { Color3.fromRGB(176, 104, 46), Color3.fromRGB(150, 70, 44), Color3.fromRGB(196, 150, 60), Color3.fromRGB(96, 110, 60) },
	trunk = Color3.fromRGB(70, 52, 42),
	brick = Color3.fromRGB(122, 78, 66),
	gold = Color3.fromRGB(255, 200, 60),
	black = Color3.fromRGB(26, 24, 28),
	asphalt = Color3.fromRGB(52, 52, 60),
	curb = Color3.fromRGB(150, 146, 140),
	houses = { Color3.fromRGB(96, 78, 84), Color3.fromRGB(84, 88, 104), Color3.fromRGB(104, 92, 76), Color3.fromRGB(78, 92, 88) },
}
Scenery.COLORS = C

local function pick(rng: Random, list)
	return list[rng:NextInteger(1, #list)]
end

-- Walec pionowy (oś Y) jako ozdoba
local function pillar(parent: Instance, name: string, height: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	return Parts.Deco(parent, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

-- Walec między dwoma punktami
local function rod(parent: Instance, name: string, from: Vector3, to: Vector3, diameter: number, color: Color3, material: Enum.Material?): Part
	return Parts.Deco(parent, name, Vector3.new((to - from).Magnitude, diameter, diameter), CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0), color, material, Enum.PartType.Cylinder)
end

-- Drobiazgi ---------------------------------------------------------------------------------------

-- Dym z komina (albo para): emiter cząsteczek na części
function Scenery.Smoke(part: BasePart, rate: number?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Smoke"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Rate = rate or 3
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Speed = NumberRange.new(1.5, 2.5)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Acceleration = Vector3.new(0.4, 0.3, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-15, 15)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.8), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 150, 160))
	emitter.LightEmission = 0
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = part
	return emitter
end

-- Latarenka: daszek, świecąca kulka (PointLight) i denko. Zwraca światło.
function Scenery.Lantern(parent: Instance, position: Vector3, brightness: number, range: number, color: Color3?): PointLight
	Parts.Deco(parent, "LanternCap", Vector3.new(1.1, 0.25, 1.1), CFrame.new(position + Vector3.new(0, 0.55, 0)), C.metal, M.Metal)
	Parts.Deco(parent, "LanternTip", Vector3.new(0.3, 0.35, 0.3), CFrame.new(position + Vector3.new(0, 0.8, 0)), C.metal, M.Metal)
	Parts.Deco(parent, "LanternBase", Vector3.new(0.8, 0.18, 0.8), CFrame.new(position + Vector3.new(0, -0.5, 0)), C.metal, M.Metal)
	for _, corner in { Vector3.new(0.38, 0, 0.38), Vector3.new(-0.38, 0, 0.38), Vector3.new(0.38, 0, -0.38), Vector3.new(-0.38, 0, -0.38) } do
		Parts.Deco(parent, "LanternBar", Vector3.new(0.08, 1, 0.08), CFrame.new(position + corner), C.metal, M.Metal)
	end
	return Parts.Lamp(parent, position, brightness, range, color or Color3.fromRGB(255, 205, 140), false)
end

-- Latarnia uliczna z wysięgnikiem. direction = w którą stronę wisi lampa.
function Scenery.StreetLamp(parent: Instance, position: Vector3, direction: Vector3, brightness: number?, color: Color3?): PointLight
	local dir = Vector3.new(direction.X, 0, direction.Z).Unit
	Parts.Block(parent, "LampPost", Vector3.new(0.55, 11, 0.55), CFrame.new(position + Vector3.new(0, 5.5, 0)), C.metal, M.Metal)
	Parts.Deco(parent, "LampFoot", Vector3.new(1.2, 1.2, 1.2), CFrame.new(position + Vector3.new(0, 0.6, 0)), C.metal, M.Metal)
	Parts.Deco(parent, "LampRing", Vector3.new(0.8, 0.3, 0.8), CFrame.new(position + Vector3.new(0, 7.5, 0)), C.metal, M.Metal)
	local top = position + Vector3.new(0, 10.8, 0)
	rod(parent, "LampArm", top, top + dir * 2.2 + Vector3.new(0, 0.5, 0), 0.25, C.metal, M.Metal)
	return Scenery.Lantern(parent, top + dir * 2.2 + Vector3.new(0, -0.3, 0), brightness or 1.4, 30, color)
end

-- Drzewo liściaste (jesienne kolory)
function Scenery.Tree(parent: Instance, position: Vector3, scale: number, rng: Random)
	local trunk = Parts.Block(parent, "Trunk", Vector3.new(7 * scale, 1.3 * scale, 1.3 * scale), CFrame.new(position + Vector3.new(0, 3.5 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)), C.trunk, M.Wood)
	trunk.Shape = Enum.PartType.Cylinder
	local color = pick(rng, C.autumn)
	for _, blob in { { 0, 9, 0, 7.5 }, { 2.2, 7.6, 0.8, 5 }, { -2, 8, -1, 5.4 }, { 0.4, 11.4, -0.6, 4.6 } } do
		Parts.Blob(parent, "Leaves", Vector3.new(blob[4], blob[4] * 0.85, blob[4]) * scale, CFrame.new(position + Vector3.new(blob[1], blob[2], blob[3]) * scale), color:Lerp(pick(rng, C.autumn), 0.35), M.Grass)
	end
end

-- Bezlistne, powykręcane drzewo (straszne podwórko)
function Scenery.BareTree(parent: Instance, position: Vector3, scale: number, rng: Random)
	local trunk = Parts.Block(parent, "Trunk", Vector3.new(8 * scale, 1.4 * scale, 1.4 * scale), CFrame.new(position + Vector3.new(0, 4 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)), C.trunk, M.Wood)
	trunk.Shape = Enum.PartType.Cylinder
	local top = position + Vector3.new(0, 7.6 * scale, 0)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + rng:NextNumber() * 0.6
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local start = top - Vector3.new(0, rng:NextNumber() * 2.6 * scale, 0)
		local elbow = start + (out * (2.2 + rng:NextNumber() * 1.6) + Vector3.new(0, 1.6 + rng:NextNumber() * 1.4, 0)) * scale
		local tip = elbow + (out * (1 + rng:NextNumber()) + Vector3.new(0, 1.8 + rng:NextNumber() * 1.6, 0)) * scale
		rod(parent, "Branch", start, elbow, 0.55 * scale, C.trunk, M.Wood)
		rod(parent, "Branch", elbow, tip, 0.32 * scale, C.trunk, M.Wood)
		if i % 2 == 0 then
			local twig = elbow + (Vector3.new(-out.Z, 0, out.X) * 1.4 + Vector3.new(0, 1.2, 0)) * scale
			rod(parent, "Twig", elbow, twig, 0.22 * scale, C.trunk, M.Wood)
		end
	end
end

function Scenery.Bush(parent: Instance, position: Vector3, size: Vector3, color: Color3?)
	Parts.Blob(parent, "Bush", size, CFrame.new(position + Vector3.new(0, size.Y * 0.42, 0)), color or C.leaves, M.Grass)
	Parts.Blob(parent, "Bush", size * 0.62, CFrame.new(position + Vector3.new(size.X * 0.3, size.Y * 0.62, size.Z * 0.1)), (color or C.leaves):Lerp(Color3.new(1, 1, 1), 0.08), M.Grass)
end

-- Wrona (przód = -Z)
function Scenery.Crow(parent: Instance, cframe: CFrame)
	Parts.Blob(parent, "Crow", Vector3.new(0.8, 0.75, 1.4), cframe * CFrame.new(0, 0.45, 0) * CFrame.Angles(math.rad(18), 0, 0), C.black)
	Parts.Blob(parent, "CrowHead", Vector3.new(0.55, 0.55, 0.6), cframe * CFrame.new(0, 0.95, -0.55), C.black)
	Parts.Deco(parent, "CrowBeak", Vector3.new(0.14, 0.14, 0.4), cframe * CFrame.new(0, 0.92, -0.95), Color3.fromRGB(230, 150, 40))
	Parts.Deco(parent, "CrowTail", Vector3.new(0.5, 0.1, 0.8), cframe * CFrame.new(0, 0.3, 0.85) * CFrame.Angles(math.rad(-25), 0, 0), C.black)
	Parts.Deco(parent, "CrowEye", Vector3.new(0.6, 0.1, 0.1), cframe * CFrame.new(0, 1.02, -0.72), Color3.fromRGB(255, 240, 200), M.Neon)
end

function Scenery.TrashBin(parent: Instance, position: Vector3, rng: Random)
	local bin = Parts.Block(parent, "TrashBin", Vector3.new(2.8, 2.2, 2.2), CFrame.new(position + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(86, 96, 100), M.Metal)
	bin.Shape = Enum.PartType.Cylinder
	Parts.Deco(parent, "BinLid", Vector3.new(0.3, 2.5, 2.5), CFrame.new(position + Vector3.new(0.2, 3, 0)) * CFrame.Angles(0, 0, math.rad(90 + rng:NextInteger(-14, 14))), Color3.fromRGB(70, 78, 82), M.Metal, Enum.PartType.Cylinder)
	for _, y in { 0.9, 2 } do
		Parts.Deco(parent, "BinRing", Vector3.new(0.12, 2.3, 2.3), CFrame.new(position + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 66, 70), M.Metal, Enum.PartType.Cylinder)
	end
end

function Scenery.Crates(parent: Instance, position: Vector3, rng: Random)
	local color = Color3.fromRGB(128, 96, 64)
	Parts.Block(parent, "Crate", Vector3.new(2.6, 2.6, 2.6), CFrame.new(position + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, math.rad(rng:NextInteger(-15, 15)), 0), color, M.WoodPlanks)
	Parts.Block(parent, "Crate", Vector3.new(2, 2, 2), CFrame.new(position + Vector3.new(2.6, 1, 0.4)) * CFrame.Angles(0, math.rad(rng:NextInteger(-25, 25)), 0), color:Lerp(Color3.new(0, 0, 0), 0.15), M.WoodPlanks)
	Parts.Block(parent, "Crate", Vector3.new(1.8, 1.8, 1.8), CFrame.new(position + Vector3.new(0.3, 3.5, 0.1)) * CFrame.Angles(0, math.rad(rng:NextInteger(-30, 30)), 0), color:Lerp(Color3.new(1, 1, 1), 0.08), M.WoodPlanks)
end

function Scenery.Puddle(parent: Instance, position: Vector3, size: number)
	local puddle = Parts.Deco(parent, "Puddle", Vector3.new(0.06, size, size * 0.7), CFrame.new(position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 52, 80), M.Glass, Enum.PartType.Cylinder)
	puddle.Transparency = 0.25
	puddle.Reflectance = 0.35
end

function Scenery.Bench(parent: Instance, cframe: CFrame)
	Parts.Block(parent, "BenchSeat", Vector3.new(6, 0.4, 1.8), cframe * CFrame.new(0, 1.6, 0), C.wood, M.Wood)
	Parts.Block(parent, "BenchBack", Vector3.new(6, 1.6, 0.3), cframe * CFrame.new(0, 2.7, 0.8) * CFrame.Angles(math.rad(-8), 0, 0), C.wood, M.Wood)
	for _, x in { -2.6, 2.6 } do
		Parts.Deco(parent, "BenchLeg", Vector3.new(0.3, 1.6, 1.6), cframe * CFrame.new(x, 0.8, 0), C.metal, M.Metal)
		Parts.Deco(parent, "BenchArm", Vector3.new(0.3, 0.25, 2), cframe * CFrame.new(x, 2.3, 0), C.metal, M.Metal)
	end
end

-- Sznur z praniem między dwoma słupkami; jedno prześcieradło wygląda jak duszek
function Scenery.Clothesline(parent: Instance, from: Vector3, to: Vector3, rng: Random)
	local height = 7
	for _, base in { from, to } do
		Parts.Block(parent, "LinePost", Vector3.new(0.4, height, 0.4), CFrame.new(base + Vector3.new(0, height / 2, 0)), C.darkWood, M.Wood)
		Parts.Deco(parent, "LinePostArm", Vector3.new(0.3, 0.3, 2), CFrame.lookAt(base + Vector3.new(0, height - 0.3, 0), to + Vector3.new(0, height - 0.3, 0)) * CFrame.Angles(0, math.rad(90), 0), C.darkWood, M.Wood)
	end
	local a, b = from + Vector3.new(0, height - 0.4, 0), to + Vector3.new(0, height - 0.4, 0)
	rod(parent, "Line", a, b, 0.08, Color3.fromRGB(220, 220, 210))
	local count = math.max(2, math.floor((b - a).Magnitude / 4))
	local ghost = rng:NextInteger(1, count)
	for i = 1, count do
		local point = a:Lerp(b, i / (count + 1))
		local frame = CFrame.lookAt(point, b) * CFrame.Angles(0, math.rad(90), 0)
		local drop = if i == ghost then 3.6 else 2.2 + rng:NextNumber() * 1.6
		local color = if i == ghost then Color3.fromRGB(240, 240, 235) else pick(rng, { Color3.fromRGB(230, 230, 220), Color3.fromRGB(190, 210, 230), Color3.fromRGB(230, 200, 200) })
		local sheet = Parts.Deco(parent, "Laundry", Vector3.new(2.6, drop, 0.1), frame * CFrame.new(0, -drop / 2 - 0.05, 0) * CFrame.Angles(math.rad(rng:NextInteger(-6, 6)), 0, 0), color, M.Fabric)
		if i == ghost then
			for _, x in { -0.5, 0.5 } do
				for _, side in { -1, 1 } do
					Parts.Deco(parent, "GhostEye", Vector3.new(0.4, 0.55, 0.04), sheet.CFrame * CFrame.new(x, 0.7, side * 0.07), C.black)
				end
			end
		end
	end
end

-- Kuty płot: słupki z kulkami i trzy poprzeczki (środkowa ma kolizję)
function Scenery.IronFence(parent: Instance, from: Vector3, to: Vector3, height: number?)
	local h = height or 4.5
	local length = (to - from).Magnitude
	local count = math.max(1, math.floor(length / 3.5))
	for i = 0, count do
		local base = from:Lerp(to, i / count)
		Parts.Deco(parent, "FencePost", Vector3.new(0.35, h, 0.35), CFrame.new(base + Vector3.new(0, h / 2, 0)), C.metal, M.Metal)
		Parts.Deco(parent, "FenceBall", Vector3.new(0.6, 0.6, 0.6), CFrame.new(base + Vector3.new(0, h + 0.25, 0)), C.metal, M.Metal, Enum.PartType.Ball)
	end
	local frame = CFrame.lookAt((from + to) / 2, to)
	Parts.Block(parent, "FenceRail", Vector3.new(0.2, h * 0.7, length), frame * CFrame.new(0, h * 0.45, 0), C.metal, M.Metal).Transparency = 1
	for _, y in { 0.6, h * 0.55, h - 0.5 } do
		Parts.Deco(parent, "FenceRail", Vector3.new(0.16, 0.16, length), frame * CFrame.new(0, y, 0), C.metal, M.Metal)
	end
	local bars = math.floor(length / 1.2)
	for i = 1, bars - 1 do
		if i % 3 ~= 0 then
			Parts.Deco(parent, "FenceBar", Vector3.new(0.1, h - 1.1, 0.1), CFrame.new(from:Lerp(to, i / bars) + Vector3.new(0, 0.6 + (h - 1.1) / 2, 0)), C.metal, M.Metal)
		end
	end
end

-- Ulica: asfalt, krawężniki i przerywana linia. frame = środek ulicy, oś Z wzdłuż jezdni.
function Scenery.Street(parent: Instance, frame: CFrame, length: number, width: number)
	Parts.Block(parent, "Street", Vector3.new(width, 0.3, length), frame * CFrame.new(0, 0.05, 0), C.asphalt, M.Asphalt)
	for _, side in { -1, 1 } do
		Parts.Block(parent, "Sidewalk", Vector3.new(4, 0.5, length), frame * CFrame.new(side * (width / 2 + 2), 0.2, 0), C.curb, M.Concrete)
	end
	for z = -length / 2 + 4, length / 2 - 4, 9 do
		Parts.Deco(parent, "StreetLine", Vector3.new(0.5, 0.04, 4), frame * CFrame.new(0, 0.22, z), Color3.fromRGB(210, 205, 180))
	end
end

-- Dom w tle: bryła, dwuspadowy dach, komin i kilka okien (część zapalona). frame = na ziemi pośrodku
-- frontu, -Z = strona, z której dom widać.
function Scenery.House(parent: Instance, frame: CFrame, width: number, height: number, depth: number, rng: Random)
	local color = pick(rng, C.houses)
	Parts.Deco(parent, "House", Vector3.new(width, height, depth), frame * CFrame.new(0, height / 2, depth / 2), color, M.Brick)
	-- Dach dwuspadowy: dwie pochylone płyty (kalenica równolegle do frontu)
	local rise = 5 + rng:NextNumber() * 3
	local half = depth / 2 + 1
	for _, side in { -1, 1 } do
		local eave = Vector3.new(0, height, depth / 2 + side * half)
		local ridge = Vector3.new(0, height + rise, depth / 2)
		Parts.Deco(parent, "HouseRoof", Vector3.new(width + 1.6, 0.6, (ridge - eave).Magnitude + 0.4), frame * CFrame.lookAt((eave + ridge) / 2, ridge), C.roof, M.Slate)
	end
	for _, side in { -1, 1 } do
		Parts.Deco(parent, "HouseGable", Vector3.new(0.5, rise * 0.55, depth * 0.55), frame * CFrame.new(side * (width / 2 - 0.25), height + rise * 0.27, depth / 2), color, M.Brick)
	end
	local chimney = Parts.Deco(parent, "HouseChimney", Vector3.new(2, rise + 2, 2), frame * CFrame.new(width * (rng:NextNumber() - 0.5) * 0.6, height + rise * 0.7, depth / 2 + 1.5), C.brick, M.Brick)
	if rng:NextNumber() < 0.5 then
		Scenery.Smoke(chimney, 2)
	end
	-- Okna na froncie
	local columns = math.max(2, math.floor(width / 7))
	local rows = math.max(1, math.floor(height / 10))
	for row = 1, rows do
		for column = 1, columns do
			local x = (column - (columns + 1) / 2) * (width / columns)
			local y = (row - 0.45) * (height / rows)
			local lit = rng:NextNumber() < 0.3
			Parts.Deco(parent, "HouseWindowFrame", Vector3.new(3.6, 4.6, 0.2), frame * CFrame.new(x, y, -0.08), C.trim)
			Parts.Deco(parent, "HouseWindow", Vector3.new(3, 4, 0.24), frame * CFrame.new(x, y, -0.1), if lit then C.windowLit else C.windowDark, if lit then M.Neon else M.Glass)
		end
	end
	Parts.Deco(parent, "HouseCornice", Vector3.new(width + 0.8, 0.7, 0.7), frame * CFrame.new(0, height - 0.4, -0.3), C.trim)
	Parts.Deco(parent, "HousePlinth", Vector3.new(width + 0.3, 1.8, 0.4), frame * CFrame.new(0, 0.9, -0.2), C.stone, M.Slate)
end

-- Fasada kamienicy ----------------------------------------------------------------------------------
-- frame = na ziemi pośrodku fasady, -Z = na zewnątrz (w stronę patrzącego). Sama ściana nie jest budowana.
-- opts: width, height, rows = { wysokości środków okien }, columns = { przesunięcia okien w poziomie },
--   skipGround = { kolumny bez okna na parterze }, windowSize = Vector2, wall = kolor ściany,
--   door = { width, height } albo nil, balconyY = wysokość balkonu nad drzwiami albo nil (wtedy daszek),
--   cat = { row, column } okno z oczami Mruczka, litChance, roof = { rise, run, depth }, dormers = { x },
--   chimneys = { x }, ivy = x albo nil, rng
function Scenery.Facade(parent: Instance, frame: CFrame, opts)
	local rng: Random = opts.rng
	local width, height = opts.width, opts.height
	local w, h = opts.windowSize.X, opts.windowSize.Y
	local half = width / 2
	local door = opts.door
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end

	-- Okna: rama, szyba, szprosy, nadproże, parapet, okiennice, czasem skrzynka z kwiatami
	for row, y in opts.rows do
		for _, x in opts.columns do
			if row == 1 and table.find(opts.skipGround or {}, x) then
				continue
			end
			local balconyDoor = opts.balconyY ~= nil and row == 2 and x == 0
			local top = y + h / 2
			local bottom = if balconyDoor then opts.balconyY + 0.3 else y - h / 2
			local hh = top - bottom
			local cy = (top + bottom) / 2
			local isCat = opts.cat ~= nil and opts.cat.row == row and opts.cat.column == x
			local lit = not isCat and rng:NextNumber() < (opts.litChance or 0.4)
			Parts.Deco(parent, "WindowFrame", Vector3.new(w + 0.9, hh + 0.9, 0.3), at(x, cy, -0.16), C.trim, M.Plaster)
			Parts.Deco(parent, "Window", Vector3.new(w, hh, 0.34), at(x, cy, -0.18), if lit then C.windowLit else C.windowDark, if lit then M.Neon else M.Glass)
			Parts.Deco(parent, "WindowBar", Vector3.new(0.22, hh, 0.4), at(x, cy, -0.19), C.trim, M.Plaster)
			Parts.Deco(parent, "WindowBar", Vector3.new(w, 0.22, 0.4), at(x, cy + hh * 0.18, -0.19), C.trim, M.Plaster)
			Parts.Deco(parent, "WindowLintel", Vector3.new(w + 1.7, 0.7, 0.6), at(x, top + 0.75, -0.3), C.trim, M.Plaster)
			if isCat then
				for _, dx in { -0.6, 0.6 } do
					Parts.Deco(parent, "CatEye", Vector3.new(0.45, 0.45, 0.45), at(x + dx, cy + 0.3, -0.4), Color3.fromRGB(255, 240, 80), M.Neon, Enum.PartType.Ball)
				end
			end
			if not balconyDoor then
				Parts.Deco(parent, "WindowSill", Vector3.new(w + 1.7, 0.4, 0.9), at(x, bottom - 0.6, -0.42), C.trim, M.Plaster)
				local shutterColor = pick(rng, C.shutters)
				local sw = w * 0.42
				for _, side in { -1, 1 } do
					local crooked = rng:NextNumber() < 0.1
					local shutter = at(x + side * (w / 2 + 0.3 + sw / 2), cy - (if crooked then 0.35 else 0), -0.12)
					if crooked then
						shutter *= CFrame.Angles(0, 0, math.rad(side * -9))
					end
					Parts.Deco(parent, "Shutter", Vector3.new(sw, hh, 0.16), shutter, shutterColor, M.WoodPlanks)
				end
				if rng:NextNumber() < 0.3 then
					Parts.Deco(parent, "FlowerBox", Vector3.new(w + 0.4, 0.7, 0.9), at(x, bottom - 0.1, -1), C.darkWood, M.Wood)
					for i = -1, 1 do
						Parts.Blob(parent, "Flowers", Vector3.new(1.1, 0.9, 0.9), at(x + i * (w / 3), bottom + 0.45, -1), pick(rng, C.flowers), M.Grass)
					end
				end
			end
		end
	end

	-- Cokół z okienkami piwnicy, gzymsy, narożniki, rynna i rury spustowe
	local gap = if door then door.width / 2 + 1.2 else 0
	for _, side in { -1, 1 } do
		local length = half - gap
		Parts.Deco(parent, "Plinth", Vector3.new(length, 2.4, 0.5), at(side * (gap + length / 2), 1.2, -0.25), C.stone, M.Slate)
	end
	for _, x in opts.columns do
		if not table.find(opts.skipGround or {}, x) or (door == nil) then
			Parts.Deco(parent, "CellarWindow", Vector3.new(2.2, 0.9, 0.56), at(x, 1.15, -0.26), C.black, M.Glass)
			for i = -1, 1 do
				Parts.Deco(parent, "CellarBar", Vector3.new(0.12, 0.9, 0.62), at(x + i * 0.6, 1.15, -0.27), C.metal, M.Metal)
			end
		end
	end
	for i = 1, #opts.rows - 1 do
		Parts.Deco(parent, "Cornice", Vector3.new(width + 0.8, 0.7, 0.8), at(0, (opts.rows[i] + opts.rows[i + 1]) / 2, -0.4), C.trim, M.Plaster)
	end
	Parts.Deco(parent, "TopCornice", Vector3.new(width + 1.6, 1, 1.4), at(0, height - 0.5, -0.7), C.trim, M.Plaster)
	for x = -half + 1.5, half - 1.5, 2.6 do
		Parts.Deco(parent, "Dentil", Vector3.new(0.9, 0.6, 0.5), at(x, height - 1.3, -0.55), C.trim, M.Plaster)
	end
	local toggle = false
	for y = 1.2, height - 2.2, 2.4 do
		toggle = not toggle
		local qw = if toggle then 1.3 else 0.9
		for _, side in { -1, 1 } do
			Parts.Deco(parent, "Quoin", Vector3.new(qw, 1.6, 0.36), at(side * (half - qw / 2), y + 1.4, -0.18), C.trim, M.Plaster)
		end
	end
	Parts.Deco(parent, "Gutter", Vector3.new(width + 2, 0.6, 0.6), at(0, height + 0.05, -1.55), C.pipe, M.Metal, Enum.PartType.Cylinder)
	for _, side in { -1, 1 } do
		pillar(parent, "Drainpipe", height - 0.6, 0.45, at(side * (half - 2), height / 2 - 0.2, -0.6), C.pipe, M.Metal)
		Parts.Deco(parent, "DrainElbow", Vector3.new(0.45, 0.45, 1.2), at(side * (half - 2), 0.45, -1), C.pipe, M.Metal)
		Parts.Deco(parent, "DrainHead", Vector3.new(0.8, 0.8, 1.1), at(side * (half - 2), height - 0.3, -1), C.pipe, M.Metal)
	end

	-- Portal drzwi z latarenkami; nad nim balkon albo daszek
	if door then
		for _, side in { -1, 1 } do
			Parts.Deco(parent, "PortalJamb", Vector3.new(1, door.height + 0.6, 1), at(side * (door.width / 2 + 0.5), (door.height + 0.6) / 2, -0.45), C.trim, M.Plaster)
			Parts.Deco(parent, "LanternBracket", Vector3.new(0.2, 0.2, 1), at(side * (door.width / 2 + 2.2), door.height - 0.6, -0.6), C.metal, M.Metal)
			Scenery.Lantern(parent, at(side * (door.width / 2 + 2.2), door.height - 1.3, -1.05).Position, 1.3, 22)
		end
		Parts.Deco(parent, "PortalHead", Vector3.new(door.width + 2.4, 1.1, 1.2), at(0, door.height + 1.1, -0.5), C.trim, M.Plaster)
		Parts.Deco(parent, "Keystone", Vector3.new(1.3, 1.7, 1.4), at(0, door.height + 1.15, -0.55), C.stone, M.Slate)
		if opts.balconyY then
			local by = opts.balconyY
			local bw = door.width + 5
			Parts.Deco(parent, "Balcony", Vector3.new(bw, 0.45, 3.1), at(0, by - 0.22, -1.55), C.trim, M.Concrete)
			for _, side in { -1, 1 } do
				Parts.Deco(parent, "Corbel", Vector3.new(0.8, 1.3, 2.2), at(side * (door.width / 2 + 1.5), by - 1.1, -1.1), C.stone, M.Slate)
				Parts.Deco(parent, "BalconyRail", Vector3.new(0.22, 0.22, 3), at(side * (bw / 2 - 0.15), by + 2.6, -1.5), C.metal, M.Metal)
				for z = -0.6, -2.4, -0.9 do
					Parts.Deco(parent, "Baluster", Vector3.new(0.16, 2.5, 0.16), at(side * (bw / 2 - 0.15), by + 1.3, z), C.metal, M.Metal)
				end
				Parts.Blob(parent, "BalconyPlant", Vector3.new(1.3, 1.5, 1.3), at(side * (bw / 2 - 1.2), by + 0.9, -2.1), C.leaves, M.Grass)
				Parts.Deco(parent, "BalconyPot", Vector3.new(0.9, 0.7, 0.9), at(side * (bw / 2 - 1.2), by + 0.35, -2.1), Color3.fromRGB(150, 90, 60), M.Slate)
			end
			Parts.Deco(parent, "BalconyRail", Vector3.new(bw, 0.22, 0.22), at(0, by + 2.6, -2.95), C.metal, M.Metal)
			for x = -bw / 2 + 0.3, bw / 2 - 0.3, 0.85 do
				Parts.Deco(parent, "Baluster", Vector3.new(0.16, 2.5, 0.16), at(x, by + 1.3, -2.95), C.metal, M.Metal)
			end
		else
			Parts.Deco(parent, "Canopy", Vector3.new(door.width + 4, 0.4, 3.2), at(0, door.height + 2.3, -1.7) * CFrame.Angles(math.rad(-8), 0, 0), C.roof, M.Slate)
		end
	end

	-- Dach mansardowy z lukarnami, ścianami szczytowymi i kominami
	local roof = opts.roof
	if roof then
		local eave = Vector3.new(0, height + 0.2, -1.4)
		local ridge = Vector3.new(0, height + roof.rise, roof.run)
		Parts.Deco(parent, "RoofSlope", Vector3.new(width + 2.4, 0.6, (ridge - eave).Magnitude), frame * CFrame.lookAt((eave + ridge) / 2, ridge), C.roof, M.Slate)
		Parts.Deco(parent, "RoofDeck", Vector3.new(width + 2.4, 0.6, roof.depth), at(0, height + roof.rise, roof.run + roof.depth / 2 - 0.2), C.roof, M.Slate)
		Parts.Deco(parent, "RoofRidge", Vector3.new(width + 2.6, 0.5, 0.7), at(0, height + roof.rise + 0.3, roof.run), C.pipe, M.Metal)
		for _, side in { -1, 1 } do
			Parts.Deco(parent, "Firewall", Vector3.new(0.8, roof.rise + 0.8, roof.run + roof.depth + 1), at(side * (half + 0.9), height + roof.rise / 2 + 0.2, (roof.run + roof.depth - 1) / 2), opts.wall, M.Brick)
			Parts.Deco(parent, "FirewallCap", Vector3.new(1.1, 0.35, roof.run + roof.depth + 1.3), at(side * (half + 0.9), height + roof.rise + 0.75, (roof.run + roof.depth - 1) / 2), C.trim, M.Plaster)
		end
		for _, x in opts.dormers or {} do
			local t = 0.42
			local zs = eave.Z + (ridge.Z - eave.Z) * t
			local ys = eave.Y + (ridge.Y - eave.Y) * t
			local lit = rng:NextNumber() < 0.35
			Parts.Deco(parent, "Dormer", Vector3.new(3.4, 3.4, 3.6), at(x, ys + 1.3, zs + 1.3), opts.wall, M.Brick)
			Parts.Deco(parent, "DormerWindow", Vector3.new(2.2, 2.2, 0.2), at(x, ys + 1.4, zs - 0.55), if lit then C.windowLit else C.windowDark, if lit then M.Neon else M.Glass)
			Parts.Deco(parent, "DormerFrame", Vector3.new(2.8, 2.8, 0.14), at(x, ys + 1.4, zs - 0.5), C.trim, M.Plaster)
			Parts.Deco(parent, "DormerRoof", Vector3.new(4.2, 0.4, 4.4), at(x, ys + 3.2, zs + 1) * CFrame.Angles(math.rad(-10), 0, 0), C.roof, M.Slate)
		end
		for _, x in opts.chimneys or {} do
			Parts.Deco(parent, "Chimney", Vector3.new(2.6, 5, 2.2), at(x, height + roof.rise + 2.5, roof.run + 2.2), C.brick, M.Brick)
			local cap = Parts.Deco(parent, "ChimneyCap", Vector3.new(3.2, 0.5, 2.8), at(x, height + roof.rise + 5.2, roof.run + 2.2), C.stone, M.Slate)
			Scenery.Smoke(cap, 3)
		end
		-- Antena na dachu
		local antenna = at(half * 0.35, height + roof.rise, roof.run + 1.5)
		Parts.Deco(parent, "Antenna", Vector3.new(0.14, 5, 0.14), antenna * CFrame.new(0, 2.5, 0), C.metal, M.Metal)
		for i = 0, 2 do
			Parts.Deco(parent, "AntennaBar", Vector3.new(2.4 - i * 0.5, 0.1, 0.1), antenna * CFrame.new(0, 3.4 + i * 0.6, 0), C.metal, M.Metal)
		end
	end

	-- Bluszcz pnący się po ścianie
	if opts.ivy then
		for i = 1, 14 do
			local x = opts.ivy + (rng:NextNumber() - 0.5) * 5 * (1 - i / 22)
			local y = 0.8 + i * (height * 0.055) + rng:NextNumber()
			local size = 2.2 + rng:NextNumber() * 1.6
			Parts.Blob(parent, "Ivy", Vector3.new(size, size * 0.9, 0.7), at(x, y, -0.3), C.leaves:Lerp(Color3.fromRGB(80, 60, 40), rng:NextNumber() * 0.25), M.Grass)
		end
	end
end

return Scenery

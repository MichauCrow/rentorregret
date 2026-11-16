-- Meble z bloków. cframe = punkt na podłodze, przód mebla to -Z (tył stoi przy ścianie).
-- Moduł wspólny: serwer stawia meble w mieszkaniu, klient buduje z niego podgląd przy ustawianiu.
local FurnitureBuilder = {}

local COLORS = {
	pot = Color3.fromRGB(170, 95, 60),
	leaves = Color3.fromRGB(70, 170, 80),
	metal = Color3.fromRGB(90, 95, 105),
	warm = Color3.fromRGB(255, 230, 170),
	rug = Color3.fromRGB(210, 70, 80),
	rugStripe = Color3.fromRGB(255, 210, 80),
	armchair = Color3.fromRGB(60, 170, 170),
	wood = Color3.fromRGB(140, 95, 60),
	dark = Color3.fromRGB(30, 30, 35),
	screen = Color3.fromRGB(80, 170, 255),
	water = Color3.fromRGB(120, 200, 255),
	fishA = Color3.fromRGB(255, 140, 40),
	fishB = Color3.fromRGB(255, 230, 60),
	sofa = Color3.fromRGB(150, 90, 200),
	pillow = Color3.fromRGB(255, 220, 120),
	books = { Color3.fromRGB(220, 70, 70), Color3.fromRGB(70, 130, 220), Color3.fromRGB(80, 190, 100) },
}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local BUILDERS = {}

function BUILDERS.plant(model, at)
	part(model, "Pot", Vector3.new(1.4, 1.4, 1.4), at(0, 0.7, 0), COLORS.pot, Enum.Material.Slate)
	part(model, "Leaves", Vector3.new(2.4, 2.4, 2.4), at(0, 2.4, 0), COLORS.leaves, Enum.Material.Grass, Enum.PartType.Ball)
end

function BUILDERS.lamp(model, at)
	part(model, "Base", Vector3.new(0.3, 1.4, 1.4), at(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), COLORS.metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(model, "Pole", Vector3.new(0.25, 4, 0.25), at(0, 2.2, 0), COLORS.metal, Enum.Material.Metal)
	local shade = part(model, "Shade", Vector3.new(1.6, 1.2, 1.6), at(0, 4.6, 0), COLORS.warm, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 1
	light.Color = COLORS.warm
	light.Parent = shade
end

function BUILDERS.rug(model, at)
	part(model, "Rug", Vector3.new(6, 0.08, 4), at(0, 0.04, 0), COLORS.rug, Enum.Material.Fabric)
	part(model, "Stripe", Vector3.new(6, 0.09, 0.6), at(0, 0.045, 0), COLORS.rugStripe, Enum.Material.Fabric)
end

function BUILDERS.armchair(model, at)
	part(model, "Seat", Vector3.new(3, 1.2, 2.6), at(0, 0.8, 0), COLORS.armchair, Enum.Material.Fabric)
	part(model, "Back", Vector3.new(3, 2.2, 0.6), at(0, 2, 1.1), COLORS.armchair, Enum.Material.Fabric)
	part(model, "ArmL", Vector3.new(0.5, 1.6, 2.6), at(-1.6, 1, 0), COLORS.armchair, Enum.Material.Fabric)
	part(model, "ArmR", Vector3.new(0.5, 1.6, 2.6), at(1.6, 1, 0), COLORS.armchair, Enum.Material.Fabric)
end

function BUILDERS.bookshelf(model, at)
	part(model, "Frame", Vector3.new(3.6, 5, 1.2), at(0, 2.5, 0.4), COLORS.wood, Enum.Material.Wood)
	for index, y in { 1.2, 2.6, 4 } do
		part(model, "Books", Vector3.new(3.2, 0.9, 0.3), at(0, y, -0.25), COLORS.books[index])
	end
end

function BUILDERS.tv(model, at)
	part(model, "Stand", Vector3.new(3.6, 1.4, 1.4), at(0, 0.7, 0.2), COLORS.wood, Enum.Material.Wood)
	part(model, "Frame", Vector3.new(3.4, 2.1, 0.25), at(0, 2.5, 0.3), COLORS.dark)
	part(model, "Display", Vector3.new(3.1, 1.8, 0.05), at(0, 2.5, 0.16), COLORS.screen, Enum.Material.Neon)
end

function BUILDERS.aquarium(model, at)
	part(model, "Stand", Vector3.new(3.6, 1.6, 1.6), at(0, 0.8, 0.1), COLORS.wood, Enum.Material.Wood)
	local tank = part(model, "Tank", Vector3.new(3.4, 2, 1.4), at(0, 2.6, 0.1), COLORS.water, Enum.Material.Glass)
	tank.Transparency = 0.5
	part(model, "FishA", Vector3.new(0.5, 0.3, 0.15), at(-0.6, 2.6, 0.1), COLORS.fishA, Enum.Material.Neon)
	part(model, "FishB", Vector3.new(0.5, 0.3, 0.15), at(0.7, 2.9, 0.1), COLORS.fishB, Enum.Material.Neon)
end

function BUILDERS.sofa(model, at)
	part(model, "Seat", Vector3.new(4.2, 1.2, 2.4), at(0, 0.8, 0), COLORS.sofa, Enum.Material.Fabric)
	part(model, "Back", Vector3.new(4.2, 2.2, 0.6), at(0, 2, 1), COLORS.sofa, Enum.Material.Fabric)
	part(model, "ArmL", Vector3.new(0.6, 1.6, 2.4), at(-2.4, 1, 0), COLORS.sofa, Enum.Material.Fabric)
	part(model, "ArmR", Vector3.new(0.6, 1.6, 2.4), at(2.4, 1, 0), COLORS.sofa, Enum.Material.Fabric)
	part(model, "Pillow", Vector3.new(1.2, 1, 0.4), at(-1.2, 1.8, 0.5), COLORS.pillow, Enum.Material.Fabric)
end

-- Wyposażenie pokoi ------------------------------------------------------------------
local ROOM = {
	lightWood = Color3.fromRGB(205, 160, 110),
	white = Color3.fromRGB(245, 245, 248),
	blanket = Color3.fromRGB(90, 160, 230),
	blanketB = Color3.fromRGB(255, 120, 150),
	paper = Color3.fromRGB(255, 255, 255),
	gaming = Color3.fromRGB(255, 60, 90),
	bean = Color3.fromRGB(170, 90, 230),
	gold = Color3.fromRGB(255, 205, 60),
}

function BUILDERS.chair(model, at)
	part(model, "Seat", Vector3.new(1.8, 0.3, 1.8), at(0, 1.6, 0), COLORS.wood, Enum.Material.Wood)
	part(model, "Back", Vector3.new(1.8, 2, 0.25), at(0, 2.75, 0.8), COLORS.wood, Enum.Material.Wood)
	for _, x in { -0.75, 0.75 } do
		for _, z in { -0.75, 0.75 } do
			part(model, "Leg", Vector3.new(0.2, 1.5, 0.2), at(x, 0.75, z), COLORS.wood, Enum.Material.Wood)
		end
	end
	part(model, "Cushion", Vector3.new(1.5, 0.15, 1.5), at(0, 1.82, -0.05), ROOM.blanketB, Enum.Material.Fabric)
end

function BUILDERS.beanBag(model, at)
	part(model, "Bag", Vector3.new(2.6, 1.6, 2.6), at(0, 0.8, 0), ROOM.bean, Enum.Material.Fabric, Enum.PartType.Ball)
	part(model, "Top", Vector3.new(1.9, 1.3, 1.9), at(0, 1.5, 0.35), ROOM.bean, Enum.Material.Fabric, Enum.PartType.Ball)
end

function BUILDERS.table(model, at)
	part(model, "Top", Vector3.new(4.2, 0.3, 2.6), at(0, 2.6, 0), ROOM.lightWood, Enum.Material.Wood)
	for _, x in { -1.8, 1.8 } do
		for _, z in { -1, 1 } do
			part(model, "Leg", Vector3.new(0.3, 2.45, 0.3), at(x, 1.22, z), ROOM.lightWood, Enum.Material.Wood)
		end
	end
	part(model, "Vase", Vector3.new(0.5, 0.8, 0.5), at(0, 3.15, 0), COLORS.water, Enum.Material.Glass)
	part(model, "Flower", Vector3.new(0.6, 0.6, 0.6), at(0, 3.75, 0), ROOM.blanketB, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.desk(model, at)
	part(model, "Top", Vector3.new(4, 0.3, 2), at(0, 2.6, 0.2), ROOM.white)
	part(model, "Drawers", Vector3.new(1.4, 2.45, 1.8), at(1.2, 1.22, 0.2), ROOM.white)
	part(model, "Leg", Vector3.new(0.25, 2.45, 1.8), at(-1.8, 1.22, 0.2), ROOM.white)
	for _, y in { 0.7, 1.5, 2.2 } do
		part(model, "Knob", Vector3.new(0.4, 0.12, 0.1), at(1.2, y, -0.72), ROOM.gold, Enum.Material.Metal)
	end
	part(model, "Notebook", Vector3.new(1, 0.08, 0.7), at(-0.7, 2.79, 0), ROOM.blanket)
	part(model, "Pencils", Vector3.new(0.35, 0.6, 0.35), at(0.6, 3.05, 0.6), ROOM.gaming, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
end

function BUILDERS.printer(model, at)
	part(model, "Stand", Vector3.new(2, 1.6, 1.6), at(0, 0.8, 0.1), ROOM.lightWood, Enum.Material.Wood)
	part(model, "Body", Vector3.new(1.8, 0.8, 1.4), at(0, 2, 0.1), Color3.fromRGB(60, 62, 70))
	part(model, "Tray", Vector3.new(1.3, 0.08, 0.6), at(0, 1.75, -0.8), Color3.fromRGB(60, 62, 70))
	part(model, "Paper", Vector3.new(1, 0.05, 0.8), at(0, 1.82, -0.75), ROOM.paper)
	part(model, "PaperIn", Vector3.new(1, 0.6, 0.05), at(0, 2.6, 0.6), ROOM.paper)
	part(model, "Light", Vector3.new(0.15, 0.15, 0.05), at(0.6, 2.2, -0.62), Color3.fromRGB(90, 255, 120), Enum.Material.Neon)
end

function BUILDERS.bed(model, at)
	part(model, "Frame", Vector3.new(3.6, 1, 6), at(0, 0.5, -1.2), COLORS.wood, Enum.Material.Wood)
	part(model, "Mattress", Vector3.new(3.4, 0.6, 5.8), at(0, 1.3, -1.2), ROOM.white, Enum.Material.Fabric)
	part(model, "Blanket", Vector3.new(3.5, 0.3, 3.8), at(0, 1.65, -2.2), ROOM.blanket, Enum.Material.Fabric)
	part(model, "Pillow", Vector3.new(2.4, 0.5, 1.1), at(0, 1.85, 0.9), ROOM.white, Enum.Material.Fabric)
	part(model, "Headboard", Vector3.new(3.6, 2.6, 0.3), at(0, 1.3, 1.65), COLORS.wood, Enum.Material.Wood)
end

function BUILDERS.bunkBed(model, at)
	for _, x in { -1.75, 1.75 } do
		for _, z in { -4, 1.6 } do
			part(model, "Post", Vector3.new(0.3, 6.4, 0.3), at(x, 3.2, z), ROOM.lightWood, Enum.Material.Wood)
		end
	end
	for index, y in { 1, 4.2 } do
		part(model, "Frame", Vector3.new(3.5, 0.4, 5.8), at(0, y, -1.2), ROOM.lightWood, Enum.Material.Wood)
		part(model, "Mattress", Vector3.new(3.3, 0.5, 5.6), at(0, y + 0.45, -1.2), ROOM.white, Enum.Material.Fabric)
		part(model, "Blanket", Vector3.new(3.4, 0.25, 3.6), at(0, y + 0.75, -2.2), if index == 1 then ROOM.blanket else ROOM.blanketB, Enum.Material.Fabric)
		part(model, "Pillow", Vector3.new(2.2, 0.45, 1), at(0, y + 0.9, 0.9), ROOM.white, Enum.Material.Fabric)
	end
	part(model, "Rail", Vector3.new(0.2, 0.6, 5.6), at(-1.75, 5.2, -1.2), ROOM.lightWood, Enum.Material.Wood)
	for y = 1.6, 4.4, 0.9 do
		part(model, "Rung", Vector3.new(0.15, 0.15, 1.2), at(1.85, y, -3.3), ROOM.lightWood, Enum.Material.Wood)
	end
end

function BUILDERS.wardrobe(model, at)
	part(model, "Body", Vector3.new(3.6, 6, 1.8), at(0, 3, 0.3), ROOM.lightWood, Enum.Material.Wood)
	part(model, "Split", Vector3.new(0.08, 5.6, 0.05), at(0, 3, -0.62), COLORS.wood)
	for _, x in { -0.35, 0.35 } do
		part(model, "Handle", Vector3.new(0.12, 0.8, 0.12), at(x, 3.2, -0.66), ROOM.gold, Enum.Material.Metal)
	end
	part(model, "Top", Vector3.new(3.8, 0.25, 2), at(0, 6.1, 0.3), COLORS.wood, Enum.Material.Wood)
end

function BUILDERS.computer(model, at)
	part(model, "Desk", Vector3.new(3.6, 0.3, 1.8), at(0, 2.5, 0.2), COLORS.dark)
	for _, x in { -1.6, 1.6 } do
		part(model, "Leg", Vector3.new(0.2, 2.35, 1.6), at(x, 1.17, 0.2), COLORS.dark)
	end
	part(model, "Monitor", Vector3.new(2.2, 1.3, 0.15), at(0, 3.7, 0.6), COLORS.dark)
	part(model, "Screen", Vector3.new(2, 1.1, 0.05), at(0, 3.7, 0.5), COLORS.screen, Enum.Material.Neon)
	part(model, "MonitorStand", Vector3.new(0.2, 0.6, 0.2), at(0, 2.95, 0.65), COLORS.dark)
	part(model, "Keyboard", Vector3.new(1.6, 0.08, 0.5), at(0, 2.69, -0.2), Color3.fromRGB(80, 80, 90))
	part(model, "Mouse", Vector3.new(0.25, 0.1, 0.35), at(1.1, 2.69, -0.2), Color3.fromRGB(80, 80, 90))
	part(model, "Tower", Vector3.new(0.7, 1.6, 1.4), at(1.3, 3.45, 0.3), COLORS.dark)
	part(model, "TowerLight", Vector3.new(0.05, 1.3, 0.1), at(0.94, 3.45, -0.2), ROOM.gaming, Enum.Material.Neon)
end

function BUILDERS.grandClock(model, at)
	part(model, "Case", Vector3.new(1.6, 6, 1.2), at(0, 3, 0.2), COLORS.wood, Enum.Material.Wood)
	part(model, "Face", Vector3.new(0.1, 1.2, 1.2), at(0, 5.1, -0.42) * CFrame.Angles(0, math.rad(90), 0), ROOM.white, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(model, "HandA", Vector3.new(0.06, 0.45, 0.04), at(0, 5.25, -0.49), COLORS.dark)
	part(model, "HandB", Vector3.new(0.35, 0.06, 0.04), at(0.12, 5.1, -0.49), COLORS.dark)
	local glass = part(model, "Glass", Vector3.new(1, 2.6, 0.05), at(0, 2.4, -0.42), COLORS.water, Enum.Material.Glass)
	glass.Transparency = 0.5
	part(model, "Pendulum", Vector3.new(0.5, 0.5, 0.1), at(0, 1.6, -0.3), ROOM.gold, Enum.Material.Metal, Enum.PartType.Ball)
	part(model, "Rod", Vector3.new(0.06, 1.4, 0.06), at(0, 2.4, -0.3), ROOM.gold, Enum.Material.Metal)
end

function BUILDERS.gamingChair(model, at)
	part(model, "Base", Vector3.new(2, 0.2, 2), at(0, 0.3, 0), COLORS.dark)
	part(model, "Pole", Vector3.new(0.3, 1.2, 0.3), at(0, 1, 0), COLORS.metal, Enum.Material.Metal)
	part(model, "Seat", Vector3.new(2, 0.5, 2), at(0, 1.8, 0), COLORS.dark, Enum.Material.Fabric)
	part(model, "Back", Vector3.new(2, 3.2, 0.5), at(0, 3.5, 0.85), COLORS.dark, Enum.Material.Fabric)
	part(model, "BackStripe", Vector3.new(0.5, 3, 0.52), at(0, 3.5, 0.84), ROOM.gaming, Enum.Material.Fabric)
	part(model, "Headrest", Vector3.new(1.2, 0.5, 0.3), at(0, 4.7, 0.6), ROOM.gaming, Enum.Material.Fabric)
	for _, x in { -1.05, 1.05 } do
		part(model, "Arm", Vector3.new(0.25, 0.6, 1.5), at(x, 2.4, 0.1), ROOM.gaming)
	end
end

function BUILDERS.piano(model, at)
	part(model, "Body", Vector3.new(4.6, 4, 1.6), at(0, 2, 0.4), COLORS.dark)
	part(model, "KeyBed", Vector3.new(4.4, 0.4, 1), at(0, 2.3, -0.7), COLORS.dark)
	part(model, "Keys", Vector3.new(4.1, 0.12, 0.8), at(0, 2.56, -0.75), ROOM.white)
	for i = 0, 13 do
		if i % 7 ~= 2 and i % 7 ~= 6 then
			part(model, "BlackKey", Vector3.new(0.14, 0.12, 0.45), at(-1.85 + i * 0.29, 2.66, -0.6), COLORS.dark)
		end
	end
	part(model, "MusicStand", Vector3.new(1.6, 0.9, 0.08), at(0, 3.5, -0.42) * CFrame.Angles(math.rad(-15), 0, 0), ROOM.paper)
	part(model, "Bench", Vector3.new(2.4, 0.3, 1), at(0, 1.5, -2.2), COLORS.dark, Enum.Material.Fabric)
	for _, x in { -1, 1 } do
		part(model, "BenchLeg", Vector3.new(0.2, 1.35, 0.8), at(x, 0.68, -2.2), COLORS.dark)
	end
end

-- Rzadkie meble (nagrody)
function BUILDERS.trophy(model, at)
	part(model, "Pedestal", Vector3.new(2, 2.5, 2), at(0, 1.25, 0), COLORS.wood, Enum.Material.Wood)
	part(model, "Cup", Vector3.new(1.2, 1.4, 1.2), at(0, 3.3, 0), Color3.fromRGB(255, 205, 50), Enum.Material.Metal)
	part(model, "Base", Vector3.new(0.6, 0.6, 0.6), at(0, 2.8, 0), Color3.fromRGB(255, 205, 50), Enum.Material.Metal)
end

function BUILDERS.neonSign(model, at)
	part(model, "Board", Vector3.new(3.4, 2.2, 0.3), at(0, 4, 0.8), COLORS.dark)
	part(model, "NeonA", Vector3.new(2.8, 0.25, 0.1), at(0, 4.5, 0.6), Color3.fromRGB(255, 80, 200), Enum.Material.Neon)
	part(model, "NeonB", Vector3.new(2.2, 0.25, 0.1), at(0, 3.6, 0.6), Color3.fromRGB(80, 220, 255), Enum.Material.Neon)
	part(model, "Stand", Vector3.new(0.3, 3, 0.3), at(0, 1.5, 0.8), COLORS.metal, Enum.Material.Metal)
end

function BUILDERS.canShelf(model, at)
	part(model, "Shelf", Vector3.new(2.6, 3.2, 1.2), at(0, 1.6, 0.3), COLORS.wood, Enum.Material.Wood)
	part(model, "GoldenCan", Vector3.new(0.6, 1, 0.6), at(0, 3.7, 0.3), Color3.fromRGB(255, 205, 50), Enum.Material.Neon)
end

function BUILDERS.starLamp(model, at)
	part(model, "Base", Vector3.new(1.4, 0.4, 1.4), at(0, 0.2, 0), COLORS.dark)
	part(model, "Pole", Vector3.new(0.25, 3.5, 0.25), at(0, 2, 0), COLORS.metal, Enum.Material.Metal)
	local globe = part(model, "Globe", Vector3.new(1.8, 1.8, 1.8), at(0, 4.4, 0), Color3.fromRGB(120, 100, 255), Enum.Material.Neon, Enum.PartType.Ball)
	globe.Transparency = 0.2
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Color = Color3.fromRGB(150, 130, 255)
	light.Parent = globe
end

-- Zwraca model mebla albo nil dla nieznanego przedmiotu
function FurnitureBuilder.Build(itemId: string, cframe: CFrame): Model?
	local builder = BUILDERS[itemId]
	if not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Furniture_" .. itemId
	builder(model, function(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end)
	return model
end

-- Promień "podstawy" mebla na podłodze (do sprawdzania, czy się mieści i czy nie wchodzi na inne meble)
local footprints = {}
function FurnitureBuilder.Footprint(itemId: string): number
	if footprints[itemId] then
		return footprints[itemId]
	end
	local model = FurnitureBuilder.Build(itemId, CFrame.new())
	local radius = 1.5
	if model then
		local size = model:GetExtentsSize()
		radius = math.max(size.X, size.Z) / 2
		model:Destroy()
	end
	footprints[itemId] = radius
	return radius
end

return FurnitureBuilder

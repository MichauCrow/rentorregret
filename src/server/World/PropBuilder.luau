-- Rekwizyty z bloków do prac i zleceń: pies, auto, flaga, sterta złomu, kot, złota puszka.
-- Każda funkcja zwraca model bez rodzica; wołający sam ustawia Parent.
local PropBuilder = {}

local COLORS = {
	dog = Color3.fromRGB(190, 130, 70),
	dogDark = Color3.fromRGB(110, 70, 40),
	black = Color3.fromRGB(25, 20, 20),
	carBody = Color3.fromRGB(70, 140, 230),
	carCabin = Color3.fromRGB(180, 220, 255),
	tire = Color3.fromRGB(35, 35, 40),
	engine = Color3.fromRGB(120, 120, 130),
	light = Color3.fromRGB(255, 250, 200),
	pole = Color3.fromRGB(230, 230, 230),
	flag = Color3.fromRGB(255, 80, 90),
	rust = Color3.fromRGB(125, 85, 55),
	scrapBits = Color3.fromRGB(95, 100, 110),
	cat = Color3.fromRGB(255, 160, 60),
	gold = Color3.fromRGB(255, 205, 50),
	ladder = Color3.fromRGB(160, 110, 60),
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

-- Przyłącza część do korzenia: przesuwanie korzenia przesuwa cały model
local function weld(root: BasePart, child: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = root
	constraint.Part1 = child
	constraint.Parent = child
	child.Anchored = false
	child.Massless = true
end

local function billboard(adornee: BasePart, text: string, color: Color3, offset: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = adornee
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	return gui
end

-- Pies: cframe = punkt pod łapami, przód (głowa) to -Z. Korzeń "Body" jest zakotwiczony.
function PropBuilder.Dog(cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Dog"
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	local body = part(model, "Body", Vector3.new(1.4, 1.2, 2.6), at(0, 1.6, 0), COLORS.dog)
	model.PrimaryPart = body
	local pieces = {
		part(model, "Head", Vector3.new(1.2, 1.1, 1.1), at(0, 2.4, -1.5), COLORS.dog),
		part(model, "Snout", Vector3.new(0.6, 0.5, 0.6), at(0, 2.2, -2.2), COLORS.dogDark),
		part(model, "Nose", Vector3.new(0.25, 0.25, 0.25), at(0, 2.35, -2.55), COLORS.black, nil, Enum.PartType.Ball),
		part(model, "EarL", Vector3.new(0.3, 0.6, 0.3), at(-0.4, 3.0, -1.5), COLORS.dogDark),
		part(model, "EarR", Vector3.new(0.3, 0.6, 0.3), at(0.4, 3.0, -1.5), COLORS.dogDark),
		part(model, "Tail", Vector3.new(0.3, 0.3, 1), at(0, 2.1, 1.6) * CFrame.Angles(math.rad(-35), 0, 0), COLORS.dogDark),
	}
	for _, x in { -0.45, 0.45 } do
		for _, z in { -0.9, 0.9 } do
			table.insert(pieces, part(model, "Leg", Vector3.new(0.4, 1, 0.4), at(x, 0.5, z), COLORS.dog))
		end
	end
	for _, piece in pieces do
		weld(body, piece)
	end
	return model
end

-- Auto do naprawy. Zwraca model i listę { part, key } części, które mogą być zepsute.
function PropBuilder.Car(cframe: CFrame)
	local model = Instance.new("Model")
	model.Name = "Car"
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	local body = part(model, "Body", Vector3.new(7, 2.4, 12), at(0, 2.2, 0), COLORS.carBody, Enum.Material.Metal)
	body.CanCollide = true
	model.PrimaryPart = body
	part(model, "Cabin", Vector3.new(6, 2, 6), at(0, 4.4, 1), COLORS.carCabin, Enum.Material.Glass).Transparency = 0.3
	local repairable = {}
	for _, x in { -3.8, 3.8 } do
		for _, z in { -4, 4 } do
			local wheel = part(model, "Wheel", Vector3.new(1.2, 2.4, 2.4), at(x, 1.2, z), COLORS.tire, Enum.Material.Rubber, Enum.PartType.Cylinder)
			table.insert(repairable, { part = wheel, key = "wheel" })
		end
	end
	local engine = part(model, "Engine", Vector3.new(4, 1, 3), at(0, 3.9, -4), COLORS.engine, Enum.Material.Metal)
	table.insert(repairable, { part = engine, key = "engine" })
	for _, x in { -2.5, 2.5 } do
		local light = part(model, "Light", Vector3.new(1.2, 0.8, 0.3), at(x, 2.4, -6.15), COLORS.light, Enum.Material.Neon)
		table.insert(repairable, { part = light, key = "light" })
	end
	local exhaust = part(model, "Exhaust", Vector3.new(1.5, 0.5, 0.5), at(2, 1.2, 6.5) * CFrame.Angles(0, math.rad(90), 0), COLORS.engine, Enum.Material.Metal, Enum.PartType.Cylinder)
	table.insert(repairable, { part = exhaust, key = "exhaust" })
	return model, repairable
end

-- Flaga punktu kontrolnego na wybiegu
function PropBuilder.Flag(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Flag"
	local pole = part(model, "Pole", Vector3.new(0.3, 8, 0.3), CFrame.new(position + Vector3.new(0, 4.3, 0)), COLORS.pole)
	model.PrimaryPart = pole
	part(model, "Cloth", Vector3.new(2.2, 1.4, 0.1), CFrame.new(position + Vector3.new(1.2, 7.4, 0)), COLORS.flag, Enum.Material.Fabric)
	billboard(pole, "🚩", COLORS.flag, 6)
	return model
end

-- Sterta złomu do przeszukania (PrimaryPart = Base)
function PropBuilder.ScrapPile(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "ScrapPile"
	local base = part(model, "Base", Vector3.new(4, 2, 4), CFrame.new(position + Vector3.new(0, 1, 0)), COLORS.rust, Enum.Material.CorrodedMetal, Enum.PartType.Ball)
	model.PrimaryPart = base
	part(model, "Bit", Vector3.new(1.4, 0.4, 1), CFrame.new(position + Vector3.new(0.6, 2, 0.3)) * CFrame.Angles(0, 0.6, 0.3), COLORS.scrapBits, Enum.Material.Metal)
	part(model, "Bit", Vector3.new(0.4, 1.2, 0.4), CFrame.new(position + Vector3.new(-0.8, 2, -0.4)) * CFrame.Angles(0.4, 0, 0.2), COLORS.scrapBits, Enum.Material.Metal)
	return model
end

-- Kot (do zlecenia "Kot na drzewie")
function PropBuilder.Cat(cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Cat"
	local body = part(model, "Body", Vector3.new(1.4, 1.1, 1.4), cframe, COLORS.cat, nil, Enum.PartType.Ball)
	model.PrimaryPart = body
	part(model, "Head", Vector3.new(1, 1, 1), cframe * CFrame.new(0, 0.8, -0.5), COLORS.cat, nil, Enum.PartType.Ball)
	part(model, "EarL", Vector3.new(0.25, 0.4, 0.25), cframe * CFrame.new(-0.3, 1.35, -0.5), COLORS.cat)
	part(model, "EarR", Vector3.new(0.25, 0.4, 0.25), cframe * CFrame.new(0.3, 1.35, -0.5), COLORS.cat)
	billboard(body, "🐱 Miau!", COLORS.cat, 3)
	return model
end

-- Drabina oparta o pień drzewa
function PropBuilder.Ladder(cframe: CFrame): BasePart
	local ladder = Instance.new("Part")
	ladder.Name = "Ladder"
	ladder.Size = Vector3.new(1.6, 7, 0.4)
	ladder.CFrame = cframe
	ladder.Color = COLORS.ladder
	ladder.Material = Enum.Material.Wood
	ladder.Anchored = true
	ladder.CanCollide = false
	return ladder
end

-- Szop-łasuch: korzeń "Body" zakotwiczony, reszta przyłączona (można go przestawiać przez PivotTo)
function PropBuilder.Raccoon(cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Raccoon"
	local grey = Color3.fromRGB(130, 130, 140)
	local dark = Color3.fromRGB(45, 45, 55)
	local body = part(model, "Body", Vector3.new(1.6, 1.2, 2), cframe * CFrame.new(0, 0.9, 0), grey, nil, Enum.PartType.Ball)
	model.PrimaryPart = body
	local pieces = {
		part(model, "Head", Vector3.new(1.1, 1, 1), cframe * CFrame.new(0, 1.4, -1), grey, nil, Enum.PartType.Ball),
		part(model, "Mask", Vector3.new(1.15, 0.35, 0.5), cframe * CFrame.new(0, 1.5, -1.3), dark),
		part(model, "TailA", Vector3.new(0.5, 0.5, 0.6), cframe * CFrame.new(0, 1, 1.2), dark),
		part(model, "TailB", Vector3.new(0.5, 0.5, 0.6), cframe * CFrame.new(0, 1.1, 1.8), grey),
		part(model, "TailC", Vector3.new(0.5, 0.5, 0.6), cframe * CFrame.new(0, 1.2, 2.4), dark),
	}
	for _, piece in pieces do
		weld(body, piece)
	end
	billboard(body, "🦝 Łap szopa!", Color3.fromRGB(200, 200, 210), 2.5)
	return model
end

-- Złoty krasnal (sekret). position = punkt na ziemi.
function PropBuilder.Gnome(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Gnome"
	local body = part(model, "Body", Vector3.new(1.4, 1, 1), CFrame.new(position + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), COLORS.gold, Enum.Material.Metal, Enum.PartType.Cylinder)
	model.PrimaryPart = body
	part(model, "Head", Vector3.new(0.8, 0.8, 0.8), CFrame.new(position + Vector3.new(0, 1.7, 0)), Color3.fromRGB(255, 210, 170), nil, Enum.PartType.Ball)
	part(model, "Beard", Vector3.new(0.7, 0.5, 0.3), CFrame.new(position + Vector3.new(0, 1.45, -0.35)), Color3.fromRGB(245, 245, 245))
	part(model, "HatBrim", Vector3.new(0.3, 0.9, 0.9), CFrame.new(position + Vector3.new(0, 2.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 50, 50), nil, Enum.PartType.Cylinder)
	part(model, "HatTip", Vector3.new(0.45, 0.7, 0.45), CFrame.new(position + Vector3.new(0, 2.5, 0)), Color3.fromRGB(220, 50, 50))
	return model
end

-- Złota puszka (sekret)
function PropBuilder.GoldenCan(position: Vector3): BasePart
	local can = Instance.new("Part")
	can.Name = "GoldenCan"
	can.Shape = Enum.PartType.Cylinder
	can.Size = Vector3.new(1.2, 0.7, 0.7)
	can.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	can.Color = COLORS.gold
	can.Material = Enum.Material.Neon
	can.Anchored = true
	can.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = COLORS.gold
	light.Range = 10
	light.Brightness = 2
	light.Parent = can
	billboard(can, "✨", COLORS.gold, 2.5)
	return can
end

return PropBuilder

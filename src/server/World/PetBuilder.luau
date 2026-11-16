-- Zwierzaki z klocków. cframe = punkt na ziemi, przód (głowa) to -Z. Korzeń "Body" jest zakotwiczony,
-- reszta przyspawana (przesuwanie Body przesuwa całe zwierzę). Atrybut BodyHeight = wysokość Body nad ziemią.
local ModernBuilder = require(script.Parent.ModernBuilder)

local PetBuilder = {}

local function part(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- staticParts = true: wszystko zostaje zakotwiczone (klatka chomika stoi w miejscu, a kołowrotek się kręci)
local function finish(model: Model, body: BasePart, height: number, staticParts: boolean?)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child ~= body and not staticParts then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = child
			weld.Parent = child
			child.Anchored = false
			child.Massless = true
		end
	end
	model.PrimaryPart = body
	model:SetAttribute("BodyHeight", height)
	return model
end

local BUILDERS = {}

BUILDERS.dog = function(model, at, variant)
	local fur = if variant == 2 then Color3.fromRGB(240, 235, 225) else Color3.fromRGB(190, 130, 70)
	local dark = if variant == 2 then Color3.fromRGB(70, 60, 55) else Color3.fromRGB(110, 70, 40)
	local body = part(model, "Body", Vector3.new(1.4, 1.2, 2.6), at(0, 1.6, 0), fur)
	part(model, "Head", Vector3.new(1.2, 1.1, 1.1), at(0, 2.4, -1.5), fur)
	part(model, "Snout", Vector3.new(0.6, 0.5, 0.6), at(0, 2.2, -2.2), dark)
	part(model, "Nose", Vector3.new(0.25, 0.25, 0.25), at(0, 2.35, -2.55), Color3.fromRGB(25, 20, 20), Enum.PartType.Ball)
	for _, x in { -0.4, 0.4 } do
		part(model, "Ear", Vector3.new(0.3, 0.6, 0.3), at(x, 3.0, -1.5), dark)
		part(model, "Eye", Vector3.new(0.18, 0.18, 0.05), at(x * 0.6, 2.55, -2.06), Color3.fromRGB(20, 20, 25), Enum.PartType.Ball)
	end
	part(model, "Tail", Vector3.new(0.3, 0.3, 1), at(0, 2.1, 1.6) * CFrame.Angles(math.rad(-35), 0, 0), dark)
	part(model, "Collar", Vector3.new(1.3, 0.25, 0.3), at(0, 2.0, -1.0), Color3.fromRGB(230, 40, 70))
	for _, x in { -0.45, 0.45 } do
		for _, z in { -0.9, 0.9 } do
			part(model, if z < 0 and x > 0 then "FrontLegR" else "Leg", Vector3.new(0.4, 1, 0.4), at(x, 0.5, z), fur)
		end
	end
	return body, 1.6
end

BUILDERS.cat = function(model, at, variant)
	local fur = if variant == 2 then Color3.fromRGB(70, 70, 80) else Color3.fromRGB(255, 160, 60)
	local body = part(model, "Body", Vector3.new(1.0, 0.9, 1.9), at(0, 1.05, 0), fur)
	part(model, "Head", Vector3.new(1.0, 0.9, 0.9), at(0, 1.7, -1.1), fur)
	for _, x in { -0.3, 0.3 } do
		part(model, "Ear", Vector3.new(0.25, 0.45, 0.2), at(x, 2.3, -1.1) * CFrame.Angles(0, 0, math.rad(x > 0 and -15 or 15)), fur)
		part(model, "Eye", Vector3.new(0.16, 0.2, 0.05), at(x * 0.8, 1.8, -1.56), Color3.fromRGB(90, 200, 90), Enum.PartType.Ball)
	end
	part(model, "Nose", Vector3.new(0.15, 0.12, 0.05), at(0, 1.6, -1.57), Color3.fromRGB(255, 130, 150))
	part(model, "Tail", Vector3.new(0.22, 1.4, 0.22), at(0, 1.6, 1.1) * CFrame.Angles(math.rad(25), 0, 0), fur)
	for _, x in { -0.3, 0.3 } do
		for _, z in { -0.65, 0.65 } do
			part(model, "Leg", Vector3.new(0.28, 0.65, 0.28), at(x, 0.32, z), fur)
		end
	end
	return body, 1.05
end

BUILDERS.rabbit = function(model, at)
	local fur = Color3.fromRGB(245, 245, 250)
	local body = part(model, "Body", Vector3.new(1.3, 1.3, 1.3), at(0, 0.7, 0.1), fur, Enum.PartType.Ball)
	part(model, "Head", Vector3.new(0.9, 0.9, 0.9), at(0, 1.25, -0.55), fur, Enum.PartType.Ball)
	for _, x in { -0.2, 0.2 } do
		part(model, "Ear", Vector3.new(0.22, 1.0, 0.12), at(x, 2.0, -0.5), fur)
		part(model, "EarInside", Vector3.new(0.12, 0.8, 0.05), at(x, 2.0, -0.57), Color3.fromRGB(255, 170, 190))
		part(model, "Eye", Vector3.new(0.14, 0.14, 0.05), at(x * 1.2, 1.35, -0.98), Color3.fromRGB(30, 20, 30), Enum.PartType.Ball)
	end
	part(model, "Nose", Vector3.new(0.12, 0.1, 0.05), at(0, 1.2, -1.0), Color3.fromRGB(255, 140, 170))
	part(model, "Tail", Vector3.new(0.45, 0.45, 0.45), at(0, 0.8, 0.8), fur, Enum.PartType.Ball)
	return body, 0.7
end

BUILDERS.parrot = function(model, at)
	local green = Color3.fromRGB(60, 200, 90)
	local body = part(model, "Body", Vector3.new(0.8, 1.1, 0.8), at(0, 0, 0), green)
	part(model, "Head", Vector3.new(0.7, 0.7, 0.7), at(0, 0.75, -0.1), Color3.fromRGB(255, 80, 80), Enum.PartType.Ball)
	part(model, "Beak", Vector3.new(0.25, 0.25, 0.35), at(0, 0.7, -0.5), Color3.fromRGB(255, 200, 50))
	for _, x in { -0.18, 0.18 } do
		part(model, "Eye", Vector3.new(0.12, 0.12, 0.05), at(x, 0.85, -0.42), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	end
	for _, x in { -0.5, 0.5 } do
		part(model, "Wing", Vector3.new(0.15, 0.9, 0.7), at(x, 0.05, 0.05) * CFrame.Angles(0, 0, math.rad(x > 0 and -15 or 15)), Color3.fromRGB(70, 140, 255))
	end
	part(model, "Tail", Vector3.new(0.3, 0.9, 0.15), at(0, -0.7, 0.35) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(255, 200, 50))
	return body, 0
end

-- Chomik z klatką: korzeń = podstawa klatki, w środku chomik i kołowrotek
BUILDERS.hamster = function(model, at)
	local body = part(model, "Body", Vector3.new(3.2, 0.3, 2.2), at(0, 0.15, 0), Color3.fromRGB(80, 170, 255))
	local wire = Color3.fromRGB(220, 225, 235)
	for _, x in { -1.55, 1.55 } do
		for z = -1.05, 1.05, 0.35 do
			part(model, "Bar", Vector3.new(0.06, 2.2, 0.06), at(x, 1.4, z), wire, nil, Enum.Material.Metal)
		end
	end
	for _, z in { -1.05, 1.05 } do
		for x = -1.55, 1.55, 0.35 do
			part(model, "Bar", Vector3.new(0.06, 2.2, 0.06), at(x, 1.4, z), wire, nil, Enum.Material.Metal)
		end
	end
	part(model, "Roof", Vector3.new(3.3, 0.2, 2.3), at(0, 2.55, 0), Color3.fromRGB(255, 120, 160))
	part(model, "Sawdust", Vector3.new(3, 0.12, 2), at(0, 0.36, 0), Color3.fromRGB(240, 210, 150), nil, Enum.Material.Sand)
	local wheel = part(model, "Wheel", Vector3.new(0.3, 1.5, 1.5), at(0.8, 1.15, 0), Color3.fromRGB(255, 200, 40), Enum.PartType.Cylinder)
	part(model, "WheelStand", Vector3.new(0.15, 0.8, 0.15), at(0.8, 0.75, 0), wire, nil, Enum.Material.Metal)
	local hamster = part(model, "Hamster", Vector3.new(0.75, 0.75, 0.75), at(-0.6, 0.78, 0), Color3.fromRGB(240, 170, 90), Enum.PartType.Ball)
	part(model, "HamsterEar", Vector3.new(0.2, 0.2, 0.2), at(-0.75, 1.15, -0.2), Color3.fromRGB(255, 190, 170), Enum.PartType.Ball)
	part(model, "HamsterEar", Vector3.new(0.2, 0.2, 0.2), at(-0.45, 1.15, -0.2), Color3.fromRGB(255, 190, 170), Enum.PartType.Ball)
	part(model, "HamsterNose", Vector3.new(0.1, 0.1, 0.1), at(-0.6, 0.8, -0.38), Color3.fromRGB(255, 120, 150), Enum.PartType.Ball)
	wheel.Name = "Wheel"
	hamster.Name = "Hamster"
	return body, 0.15, true
end

-- variant: 1 albo 2 (drugi pies/kot ma inne umaszczenie)
function PetBuilder.Build(species: string, cframe: CFrame, variant: number?): Model?
	local builder = BUILDERS[species]
	if not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Pet_" .. species
	local body, height, staticParts = builder(model, function(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end, variant)
	return finish(model, body, height, staticParts)
end

-- Sklep zoologiczny: origin = środek podłogi na ziemi, wejście od strony -Z. Zwraca część z podpowiedzią zakupu.
function PetBuilder.BuildShop(origin: CFrame, parent: Instance): BasePart
	local model = Instance.new("Model")
	model.Name = "PetShop"
	local function block(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material?)
		local p = part(model, name, size, origin * CFrame.new(x, y, z), color, nil, material)
		p.CanCollide = true
		return p
	end
	-- Nowoczesny lokal z witryną i drzwiami rozsuwanymi (ModernBuilder), różowy pas nad wejściem
	ModernBuilder.Shell(model, origin, { width = 22, depth = 16, height = 12, accent = Color3.fromRGB(255, 130, 180) })
	local sign = block("Sign", Vector3.new(14, 2.8, 0.4), 0, 11.4, -8.3, Color3.fromRGB(255, 215, 60))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(120, 50, 160)
	text.Text = "🐾 ZOO SKLEP"
	text.Parent = gui

	-- Lada z podpowiedzią i zwierzaki na wystawie
	local counter = block("Counter", Vector3.new(8, 3.5, 2), 0, 2.75, 4, Color3.fromRGB(190, 130, 80), Enum.Material.Wood)
	block("CounterTop", Vector3.new(8.4, 0.3, 2.4), 0, 4.65, 4, Color3.fromRGB(255, 150, 190))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PetShopPrompt"
	prompt.ActionText = "Kup zwierzaka"
	prompt.ObjectText = "Zoo sklep"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	block("Shelf", Vector3.new(6, 0.4, 2), 6.5, 4.5, 6.4, Color3.fromRGB(255, 255, 255))
	block("Perch", Vector3.new(0.3, 5, 0.3), -8, 3.5, 5.5, Color3.fromRGB(140, 90, 50), Enum.Material.Wood)
	block("PerchBar", Vector3.new(2, 0.25, 0.25), -8, 6, 5.5, Color3.fromRGB(140, 90, 50), Enum.Material.Wood)
	local displays = {
		{ "dog", CFrame.new(-6, 1, -2) * CFrame.Angles(0, math.rad(-20), 0) },
		{ "cat", CFrame.new(6.5, 4.7, 6.4) },
		{ "rabbit", CFrame.new(5, 1, -3) * CFrame.Angles(0, math.rad(25), 0) },
		{ "hamster", CFrame.new(8, 1, 1) * CFrame.Angles(0, math.rad(90), 0) },
		{ "parrot", CFrame.new(-8, 6.9, 5.5) },
	}
	for _, display in displays do
		local pet = PetBuilder.Build(display[1], origin * display[2], 1)
		if pet then
			pet.Parent = model
		end
	end
	model.Parent = parent
	return counter
end

return PetBuilder

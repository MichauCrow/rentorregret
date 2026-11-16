-- Wygląd potworów z gładkich brył. Straszne z daleka (świecące oczy, sylwetka), zabawne z bliska
-- (kapcie, szlafmyca, wąsy). Każdy model ma niewidzialny "Root" w miejscu stóp; przód = -Z.
local MonsterModels = {}

local function base(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	return model
end

local function part(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function blob(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(model, name, size, cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function limb(model: Model, name: string, from: Vector3, to: Vector3, diameter: number, color: Color3, material: Enum.Material?): Part
	local length = (to - from).Magnitude
	return part(model, name, Vector3.new(length, diameter, diameter), CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0), color, material, Enum.PartType.Cylinder)
end

local function nameTag(model: Model, adornee: BasePart, text: string, color: Color3, offset: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 44)
	billboard.StudsOffset = Vector3.new(0, offset, 0)
	billboard.Adornee = adornee
	billboard.MaxDistance = 35
	billboard.Parent = model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 15, 30)
	stroke.Parent = label
end

-- Cichy Sąsiad: wysoki, chudy, w piżamie w paski i różowych kapciach. Wielkie uszy (słyszy wszystko!),
-- maska do spania na czole, szlafmyca i świeczka w dłoni (jej światło zdradza, gdzie idzie).
function MonsterModels.Neighbor(): Model
	local model = base("CichySasiad")
	local pajama = Color3.fromRGB(90, 110, 170)
	local stripe = Color3.fromRGB(220, 225, 240)
	local skin = Color3.fromRGB(200, 225, 205)
	for _, x in { -0.6, 0.6 } do
		blob(model, "Slipper", Vector3.new(1.1, 0.7, 1.9), CFrame.new(x, 0.35, -0.3), Color3.fromRGB(255, 150, 200), Enum.Material.Fabric)
		blob(model, "Pompom", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, 0.75, -1.1), Color3.fromRGB(255, 255, 255), Enum.Material.Fabric)
		part(model, "Leg", Vector3.new(3.4, 0.7, 0.7), CFrame.new(x, 2.3, 0) * CFrame.Angles(0, 0, math.rad(90)), pajama, Enum.Material.Fabric, Enum.PartType.Cylinder)
	end
	local body = blob(model, "Body", Vector3.new(2.5, 4.4, 1.9), CFrame.new(0, 5.8, 0), pajama, Enum.Material.Fabric)
	for i = 0, 3 do
		blob(model, "Stripe", Vector3.new(2.45, 0.35, 1.95), CFrame.new(0, 4.4 + i * 0.95, 0), stripe, Enum.Material.Fabric)
	end
	-- Ręce: lewa zwisa, prawa trzyma świeczkę przed sobą
	limb(model, "ArmL", Vector3.new(-1.2, 7.3, 0), Vector3.new(-1.6, 4.2, -0.2), 0.55, pajama, Enum.Material.Fabric)
	blob(model, "Hand", Vector3.new(0.6, 0.6, 0.6), CFrame.new(-1.65, 3.9, -0.2), skin)
	limb(model, "ArmR", Vector3.new(1.2, 7.3, 0), Vector3.new(1.1, 5.4, -1.5), 0.55, pajama, Enum.Material.Fabric)
	blob(model, "Hand", Vector3.new(0.6, 0.6, 0.6), CFrame.new(1.1, 5.3, -1.6), skin)
	part(model, "CandleDish", Vector3.new(0.2, 1, 1), CFrame.new(1.1, 5.0, -1.7) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 200, 60), Enum.Material.Metal, Enum.PartType.Cylinder)
	part(model, "Candle", Vector3.new(1, 0.35, 0.35), CFrame.new(1.1, 5.6, -1.7) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(250, 245, 230), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local flame = blob(model, "Flame", Vector3.new(0.3, 0.5, 0.3), CFrame.new(1.1, 6.35, -1.7), Color3.fromRGB(255, 170, 60), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Brightness = 1.4
	light.Range = 16
	light.Shadows = true
	light.Parent = flame
	-- Głowa: blada, senna, wielkie różowe uszy
	local head = blob(model, "Head", Vector3.new(1.9, 2.2, 1.9), CFrame.new(0, 8.9, 0), skin)
	for _, side in { -1, 1 } do
		blob(model, "Ear", Vector3.new(0.45, 1.8, 1.1), CFrame.new(side * 1.15, 9.1, 0) * CFrame.Angles(0, 0, math.rad(side * -15)), Color3.fromRGB(240, 170, 180))
		blob(model, "Eye", Vector3.new(0.45, 0.18, 0.2), CFrame.new(side * 0.42, 8.9, -0.9), Color3.fromRGB(30, 30, 40))
		blob(model, "Cheek", Vector3.new(0.4, 0.25, 0.1), CFrame.new(side * 0.6, 8.5, -0.85), Color3.fromRGB(240, 170, 180))
	end
	blob(model, "Mouth", Vector3.new(0.5, 0.15, 0.1), CFrame.new(0, 8.25, -0.92), Color3.fromRGB(80, 50, 60))
	part(model, "SleepMask", Vector3.new(2, 0.55, 0.3), CFrame.new(0, 9.55, -0.8), Color3.fromRGB(150, 200, 255), Enum.Material.Fabric)
	blob(model, "Nightcap", Vector3.new(1.9, 1.5, 1.9), CFrame.new(0, 10, 0.1), Color3.fromRGB(90, 110, 170), Enum.Material.Fabric)
	blob(model, "NightcapTip", Vector3.new(1, 1.2, 1), CFrame.new(0.5, 10.7, 0.5) * CFrame.Angles(0, 0, math.rad(-35)), Color3.fromRGB(90, 110, 170), Enum.Material.Fabric)
	blob(model, "NightcapPompom", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0.95, 11.05, 0.7), Color3.fromRGB(255, 255, 255), Enum.Material.Fabric)
	nameTag(model, head, "🤫 Cichy Sąsiad", Color3.fromRGB(180, 210, 255), 3)
	local _ = body
	return model
end

-- Mruczek: wielki, okrągły, ciemny kot ze świecącymi żółtymi oczami. Z bliska: wąsy, różowy nosek, ogon.
-- Części "Eye" rozjaśniają się, gdy kot idzie za światłem.
function MonsterModels.Cat(): Model
	local model = base("Mruczek")
	local fur = Color3.fromRGB(60, 58, 70)
	local belly = Color3.fromRGB(150, 145, 160)
	blob(model, "Body", Vector3.new(5, 4.2, 8), CFrame.new(0, 2.7, 0.6), fur, Enum.Material.Fabric)
	blob(model, "Belly", Vector3.new(3.4, 2.6, 5.5), CFrame.new(0, 2.1, -0.2), belly, Enum.Material.Fabric)
	for _, x in { -1.6, 1.6 } do
		for _, z in { -2.6, 3.2 } do
			blob(model, "Paw", Vector3.new(1.4, 1, 1.8), CFrame.new(x, 0.5, z), fur, Enum.Material.Fabric)
		end
	end
	local head = blob(model, "Head", Vector3.new(4.2, 3.6, 3.6), CFrame.new(0, 4.6, -3.9), fur, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		blob(model, "Ear", Vector3.new(1.1, 1.7, 0.6), CFrame.new(side * 1.3, 6.5, -3.8) * CFrame.Angles(0, 0, math.rad(side * -20)), fur, Enum.Material.Fabric)
		blob(model, "EarInside", Vector3.new(0.6, 1.1, 0.3), CFrame.new(side * 1.3, 6.4, -4.05) * CFrame.Angles(0, 0, math.rad(side * -20)), Color3.fromRGB(240, 150, 170))
		blob(model, "Eye", Vector3.new(1, 1.2, 0.35), CFrame.new(side * 0.9, 5, -5.55), Color3.fromRGB(255, 225, 60), Enum.Material.Neon)
		blob(model, "Pupil", Vector3.new(0.25, 0.9, 0.2), CFrame.new(side * 0.9, 5, -5.72), Color3.fromRGB(20, 20, 20))
		for i = -1, 1 do
			part(model, "Whisker", Vector3.new(2.2, 0.06, 0.06), CFrame.new(side * 1.6, 4.1 + i * 0.25, -5.4) * CFrame.Angles(0, 0, math.rad(i * side * 10)), Color3.fromRGB(240, 240, 240))
		end
	end
	blob(model, "Nose", Vector3.new(0.5, 0.35, 0.3), CFrame.new(0, 4.35, -5.7), Color3.fromRGB(255, 140, 170))
	blob(model, "Mouth", Vector3.new(0.8, 0.2, 0.15), CFrame.new(0, 3.9, -5.62), Color3.fromRGB(40, 30, 35))
	-- Ogon zakręcony do góry
	local tail = { Vector3.new(0, 3, 4.4), Vector3.new(0.4, 4.6, 5.2), Vector3.new(0.2, 6.2, 5), Vector3.new(-0.4, 7.2, 4.3) }
	for i = 1, #tail - 1 do
		limb(model, "Tail", tail[i], tail[i + 1], 0.9, fur, Enum.Material.Fabric)
	end
	local glow = Instance.new("PointLight")
	glow.Name = "EyeGlow"
	glow.Color = Color3.fromRGB(255, 220, 80)
	glow.Brightness = 0.6
	glow.Range = 9
	glow.Parent = head
	nameTag(model, head, "🐾 Mruczek", Color3.fromRGB(255, 225, 90), 3.5)
	return model
end

-- Klucznik o północy: wysoki, w długim płaszczu i meloniku, z pomarańczowo świecącymi oczami,
-- długimi rękami i gigantycznym kluczem. Wąsy zostały (to wciąż on!).
function MonsterModels.Landlord(): Model
	local model = base("KlucznikOPolnocy")
	local coat = Color3.fromRGB(55, 35, 55)
	local skin = Color3.fromRGB(170, 160, 175)
	local gold = Color3.fromRGB(255, 200, 60)
	for _, x in { -0.7, 0.7 } do
		blob(model, "Shoe", Vector3.new(1, 0.6, 1.6), CFrame.new(x, 0.3, -0.3), Color3.fromRGB(25, 20, 25))
	end
	part(model, "CoatBottom", Vector3.new(4.6, 3, 3), CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(90)), coat, Enum.Material.Fabric, Enum.PartType.Cylinder)
	blob(model, "Coat", Vector3.new(3.4, 6.2, 2.6), CFrame.new(0, 6, 0), coat, Enum.Material.Fabric)
	for i = 0, 2 do
		blob(model, "Button", Vector3.new(0.3, 0.3, 0.15), CFrame.new(0, 5 + i * 1.1, -1.28), gold, Enum.Material.Metal)
	end
	-- Długie ręce wyciągnięte do przodu, w prawej gigantyczny klucz
	for _, side in { -1, 1 } do
		limb(model, "Arm", Vector3.new(side * 1.6, 8.2, 0), Vector3.new(side * 1.5, 6.4, -2.8), 0.7, coat, Enum.Material.Fabric)
		blob(model, "Glove", Vector3.new(0.9, 0.9, 0.9), CFrame.new(side * 1.5, 6.3, -3.1), Color3.fromRGB(240, 240, 240))
	end
	part(model, "KeyShaft", Vector3.new(4.5, 0.4, 0.4), CFrame.new(1.5, 6.3, -4.6) * CFrame.Angles(0, math.rad(90), 0), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(model, "KeyBow", Vector3.new(0.3, 1.6, 1.6), CFrame.new(1.5, 6.3, -2.5) * CFrame.Angles(0, math.rad(90), 0), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(model, "KeyBit", Vector3.new(0.3, 1, 0.7), CFrame.new(1.5, 5.8, -6.6), gold, Enum.Material.Metal)
	local head = blob(model, "Head", Vector3.new(2.3, 2.5, 2.3), CFrame.new(0, 10.2, 0), skin)
	for _, side in { -1, 1 } do
		blob(model, "Eye", Vector3.new(0.55, 0.4, 0.2), CFrame.new(side * 0.5, 10.4, -1.08), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
		blob(model, "Mustache", Vector3.new(0.8, 0.3, 0.25), CFrame.new(side * 0.4, 9.7, -1.08) * CFrame.Angles(0, 0, math.rad(side * -18)), Color3.fromRGB(235, 235, 240))
	end
	part(model, "HatBrim", Vector3.new(0.15, 3.2, 3.2), CFrame.new(0, 11.35, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(20, 15, 20), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(model, "HatBand", Vector3.new(0.35, 2.2, 2.2), CFrame.new(0, 11.6, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
	blob(model, "HatTop", Vector3.new(2.2, 1.8, 2.2), CFrame.new(0, 12, 0), Color3.fromRGB(20, 15, 20))
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 140, 50)
	glow.Brightness = 2
	glow.Range = 18
	glow.Parent = head
	nameTag(model, head, "🔑 KLUCZNIK O PÓŁNOCY", Color3.fromRGB(255, 160, 60), 4)
	return model
end

return MonsterModels

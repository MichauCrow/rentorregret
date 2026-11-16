-- Pan Klucznik: kreskówkowy właściciel kamienicy z gładkich brył (elipsoidy i walce zamiast klocków):
-- melonik ze złotą wstążką, klasyczna głowa z buzią, wąsy, okrągłe okulary, brązowy garnitur z kamizelką
-- i muszką, białe rękawiczki i wielki złoty klucz na kółku. Lekko się kołysze, gdy czeka na czynsz.
-- cframe = punkt pod stopami, przód postaci to -Z (tak działa CFrame.lookAt).
local TweenService = game:GetService("TweenService")

local LandlordBuilder = {}

local COLORS = {
	trousers = Color3.fromRGB(55, 55, 70),
	shoes = Color3.fromRGB(35, 25, 25),
	suit = Color3.fromRGB(125, 80, 50),
	vest = Color3.fromRGB(205, 165, 95),
	shirt = Color3.fromRGB(250, 248, 240),
	bowTie = Color3.fromRGB(200, 40, 55),
	skin = Color3.fromRGB(255, 205, 160),
	cheeks = Color3.fromRGB(255, 160, 150),
	hair = Color3.fromRGB(230, 230, 235),
	hat = Color3.fromRGB(40, 32, 40),
	gold = Color3.fromRGB(255, 200, 60),
	glove = Color3.fromRGB(250, 250, 250),
	glasses = Color3.fromRGB(30, 30, 35),
}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
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
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Elipsoida o wymiarach części (SpecialMesh Sphere rozciąga się do rozmiaru części)
local function blob(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, size, cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Walec stojący pionowo (oś Y)
local function pillar(parent: Instance, name: string, height: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Walec między dwoma punktami (ręce)
local function limb(parent: Instance, name: string, from: Vector3, to: Vector3, diameter: number, color: Color3): Part
	local p = part(parent, name, Vector3.new((to - from).Magnitude, diameter, diameter), CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0), color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function LandlordBuilder.Build(cframe: CFrame, moodEmoji: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "PanKlucznik"
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	local function point(x: number, y: number, z: number): Vector3
		return at(x, y, z).Position
	end

	-- Nogi i buty
	for _, x in { -0.5, 0.5 } do
		pillar(model, "Leg", 2, 0.75, at(x, 1.15, 0), COLORS.trousers)
		blob(model, "Shoe", Vector3.new(0.85, 0.5, 1.3), at(x, 0.25, -0.2), COLORS.shoes)
	end
	-- Tułów: garnitur, kamizelka, koszula, muszka, złoty łańcuszek od zegarka
	local body = blob(model, "Body", Vector3.new(2.5, 2.9, 1.9), at(0, 3.3, 0), COLORS.suit)
	model.PrimaryPart = body
	blob(model, "Vest", Vector3.new(1.5, 2.2, 0.5), at(0, 3.25, -0.78), COLORS.vest)
	blob(model, "Shirt", Vector3.new(0.7, 0.9, 0.3), at(0, 4.15, -0.82), COLORS.shirt)
	for _, side in { -1, 1 } do
		blob(model, "BowTie", Vector3.new(0.45, 0.32, 0.2), at(side * 0.22, 4.25, -0.98) * CFrame.Angles(0, 0, math.rad(side * 12)), COLORS.bowTie)
		blob(model, "Button", Vector3.new(0.14, 0.14, 0.08), at(0, 3.55 - (side + 1) * 0.3, -1.04), COLORS.gold, Enum.Material.Metal)
	end
	blob(model, "BowKnot", Vector3.new(0.18, 0.2, 0.15), at(0, 4.25, -1.02), COLORS.bowTie)
	limb(model, "WatchChain", point(-0.55, 3.05, -1), point(0.45, 2.85, -1), 0.06, COLORS.gold)
	blob(model, "Collar", Vector3.new(1.6, 0.5, 1.2), at(0, 4.6, -0.05), COLORS.suit)

	-- Ręce: lewa wzdłuż ciała, prawa trzyma przed sobą kółko z wielkim kluczem
	limb(model, "ArmL", point(-1.15, 4.2, 0), point(-1.45, 2.6, -0.2), 0.62, COLORS.suit)
	blob(model, "Glove", Vector3.new(0.62, 0.62, 0.62), at(-1.5, 2.35, -0.25), COLORS.glove)
	limb(model, "ArmR", point(1.15, 4.2, 0), point(1.25, 3.1, -0.9), 0.62, COLORS.suit)
	blob(model, "Glove", Vector3.new(0.62, 0.62, 0.62), at(1.28, 2.95, -1.05), COLORS.glove)
	local ring = part(model, "KeyRing", Vector3.new(0.12, 0.9, 0.9), at(1.28, 2.55, -1.2) * CFrame.Angles(0, math.rad(90), 0), COLORS.gold, Enum.Material.Metal)
	ring.Shape = Enum.PartType.Cylinder
	pillar(model, "KeyShaft", 1.5, 0.18, at(1.28, 1.7, -1.25), COLORS.gold, Enum.Material.Metal)
	local bow = part(model, "KeyBow", Vector3.new(0.16, 0.6, 0.6), at(1.28, 2.5, -1.25) * CFrame.Angles(0, math.rad(90), 0), COLORS.gold, Enum.Material.Metal)
	bow.Shape = Enum.PartType.Cylinder
	part(model, "KeyBit", Vector3.new(0.12, 0.35, 0.3), at(1.28, 1.05, -1.38), COLORS.gold, Enum.Material.Metal)

	-- Głowa: klasyczna głowa z buzią, różowe policzki, siwe bokobrody, wąsy i okulary
	local head = part(model, "Head", Vector3.new(2, 1, 1), at(0, 5.45, 0), COLORS.skin)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.35, 1.35, 1.35)
	headMesh.Parent = head
	local face = Instance.new("Decal")
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	for _, side in { -1, 1 } do
		blob(model, "Cheek", Vector3.new(0.35, 0.22, 0.1), at(side * 0.55, 5.25, -0.62), COLORS.cheeks)
		blob(model, "Sideburn", Vector3.new(0.3, 0.75, 0.55), at(side * 0.95, 5.5, 0.05), COLORS.hair)
		blob(model, "Mustache", Vector3.new(0.62, 0.24, 0.22), at(side * 0.3, 5.12, -0.7) * CFrame.Angles(0, 0, math.rad(side * -18)), COLORS.hair)
		local lens = part(model, "GlassesRim", Vector3.new(0.06, 0.42, 0.42), at(side * 0.33, 5.62, -0.72) * CFrame.Angles(0, math.rad(90), 0), COLORS.glasses, Enum.Material.Metal)
		lens.Shape = Enum.PartType.Cylinder
		local glass = part(model, "GlassesLens", Vector3.new(0.04, 0.34, 0.34), at(side * 0.33, 5.62, -0.75) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(200, 230, 255), Enum.Material.Glass)
		glass.Shape = Enum.PartType.Cylinder
		glass.Transparency = 0.5
	end
	part(model, "GlassesBridge", Vector3.new(0.25, 0.05, 0.05), at(0, 5.65, -0.74), COLORS.glasses, Enum.Material.Metal)
	blob(model, "Nose", Vector3.new(0.28, 0.3, 0.28), at(0, 5.35, -0.72), COLORS.cheeks)

	-- Melonik: rondo, zaokrąglona główka i złota wstążka
	pillar(model, "HatBrim", 0.12, 2.5, at(0, 6.2, 0), COLORS.hat)
	pillar(model, "HatBand", 0.28, 1.75, at(0, 6.38, 0), COLORS.gold)
	blob(model, "HatTop", Vector3.new(1.7, 1.3, 1.7), at(0, 6.65, 0), COLORS.hat)

	-- Kołysanie się w miejscu (cały model obraca się o kilka stopni w lewo i w prawo)
	local sway = Instance.new("CFrameValue")
	sway.Value = CFrame.new()
	local pieces = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			pieces[descendant] = cframe:ToObjectSpace(descendant.CFrame)
		end
	end
	sway.Changed:Connect(function(value)
		for piece, offset in pieces do
			piece.CFrame = cframe * value * offset
		end
	end)
	TweenService:Create(sway, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Value = CFrame.Angles(0, 0, math.rad(3)) }):Play()
	sway.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 60)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.Parent = model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 215, 60)
	label.Text = "Pan Klucznik " .. moodEmoji
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(25, 15, 45)
	stroke.Parent = label

	model.Parent = parent
	return model
end

return LandlordBuilder

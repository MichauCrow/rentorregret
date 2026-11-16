-- Wygląd potworów z gładkich brył. Straszne z daleka (sylwetka, świecące oczy), zabawne z bliska
-- (kapcie, szlafmyca, wąsy, dzwoneczek). Każdy model ma niewidzialny "Root" w miejscu stóp; przód = -Z.
--
-- Dla klienta (MonsterRenderer) model niesie atrybuty:
--   Hinge<Nazwa> (Vector3): punkt obrotu animowanych części (ogon, klucz, czubek szlafmycy),
--   części z atrybutem Alert = "show" widać tylko w pościgu (otwarte oczy), "hide" tylko poza nim.
-- Potwory mieszczą się w drzwiach kamienicy (wysokość drzwi 10): patrz MAX_HEIGHT.
local MonsterModels = {}

local MAX_HEIGHT = 9.6
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon
local WHITE = Color3.fromRGB(245, 245, 245)

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

-- Elipsoida o wymiarach części
local function blob(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(model, name, size, cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Walec między dwoma punktami (ręce, ogon)
local function limb(model: Model, name: string, from: Vector3, to: Vector3, diameter: number, color: Color3, material: Enum.Material?): Part
	local length = (to - from).Magnitude
	return part(model, name, Vector3.new(length, diameter, diameter), CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0), color, material, Enum.PartType.Cylinder)
end

-- Walec stojący pionowo (oś Y)
local function pillar(model: Model, name: string, height: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	return part(model, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

-- Krążek zwrócony do przodu (oś Z): soczewki okularów, guziki
local function disc(model: Model, name: string, thickness: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	return part(model, name, Vector3.new(thickness, diameter, diameter), cframe * CFrame.Angles(0, math.rad(90), 0), color, material, Enum.PartType.Cylinder)
end

-- Pasek dookoła elipsoidy: spłaszczona elipsoida odrobinę szersza niż przekrój bryły w tym miejscu.
-- axis = "Y" (pasek poziomy) albo "Z" (pasek w poprzek grzbietu); offset = odległość od środka bryły.
local function band(model: Model, name: string, center: Vector3, size: Vector3, axis: string, offset: number, width: number, color: Color3, material: Enum.Material?)
	local half = if axis == "Y" then size.Y / 2 else size.Z / 2
	local factor = math.sqrt(math.max(0, 1 - (offset / half) ^ 2)) * 1.06
	if axis == "Y" then
		blob(model, name, Vector3.new(size.X * factor, width, size.Z * factor), CFrame.new(center + Vector3.new(0, offset, 0)), color, material)
	else
		blob(model, name, Vector3.new(size.X * factor, size.Y * factor, width), CFrame.new(center + Vector3.new(0, 0, offset)), color, material)
	end
end

-- Część widoczna tylko w pościgu ("show") albo tylko poza nim ("hide")
local function alertOnly(p: Part, mode: string): Part
	p:SetAttribute("Alert", mode)
	if mode == "show" then
		p.Transparency = 1
	end
	return p
end

local function nameTag(model: Model, adornee: BasePart, text: string, color: Color3, offset: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
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

-- Najwyższy punkt modelu (do skalowania)
local function topOf(model: Model): number
	local top = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "Root" then
			local size = descendant.Size
			-- Bezpieczne oszacowanie z góry: połowa najdłuższego wymiaru
			top = math.max(top, descendant.CFrame.Position.Y + math.min(size.Y / 2 + 0.3, math.max(size.X, size.Y, size.Z) / 2))
		end
	end
	return top
end

-- Skaluje cały model względem stóp (rozmiary, położenia, zawiasy animacji, zasięg świateł)
local function scaleModel(model: Model, scale: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "Root" then
			local cframe = descendant.CFrame
			descendant.Size *= scale
			descendant.CFrame = CFrame.new(cframe.Position * scale) * (cframe - cframe.Position)
		elseif descendant:IsA("PointLight") then
			descendant.Range *= math.max(scale, 0.9)
		elseif descendant:IsA("BillboardGui") then
			descendant.StudsOffset *= scale
		end
	end
	for name, value in model:GetAttributes() do
		if typeof(value) == "Vector3" and string.sub(name, 1, 5) == "Hinge" then
			model:SetAttribute(name, value * scale)
		end
	end
end

local function fitToDoors(model: Model)
	local top = topOf(model)
	if top > MAX_HEIGHT then
		scaleModel(model, MAX_HEIGHT / top)
	end
end

-- Cichy Sąsiad: wysoki, chudy lunatyk w piżamie w paski i różowych kapciach. Ręce wyciągnięte przed siebie,
-- w prawej świeczka (jej światło zdradza, gdzie idzie). Wielkie uszy (słyszy wszystko!), maska do spania
-- zsunięta na czoło, szlafmyca. Śpi z zamkniętymi oczami; w pościgu otwiera wielkie świecące oczy.
function MonsterModels.Neighbor(): Model
	local model = base("CichySasiad")
	local pajama = Color3.fromRGB(90, 110, 170)
	local stripe = Color3.fromRGB(220, 225, 240)
	local skin = Color3.fromRGB(200, 225, 205)
	local pink = Color3.fromRGB(240, 170, 180)
	local dark = Color3.fromRGB(30, 30, 40)

	for _, x in { -0.6, 0.6 } do
		blob(model, "Slipper", Vector3.new(1.1, 0.7, 1.9), CFrame.new(x, 0.35, -0.3), Color3.fromRGB(255, 150, 200), FABRIC)
		blob(model, "Pompom", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, 0.75, -1.1), WHITE, FABRIC)
		pillar(model, "Leg", 3.4, 0.7, CFrame.new(x, 2.3, 0), pajama, FABRIC)
		blob(model, "LegCuff", Vector3.new(0.85, 0.3, 0.85), CFrame.new(x, 0.85, 0), stripe, FABRIC)
	end

	-- Tułów w paski
	local bodyCenter = Vector3.new(0, 5.8, 0)
	local bodySize = Vector3.new(2.5, 4.4, 1.9)
	blob(model, "Body", bodySize, CFrame.new(bodyCenter), pajama, FABRIC)
	for i = 0, 3 do
		band(model, "Stripe", bodyCenter, bodySize, "Y", -1.4 + i * 0.95, 1.2, stripe, FABRIC)
	end
	for i = 0, 2 do
		blob(model, "Button", Vector3.new(0.22, 0.22, 0.14), CFrame.new(0, 5.2 + i * 0.8, -0.96), WHITE)
	end

	-- Ręce lunatyka: obie wyciągnięte przed siebie, w prawej świeczka na spodku
	for _, side in { -1, 1 } do
		local shoulder = Vector3.new(side * 1.15, 7.4, -0.15)
		local hand = Vector3.new(side * 0.95, 6.9, -3)
		limb(model, "Arm", shoulder, hand, 0.55, pajama, FABRIC)
		blob(model, "ArmCuff", Vector3.new(0.7, 0.7, 0.35), CFrame.new(hand + Vector3.new(0, 0, 0.1)), stripe, FABRIC)
		blob(model, "Hand", Vector3.new(0.62, 0.62, 0.62), CFrame.new(hand + Vector3.new(0, -0.02, -0.25)), skin)
	end
	pillar(model, "CandleDish", 0.14, 1.05, CFrame.new(0.95, 7.2, -3.3), Color3.fromRGB(255, 200, 60), METAL)
	pillar(model, "Candle", 0.9, 0.32, CFrame.new(0.95, 7.7, -3.3), Color3.fromRGB(250, 245, 230))
	local flame = blob(model, "Flame", Vector3.new(0.3, 0.5, 0.3), CFrame.new(0.95, 8.4, -3.3), Color3.fromRGB(255, 170, 60), NEON)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Brightness = 1.4
	light.Range = 16
	light.Shadows = true
	light.Parent = flame

	-- Głowa: blada, senna; wielkie różowe uszy
	local head = blob(model, "Head", Vector3.new(1.9, 2.2, 1.9), CFrame.new(0, 8.9, 0), skin)
	for _, side in { -1, 1 } do
		blob(model, "Ear", Vector3.new(0.45, 1.8, 1.1), CFrame.new(side * 1.15, 9.1, 0) * CFrame.Angles(0, 0, math.rad(side * -15)), pink)
		blob(model, "Cheek", Vector3.new(0.4, 0.25, 0.1), CFrame.new(side * 0.62, 8.5, -0.82), pink)
		-- Zamknięte oczy (śpi) i wielkie otwarte oczy (pościg)
		alertOnly(blob(model, "EyeClosed", Vector3.new(0.48, 0.14, 0.2), CFrame.new(side * 0.42, 8.92, -0.9), dark), "hide")
		alertOnly(blob(model, "EyeOpen", Vector3.new(0.66, 0.66, 0.3), CFrame.new(side * 0.42, 8.95, -0.86), Color3.fromRGB(255, 255, 230), NEON), "show")
		alertOnly(blob(model, "EyePupil", Vector3.new(0.22, 0.22, 0.14), CFrame.new(side * 0.42, 8.95, -1.02), dark), "show")
		-- Maska do spania zsunięta na czoło
		blob(model, "SleepMask", Vector3.new(0.78, 0.5, 0.24), CFrame.new(side * 0.43, 9.62, -0.7) * CFrame.Angles(math.rad(-18), 0, 0), Color3.fromRGB(150, 200, 255), FABRIC)
	end
	blob(model, "MaskStrap", Vector3.new(1.62, 0.16, 1.62), CFrame.new(0, 9.6, 0), Color3.fromRGB(110, 150, 210), FABRIC)
	blob(model, "Nose", Vector3.new(0.26, 0.3, 0.26), CFrame.new(0, 8.62, -0.95), pink)
	alertOnly(blob(model, "MouthSleep", Vector3.new(0.42, 0.13, 0.1), CFrame.new(0, 8.22, -0.9), Color3.fromRGB(80, 50, 60)), "hide")
	alertOnly(blob(model, "MouthOpen", Vector3.new(0.42, 0.52, 0.12), CFrame.new(0, 8.2, -0.9), Color3.fromRGB(60, 30, 40)), "show")

	-- Szlafmyca z kiwającym się czubkiem
	blob(model, "Nightcap", Vector3.new(1.95, 1.4, 1.95), CFrame.new(0, 10.05, 0.1), pajama, FABRIC)
	blob(model, "NightcapBrim", Vector3.new(2.08, 0.42, 2.08), CFrame.new(0, 9.9, 0.1), stripe, FABRIC)
	blob(model, "NightcapTip", Vector3.new(1, 1.2, 1), CFrame.new(0.5, 10.75, 0.5) * CFrame.Angles(0, 0, math.rad(-35)), pajama, FABRIC)
	blob(model, "NightcapPompom", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0.95, 11.05, 0.7), WHITE, FABRIC)
	model:SetAttribute("HingeCap", Vector3.new(0, 10.2, 0.1))

	nameTag(model, head, "🤫 Cichy Sąsiad", Color3.fromRGB(180, 210, 255), 3.4)
	fitToDoors(model)
	return model
end

-- Mruczek: wielki, okrągły, pręgowany kot ze świecącymi żółtymi oczami. Z bliska: wąsy, różowy nosek,
-- biały krawacik i złoty dzwoneczek. Części "Eye" rozjaśniają się, gdy kot idzie za światłem.
function MonsterModels.Cat(): Model
	local model = base("Mruczek")
	local fur = Color3.fromRGB(62, 60, 74)
	local darkFur = Color3.fromRGB(40, 38, 50)
	local belly = Color3.fromRGB(205, 200, 210)

	local bodyCenter = Vector3.new(0, 3.05, 0.6)
	local bodySize = Vector3.new(5, 4.2, 8)
	blob(model, "Body", bodySize, CFrame.new(bodyCenter), fur, FABRIC)
	for _, offset in { -1.5, 0.3, 2.1 } do
		band(model, "Stripe", bodyCenter, bodySize, "Z", offset, 1.3, darkFur, FABRIC)
	end
	for _, x in { -1.45, 1.45 } do
		for _, z in { -2, 3 } do
			blob(model, "Leg", Vector3.new(1.5, 2.8, 1.5), CFrame.new(x, 1.5, z), fur, FABRIC)
			blob(model, "Paw", Vector3.new(1.7, 0.8, 2.1), CFrame.new(x, 0.4, z - 0.35), darkFur, FABRIC)
		end
	end
	blob(model, "Chest", Vector3.new(2.7, 2.5, 1.7), CFrame.new(0, 2.75, -3), belly, FABRIC)

	local head = blob(model, "Head", Vector3.new(4.2, 3.6, 3.6), CFrame.new(0, 5, -3.9), fur, FABRIC)
	blob(model, "Muzzle", Vector3.new(2, 1.3, 0.9), CFrame.new(0, 4.35, -5.35), belly, FABRIC)
	for _, side in { -1, 1 } do
		blob(model, "Ear", Vector3.new(1.2, 1.9, 0.6), CFrame.new(side * 1.3, 6.65, -3.8) * CFrame.Angles(0, 0, math.rad(side * -20)), fur, FABRIC)
		blob(model, "EarInside", Vector3.new(0.65, 1.2, 0.3), CFrame.new(side * 1.3, 6.55, -4.05) * CFrame.Angles(0, 0, math.rad(side * -20)), Color3.fromRGB(240, 150, 170))
		blob(model, "Eye", Vector3.new(1, 1.2, 0.35), CFrame.new(side * 0.9, 5.3, -5.55), Color3.fromRGB(255, 225, 60), NEON)
		blob(model, "Pupil", Vector3.new(0.25, 0.9, 0.2), CFrame.new(side * 0.9, 5.3, -5.72), Color3.fromRGB(20, 20, 20))
		for i = -1, 1 do
			part(model, "Whisker", Vector3.new(2.2, 0.06, 0.06), CFrame.new(side * 1.7, 4.4 + i * 0.22, -5.5) * CFrame.Angles(0, 0, math.rad(i * side * 10)), WHITE)
		end
	end
	blob(model, "Nose", Vector3.new(0.5, 0.35, 0.3), CFrame.new(0, 4.7, -5.75), Color3.fromRGB(255, 140, 170))
	blob(model, "Mouth", Vector3.new(0.7, 0.16, 0.12), CFrame.new(0, 4.1, -5.78), Color3.fromRGB(40, 30, 35))
	-- Dzwoneczek na czerwonej wstążce pod brodą
	blob(model, "Ribbon", Vector3.new(2.2, 0.5, 1.2), CFrame.new(0, 3.5, -4.55), Color3.fromRGB(210, 50, 60), FABRIC)
	blob(model, "Bell", Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, 3.1, -5.05), Color3.fromRGB(255, 200, 60), METAL)

	-- Ogon zakręcony do góry: krótkie odcinki z kulkami na łączeniach (gładki łuk)
	local tail = {
		Vector3.new(0, 3.3, 4.3),
		Vector3.new(0, 4.3, 5.1),
		Vector3.new(0.1, 5.3, 5.5),
		Vector3.new(0.2, 6.3, 5.45),
		Vector3.new(0.1, 7.15, 5),
		Vector3.new(-0.2, 7.7, 4.3),
	}
	for i = 1, #tail - 1 do
		limb(model, "Tail", tail[i], tail[i + 1], 0.9, fur, FABRIC)
		blob(model, "Tail", Vector3.new(0.9, 0.9, 0.9), CFrame.new(tail[i + 1]), if i == #tail - 1 then darkFur else fur, FABRIC)
	end
	model:SetAttribute("HingeTail", tail[1])

	local glow = Instance.new("PointLight")
	glow.Name = "EyeGlow"
	glow.Color = Color3.fromRGB(255, 220, 80)
	glow.Brightness = 0.6
	glow.Range = 9
	glow.Parent = head
	nameTag(model, head, "🐾 Mruczek", Color3.fromRGB(255, 225, 90), 3.5)
	fitToDoors(model)
	return model
end

-- Klucznik o północy: ten sam Pan Klucznik (melonik, wąsy, okulary, muszka, kamizelka), ale przemieniony:
-- wyższy, pochylony do przodu, w długim ciemnym płaszczu, z pomarańczowo świecącymi okularami,
-- gniewnymi brwiami, długimi rękami i gigantycznym kluczem trzymanym jak szpada.
function MonsterModels.Landlord(): Model
	local model = base("KlucznikOPolnocy")
	local coat = Color3.fromRGB(62, 38, 66)
	local coatDark = Color3.fromRGB(42, 26, 48)
	local vest = Color3.fromRGB(150, 118, 58)
	local skin = Color3.fromRGB(196, 188, 206)
	local hair = Color3.fromRGB(235, 235, 240)
	local gold = Color3.fromRGB(255, 200, 60)
	local orange = Color3.fromRGB(255, 140, 40)
	local hat = Color3.fromRGB(24, 18, 26)
	local dark = Color3.fromRGB(30, 26, 34)

	-- Górna połowa ciała pochylona do przodu
	local lean = CFrame.new(0, 4.4, 0) * CFrame.Angles(math.rad(-9), 0, 0) * CFrame.new(0, -4.4, 0)
	local function up(x: number, y: number, z: number): CFrame
		return lean * CFrame.new(x, y, z)
	end
	local function upPoint(x: number, y: number, z: number): Vector3
		return up(x, y, z).Position
	end

	for _, x in { -0.6, 0.6 } do
		blob(model, "Shoe", Vector3.new(1, 0.6, 1.7), CFrame.new(x, 0.3, -0.3), Color3.fromRGB(25, 20, 25))
		pillar(model, "Leg", 2.4, 0.75, CFrame.new(x, 1.6, 0), Color3.fromRGB(45, 40, 55), FABRIC)
	end

	-- Długi płaszcz, kamizelka, łańcuszek od zegarka, koszula i czerwona muszka
	blob(model, "CoatSkirt", Vector3.new(3.3, 5.4, 2.8), CFrame.new(0, 4, 0.1), coat, FABRIC)
	blob(model, "Coat", Vector3.new(3.2, 4.4, 2.5), up(0, 6, 0), coat, FABRIC)
	blob(model, "Vest", Vector3.new(1.8, 2.9, 0.5), up(0, 5.9, -1.05), vest, FABRIC)
	for i = 0, 2 do
		blob(model, "Button", Vector3.new(0.24, 0.24, 0.14), up(0, 5.1 + i * 0.75, -1.3), gold, METAL)
	end
	limb(model, "WatchChain", upPoint(-0.6, 5.5, -1.28), upPoint(0.5, 5.2, -1.28), 0.07, gold, METAL)
	blob(model, "Collar", Vector3.new(2.1, 0.6, 1.5), up(0, 7.9, 0), coatDark, FABRIC)
	blob(model, "Shirt", Vector3.new(0.8, 0.9, 0.3), up(0, 7.45, -0.98), WHITE)
	for _, side in { -1, 1 } do
		blob(model, "BowTie", Vector3.new(0.6, 0.42, 0.25), up(side * 0.3, 7.62, -1.14) * CFrame.Angles(0, 0, math.rad(side * 12)), Color3.fromRGB(200, 40, 55), FABRIC)
	end
	blob(model, "BowKnot", Vector3.new(0.22, 0.26, 0.2), up(0, 7.62, -1.18), Color3.fromRGB(160, 30, 45), FABRIC)

	-- Głowa jak u Pana Klucznika, ale blada; okulary świecą na pomarańczowo
	local head = part(model, "Head", Vector3.new(2, 1, 1), up(0, 9, 0), skin)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.6, 1.6, 1.6)
	headMesh.Parent = head
	for _, side in { -1, 1 } do
		disc(model, "GlassesRim", 0.08, 0.68, up(side * 0.4, 9.15, -0.83), dark, METAL)
		disc(model, "Eye", 0.06, 0.54, up(side * 0.4, 9.15, -0.87), orange, NEON)
		blob(model, "Eyebrow", Vector3.new(0.66, 0.18, 0.2), up(side * 0.42, 9.6, -0.8) * CFrame.Angles(0, 0, math.rad(side * 22)), hair)
		blob(model, "Mustache", Vector3.new(1, 0.34, 0.3), up(side * 0.48, 8.6, -0.86) * CFrame.Angles(0, 0, math.rad(side * -25)), hair)
		blob(model, "Sideburn", Vector3.new(0.3, 0.85, 0.6), up(side * 0.84, 9, 0.05), hair)
	end
	part(model, "GlassesBridge", Vector3.new(0.3, 0.07, 0.07), up(0, 9.18, -0.86), dark, METAL)
	blob(model, "Nose", Vector3.new(0.32, 0.36, 0.32), up(0, 8.88, -0.9), Color3.fromRGB(220, 170, 185))
	blob(model, "Mouth", Vector3.new(0.5, 0.2, 0.1), up(0, 8.36, -0.8), Color3.fromRGB(50, 25, 35))

	-- Melonik ze złotą wstążką
	pillar(model, "HatBrim", 0.14, 2.8, up(0, 9.86, 0), hat)
	pillar(model, "HatBand", 0.32, 1.95, up(0, 10.08, 0), gold, METAL)
	blob(model, "HatTop", Vector3.new(1.95, 1.5, 1.95), up(0, 10.35, 0), hat)

	-- Długie ręce wyciągnięte do przodu, białe rękawiczki
	local leftHand = upPoint(-1.45, 5.4, -2.5)
	local rightHand = upPoint(1.45, 5.9, -2.6)
	limb(model, "Arm", upPoint(-1.5, 7.3, 0), leftHand, 0.7, coat, FABRIC)
	limb(model, "Arm", upPoint(1.5, 7.3, 0), rightHand, 0.7, coat, FABRIC)
	blob(model, "Glove", Vector3.new(0.95, 0.95, 0.95), CFrame.new(leftHand + Vector3.new(0, -0.05, -0.2)), WHITE)
	blob(model, "Glove", Vector3.new(0.95, 0.95, 0.95), CFrame.new(rightHand + Vector3.new(0, 0, -0.15)), WHITE)

	-- Gigantyczny klucz w prawej dłoni: kółko, trzonek i dwa zęby (kołysze się w animacji)
	local grip = rightHand + Vector3.new(0, 0, -0.15)
	part(model, "KeyBow", Vector3.new(0.28, 1.7, 1.7), CFrame.new(grip + Vector3.new(0, 0, -0.75)), gold, METAL, Enum.PartType.Cylinder)
	part(model, "KeyHole", Vector3.new(0.32, 0.85, 0.85), CFrame.new(grip + Vector3.new(0, 0, -0.75)), coatDark, nil, Enum.PartType.Cylinder)
	part(model, "KeyShaft", Vector3.new(4.2, 0.36, 0.36), CFrame.new(grip + Vector3.new(0, 0, -3.6)) * CFrame.Angles(0, math.rad(90), 0), gold, METAL, Enum.PartType.Cylinder)
	part(model, "KeyBit", Vector3.new(0.26, 1, 0.8), CFrame.new(grip + Vector3.new(0, -0.5, -5.3)), gold, METAL)
	part(model, "KeyTooth", Vector3.new(0.26, 0.7, 0.45), CFrame.new(grip + Vector3.new(0, -0.35, -4.45)), gold, METAL)
	model:SetAttribute("HingeKey", grip)

	local glow = Instance.new("PointLight")
	glow.Color = orange
	glow.Brightness = 2
	glow.Range = 18
	glow.Parent = head
	nameTag(model, head, "🔑 KLUCZNIK O PÓŁNOCY", Color3.fromRGB(255, 160, 60), 3.6)
	fitToDoors(model)
	return model
end

return MonsterModels

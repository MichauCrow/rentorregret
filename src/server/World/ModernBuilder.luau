-- Nowoczesne budynki z bloków: przeszklony front ze szklanymi drzwiami, które same się rozsuwają, gdy ktoś podejdzie
-- (czujnik nad wejściem świeci na zielono), płaski dach z attyką, daszek z podświetleniem, donice, kinkiety i okna na bokach.
-- Do tego nowoczesne domki jednorodzinne w trzech wariantach: kostka z wysuniętym piętrem, dach jednospadowy i "stodoła".
-- Lokalnie front jest na -Z, a podłoga wnętrza ma wierzch na y = 1. Używane przez JobSitesBuilder i PetBuilder.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ModernBuilder = {}

local C = {
	render = Color3.fromRGB(246, 244, 240), -- jasny tynk
	plinth = Color3.fromRGB(72, 76, 84),
	frame = Color3.fromRGB(40, 43, 50), -- grafitowe aluminium: ramy, słupki, attyka
	glass = Color3.fromRGB(175, 220, 245),
	darkGlass = Color3.fromRGB(55, 90, 120),
	wood = Color3.fromRGB(200, 140, 88),
	led = Color3.fromRGB(255, 244, 222),
	floor = Color3.fromRGB(228, 224, 216),
	ceiling = Color3.fromRGB(252, 252, 250),
	planter = Color3.fromRGB(88, 92, 100),
	soil = Color3.fromRGB(90, 65, 45),
	shrub = Color3.fromRGB(70, 170, 80),
	shrubDark = Color3.fromRGB(45, 140, 65),
	roof = Color3.fromRGB(58, 62, 70),
	stone = Color3.fromRGB(215, 210, 200),
	sensorOff = Color3.fromRGB(255, 90, 90),
	sensorOn = Color3.fromRGB(90, 255, 140),
	flowers = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 220, 60), Color3.fromRGB(170, 110, 255), Color3.fromRGB(255, 255, 255) },
}
ModernBuilder.COLORS = C

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Ozdoba bez kolizji (nie przeszkadza w chodzeniu ani w podpowiedziach)
local function deco(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = part(parent, name, size, cframe, color, material, false)
	p.CanQuery = false
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	return p
end

local function glass(parent: Instance, name: string, size: Vector3, cframe: CFrame, collide: boolean?, tint: Color3?): Part
	local p = part(parent, name, size, cframe, tint or C.glass, Enum.Material.Glass, collide)
	p.Transparency = 0.55
	p.Reflectance = 0.12
	p.CastShadow = false
	return p
end

-- Szyba na ścianie (dekoracja): rama i ciemniejsze szkło. cframe = środek okna na licu ściany, -Z = na zewnątrz.
local function window(parent: Instance, cframe: CFrame, w: number, h: number)
	deco(parent, "WindowFrame", Vector3.new(w + 0.3, h + 0.3, 0.12), cframe * CFrame.new(0, 0, -0.06), C.frame, Enum.Material.Metal)
	local pane = deco(parent, "WindowGlass", Vector3.new(w, h, 0.06), cframe * CFrame.new(0, 0, -0.15), C.darkGlass, Enum.Material.Glass)
	pane.Transparency = 0.15
	pane.Reflectance = 0.25
	if w > 2.8 then
		deco(parent, "WindowMullion", Vector3.new(0.15, h, 0.1), cframe * CFrame.new(0, 0, -0.2), C.frame, Enum.Material.Metal)
	end
	deco(parent, "WindowSill", Vector3.new(w + 0.5, 0.15, 0.35), cframe * CFrame.new(0, -h / 2 - 0.2, -0.17), C.frame, Enum.Material.Metal)
end
ModernBuilder.Window = window

-- Donica z krzewami (cframe = środek na ziemi)
local function planter(parent: Instance, cframe: CFrame, length: number)
	part(parent, "Planter", Vector3.new(length, 1.3, 1.4), cframe * CFrame.new(0, 0.65, 0), C.planter, Enum.Material.Concrete)
	deco(parent, "PlanterSoil", Vector3.new(length - 0.3, 0.1, 1.1), cframe * CFrame.new(0, 1.28, 0), C.soil, Enum.Material.Ground)
	local count = math.max(2, math.floor(length / 1.1))
	for i = 1, count do
		local x = -length / 2 + (i - 0.5) * length / count
		local size = if i % 2 == 0 then 1.3 else 1.1
		deco(parent, "Shrub", Vector3.new(size, size, size), cframe * CFrame.new(x, 1.3 + size * 0.35, 0), if i % 2 == 0 then C.shrub else C.shrubDark, Enum.Material.Grass, Enum.PartType.Ball)
		if i % 2 == 1 then
			deco(parent, "PlanterFlower", Vector3.new(0.35, 0.35, 0.35), cframe * CFrame.new(x + 0.3, 1.3 + size * 0.75, -0.35), C.flowers[i % #C.flowers + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
end
ModernBuilder.Planter = planter

-- Lampa ścienna: grafitowy kinkiet świecący w górę i w dół (cframe = środek na licu ściany)
local function sconce(parent: Instance, cframe: CFrame)
	deco(parent, "Sconce", Vector3.new(0.45, 1.1, 0.35), cframe * CFrame.new(0, 0, -0.18), C.frame, Enum.Material.Metal)
	for _, y in { 0.6, -0.6 } do
		local glow = deco(parent, "SconceGlow", Vector3.new(0.35, 0.08, 0.25), cframe * CFrame.new(0, y, -0.18), C.led, Enum.Material.Neon)
		if y > 0 then
			local light = Instance.new("PointLight")
			light.Range = 9
			light.Brightness = 0.7
			light.Color = C.led
			light.Parent = glow
		end
	end
end

-- Automatyczne drzwi przesuwne ------------------------------------------------------------------
local doors = {}
local DOOR_RANGE = 9
local doorLoop = false

local function runDoors()
	if doorLoop then
		return
	end
	doorLoop = true
	task.spawn(function()
		local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		while #doors > 0 do
			local positions = {}
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					table.insert(positions, root.Position)
				end
			end
			for index = #doors, 1, -1 do
				local door = doors[index]
				if not door.leaves[1].part.Parent then
					table.remove(doors, index)
				else
					local near = false
					for _, position in positions do
						if (position - door.center).Magnitude <= DOOR_RANGE then
							near = true
							break
						end
					end
					if near ~= door.open then
						door.open = near
						for _, leaf in door.leaves do
							TweenService:Create(leaf.part, info, { CFrame = if near then leaf.opened else leaf.closed }):Play()
						end
						door.sensor.Color = if near then C.sensorOn else C.sensorOff
					end
				end
			end
			task.wait(0.15)
		end
		doorLoop = false
	end)
end

-- Dwuskrzydłowe szklane drzwi rozsuwane na boki (za stałe szyby). base = środek otworu na poziomie podłogi, -Z = na zewnątrz.
function ModernBuilder.SlidingDoor(parent: Instance, base: CFrame, width: number, height: number)
	local leafWidth = width / 2
	local leaves = {}
	for _, side in { -1, 1 } do
		local closed = base * CFrame.new(side * leafWidth / 2, height / 2, 0)
		local opened = base * CFrame.new(side * (leafWidth * 1.5 - 0.25), height / 2, 0.4)
		local leaf = glass(parent, "SlidingDoor", Vector3.new(leafWidth, height, 0.2), closed, true)
		leaf.Transparency = 0.45
		-- Ścieżki (przewodnik po pracy) prowadzą przez drzwi, bo otwierają się same
		local passThrough = Instance.new("PathfindingModifier")
		passThrough.PassThrough = true
		passThrough.Parent = leaf
		-- Rama skrzydła i biały pasek na wysokości oczu, przyspawane do szyby (jadą razem z nią)
		local function trim(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
			local p = deco(parent, name, size, closed * offset, color, material)
			p.Anchored = false
			p.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = leaf
			weld.Part1 = p
			weld.Parent = p
		end
		for _, x in { -leafWidth / 2 + 0.1, leafWidth / 2 - 0.1 } do
			trim("DoorStile", Vector3.new(0.2, height, 0.3), CFrame.new(x, 0, 0), C.frame, Enum.Material.Metal)
		end
		for _, y in { height / 2 - 0.15, -height / 2 + 0.15 } do
			trim("DoorRail", Vector3.new(leafWidth, 0.3, 0.3), CFrame.new(0, y, 0), C.frame, Enum.Material.Metal)
		end
		trim("DoorStripe", Vector3.new(leafWidth - 0.4, 0.22, 0.24), CFrame.new(0, 0.6, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		table.insert(leaves, { part = leaf, closed = closed, opened = opened })
	end
	-- Skrzynka z mechanizmem i czujnikiem nad drzwiami, szyna w podłodze
	deco(parent, "DoorHeader", Vector3.new(width + 0.6, 0.7, 0.8), base * CFrame.new(0, height + 0.35, 0.15), C.frame, Enum.Material.Metal)
	local sensor = deco(parent, "DoorSensor", Vector3.new(0.7, 0.18, 0.1), base * CFrame.new(0, height + 0.35, -0.3), C.sensorOff, Enum.Material.Neon)
	deco(parent, "DoorTrack", Vector3.new(width * 2, 0.04, 0.35), base * CFrame.new(0, 0.02, 0.3), C.frame, Enum.Material.Metal)
	table.insert(doors, { leaves = leaves, sensor = sensor, center = (base * CFrame.new(0, 2.5, 0)).Position, open = false })
	runDoors()
end

-- Lokal (sklep, biuro, pizzeria...): podłoga, ściany z tynku na cokole, przeszklony front między grafitowymi filarami,
-- kolorowy pas nad witryną (miejsce na szyld), drzwi przesuwne, daszek z LED-ami, płaski dach z attyką i panele świetlne w środku.
-- opts = { width, depth, height, accent, doorWidth?, doorHeight?, rooftop? (agregaty na dachu), sideWindows? }
-- Zwraca at(x, y, z) i info { fasciaBottom, top, roofTop }.
function ModernBuilder.Shell(model: Instance, origin: CFrame, opts)
	local width, depth, height = opts.width, opts.depth, opts.height
	local accent = opts.accent or C.frame
	local doorWidth = opts.doorWidth or 6
	local doorHeight = opts.doorHeight or 7.5
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local top = 1 + height
	local parapet = 1.4
	local wallY = 1 + height / 2
	local frontZ = -depth / 2 + 0.5
	local fasciaBottom = 1 + doorHeight + 0.7
	local pier = 1.6

	part(model, "Floor", Vector3.new(width, 1, depth), at(0, 0.5, 0), C.floor)
	part(model, "WallBack", Vector3.new(width, height, 1), at(0, wallY, depth / 2 - 0.5), C.render)
	for _, side in { -1, 1 } do
		part(model, if side < 0 then "WallLeft" else "WallRight", Vector3.new(1, height, depth - 1), at(side * (width / 2 - 0.5), wallY, 0.5), C.render)
		deco(model, "Plinth", Vector3.new(0.3, 1.2, depth), at(side * (width / 2 + 0.05), 0.6, 0), C.plinth, Enum.Material.Concrete)
	end
	deco(model, "Plinth", Vector3.new(width + 0.4, 1.2, 0.3), at(0, 0.6, depth / 2 + 0.05), C.plinth, Enum.Material.Concrete)

	-- Front: grafitowe filary na rogach i kolorowy pas od witryny aż po attykę
	for _, side in { -1, 1 } do
		part(model, "Pier", Vector3.new(pier + 0.1, top + parapet, 1.2), at(side * (width / 2 - pier / 2 + 0.05), (top + parapet) / 2, frontZ - 0.1), C.frame, Enum.Material.Metal)
		sconce(model, at(side * (width / 2 - pier / 2), 5.5, -depth / 2 - 0.2))
	end
	part(model, "Fascia", Vector3.new(width - pier * 2, top + parapet - fasciaBottom, 1), at(0, (fasciaBottom + top + parapet) / 2, frontZ), accent)
	deco(model, "Coping", Vector3.new(width + 0.4, 0.2, 1.4), at(0, top + parapet + 0.1, frontZ - 0.1), C.frame, Enum.Material.Metal)

	-- Witryny po obu stronach drzwi: szkło od listwy przy podłodze do pasa, słupki co ok. 3,5 studa i poprzeczka
	local inner = doorWidth / 2 + 0.3
	local outer = width / 2 - pier
	local span = outer - inner
	if span > 0.4 then
		local glassHeight = fasciaBottom - 1.4
		for _, side in { -1, 1 } do
			local cx = side * (inner + span / 2)
			glass(model, "Storefront", Vector3.new(span, glassHeight, 0.2), at(cx, 1.4 + glassHeight / 2, frontZ), true)
			part(model, "StorefrontBase", Vector3.new(span, 0.4, 0.5), at(cx, 1.2, frontZ), C.frame, Enum.Material.Metal)
			deco(model, "Transom", Vector3.new(span, 0.22, 0.4), at(cx, 1 + doorHeight + 0.1, frontZ), C.frame, Enum.Material.Metal)
			local panes = math.max(1, math.floor(span / 3.5 + 0.5))
			for k = 1, panes - 1 do
				local x = side * (inner + span * k / panes)
				deco(model, "Mullion", Vector3.new(0.22, glassHeight, 0.4), at(x, 1.4 + glassHeight / 2, frontZ), C.frame, Enum.Material.Metal)
			end
			part(model, "DoorJamb", Vector3.new(0.3, fasciaBottom - 1, 0.6), at(side * (doorWidth / 2 + 0.15), (1 + fasciaBottom) / 2, frontZ), C.frame, Enum.Material.Metal)
		end
	end
	ModernBuilder.SlidingDoor(model, at(0, 1, frontZ), doorWidth, doorHeight)

	-- Stopień przed wejściem z wycieraczką, daszek z listwą LED i donice po bokach
	part(model, "EntranceStep", Vector3.new(doorWidth + 2, 0.5, 1.6), at(0, 0.25, -depth / 2 - 0.8), C.stone, Enum.Material.Concrete)
	deco(model, "DoorMat", Vector3.new(doorWidth - 1, 0.05, 1), at(0, 0.52, -depth / 2 - 0.75), Color3.fromRGB(60, 60, 68), Enum.Material.Fabric)
	local canopy = deco(model, "Canopy", Vector3.new(doorWidth + 4, 0.35, 3), at(0, fasciaBottom - 0.2, -depth / 2 - 1.5), C.frame, Enum.Material.Metal)
	local strip = deco(model, "CanopyLED", Vector3.new(doorWidth + 3.4, 0.05, 0.2), at(0, fasciaBottom - 0.4, -depth / 2 - 2.7), C.led, Enum.Material.Neon)
	strip.CastShadow = false
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Range = 12
	spot.Angle = 100
	spot.Brightness = 1.2
	spot.Color = C.led
	spot.Parent = canopy
	if span > 3 then
		for _, side in { -1, 1 } do
			planter(model, at(side * (inner + math.min(span, 6) / 2 + 0.3), 0, -depth / 2 - 1.1), math.min(span - 0.6, 4))
		end
	end

	-- Okna na bocznych ścianach (od zewnątrz)
	if opts.sideWindows ~= false then
		local windowHeight = height - 3.6
		for _, side in { -1, 1 } do
			for z = -depth / 2 + 4, depth / 2 - 3, 5 do
				window(model, at(side * width / 2, 2.4 + windowHeight / 2, z) * CFrame.Angles(0, -side * math.rad(90), 0), 2.2, windowHeight)
			end
		end
	end

	-- Płaski dach z attyką i obróbką
	-- Strop odsunięty od lic ścian (inaczej migotałby z pasem i attyką)
	part(model, "Roof", Vector3.new(width - 1.2, 0.8, depth - 1.2), at(0, top + 0.4, 0), C.roof, Enum.Material.Concrete)
	for _, side in { -1, 1 } do
		part(model, "Parapet", Vector3.new(0.6, parapet, depth - 1), at(side * (width / 2 - 0.3), top + parapet / 2, 0.5), C.render)
		deco(model, "Coping", Vector3.new(0.9, 0.2, depth - 0.8), at(side * (width / 2 - 0.3), top + parapet + 0.1, 0.5), C.frame, Enum.Material.Metal)
	end
	part(model, "Parapet", Vector3.new(width, parapet, 0.6), at(0, top + parapet / 2, depth / 2 - 0.3), C.render)
	deco(model, "Coping", Vector3.new(width + 0.3, 0.2, 0.9), at(0, top + parapet + 0.1, depth / 2 - 0.3), C.frame, Enum.Material.Metal)
	if opts.rooftop then
		for i, x in { -width / 4, width / 4 } do
			deco(model, "RoofUnit", Vector3.new(3, 1.6, 2.2), at(x, top + 1.6, depth / 4 - (i - 1) * 2), Color3.fromRGB(200, 205, 212), Enum.Material.Metal)
			deco(model, "RoofFan", Vector3.new(0.15, 1.6, 1.6), at(x, top + 2.45, depth / 4 - (i - 1) * 2) * CFrame.Angles(0, 0, math.rad(90)), C.frame, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end

	-- Wnętrze: jasny sufit i panele świetlne
	deco(model, "Ceiling", Vector3.new(width - 2, 0.1, depth - 2), at(0, top - 0.05, 0), C.ceiling)
	local lit = 0
	for x = -width / 2 + 5, width / 2 - 4.9, 7 do
		for z = -depth / 2 + 4, depth / 2 - 3.9, 6 do
			local panel = deco(model, "CeilingLight", Vector3.new(3, 0.08, 1.2), at(x, top - 0.14, z), C.led, Enum.Material.Neon)
			panel.CastShadow = false
			lit += 1
			if lit % 2 == 1 then
				local light = Instance.new("PointLight")
				light.Range = 16
				light.Brightness = 0.8
				light.Color = C.led
				light.Parent = panel
			end
		end
	end
	return at, { fasciaBottom = fasciaBottom, top = top, roofTop = top + 0.8 }
end

-- Przeszklone wyższe piętra na dachu (biurowiec): ciemne szkło, białe pasy stropów, pionowe słupki i antena.
-- baseY = wierzch dachu parteru; width/depth = obrys pięter (mniejszy niż parter, żeby został taras).
function ModernBuilder.Tower(model: Instance, at, baseY: number, width: number, depth: number, floors: number, accent: Color3)
	local floorHeight = 7
	local height = floors * floorHeight
	local core = part(model, "TowerGlass", Vector3.new(width, height, depth), at(0, baseY + height / 2, 0), C.darkGlass, Enum.Material.Glass)
	core.Reflectance = 0.3
	for k = 0, floors do
		local y = baseY + k * floorHeight
		local band = deco(model, "TowerBand", Vector3.new(width + 0.4, if k == floors then 1.2 else 0.7, depth + 0.4), at(0, y + (if k == floors then 0.6 else 0.35), 0), if k == floors then accent else C.render, Enum.Material.SmoothPlastic)
		band.CanCollide = true
	end
	for x = -width / 2 + 1.5, width / 2 - 1.4, 3.2 do
		for _, z in { -depth / 2 - 0.12, depth / 2 + 0.12 } do
			deco(model, "TowerMullion", Vector3.new(0.22, height, 0.22), at(x, baseY + height / 2, z), C.frame, Enum.Material.Metal)
		end
	end
	for z = -depth / 2 + 1.5, depth / 2 - 1.4, 3.2 do
		for _, x in { -width / 2 - 0.12, width / 2 + 0.12 } do
			deco(model, "TowerMullion", Vector3.new(0.22, height, 0.22), at(x, baseY + height / 2, z), C.frame, Enum.Material.Metal)
		end
	end
	local roofY = baseY + height + 1.2
	deco(model, "TowerRoofUnit", Vector3.new(4, 2, 3), at(width / 4, roofY + 1, depth / 5), Color3.fromRGB(200, 205, 212), Enum.Material.Metal)
	deco(model, "Antenna", Vector3.new(0.3, 7, 0.3), at(-width / 4, roofY + 3.5, -depth / 6), C.frame, Enum.Material.Metal)
	local beacon = deco(model, "AntennaLight", Vector3.new(0.6, 0.6, 0.6), at(-width / 4, roofY + 7.2, -depth / 6), Color3.fromRGB(255, 70, 70), Enum.Material.Neon, Enum.PartType.Ball)
	beacon.CastShadow = false
end

-- Domki jednorodzinne ----------------------------------------------------------------------------
local HOUSE_W, HOUSE_D = 12, 10

-- Słupek z numerem domu, skrzynką na listy i lampką przy wejściu na posesję (numer widać z ulicy)
local function numberPost(parent: Instance, cframe: CFrame, number: number)
	local post = part(parent, "NumberPost", Vector3.new(1.8, 3.4, 0.7), cframe * CFrame.new(0, 1.7, 0), C.frame, Enum.Material.Metal)
	deco(parent, "MailSlot", Vector3.new(1, 0.1, 0.05), cframe * CFrame.new(0, 1.2, -0.37), C.wood, Enum.Material.Metal)
	local glow = deco(parent, "PostLight", Vector3.new(1.7, 0.12, 0.6), cframe * CFrame.new(0, 3.46, 0), C.led, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 8
	light.Brightness = 0.6
	light.Color = C.led
	light.Parent = glow
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0
		gui.Parent = post
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.9, 0.36)
		label.Position = UDim2.fromScale(0.05, 0.08)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = string.format("Nr %d", number)
		label.Parent = gui
	end
end

-- Szklane drzwi wejściowe domu z daszkiem i stopniem (z = lico ściany frontowej)
local function houseDoor(parent: Instance, at, z: number, canopyY: number)
	deco(parent, "DoorFrame", Vector3.new(2.8, 4.9, 0.12), at(0, 2.75, z - 0.06), C.frame, Enum.Material.Metal)
	local pane = deco(parent, "DoorGlass", Vector3.new(2.2, 4.4, 0.08), at(0, 2.75, z - 0.14), C.glass, Enum.Material.Glass)
	pane.Transparency = 0.25
	pane.Reflectance = 0.2
	deco(parent, "DoorHandle", Vector3.new(0.14, 2, 0.14), at(0.75, 2.8, z - 0.28), Color3.fromRGB(205, 210, 220), Enum.Material.Metal)
	part(parent, "DoorStep", Vector3.new(3.6, 0.4, 1.6), at(0, 0.2, z - 0.8), C.stone, Enum.Material.Concrete)
	deco(parent, "DoorCanopy", Vector3.new(3.8, 0.25, 1.6), at(0, canopyY, z - 0.8), C.frame, Enum.Material.Metal)
	sconce(parent, at(-1.95, 3.9, z))
end

-- Ogródek przed domem: kamienne płyty do furtki, niskie żywopłoty i słupek z numerem
local function frontYard(parent: Instance, at, number: number)
	local front = -HOUSE_D / 2
	part(parent, "Yard", Vector3.new(HOUSE_W + 6, 0.2, HOUSE_D + 9), at(0, 0.1, -2.5), Color3.fromRGB(100, 200, 85), Enum.Material.Grass)
	for i, z in { front - 2.2, front - 3.7, front - 5.2 } do
		deco(parent, "PathStone", Vector3.new(2.4, 0.12, 1.1), at(if i % 2 == 0 then 0.25 else -0.15, 0.22, z), C.stone, Enum.Material.Slate)
	end
	for _, side in { -1, 1 } do
		part(parent, "Hedge", Vector3.new(3.4, 1.2, 1.1), at(side * 3.9, 0.6, front - 2.4), C.shrubDark, Enum.Material.Grass)
		deco(parent, "HedgeTop", Vector3.new(3.2, 0.25, 0.9), at(side * 3.9, 1.3, front - 2.4), C.shrub, Enum.Material.Grass)
		deco(parent, "Topiary", Vector3.new(1.6, 1.6, 1.6), at(side * 5.6, 1.9, front - 2.4), C.shrub, Enum.Material.Grass, Enum.PartType.Ball)
	end
	numberPost(parent, at(2.2, 0, front - 5.6), number)
end

-- Domek do dostaw: wariant zależy od numeru. Zwraca część "Body" (bryła parteru, od niej liczy się punkt przy drzwiach).
function ModernBuilder.House(model: Model, origin: CFrame, number: number, color: Color3): BasePart
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local variant = number % 3
	local front = -HOUSE_D / 2
	local body
	if variant == 1 then
		-- Kostka: biały parter, kolorowe piętro wysunięte nad wejście, taras z balustradą ze szkła
		body = part(model, "Body", Vector3.new(HOUSE_W, 5.5, HOUSE_D), at(0, 2.75, 0), C.render)
		part(model, "Upper", Vector3.new(9, 4.5, HOUSE_D), at(1.5, 7.75, -1), color)
		deco(model, "Coping", Vector3.new(HOUSE_W + 0.3, 0.25, HOUSE_D + 0.3), at(0, 5.62, 0), C.frame, Enum.Material.Metal)
		deco(model, "Coping", Vector3.new(9.3, 0.3, HOUSE_D + 0.3), at(1.5, 10.15, -1), C.frame, Enum.Material.Metal)
		window(model, at(1.5, 7.8, -6), 6.6, 2.2)
		window(model, at(6, 7.8, -1) * CFrame.Angles(0, math.rad(-90), 0), 4, 2.2)
		local rail = glass(model, "TerraceRail", Vector3.new(3, 1.2, 0.1), at(-4.5, 6.35, front + 0.1), false)
		rail.CanQuery = false
		local sideRail = glass(model, "TerraceRail", Vector3.new(0.1, 1.2, HOUSE_D - 0.2), at(-5.9, 6.35, 0), false)
		sideRail.CanQuery = false
		deco(model, "TerraceRailTop", Vector3.new(3, 0.12, 0.16), at(-4.5, 7, front + 0.1), C.frame, Enum.Material.Metal)
		deco(model, "TerraceRailTop", Vector3.new(0.16, 0.12, HOUSE_D - 0.2), at(-5.9, 7, 0), C.frame, Enum.Material.Metal)
		window(model, at(3.8, 2.9, front), 3.4, 3.2)
		window(model, at(-4.3, 2.9, front), 1.4, 3.2)
		houseDoor(model, at, front, 5.15)
	elseif variant == 2 then
		-- Dach jednospadowy: wysoka bryła, kolorowy panel z oknami, drewniane lamele i wysokie okno
		body = part(model, "Body", Vector3.new(HOUSE_W, 8, HOUSE_D), at(0, 4, 0), C.render)
		local roof = Instance.new("WedgePart")
		roof.Name = "Roof"
		roof.Size = Vector3.new(HOUSE_W + 0.6, 2.4, HOUSE_D + 0.6)
		roof.CFrame = at(0, 9.2, 0) * CFrame.Angles(0, math.pi, 0)
		roof.Color = C.roof
		roof.Material = Enum.Material.Metal
		roof.Anchored = true
		roof.Parent = model
		deco(model, "AccentPanel", Vector3.new(4.4, 8, 0.15), at(-3.8, 4, front - 0.08), color)
		window(model, at(-3.8, 2.6, front - 0.15), 2.2, 2.2)
		window(model, at(-3.8, 6.2, front - 0.15), 2.2, 2.2)
		for x = 2.2, 5.6, 0.62 do
			deco(model, "WoodSlat", Vector3.new(0.32, 2.2, 0.2), at(x, 6.8, front - 0.1), C.wood, Enum.Material.Wood)
		end
		window(model, at(3.9, 3.2, front), 3, 4.4)
		window(model, at(-6, 4, 1) * CFrame.Angles(0, math.rad(90), 0), 2.4, 3.4)
		houseDoor(model, at, front, 5.4)
	else
		-- "Stodoła": kolorowe ściany, grafitowy dach dwuspadowy bez okapu i przeszklony szczyt
		body = part(model, "Body", Vector3.new(HOUSE_W, 5.5, HOUSE_D), at(0, 2.75, 0), color)
		for _, side in { -1, 1 } do
			local half = Instance.new("WedgePart")
			half.Name = "Roof"
			half.Size = Vector3.new(HOUSE_D + 0.4, 4, HOUSE_W / 2 + 0.2)
			half.CFrame = at(side * (HOUSE_W / 4 + 0.05), 7.5, 0) * CFrame.Angles(0, side * math.rad(-90), 0)
			half.Color = C.roof
			half.Material = Enum.Material.Metal
			half.Anchored = true
			half.Parent = model
		end
		local gable = deco(model, "GableGlass", Vector3.new(2.4, 3, 0.1), at(0, 6.95, front - 0.27), C.darkGlass, Enum.Material.Glass)
		gable.Reflectance = 0.25
		deco(model, "GableFrame", Vector3.new(2.7, 3.2, 0.08), at(0, 6.95, front - 0.22), C.frame, Enum.Material.Metal)
		deco(model, "Plinth", Vector3.new(HOUSE_W + 0.3, 0.6, HOUSE_D + 0.3), at(0, 0.3, 0), C.plinth, Enum.Material.Concrete)
		for _, x in { -4, 4 } do
			window(model, at(x, 3, front), 2.2, 2.8)
		end
		for _, side in { -1, 1 } do
			window(model, at(side * HOUSE_W / 2, 3, 0) * CFrame.Angles(0, -side * math.rad(90), 0), 3, 2.6)
		end
		houseDoor(model, at, front, 5.15)
	end
	frontYard(model, at, number)
	return body
end

return ModernBuilder

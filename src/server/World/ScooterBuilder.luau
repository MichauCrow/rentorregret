-- Pojazdy pod nogami gracza: hulajnoga elektryczna (wypożyczalnia), skuter z kufrem na pizzę (praca w pizzerii)
-- i rower z koszykiem (dostawca kebabów: dłonie na kierownicy i stopy na pedałach przez IKControl).
-- Pojazd jest przyspawany do HumanoidRootPart (Weld z C0), a postać dostaje atrybut "RidePose":
-- klient podmienia wtedy animację biegu na stanie (hulajnoga) albo siedzenie (skuter), więc jedzie pojazd, a nie biegną nogi.
-- Wheelie obraca pojazd wokół osi tylnego koła; klienci przechylają postać o ten sam kąt (RidePoseController),
-- bo staw biodrowy postaci (C0) jest tylko do odczytu.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ScooterBuilder = {}

local KICK = {
	frame = Color3.fromRGB(38, 40, 46),
	grip = Color3.fromRGB(20, 20, 24),
	accent = Color3.fromRGB(255, 120, 30),
	tire = Color3.fromRGB(28, 28, 32),
	metal = Color3.fromRGB(150, 155, 165),
	display = Color3.fromRGB(80, 220, 255),
}
local BIKE = {
	frame = Color3.fromRGB(40, 190, 170),
	accent = Color3.fromRGB(255, 120, 40),
	tire = Color3.fromRGB(28, 28, 32),
	rim = Color3.fromRGB(215, 220, 228),
	saddle = Color3.fromRGB(40, 32, 30),
	basket = Color3.fromRGB(190, 140, 80),
}
local MOPED = {
	body = Color3.fromRGB(235, 50, 60),
	trim = Color3.fromRGB(250, 250, 250),
	seat = Color3.fromRGB(45, 35, 40),
	tire = Color3.fromRGB(28, 28, 32),
	metal = Color3.fromRGB(190, 195, 205),
	crate = Color3.fromRGB(255, 200, 40),
	crateText = Color3.fromRGB(200, 40, 40),
}
-- Kufer na pizzę zaczyna się tyle nad ziemią modelu (PizzaJob kładzie na nim pudełko)
ScooterBuilder.CRATE_TOP = 3.65

local function newPart(model: Model, base: BasePart, ground: CFrame, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Anchored = false
	if shape then
		p.Shape = shape
	end
	p.CFrame = ground * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

-- Korzeń "Base" leży na osi tylnego koła (rearZ), wokół niej obraca się wheelie. ground = punkt na ziemi pod środkiem, przód = -Z.
local function newModel(name: string, ground: CFrame, rearZ: number, axleY: number, anchored: boolean)
	local model = Instance.new("Model")
	model.Name = name
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(0.2, 0.2, 0.2)
	base.Transparency = 1
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.Massless = true
	base.Anchored = anchored
	base.CFrame = ground * CFrame.new(0, axleY, rearZ)
	base.Parent = model
	model.PrimaryPart = base
	model:SetAttribute("RearZ", rearZ)
	model:SetAttribute("AxleY", axleY)
	return model, base
end

-- Punkt na ziemi pod środkiem pojazdu (odwrotność newModel), np. dla zaparkowanych skuterów i rowerów
function ScooterBuilder.GroundOf(model: Model): CFrame
	return model.PrimaryPart.CFrame * CFrame.new(0, -(model:GetAttribute("AxleY") or 0), -(model:GetAttribute("RearZ") or 0))
end

-- Drążek ramy między dwoma punktami (współrzędne względem ziemi pojazdu)
local function bar(model: Model, base: BasePart, ground: CFrame, name: string, from: Vector3, to: Vector3, thickness: number, color: Color3, material: Enum.Material?)
	return newPart(model, base, ground, name, Vector3.new(thickness, thickness, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), color, nil, material)
end

-- Hulajnoga elektryczna: czarna rama, grube koła, pomarańczowe akcenty
function ScooterBuilder.Kick(ground: CFrame, anchored: boolean): Model
	local model, base = newModel("RentalScooter", ground, 2.3, 0.55, anchored)
	local function piece(...)
		return newPart(model, base, ground, ...)
	end
	piece("Deck", Vector3.new(1.5, 0.4, 4.2), CFrame.new(0, 0.75, 0), KICK.frame)
	piece("Grip", Vector3.new(1.3, 0.06, 3.6), CFrame.new(0, 0.97, -0.1), KICK.grip, nil, Enum.Material.Fabric)
	piece("SideStripe", Vector3.new(1.54, 0.12, 4), CFrame.new(0, 0.66, 0), KICK.accent)
	piece("Fender", Vector3.new(1.1, 0.16, 1.7), CFrame.new(0, 1.42, 2.25), KICK.frame)
	piece("TailLight", Vector3.new(0.7, 0.22, 0.12), CFrame.new(0, 1.36, 3.12), Color3.fromRGB(255, 40, 40), nil, Enum.Material.Neon).CastShadow = false
	piece("Neck", Vector3.new(0.45, 1.3, 0.45), CFrame.new(0, 1.15, -2.15) * CFrame.Angles(math.rad(-35), 0, 0), KICK.frame)
	piece("Stem", Vector3.new(0.32, 3.4, 0.32), CFrame.new(0, 2.95, -2.35) * CFrame.Angles(math.rad(-8), 0, 0), KICK.frame)
	piece("StemAccent", Vector3.new(0.34, 0.5, 0.34), CFrame.new(0, 2.1, -2.27) * CFrame.Angles(math.rad(-8), 0, 0), KICK.accent)
	for _, x in { -0.38, 0.38 } do
		piece("Fork", Vector3.new(0.14, 1.3, 0.14), CFrame.new(x, 1.05, -2.32), KICK.metal, nil, Enum.Material.Metal)
	end
	piece("Handlebar", Vector3.new(2.6, 0.22, 0.22), CFrame.new(0, 4.6, -2.6), KICK.frame)
	for _, x in { -1.2, 1.2 } do
		piece("HandGrip", Vector3.new(0.5, 0.3, 0.3), CFrame.new(x, 4.6, -2.6), KICK.grip, nil, Enum.Material.Fabric)
	end
	piece("Display", Vector3.new(0.55, 0.08, 0.4), CFrame.new(0, 4.76, -2.6), KICK.display, nil, Enum.Material.Neon).CastShadow = false
	piece("HeadLight", Vector3.new(0.5, 0.36, 0.14), CFrame.new(0, 3.7, -2.6), Color3.fromRGB(255, 250, 215), nil, Enum.Material.Neon).CastShadow = false
	for _, z in { -2.3, 2.3 } do
		piece("Tire", Vector3.new(0.6, 1.1, 1.1), CFrame.new(0, 0.55, z), KICK.tire, Enum.PartType.Cylinder)
		piece("Hub", Vector3.new(0.64, 0.55, 0.55), CFrame.new(0, 0.55, z), KICK.accent, Enum.PartType.Cylinder)
	end
	return model
end

-- Rower dostawcy kebabów: turkusowa rama, wiklinowy koszyk z przodu (KebabBasket), siodełko, kierownica z chwytami
-- i korba z pedałami. Chwyty i pedały mają Attachmenty (LeftGrip/RightGrip/LeftPedal/RightPedal), do których IKControl
-- przyciąga dłonie i stopy; korba wisi na Weldzie "CrankWeld", który klienci obracają w czasie jazdy (RidePoseController).
function ScooterBuilder.Bike(ground: CFrame, anchored: boolean): Model
	local model, base = newModel("KebabBike", ground, 2.2, 1.05, anchored)
	local function piece(...)
		return newPart(model, base, ground, ...)
	end
	local function tube(name: string, from: Vector3, to: Vector3, thickness: number?)
		return bar(model, base, ground, name, from, to, thickness or 0.22, BIKE.frame)
	end
	-- Koła: opona, jasna obręcz i piasta
	for _, z in { -1.8, 2.2 } do
		piece("Tire", Vector3.new(0.22, 2.1, 2.1), CFrame.new(0, 1.05, z), BIKE.tire, Enum.PartType.Cylinder)
		piece("Rim", Vector3.new(0.24, 1.7, 1.7), CFrame.new(0, 1.05, z), BIKE.rim, Enum.PartType.Cylinder, Enum.Material.Metal)
		piece("Hub", Vector3.new(0.34, 0.45, 0.45), CFrame.new(0, 1.05, z), BIKE.accent, Enum.PartType.Cylinder)
	end
	-- Rama (punkty: korba, siodełko, główka ramy, osie kół)
	local crank = Vector3.new(0, 0.95, 0.45)
	local seat = Vector3.new(0, 2.35, 1.05)
	local headTop = Vector3.new(0, 2.75, -1.25)
	local headBottom = Vector3.new(0, 2.05, -1.4)
	local rear = Vector3.new(0, 1.05, 2.2)
	local front = Vector3.new(0, 1.05, -1.8)
	tube("DownTube", crank, headBottom, 0.26)
	tube("SeatTube", crank, seat)
	tube("TopTube", seat, Vector3.new(0, 2.55, -1.3))
	tube("HeadTube", headBottom, headTop, 0.3)
	for _, x in { -0.17, 0.17 } do
		local side = Vector3.new(x, 0, 0)
		tube("ChainStay", crank + side, rear + side, 0.14)
		tube("SeatStay", seat + side, rear + side, 0.14)
		bar(model, base, ground, "Fork", headBottom + side, front + side, 0.14, BIKE.rim, Enum.Material.Metal)
	end
	piece("Fender", Vector3.new(0.4, 0.12, 1.6), CFrame.new(0, 2.25, 2.3) * CFrame.Angles(math.rad(12), 0, 0), BIKE.accent)
	bar(model, base, ground, "SeatPost", seat, Vector3.new(0, 2.5, 1.12), 0.16, BIKE.rim, Enum.Material.Metal)
	piece("Saddle", Vector3.new(0.7, 0.22, 1.3), CFrame.new(0, 2.62, 1.2), BIKE.saddle, nil, Enum.Material.Fabric)
	-- Kierownica z chwytami
	local barY, barZ = 3.45, -1.05
	bar(model, base, ground, "Stem", headTop, Vector3.new(0, barY, barZ), 0.18, BIKE.rim, Enum.Material.Metal)
	piece("Handlebar", Vector3.new(2.1, 0.16, 0.16), CFrame.new(0, barY, barZ), BIKE.rim, nil, Enum.Material.Metal)
	for _, x in { -0.9, 0.9 } do
		local grip = piece("HandGrip", Vector3.new(0.4, 0.24, 0.24), CFrame.new(x, barY, barZ), BIKE.saddle, nil, Enum.Material.Fabric)
		local attachment = Instance.new("Attachment")
		attachment.Name = if x < 0 then "LeftGrip" else "RightGrip"
		attachment.Parent = grip
		-- Bieguny IK: łokcie lekko na zewnątrz i w dół, kolana do przodu
		local elbow = Instance.new("Attachment")
		elbow.Name = if x < 0 then "LeftElbowPole" else "RightElbowPole"
		elbow.Position = Vector3.new(x * 1.2, -1, 1.4)
		elbow.Parent = grip
		local knee = Instance.new("Attachment")
		knee.Name = if x < 0 then "LeftKneePole" else "RightKneePole"
		knee.Position = Vector3.new(x * 0.3, -0.9, -0.6)
		knee.Parent = grip
	end
	piece("Bell", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0.55, barY + 0.15, barZ), Color3.fromRGB(255, 215, 60), Enum.PartType.Ball, Enum.Material.Metal)
	-- Koszyk na kebab nad przednim kołem i lampka
	local basket = piece("KebabBasket", Vector3.new(1.4, 0.8, 1.1), CFrame.new(0, 3, -2.05), BIKE.basket, nil, Enum.Material.WoodPlanks)
	basket.Name = "KebabBasket"
	for _, x in { -0.4, 0.4 } do
		bar(model, base, ground, "BasketStrut", Vector3.new(x, 2.6, -2.05), Vector3.new(x * 0.4, 1.4, -1.75), 0.08, BIKE.rim, Enum.Material.Metal)
	end
	piece("HeadLight", Vector3.new(0.45, 0.3, 0.12), CFrame.new(0, 2.85, -2.62), Color3.fromRGB(255, 250, 215), nil, Enum.Material.Neon).CastShadow = false
	piece("TailLight", Vector3.new(0.3, 0.2, 0.1), CFrame.new(0, 2.3, 3.05), Color3.fromRGB(255, 40, 40), nil, Enum.Material.Neon).CastShadow = false

	-- Korba z pedałami: koło zębate na Weldzie (obraca się u klientów), ramiona i pedały przyspawane do niego
	local crankCFrame = ground * CFrame.new(crank)
	local gear = Instance.new("Part")
	gear.Name = "Crank"
	gear.Shape = Enum.PartType.Cylinder
	gear.Size = Vector3.new(0.1, 0.75, 0.75)
	gear.Color = BIKE.rim
	gear.Material = Enum.Material.Metal
	gear.CanCollide = false
	gear.CanTouch = false
	gear.CanQuery = false
	gear.Massless = true
	gear.CFrame = crankCFrame * CFrame.new(0.22, 0, 0)
	gear.Parent = model
	local crankWeld = Instance.new("Weld")
	crankWeld.Name = "CrankWeld"
	crankWeld.Part0 = base
	crankWeld.Part1 = gear
	crankWeld.C0 = base.CFrame:ToObjectSpace(crankCFrame)
	crankWeld.C1 = CFrame.new(0.22, 0, 0):Inverse()
	crankWeld.Parent = gear
	for _, side in { -1, 1 } do
		local reach = Vector3.new(0, -side * 0.55, 0)
		local function onCrank(name: string, size: Vector3, offset: CFrame, color: Color3)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.Color = color
			p.Material = Enum.Material.Metal
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.CFrame = crankCFrame * offset
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = gear
			weld.Part1 = p
			weld.Parent = p
			p.Parent = model
			return p
		end
		onCrank("CrankArm", Vector3.new(0.12, 0.6, 0.14), CFrame.new(side * 0.3, reach.Y / 2, 0), BIKE.rim)
		local pedal = onCrank("Pedal", Vector3.new(0.45, 0.1, 0.3), CFrame.new(side * 0.5, reach.Y, 0), BIKE.saddle)
		local attachment = Instance.new("Attachment")
		attachment.Name = if side < 0 then "LeftPedal" else "RightPedal"
		attachment.Position = Vector3.new(0, 0.25, 0)
		attachment.Parent = pedal
	end
	if anchored then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
	end
	return model
end

-- Skuter dostawcy: czerwona karoseria z białymi akcentami, szyba, lusterka, siedzenie i żółty kufer z napisem PIZZA
function ScooterBuilder.Moped(ground: CFrame, anchored: boolean): Model
	local model, base = newModel("PizzaScooter", ground, 2.2, 0.75, anchored)
	local function piece(...)
		return newPart(model, base, ground, ...)
	end
	-- Koła z błotnikami
	for _, z in { -2.4, 2.2 } do
		piece("Tire", Vector3.new(0.7, 1.5, 1.5), CFrame.new(0, 0.75, z), MOPED.tire, Enum.PartType.Cylinder)
		piece("Hub", Vector3.new(0.74, 0.7, 0.7), CFrame.new(0, 0.75, z), MOPED.metal, Enum.PartType.Cylinder, Enum.Material.Metal)
	end
	piece("FrontFender", Vector3.new(0.9, 0.3, 1.6), CFrame.new(0, 1.6, -2.4), MOPED.body)
	-- Podest na stopy i tylna karoseria pod siedzeniem
	piece("Floorboard", Vector3.new(1.7, 0.35, 2.4), CFrame.new(0, 0.85, -0.4), MOPED.trim)
	piece("RearBody", Vector3.new(1.9, 1.5, 2.6), CFrame.new(0, 1.65, 1.6), MOPED.body)
	piece("RearBodyTop", Vector3.new(1.7, 0.4, 2.2), CFrame.new(0, 2.3, 1.5), MOPED.body)
	piece("SideStripe", Vector3.new(1.94, 0.18, 2.4), CFrame.new(0, 1.55, 1.6), MOPED.trim)
	piece("Seat", Vector3.new(1.4, 0.45, 2), CFrame.new(0, 2.62, 1.2), MOPED.seat, nil, Enum.Material.Fabric)
	-- Przednia osłona nóg, kolumna kierownicy, kierownica z lusterkami i lampą
	piece("LegShield", Vector3.new(1.8, 2.6, 0.4), CFrame.new(0, 2, -1.75) * CFrame.Angles(math.rad(-12), 0, 0), MOPED.body)
	piece("ShieldTrim", Vector3.new(1.84, 0.2, 0.44), CFrame.new(0, 3.25, -2.0) * CFrame.Angles(math.rad(-12), 0, 0), MOPED.trim)
	piece("Column", Vector3.new(0.6, 1.6, 0.6), CFrame.new(0, 3.9, -2.15) * CFrame.Angles(math.rad(-12), 0, 0), MOPED.body)
	piece("Handlebar", Vector3.new(2.6, 0.24, 0.24), CFrame.new(0, 4.65, -2.25), MOPED.metal, nil, Enum.Material.Metal)
	for _, x in { -1.2, 1.2 } do
		piece("HandGrip", Vector3.new(0.45, 0.3, 0.3), CFrame.new(x, 4.65, -2.25), MOPED.seat, nil, Enum.Material.Fabric)
		piece("MirrorStem", Vector3.new(0.08, 0.7, 0.08), CFrame.new(x * 0.8, 5.05, -2.25), MOPED.metal, nil, Enum.Material.Metal)
		piece("Mirror", Vector3.new(0.5, 0.35, 0.1), CFrame.new(x * 0.8, 5.45, -2.25), MOPED.metal, nil, Enum.Material.Metal)
	end
	piece("Windshield", Vector3.new(1.6, 1.1, 0.08), CFrame.new(0, 5.1, -2.45) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(190, 230, 255), nil, Enum.Material.Glass).Transparency = 0.5
	piece("HeadLight", Vector3.new(0.7, 0.5, 0.15), CFrame.new(0, 4.2, -2.5), Color3.fromRGB(255, 250, 215), nil, Enum.Material.Neon).CastShadow = false
	piece("TailLight", Vector3.new(0.9, 0.25, 0.12), CFrame.new(0, 2.2, 2.92), Color3.fromRGB(255, 40, 40), nil, Enum.Material.Neon).CastShadow = false
	-- Bagażnik i kufer na pizzę
	piece("Rack", Vector3.new(1.6, 0.15, 1.4), CFrame.new(0, 2.85, 2.55), MOPED.metal, nil, Enum.Material.Metal)
	local crate = piece("PizzaCrate", Vector3.new(1.9, 1.6, 1.7), CFrame.new(0, 2.85 + 0.8, 2.55), MOPED.crate)
	crate.Name = "PizzaCrate"
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = crate
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = MOPED.crateText
		label.Text = "🍕 PIZZA"
		label:SetAttribute("NoTranslate", true)
		label.Parent = gui
	end
	return model
end

-- Odległość od środka HumanoidRootPart do podłoża (promień, bo wzór z HipHeight nie pasuje do wszystkich awatarów)
local function groundOffset(character: Model, root: BasePart, humanoid: Humanoid): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, Workspace:FindFirstChild("Pets"), Workspace:FindFirstChild("JobObjects") }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	if hit then
		return root.Position.Y - hit.Position.Y
	end
	return if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3
end

-- Dłonie na chwytach kierownicy i stopy na pedałach roweru (IKControl liczy się u każdego klienta)
local function bikeIK(character: Model, humanoid: Humanoid, model: Model): { IKControl }
	local controls = {}
	local function chain(rootName: string, effectorName: string, targetName: string, poleName: string)
		local chainRoot = character:FindFirstChild(rootName)
		local effector = character:FindFirstChild(effectorName)
		local target = model:FindFirstChild(targetName, true)
		if not chainRoot or not effector or not target then
			return
		end
		local control = Instance.new("IKControl")
		control.Name = "Bike" .. effectorName
		control.Type = Enum.IKControlType.Position
		control.ChainRoot = chainRoot
		control.EndEffector = effector
		control.Target = target
		control.Pole = model:FindFirstChild(poleName, true)
		control.Parent = humanoid
		table.insert(controls, control)
	end
	chain("LeftUpperArm", "LeftHand", "LeftGrip", "LeftElbowPole")
	chain("RightUpperArm", "RightHand", "RightGrip", "RightElbowPole")
	chain("LeftUpperLeg", "LeftFoot", "LeftPedal", "LeftKneePole")
	chain("RightUpperLeg", "RightFoot", "RightPedal", "RightKneePole")
	return controls
end

-- kind = "kick" (stoi na desce), "moped" (siedzi) albo "bike" (siedzi, ręce na kierownicy, nogi na pedałach).
-- Zwraca dane jazdy albo nil.
function ScooterBuilder.Attach(character: Model, kind: string)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return nil
	end
	local offset = groundOffset(character, root, humanoid)
	local model
	if kind == "moped" then
		-- Siedzenie pod biodrami w pozie siedzącej (koła stoją na ziemi), skuter przesunięty do przodu
		model = ScooterBuilder.Moped(root.CFrame * CFrame.new(0, -offset, -0.9), false)
	elseif kind == "bike" then
		-- Siodełko w tym samym miejscu co siedzenie skutera
		model = ScooterBuilder.Bike(root.CFrame * CFrame.new(0, -offset, -0.9), false)
	else
		-- Podest tuż przy butach: ziemia modelu trochę niżej (koła lekko w podłożu)
		model = ScooterBuilder.Kick(root.CFrame * CFrame.new(0, -(offset + 0.55), 0.3), false)
	end
	local base = model.PrimaryPart
	local weld = Instance.new("Weld")
	weld.Name = "RideWeld"
	weld.Part0 = root
	weld.Part1 = base
	weld.C0 = root.CFrame:ToObjectSpace(base.CFrame)
	weld.Parent = base
	model.Parent = character
	character:SetAttribute("RidePose", if kind == "kick" then "stand" else "sit")
	return {
		model = model,
		weld = weld,
		baseC0 = weld.C0,
		character = character,
		ik = if kind == "bike" then bikeIK(character, humanoid, model) else nil,
	}
end

-- Wheelie: przód pojazdu w górę (obrót wokół osi tylnego koła)
function ScooterBuilder.SetWheelie(ride, on: boolean, angle: number)
	if not ride or not ride.weld.Parent then
		return
	end
	local info = TweenInfo.new(if on then 0.18 else 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tilt = if on then CFrame.Angles(angle, 0, 0) else CFrame.new()
	TweenService:Create(ride.weld, info, { C0 = ride.baseC0 * tilt }):Play()
end

function ScooterBuilder.Detach(ride)
	if not ride then
		return
	end
	if ride.model then
		ride.model:Destroy()
	end
	for _, control in ride.ik or {} do
		control:Destroy()
	end
	if ride.character then
		ride.character:SetAttribute("RidePose", nil)
	end
end

return ScooterBuilder

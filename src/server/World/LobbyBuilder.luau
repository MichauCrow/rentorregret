-- Hol: przytulny wieczorny dziedziniec przed fasadą kamienicy. Wycieraczka przed drzwiami = kolejka do rundy,
-- budka ze sklepikiem, tablica "Jak grać", Pan Klucznik w dobrym humorze (za dnia jest miły!).
local Workspace = game:GetService("Workspace")

local LandlordBuilder = require(script.Parent.LandlordBuilder)
local Parts = require(script.Parent.Parts)

local LobbyBuilder = {}

local COLORS = {
	ground = Color3.fromRGB(70, 110, 60),
	path = Color3.fromRGB(175, 160, 140),
	facade = Color3.fromRGB(150, 95, 80),
	trim = Color3.fromRGB(235, 220, 190),
	roof = Color3.fromRGB(70, 50, 60),
	windowLit = Color3.fromRGB(255, 200, 110),
	windowDark = Color3.fromRGB(35, 45, 80),
	door = Color3.fromRGB(85, 55, 35),
	rug = Color3.fromRGB(120, 200, 120),
	kiosk = Color3.fromRGB(80, 160, 220),
	awning = { Color3.fromRGB(255, 90, 100), Color3.fromRGB(255, 245, 235) },
	wood = Color3.fromRGB(125, 85, 55),
	metal = Color3.fromRGB(40, 40, 50),
	leaves = Color3.fromRGB(70, 140, 70),
	trunk = Color3.fromRGB(100, 70, 45),
}

local function tree(parent: Instance, position: Vector3, scale: number)
	Parts.Block(parent, "Trunk", Vector3.new(1.2, 7, 1.2) * scale, CFrame.new(position + Vector3.new(0, 3.5 * scale, 0)), COLORS.trunk, Enum.Material.Wood)
	Parts.Deco(parent, "Leaves", Vector3.new(7, 7, 7) * scale, CFrame.new(position + Vector3.new(0, 8.5 * scale, 0)), COLORS.leaves, Enum.Material.Grass, Enum.PartType.Ball)
end

local function lampPost(parent: Instance, position: Vector3)
	Parts.Block(parent, "LampPost", Vector3.new(0.6, 10, 0.6), CFrame.new(position + Vector3.new(0, 5, 0)), COLORS.metal, Enum.Material.Metal)
	Parts.Lamp(parent, position + Vector3.new(0, 10.3, 0), 1.5, 32, Color3.fromRGB(255, 205, 140))
end

local function bench(parent: Instance, cframe: CFrame)
	Parts.Block(parent, "BenchSeat", Vector3.new(6, 0.4, 1.8), cframe * CFrame.new(0, 1.6, 0), COLORS.wood, Enum.Material.Wood)
	Parts.Block(parent, "BenchBack", Vector3.new(6, 1.6, 0.3), cframe * CFrame.new(0, 2.6, 0.8), COLORS.wood, Enum.Material.Wood)
	for _, x in { -2.6, 2.6 } do
		Parts.Deco(parent, "BenchLeg", Vector3.new(0.3, 1.6, 1.6), cframe * CFrame.new(x, 0.8, 0), COLORS.metal, Enum.Material.Metal)
	end
end

-- Fasada kamienicy (tylko dekoracja, do środka wchodzi się przez wycieraczkę)
local function facade(parent: Instance)
	local z = 46
	Parts.Box(parent, "Facade", Vector3.new(-34, 0, z), Vector3.new(34, 38, z + 4), COLORS.facade, Enum.Material.Brick)
	Parts.Box(parent, "Cornice", Vector3.new(-35, 38, z - 1), Vector3.new(35, 39.5, z + 5), COLORS.trim)
	Parts.Box(parent, "Roof", Vector3.new(-34, 39.5, z), Vector3.new(34, 44, z + 4), COLORS.roof, Enum.Material.Slate)
	local sign = Parts.Block(parent, "TitleSign", Vector3.new(30, 6, 0.6), CFrame.new(0, 33, z - 0.4), Color3.fromRGB(40, 25, 50))
	Parts.Sign(sign, Enum.NormalId.Front, "RENT OR REGRET: PÓŁNOC", Color3.fromRGB(255, 210, 90))
	-- Okna: część zapalona, część ciemna (a w jednym ktoś wygląda... to Mruczek!)
	local rng = Random.new(7)
	for floor = 0, 2 do
		for i = -3, 3 do
			if not (floor == 0 and math.abs(i) <= 1) then
				local center = Vector3.new(i * 9, 8 + floor * 9, z - 0.15)
				local lit = rng:NextNumber() < 0.45
				Parts.Deco(parent, "WindowFrame", Vector3.new(5, 6, 0.3), CFrame.new(center), COLORS.trim)
				local glass = Parts.Deco(parent, "Window", Vector3.new(4, 5, 0.35), CFrame.new(center - Vector3.new(0, 0, 0.05)), if lit then COLORS.windowLit else COLORS.windowDark, if lit then Enum.Material.Neon else Enum.Material.Glass)
				if floor == 2 and i == 2 then
					glass.Color = COLORS.windowDark
					glass.Material = Enum.Material.Glass
					for _, dx in { -0.7, 0.7 } do
						Parts.Deco(parent, "CatEye", Vector3.new(0.6, 0.6, 0.2), CFrame.new(center + Vector3.new(dx, 0.4, -0.3)), Color3.fromRGB(255, 240, 80), Enum.Material.Neon, Enum.PartType.Ball)
					end
				end
			end
		end
	end
	-- Wielkie drzwi i schodki
	Parts.Block(parent, "BigDoor", Vector3.new(8, 12, 0.6), CFrame.new(0, 6, z - 0.3), COLORS.door, Enum.Material.Wood)
	Parts.Deco(parent, "DoorKnob", Vector3.new(0.6, 0.6, 0.4), CFrame.new(2.8, 6, z - 0.8), Color3.fromRGB(255, 200, 60), Enum.Material.Metal, Enum.PartType.Ball)
	Parts.Block(parent, "Step", Vector3.new(14, 0.6, 4), CFrame.new(0, 0.3, z - 2), COLORS.trim, Enum.Material.Concrete)
	Parts.Lamp(parent, Vector3.new(-5.5, 10, z - 0.8), 1.4, 24)
	Parts.Lamp(parent, Vector3.new(5.5, 10, z - 0.8), 1.4, 24)
end

local function kiosk(parent: Instance, position: Vector3): BasePart
	local base = CFrame.lookAt(position, position + Vector3.new(1, 0, 0))
	Parts.Block(parent, "KioskBack", Vector3.new(8, 8, 0.6), base * CFrame.new(0, 4, 3), COLORS.kiosk)
	Parts.Block(parent, "KioskSide", Vector3.new(0.6, 8, 6), base * CFrame.new(-3.7, 4, 0), COLORS.kiosk)
	Parts.Block(parent, "KioskSide", Vector3.new(0.6, 8, 6), base * CFrame.new(3.7, 4, 0), COLORS.kiosk)
	local counter = Parts.Block(parent, "Counter", Vector3.new(8, 3.2, 1.6), base * CFrame.new(0, 1.6, -2.2), COLORS.wood, Enum.Material.Wood)
	for i = 0, 5 do
		Parts.Deco(parent, "Awning", Vector3.new(1.4, 0.3, 4), base * CFrame.new(-3.5 + i * 1.4, 8.5, -2.5) * CFrame.Angles(math.rad(-15), 0, 0), COLORS.awning[i % 2 + 1], Enum.Material.Fabric)
	end
	-- Towar na ladzie: latarki i buty
	Parts.Deco(parent, "Flashlight", Vector3.new(1.6, 0.6, 0.6), base * CFrame.new(-2, 3.5, -2.2), Color3.fromRGB(255, 220, 60), Enum.Material.Metal, Enum.PartType.Cylinder)
	Parts.Deco(parent, "Shoe", Vector3.new(1.4, 0.7, 0.7), base * CFrame.new(1.5, 3.55, -2.2), Color3.fromRGB(240, 240, 255))
	local sign = Parts.Deco(parent, "KioskSign", Vector3.new(8, 2, 0.3), base * CFrame.new(0, 9.8, -0.4), Color3.fromRGB(40, 30, 60))
	Parts.Sign(sign, Enum.NormalId.Front, "🛒 SKLEPIK", Color3.fromRGB(255, 220, 90))
	Parts.Lamp(parent, (base * CFrame.new(0, 7.5, -1)).Position, 1.2, 16)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Otwórz sklepik"
	prompt.ObjectText = "🛒 Sklepik"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Action", "Shop")
	prompt.Parent = counter
	return counter
end

local function howToBoard(parent: Instance, cframe: CFrame)
	Parts.Block(parent, "BoardPost", Vector3.new(0.5, 6, 0.5), cframe * CFrame.new(-4.5, 3, 0), COLORS.wood, Enum.Material.Wood)
	Parts.Block(parent, "BoardPost", Vector3.new(0.5, 6, 0.5), cframe * CFrame.new(4.5, 3, 0), COLORS.wood, Enum.Material.Wood)
	local board = Parts.Block(parent, "HowTo", Vector3.new(10, 6.5, 0.4), cframe * CFrame.new(0, 7, 0), Color3.fromRGB(45, 70, 50))
	Parts.Sign(
		board,
		Enum.NormalId.Front,
		"JAK GRAĆ\n🔍 Przeszukuj meble i zbieraj monety\n💰 Zanieś je do skrzynki Klucznika\n🕛 Zapłać czynsz przed północą!\n🤫 Sąsiad słyszy bieganie\n🔦 Mruczek idzie za światłem\n🚪 Chowaj się w szafach",
		Color3.fromRGB(255, 250, 230)
	)
end

function LobbyBuilder.Build()
	local existing = Workspace:FindFirstChild("Lobby")
	if existing then
		existing:Destroy()
	end
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"

	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = COLORS.ground
		baseplate.Material = Enum.Material.Grass
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child:Destroy()
			end
		end
	end

	-- Dziedziniec
	Parts.Box(lobby, "Path", Vector3.new(-6, -0.5, -40), Vector3.new(6, 0.1, 44), COLORS.path, Enum.Material.Cobblestone)
	Parts.Box(lobby, "Square", Vector3.new(-30, -0.5, 10), Vector3.new(30, 0.1, 44), COLORS.path, Enum.Material.Cobblestone)
	facade(lobby)
	for _, x in { -18, 18 } do
		lampPost(lobby, Vector3.new(x, 0, 14))
		lampPost(lobby, Vector3.new(x, 0, -14))
	end
	for _, spot in { { -40, 30, 1.2 }, { 40, 30, 1.1 }, { -42, -10, 1.3 }, { 42, -12, 1 }, { -28, -36, 1.1 }, { 30, -34, 1.2 } } do
		tree(lobby, Vector3.new(spot[1], 0, spot[2]), spot[3])
	end
	bench(lobby, CFrame.lookAt(Vector3.new(16, 0, 0), Vector3.new(0, 0, 0)))
	bench(lobby, CFrame.lookAt(Vector3.new(-16, 0, -4), Vector3.new(0, 0, -4)))
	howToBoard(lobby, CFrame.lookAt(Vector3.new(12, 0, 24), Vector3.new(0, 0, 12)))
	kiosk(lobby, Vector3.new(-24, 0, 24))

	-- Pan Klucznik przy drzwiach (w holu jest miły)
	LandlordBuilder.Build(CFrame.lookAt(Vector3.new(-8, 0.1, 40), Vector3.new(-8, 0.1, 30)), "🙂", lobby)

	-- Wycieraczka przed drzwiami: kolejka do rundy
	local pad = Parts.Block(lobby, "QueuePad", Vector3.new(12, 0.4, 8), CFrame.new(0, 0.3, 36), COLORS.rug, Enum.Material.Fabric)
	pad.CanCollide = true
	local glow = Instance.new("PointLight")
	glow.Color = COLORS.rug
	glow.Brightness = 1
	glow.Range = 12
	glow.Parent = pad
	local label = Parts.Billboard(pad, "Stań na wycieraczce, żeby wejść!", Color3.fromRGB(150, 255, 160), 6, Vector2.new(360, 80))
	label.Parent.MaxDistance = 140

	-- Tablica "Dzisiejsza noc" (modyfikator dnia) obok wycieraczki
	local nightBoard = Parts.Block(lobby, "NightBoard", Vector3.new(9, 4.5, 0.4), CFrame.lookAt(Vector3.new(13, 6, 36), Vector3.new(13, 6, 20)), Color3.fromRGB(40, 30, 70))
	Parts.Block(lobby, "NightPost", Vector3.new(0.5, 4, 0.5), CFrame.new(13, 2, 36), COLORS.wood, Enum.Material.Wood)
	local nightLabel = Parts.Sign(nightBoard, Enum.NormalId.Front, "🌙", Color3.fromRGB(255, 230, 150))

	-- Punkt startowy graczy
	local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawn.CFrame = CFrame.new(0, 0.6, -24)
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.Transparency = 1
		spawn.CanCollide = false
		for _, child in spawn:GetChildren() do
			if child:IsA("Decal") then
				child:Destroy()
			end
		end
	end

	lobby.Parent = Workspace
	return {
		folder = lobby,
		pad = pad,
		padLabel = label,
		nightLabel = nightLabel,
		spawnCFrame = CFrame.lookAt(Vector3.new(0, 3, -20), Vector3.new(0, 3, 30)),
	}
end

return LobbyBuilder

-- Hol: wieczorny dziedziniec przed kamienicą na cichej uliczce. Wycieraczka przed drzwiami = kolejka do rundy,
-- budka ze sklepikiem, tablica "Jak grać", tablica "Dzisiejsza noc", pomnik złotego klucza i Pan Klucznik
-- w dobrym humorze (za dnia jest miły!). Dookoła kuty płot, ulica i sąsiednie domy.
local Workspace = game:GetService("Workspace")

local LandlordBuilder = require(script.Parent.LandlordBuilder)
local Parts = require(script.Parent.Parts)
local Scenery = require(script.Parent.Scenery)

local LobbyBuilder = {}

local M = Enum.Material
local COLORS = {
	ground = Color3.fromRGB(62, 96, 58),
	path = Color3.fromRGB(150, 138, 124),
	square = Color3.fromRGB(132, 122, 112),
	facade = Color3.fromRGB(140, 88, 74),
	trim = Color3.fromRGB(226, 214, 190),
	door = Color3.fromRGB(85, 55, 35),
	rug = Color3.fromRGB(120, 200, 120),
	kiosk = Color3.fromRGB(80, 160, 220),
	awning = { Color3.fromRGB(255, 90, 100), Color3.fromRGB(255, 245, 235) },
	wood = Color3.fromRGB(125, 85, 55),
	stone = Color3.fromRGB(118, 110, 106),
	gold = Color3.fromRGB(255, 200, 60),
}

-- Fasada kamienicy (tylko dekoracja, do środka wchodzi się przez wycieraczkę)
local function facade(parent: Instance, rng: Random)
	local z = 46
	Parts.Box(parent, "Facade", Vector3.new(-34, 0, z), Vector3.new(34, 38, z + 6), COLORS.facade, M.Brick)
	Scenery.Facade(parent, CFrame.lookAt(Vector3.new(0, 0, z), Vector3.new(0, 0, 0)), {
		rng = rng,
		width = 68,
		height = 38,
		rows = { 8, 17, 26 },
		columns = { -27, -18, -9, 0, 9, 18, 27 },
		skipGround = { -9, 0, 9 },
		windowSize = Vector2.new(4, 5),
		wall = COLORS.facade,
		door = { width = 8, height = 12 },
		balconyY = 13.5,
		cat = { row = 3, column = 18 },
		litChance = 0.45,
		roof = { rise = 7, run = 6, depth = 5 },
		dormers = { -24, -12, 0, 12, 24 },
		chimneys = { -22, 20 },
		ivy = -30,
	})
	local sign = Parts.Block(parent, "TitleSign", Vector3.new(30, 5, 0.6), CFrame.new(0, 33, z - 0.5), Color3.fromRGB(40, 25, 50))
	Parts.Deco(parent, "TitleSignFrame", Vector3.new(31, 6, 0.4), CFrame.new(0, 33, z - 0.3), COLORS.gold, M.Metal)
	Parts.Sign(sign, Enum.NormalId.Front, "RENT OR REGRET: PÓŁNOC", Color3.fromRGB(255, 210, 90))
	-- Wielkie drzwi i schodki
	Parts.Block(parent, "BigDoor", Vector3.new(8, 12, 0.6), CFrame.new(0, 6, z - 0.3), COLORS.door, M.Wood)
	for _, x in { -2, 2 } do
		for _, y in { 3.2, 8.8 } do
			Parts.Deco(parent, "DoorPanel", Vector3.new(3, 4.6, 0.12), CFrame.new(x, y, z - 0.64), COLORS.wood, M.Wood)
		end
	end
	Parts.Deco(parent, "DoorKnob", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0.9, 6, z - 0.9), COLORS.gold, M.Metal, Enum.PartType.Ball)
	Parts.Block(parent, "Step", Vector3.new(14, 0.6, 4), CFrame.new(0, 0.3, z - 2), COLORS.trim, M.Concrete)
	for _, x in { -27, -18, 18, 27 } do
		Scenery.Bush(parent, Vector3.new(x, 0, z - 2.2), Vector3.new(5, 2.8, 3))
	end
end

-- Pomnik złotego klucza na cokole, z rabatką dookoła
local function keyStatue(parent: Instance, position: Vector3, rng: Random)
	local base = CFrame.new(position)
	local pedestal = Parts.Block(parent, "Pedestal", Vector3.new(1.4, 5, 5), base * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), COLORS.stone, M.Slate)
	pedestal.Shape = Enum.PartType.Cylinder
	Parts.Block(parent, "PedestalTop", Vector3.new(2.6, 2.2, 2.6), base * CFrame.new(0, 2.5, 0), COLORS.stone, M.Slate)
	Parts.Deco(parent, "StatuePlate", Vector3.new(1.8, 0.9, 0.1), base * CFrame.new(0, 2.6, -1.32), COLORS.gold, M.Metal)
	-- Klucz stoi pionowo: kółko u góry, zęby na dole
	Parts.Deco(parent, "StatueKeyShaft", Vector3.new(5, 0.5, 0.5), base * CFrame.new(0, 6.1, 0) * CFrame.Angles(0, 0, math.rad(90)), COLORS.gold, M.Metal, Enum.PartType.Cylinder)
	Parts.Deco(parent, "StatueKeyBow", Vector3.new(0.4, 2.6, 2.6), base * CFrame.new(0, 9.6, 0) * CFrame.Angles(0, math.rad(90), 0), COLORS.gold, M.Metal, Enum.PartType.Cylinder)
	Parts.Deco(parent, "StatueKeyHole", Vector3.new(0.46, 1.3, 1.3), base * CFrame.new(0, 9.6, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(60, 40, 70), M.SmoothPlastic, Enum.PartType.Cylinder)
	Parts.Deco(parent, "StatueKeyBit", Vector3.new(1.3, 0.9, 0.36), base * CFrame.new(0.8, 4.3, 0), COLORS.gold, M.Metal)
	Parts.Deco(parent, "StatueKeyBit", Vector3.new(0.9, 0.7, 0.36), base * CFrame.new(0.6, 5.4, 0), COLORS.gold, M.Metal)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 210, 110)
	glow.Brightness = 1.2
	glow.Range = 14
	glow.Parent = pedestal
	for i = 1, 10 do
		local angle = i / 10 * math.pi * 2
		local spot = position + Vector3.new(math.cos(angle) * 3.6, 0.35, math.sin(angle) * 3.6)
		Parts.Blob(parent, "StatueFlowers", Vector3.new(1.5, 1, 1.5), CFrame.new(spot), Scenery.COLORS.flowers[rng:NextInteger(1, #Scenery.COLORS.flowers)], M.Grass)
	end
end

local function kiosk(parent: Instance, position: Vector3): BasePart
	local base = CFrame.lookAt(position, position + Vector3.new(1, 0, 0))
	Parts.Block(parent, "KioskBack", Vector3.new(8, 8, 0.6), base * CFrame.new(0, 4, 3), COLORS.kiosk)
	Parts.Block(parent, "KioskSide", Vector3.new(0.6, 8, 6), base * CFrame.new(-3.7, 4, 0), COLORS.kiosk)
	Parts.Block(parent, "KioskSide", Vector3.new(0.6, 8, 6), base * CFrame.new(3.7, 4, 0), COLORS.kiosk)
	local counter = Parts.Block(parent, "Counter", Vector3.new(8, 3.2, 1.6), base * CFrame.new(0, 1.6, -2.2), COLORS.wood, M.Wood)
	for i = 0, 5 do
		Parts.Deco(parent, "Awning", Vector3.new(1.4, 0.3, 4), base * CFrame.new(-3.5 + i * 1.4, 8.5, -2.5) * CFrame.Angles(math.rad(-15), 0, 0), COLORS.awning[i % 2 + 1], M.Fabric)
	end
	-- Towar na ladzie: latarki i buty
	Parts.Deco(parent, "Flashlight", Vector3.new(1.6, 0.6, 0.6), base * CFrame.new(-2, 3.5, -2.2), Color3.fromRGB(255, 220, 60), M.Metal, Enum.PartType.Cylinder)
	Parts.Deco(parent, "Shoe", Vector3.new(1.4, 0.7, 0.7), base * CFrame.new(1.5, 3.55, -2.2), Color3.fromRGB(240, 240, 255))
	-- Półka z towarem na tylnej ścianie: plecak, butelka, latarki
	Parts.Deco(parent, "KioskShelf", Vector3.new(6.6, 0.25, 1.2), base * CFrame.new(0, 5.2, 2.1), COLORS.wood, M.Wood)
	Parts.Deco(parent, "Backpack", Vector3.new(1.4, 1.6, 0.8), base * CFrame.new(-2.2, 6.1, 2.1), Color3.fromRGB(210, 70, 70), M.Fabric)
	Parts.Deco(parent, "Bottle", Vector3.new(1.3, 0.6, 0.6), base * CFrame.new(-0.4, 5.98, 2.1) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(90, 170, 240), M.Glass, Enum.PartType.Cylinder)
	for i = 0, 1 do
		Parts.Deco(parent, "Flashlight", Vector3.new(1.2, 0.5, 0.5), base * CFrame.new(1.2 + i * 1.1, 5.93, 2.1) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 220, 60), M.Metal, Enum.PartType.Cylinder)
	end
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
	Parts.Block(parent, "BoardPost", Vector3.new(0.5, 6, 0.5), cframe * CFrame.new(-4.5, 3, 0), COLORS.wood, M.Wood)
	Parts.Block(parent, "BoardPost", Vector3.new(0.5, 6, 0.5), cframe * CFrame.new(4.5, 3, 0), COLORS.wood, M.Wood)
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
	local rng = Random.new(7)

	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = COLORS.ground
		baseplate.Material = M.Grass
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child:Destroy()
			end
		end
	end

	-- Dziedziniec: ścieżka od bramy do drzwi i plac przed kamienicą
	Parts.Box(lobby, "Path", Vector3.new(-6, -0.5, -46), Vector3.new(6, 0.1, 44), COLORS.path, M.Cobblestone)
	Parts.Box(lobby, "Square", Vector3.new(-32, -0.5, 8), Vector3.new(32, 0.08, 44), COLORS.square, M.Cobblestone)
	for _, x in { -6.4, 6.4 } do
		Parts.Deco(lobby, "PathEdge", Vector3.new(0.8, 0.3, 54), CFrame.new(x, 0.2, -19), COLORS.stone, M.Slate)
	end
	facade(lobby, rng)

	-- Latarnie, drzewa, ławki, krzaki wzdłuż ścieżki
	for _, z in { 16, -6, -38 } do
		Scenery.StreetLamp(lobby, Vector3.new(-13, 0, z), Vector3.new(1, 0, 0), 1.5)
		Scenery.StreetLamp(lobby, Vector3.new(13, 0, z), Vector3.new(-1, 0, 0), 1.5)
	end
	for _, spot in { { -40, 30, 1.2 }, { 40, 30, 1.1 }, { -40, -10, 1.3 }, { 40, -12, 1 }, { -28, -36, 1.1 }, { 30, -34, 1.2 } } do
		Scenery.Tree(lobby, Vector3.new(spot[1], 0, spot[2]), spot[3], rng)
	end
	for _, z in { -32, -24, -6, 2 } do
		Scenery.Bush(lobby, Vector3.new(-9.5, 0, z), Vector3.new(3, 2, 3))
		Scenery.Bush(lobby, Vector3.new(9.5, 0, z), Vector3.new(3, 2, 3))
	end
	Scenery.Bench(lobby, CFrame.lookAt(Vector3.new(17, 0, -2), Vector3.new(0, 0, -2)))
	Scenery.Bench(lobby, CFrame.lookAt(Vector3.new(-17, 0, -8), Vector3.new(0, 0, -8)))
	Scenery.Puddle(lobby, Vector3.new(3, 0.08, -10), 4)
	Scenery.Puddle(lobby, Vector3.new(-14, 0.06, 18), 3)
	keyStatue(lobby, Vector3.new(-18, 0, 5), rng)
	howToBoard(lobby, CFrame.lookAt(Vector3.new(23, 0, 20), Vector3.new(0, 0, -12)))
	kiosk(lobby, Vector3.new(-24, 0, 24))

	-- Kuty płot dookoła i brama z ceglanymi słupkami
	local edge, front = 47, -46
	Scenery.IronFence(lobby, Vector3.new(-edge, 0, front), Vector3.new(-8, 0, front))
	Scenery.IronFence(lobby, Vector3.new(8, 0, front), Vector3.new(edge, 0, front))
	Scenery.IronFence(lobby, Vector3.new(-edge, 0, front), Vector3.new(-edge, 0, 46))
	Scenery.IronFence(lobby, Vector3.new(edge, 0, front), Vector3.new(edge, 0, 46))
	for _, x in { -8, 8 } do
		Parts.Block(lobby, "GatePillar", Vector3.new(1.8, 7, 1.8), CFrame.new(x, 3.5, front), COLORS.facade, M.Brick)
		Parts.Deco(lobby, "GatePillarCap", Vector3.new(2.3, 0.5, 2.3), CFrame.new(x, 7.2, front), COLORS.trim, M.Concrete)
		Scenery.Lantern(lobby, Vector3.new(x, 8.2, front), 1.3, 22)
	end
	Scenery.Crow(lobby, CFrame.lookAt(Vector3.new(-26, 4.7, front), Vector3.new(-26, 4.7, 0)))
	Scenery.Crow(lobby, CFrame.lookAt(Vector3.new(22, 2.9, -2.8), Vector3.new(0, 2.9, 10)))

	-- Ulica przed bramą, domy po drugiej stronie i sąsiednie kamienice
	Scenery.Street(lobby, CFrame.new(0, 0, -60) * CFrame.Angles(0, math.rad(90), 0), 240, 16)
	for _, x in { -84, 84, -40, 40 } do
		Scenery.StreetLamp(lobby, Vector3.new(x, 0, -50.5), Vector3.new(0, 0, -1), 1.2)
	end
	for i, x in { -92, -62, -32, -2, 28, 58, 88 } do
		Scenery.House(lobby, CFrame.lookAt(Vector3.new(x, 0, -74), Vector3.new(x, 0, 0)), 27, 22 + rng:NextInteger(0, 14) + (i % 2) * 4, 16, rng)
	end
	Scenery.House(lobby, CFrame.lookAt(Vector3.new(-57.5, 0, 47), Vector3.new(-57.5, 0, 0)), 38, 31, 18, rng)
	Scenery.House(lobby, CFrame.lookAt(Vector3.new(57.5, 0, 47), Vector3.new(57.5, 0, 0)), 38, 35, 18, rng)
	for _, spot in { { -62, 14, 1.2 }, { 60, 18, 1.1 }, { -58, -24, 1 }, { 64, -20, 1.3 } } do
		Scenery.Tree(lobby, Vector3.new(spot[1], 0, spot[2]), spot[3], rng)
	end

	-- Pan Klucznik przy drzwiach (w holu jest miły)
	LandlordBuilder.Build(CFrame.lookAt(Vector3.new(-8, 0.1, 40), Vector3.new(-8, 0.1, 30)), "🙂", lobby)

	-- Wycieraczka przed drzwiami: kolejka do rundy
	local pad = Parts.Block(lobby, "QueuePad", Vector3.new(12, 0.4, 8), CFrame.new(0, 0.3, 36), COLORS.rug, M.Fabric)
	pad.CanCollide = true
	local glow = Instance.new("PointLight")
	glow.Color = COLORS.rug
	glow.Brightness = 1
	glow.Range = 12
	glow.Parent = pad
	local label = Parts.Billboard(pad, "Stań na wycieraczce, żeby wejść!", Color3.fromRGB(150, 255, 160), 6, Vector2.new(360, 80))
	label.Parent.MaxDistance = 140

	-- Tablica "Dzisiejsza noc" (modyfikator dnia) na ścianie obok drzwi
	local nightBoard = Parts.Block(lobby, "NightBoard", Vector3.new(9, 4.6, 0.4), CFrame.lookAt(Vector3.new(11.6, 6.2, 45.75), Vector3.new(11.6, 6.2, 30)), Color3.fromRGB(40, 30, 70))
	Parts.Deco(lobby, "NightBoardFrame", Vector3.new(9.6, 5.2, 0.3), CFrame.new(11.6, 6.2, 45.82), COLORS.trim)
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

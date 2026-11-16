-- Kamienica na jedną rozgrywkę: parter (biuro Klucznika) + 2 piętra z mieszkaniami, klatka schodowa,
-- meble do przeszukania, szafy do chowania się, jedno zamknięte mieszkanie, podwórko z bramą wyjściową.
-- Wszystko z prostych klocków, budowane od zera dla każdej rundy (losowe ustawienie mebli).
--
-- Układ (współrzędne lokalne, origin = róg kamienicy na poziomie podłogi parteru):
--   X 0..52 mieszkania i korytarz, X 52..64 klatka schodowa, Z 16..24 korytarz, Y piętra co 14.
--   Pokoje: X 0..26 / 26..52, Z 0..16 (południe) / 24..40 (północ). Drzwi frontowe w ścianie X = 0,
--   podwórko X -32..0, brama wyjściowa w płocie X = -32.
-- Folder Geometry: wszystko z kolizją (ściany, podłogi, meble); po nim liczona jest widoczność potworów.
-- Folder Decor: ozdoby bez kolizji (nie przeszkadzają w chodzeniu ani w wyszukiwaniu ścieżek).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local LandlordBuilder = require(script.Parent.LandlordBuilder)
local Parts = require(script.Parent.Parts)

local BuildingBuilder = {}

local W, D = 64, 40
local FLOOR_HEIGHT = 14
local WALL_HEIGHT = FLOOR_HEIGHT - 1
local FLOORS = 3
local CORRIDOR_MIN, CORRIDOR_MAX = 16, 24
local STAIR_X = 52
local DOOR_WIDTH, DOOR_HEIGHT = 5, 10 -- potwory mają najwyżej 9.6 (MonsterModels)
local YARD_X = -32 -- płot z bramą

BuildingBuilder.FLOOR_HEIGHT = FLOOR_HEIGHT
BuildingBuilder.FLOORS = FLOORS

local M = Enum.Material
local COLORS = {
	slab = Color3.fromRGB(96, 74, 60),
	ceiling = Color3.fromRGB(205, 196, 180),
	corridorFloor = Color3.fromRGB(120, 60, 55),
	wallFloor = {
		[0] = Color3.fromRGB(190, 170, 130), -- parter: ciepły beż
		[1] = Color3.fromRGB(124, 146, 124), -- 1. piętro: zgniła zieleń
		[2] = Color3.fromRGB(116, 116, 152), -- 2. piętro: chłodny fiolet
	},
	wainscot = Color3.fromRGB(92, 62, 44),
	trim = Color3.fromRGB(226, 214, 190),
	outer = Color3.fromRGB(122, 78, 66),
	stairs = Color3.fromRGB(84, 62, 48),
	tread = Color3.fromRGB(156, 120, 88),
	wood = Color3.fromRGB(120, 80, 50),
	darkWood = Color3.fromRGB(80, 52, 35),
	fabric = { Color3.fromRGB(150, 60, 70), Color3.fromRGB(60, 90, 150), Color3.fromRGB(90, 130, 80), Color3.fromRGB(170, 120, 60) },
	rug = { Color3.fromRGB(140, 70, 70), Color3.fromRGB(70, 100, 130), Color3.fromRGB(150, 120, 70), Color3.fromRGB(100, 80, 130) },
	picture = { Color3.fromRGB(200, 170, 120), Color3.fromRGB(130, 170, 190), Color3.fromRGB(190, 140, 150), Color3.fromRGB(150, 180, 140) },
	metal = Color3.fromRGB(190, 195, 200),
	window = Color3.fromRGB(30, 45, 90),
	windowLit = Color3.fromRGB(255, 205, 120),
	yard = Color3.fromRGB(86, 84, 82),
	path = Color3.fromRGB(128, 120, 110),
	fence = Color3.fromRGB(60, 50, 45),
	bush = Color3.fromRGB(52, 92, 58),
	gold = Color3.fromRGB(255, 200, 60),
	jar = Color3.fromRGB(180, 230, 255),
	black = Color3.fromRGB(34, 30, 34),
}

-- Ściany ------------------------------------------------------------------------------------------
-- Ściana wzdłuż osi X (stałe z) albo osi Z (stałe x), z otworami { from, to, height }; half = połowa grubości

local function wallAlongX(folder: Instance, origin: Vector3, x0: number, x1: number, z: number, y0: number, color: Color3, openings, material: Enum.Material?)
	local cursor = x0
	table.sort(openings, function(a, b)
		return a.from < b.from
	end)
	for _, opening in openings do
		if opening.from > cursor then
			Parts.Box(folder, "Wall", origin + Vector3.new(cursor, y0, z - 0.5), origin + Vector3.new(opening.from, y0 + WALL_HEIGHT, z + 0.5), color, material)
		end
		Parts.Box(folder, "Lintel", origin + Vector3.new(opening.from, y0 + opening.height, z - 0.5), origin + Vector3.new(opening.to, y0 + WALL_HEIGHT, z + 0.5), color, material)
		cursor = opening.to
	end
	if cursor < x1 then
		Parts.Box(folder, "Wall", origin + Vector3.new(cursor, y0, z - 0.5), origin + Vector3.new(x1, y0 + WALL_HEIGHT, z + 0.5), color, material)
	end
end

local function wallAlongZ(folder: Instance, origin: Vector3, z0: number, z1: number, x: number, y0: number, color: Color3, openings, material: Enum.Material?, half: number?)
	local h = half or 0.5
	local cursor = z0
	table.sort(openings, function(a, b)
		return a.from < b.from
	end)
	for _, opening in openings do
		if opening.from > cursor then
			Parts.Box(folder, "Wall", origin + Vector3.new(x - h, y0, cursor), origin + Vector3.new(x + h, y0 + WALL_HEIGHT, opening.from), color, material)
		end
		Parts.Box(folder, "Lintel", origin + Vector3.new(x - h, y0 + opening.height, opening.from), origin + Vector3.new(x + h, y0 + WALL_HEIGHT, opening.to), color, material)
		cursor = opening.to
	end
	if cursor < z1 then
		Parts.Box(folder, "Wall", origin + Vector3.new(x - h, y0, cursor), origin + Vector3.new(x + h, y0 + WALL_HEIGHT, z1), color, material)
	end
end

-- Pokoje ------------------------------------------------------------------------------------------
-- Pokój: x0 (lewy brzeg), south (czy po stronie Z 0..16), floor. Punkty w pokoju podajemy jako (u, v):
-- u = 0..26 wzdłuż X, v = 0 przy ścianie korytarza, 16 przy ścianie zewnętrznej. Drzwi są zawsze przy u = 13.

local function roomPoint(building, room, u: number, v: number, h: number): Vector3
	local z = if room.south then CORRIDOR_MIN - v else CORRIDOR_MAX + v
	local x = if room.mirror then room.x0 + 26 - u else room.x0 + u
	return building.origin + Vector3.new(x, building.floorY[room.floor] - building.origin.Y + h, z)
end

-- Kierunek od ściany zewnętrznej w stronę korytarza
local function inward(room): Vector3
	return if room.south then Vector3.new(0, 0, 1) else Vector3.new(0, 0, -1)
end

-- Kierunek wzdłuż X uwzględniający lustrzane odbicie pokoju
local function along(room, sign: number): Vector3
	return Vector3.new(if room.mirror then -sign else sign, 0, 0)
end

local function facing(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction)
end

local function pick(rng: Random, list)
	return list[rng:NextInteger(1, #list)]
end

-- Meble do przeszukania: każdy zwraca część z podpowiedzią i nazwę ---------------------------------

local function bed(building, room, rng: Random)
	local base = facing(roomPoint(building, room, 6, 11.5, 1), inward(room))
	local frame = Parts.Block(building.geometry, "Bed", Vector3.new(5, 2, 8), base, COLORS.wood, M.Wood)
	Parts.Deco(building.decor, "Blanket", Vector3.new(5.1, 0.4, 5.5), base * CFrame.new(0, 1.15, -1.2), pick(rng, COLORS.fabric), M.Fabric)
	Parts.Deco(building.decor, "Pillow", Vector3.new(3.4, 0.6, 1.4), base * CFrame.new(0, 1.3, 3), Color3.fromRGB(235, 235, 225), M.Fabric)
	Parts.Block(building.geometry, "Headboard", Vector3.new(5, 4, 0.5), base * CFrame.new(0, 1, 3.95), COLORS.darkWood, M.Wood)
	return frame, "Łóżko"
end

local function dresser(building, room, _rng: Random)
	local base = facing(roomPoint(building, room, 13, 14.5, 1.5), inward(room))
	local body = Parts.Block(building.geometry, "Dresser", Vector3.new(5, 3, 2), base, COLORS.wood, M.Wood)
	for i = -1, 1, 2 do
		Parts.Deco(building.decor, "Drawer", Vector3.new(4.4, 1.1, 0.1), base * CFrame.new(0, i * 0.65, -1.02), COLORS.darkWood, M.Wood)
		Parts.Deco(building.decor, "Knob", Vector3.new(0.3, 0.3, 0.3), base * CFrame.new(0, i * 0.65, -1.12), COLORS.gold, M.Metal, Enum.PartType.Ball)
	end
	-- Lampka nocna na komodzie (nie świeci: prądu w mieszkaniach prawie nie ma)
	Parts.Deco(building.decor, "LampFoot", Vector3.new(0.9, 0.5, 0.5), base * CFrame.new(1.6, 1.95, 0) * CFrame.Angles(0, 0, math.rad(90)), COLORS.darkWood, M.Wood, Enum.PartType.Cylinder)
	Parts.Deco(building.decor, "LampHat", Vector3.new(0.8, 1.2, 1.2), base * CFrame.new(1.6, 2.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(230, 210, 170), M.Fabric, Enum.PartType.Cylinder)
	return body, "Komoda"
end

local function fridge(building, room, _rng: Random)
	local base = facing(roomPoint(building, room, 2, 6, 3.25), along(room, 1))
	local body = Parts.Block(building.geometry, "Fridge", Vector3.new(3, 6.5, 3), base, Color3.fromRGB(225, 230, 235), M.SmoothPlastic)
	Parts.Deco(building.decor, "FridgeLine", Vector3.new(2.9, 0.08, 0.06), base * CFrame.new(0, 1.2, -1.52), COLORS.metal, M.Metal)
	Parts.Deco(building.decor, "Handle", Vector3.new(0.2, 2, 0.2), base * CFrame.new(1.1, -0.4, -1.58), COLORS.metal, M.Metal)
	Parts.Deco(building.decor, "Handle", Vector3.new(0.2, 1, 0.2), base * CFrame.new(1.1, 2.2, -1.58), COLORS.metal, M.Metal)
	Parts.Deco(building.decor, "Magnet", Vector3.new(0.5, 0.5, 0.1), base * CFrame.new(-0.5, 2.2, -1.52), Color3.fromRGB(255, 90, 120))
	return body, "Lodówka"
end

local function shelf(building, room, rng: Random)
	local base = facing(roomPoint(building, room, 24.75, 8, 3), along(room, -1))
	local body = Parts.Block(building.geometry, "Shelf", Vector3.new(5, 6, 1.5), base, COLORS.darkWood, M.Wood)
	for row = 0, 2 do
		for i = 1, rng:NextInteger(1, 3) do
			Parts.Deco(building.decor, "Jar", Vector3.new(1, 0.8, 0.8), base * CFrame.new(-2 + i * 1.1, -1.8 + row * 1.9, -0.85) * CFrame.Angles(0, 0, math.rad(90)), COLORS.jar, M.Glass, Enum.PartType.Cylinder)
		end
	end
	return body, "Regał ze słoikami"
end

local function tableSet(building, room, _rng: Random)
	local base = facing(roomPoint(building, room, 16, 7, 1.5), inward(room))
	local top = Parts.Block(building.geometry, "Table", Vector3.new(5, 0.4, 3.5), base * CFrame.new(0, 1.3, 0), COLORS.wood, M.Wood)
	for _, x in { -2.2, 2.2 } do
		for _, z in { -1.4, 1.4 } do
			Parts.Deco(building.decor, "Leg", Vector3.new(0.3, 2.8, 0.3), base * CFrame.new(x, -0.1, z), COLORS.darkWood, M.Wood)
		end
	end
	Parts.Deco(building.decor, "Cloth", Vector3.new(3, 0.05, 3.6), base * CFrame.new(0, 1.52, 0), Color3.fromRGB(240, 235, 220), M.Fabric)
	-- Krzesła: za stołem i z boku (zawsze po stronie z dala od drzwi)
	for _, seat in { { 16, 9.8, inward(room) }, { 19.6, 7, along(room, -1) } } do
		local chair = facing(roomPoint(building, room, seat[1], seat[2], 0.9), seat[3])
		Parts.Block(building.geometry, "Chair", Vector3.new(1.7, 1.8, 1.7), chair, COLORS.darkWood, M.Wood)
		Parts.Block(building.geometry, "ChairBack", Vector3.new(1.7, 2.2, 0.3), chair * CFrame.new(0, 2, 0.7), COLORS.darkWood, M.Wood)
	end
	return top, "Stół"
end

local function boxes(building, room, rng: Random)
	local base = facing(roomPoint(building, room, 22, 2.5, 1.25), inward(room))
	local bottom = Parts.Block(building.geometry, "Boxes", Vector3.new(3, 2.5, 3), base, Color3.fromRGB(190, 150, 100), M.Cardboard)
	Parts.Block(building.geometry, "Box", Vector3.new(2.2, 1.8, 2.2), base * CFrame.new(0.2, 2.15, 0.1) * CFrame.Angles(0, math.rad(rng:NextInteger(-20, 20)), 0), Color3.fromRGB(205, 165, 115), M.Cardboard)
	return bottom, "Pudła"
end

local function wardrobe(building, room, _rng: Random)
	local base = facing(roomPoint(building, room, 19.5, 14.25, 3.75), inward(room))
	local body = Parts.Block(building.geometry, "Wardrobe", Vector3.new(4.5, 7.5, 2.5), base, COLORS.darkWood, M.Wood)
	Parts.Deco(building.decor, "DoorL", Vector3.new(2.1, 6.9, 0.1), base * CFrame.new(-1.1, 0, -1.27), COLORS.wood, M.Wood)
	Parts.Deco(building.decor, "DoorR", Vector3.new(2.1, 6.9, 0.1), base * CFrame.new(1.1, 0, -1.27), COLORS.wood, M.Wood)
	for _, x in { -0.3, 0.3 } do
		Parts.Deco(building.decor, "Knob", Vector3.new(0.25, 0.25, 0.25), base * CFrame.new(x, 0, -1.37), COLORS.gold, M.Metal, Enum.PartType.Ball)
	end
	-- Szczelina z oczami (świecą, gdy ktoś się chowa)
	local eyes = Parts.Deco(building.decor, "HideEyes", Vector3.new(1, 0.25, 0.05), base * CFrame.new(0, 1.6, -1.33), Color3.fromRGB(255, 255, 220), M.Neon)
	eyes.Transparency = 1
	-- Postać w środku szafy: przodem do drzwi
	local inside = base * CFrame.new(0, -0.75, 0)
	local outside = base * CFrame.new(0, -0.75, -4)
	table.insert(building.wardrobes, { part = body, eyes = eyes, floor = room.floor, inside = inside, outside = outside })
end

local SEARCHABLE = { bed, dresser, fridge, shelf, tableSet, boxes }

-- Ozdoby pokoi ------------------------------------------------------------------------------------

local function window(building, room)
	local center = roomPoint(building, room, 8, 15.88, 6)
	local frame = facing(center, inward(room))
	Parts.Deco(building.decor, "WindowFrame", Vector3.new(4.6, 4.6, 0.2), frame, COLORS.darkWood, M.Wood)
	local glass = Parts.Deco(building.decor, "Window", Vector3.new(4, 4, 0.25), frame, COLORS.window, M.Glass)
	glass.Transparency = 0.15
	Parts.Deco(building.decor, "WindowBar", Vector3.new(0.2, 4, 0.3), frame, COLORS.darkWood, M.Wood)
	Parts.Deco(building.decor, "WindowBar", Vector3.new(4, 0.2, 0.3), frame, COLORS.darkWood, M.Wood)
	-- Zasłony i karnisz
	local curtain = pick(building.rng, COLORS.fabric)
	for _, side in { -1, 1 } do
		Parts.Deco(building.decor, "Curtain", Vector3.new(1.3, 5.6, 0.25), frame * CFrame.new(side * 3, 0.1, -0.25), curtain, M.Fabric)
	end
	Parts.Deco(building.decor, "CurtainRod", Vector3.new(7.8, 0.18, 0.18), frame * CFrame.new(0, 3.05, -0.25), COLORS.darkWood, M.Wood)
	-- Księżyc za oknem: chłodny, słaby blask
	local moon = Instance.new("SurfaceLight")
	moon.Face = Enum.NormalId.Front
	moon.Brightness = 0.6
	moon.Range = 10
	moon.Angle = 70
	moon.Color = Color3.fromRGB(120, 150, 255)
	moon.Parent = glass
end

-- Dywan na środku i obrazek na ścianie od strony korytarza
local function roomDecor(building, room, rng: Random)
	Parts.Deco(building.decor, "Rug", Vector3.new(11, 0.06, 6.5), CFrame.new(roomPoint(building, room, 12, 8.2, 0.04)), pick(rng, COLORS.rug), M.Carpet)
	if rng:NextNumber() < 0.7 then
		local frame = facing(roomPoint(building, room, 20.5, 0.6, 6.2), -inward(room))
		Parts.Deco(building.decor, "PictureFrame", Vector3.new(2.8, 2.2, 0.16), frame, COLORS.darkWood, M.Wood)
		Parts.Deco(building.decor, "Picture", Vector3.new(2.3, 1.7, 0.18), frame * CFrame.new(0, 0, -0.02), pick(rng, COLORS.picture), M.Fabric)
	end
end

local function furnishApartment(building, room, rng: Random)
	window(building, room)
	roomDecor(building, room, rng)
	wardrobe(building, room, rng)
	for _, builder in SEARCHABLE do
		if rng:NextNumber() < 0.85 then
			local part, label = builder(building, room, rng)
			table.insert(building.spots, { part = part, label = label, floor = room.floor, room = room.id })
		end
	end
	-- Lampa pod sufitem: nie w każdym mieszkaniu (ciemne pokoje = latarka)
	if rng:NextNumber() < 0.45 then
		Parts.Lamp(building.decor, roomPoint(building, room, 13, 8, WALL_HEIGHT - 1), 0.35, 14)
	end
end

local function furnishOffice(building, room)
	window(building, room)
	Parts.Deco(building.decor, "Rug", Vector3.new(12, 0.06, 7), CFrame.new(roomPoint(building, room, 13, 7, 0.04)), Color3.fromRGB(120, 50, 50), M.Carpet)
	local deskFrame = facing(roomPoint(building, room, 13, 9, 1.5), inward(room))
	Parts.Block(building.geometry, "Desk", Vector3.new(9, 3, 3), deskFrame, COLORS.darkWood, M.Wood)
	Parts.Deco(building.decor, "DeskTop", Vector3.new(9.4, 0.2, 3.4), deskFrame * CFrame.new(0, 1.6, 0), COLORS.wood, M.Wood)
	-- Skrzynka na czynsz stoi z boku biurka, żeby nie zasłaniała Pana Klucznika
	local box = Parts.Block(building.geometry, "RentBox", Vector3.new(2.4, 1.6, 1.6), deskFrame * CFrame.new(2.9, 2.5, -0.4), COLORS.gold, M.Metal)
	Parts.Deco(building.decor, "Slot", Vector3.new(1.4, 0.1, 0.25), deskFrame * CFrame.new(2.9, 3.32, -0.4), COLORS.black)
	Parts.Deco(building.decor, "BoxLock", Vector3.new(0.5, 0.6, 0.1), deskFrame * CFrame.new(2.9, 2.4, -1.22), COLORS.black, M.Metal)
	Parts.Billboard(box, "💰 SKRZYNKA NA CZYNSZ", Color3.fromRGB(255, 220, 90), 2.2)
	-- Dzwonek i księga na biurku
	Parts.Deco(building.decor, "Bell", Vector3.new(0.7, 0.7, 0.7), deskFrame * CFrame.new(-3, 1.95, -0.6), COLORS.gold, M.Metal, Enum.PartType.Ball)
	Parts.Deco(building.decor, "Ledger", Vector3.new(2, 0.25, 1.4), deskFrame * CFrame.new(-0.6, 1.83, -0.5) * CFrame.Angles(0, math.rad(12), 0), Color3.fromRGB(110, 40, 45), M.Fabric)
	building.depositBox = box
	building.landlordCFrame = facing(roomPoint(building, room, 13, 12.5, 0), inward(room))
	building.landlordModel = LandlordBuilder.Build(building.landlordCFrame, "🙂", building.decor)
	-- Tablica z napisem i tablica z kluczami do mieszkań
	local board = Parts.Deco(building.decor, "Board", Vector3.new(6, 3.5, 0.2), facing(roomPoint(building, room, 19.5, 15.88, 7), inward(room)), Color3.fromRGB(60, 90, 60))
	Parts.Sign(board, Enum.NormalId.Front, "CZYNSZ DO PÓŁNOCY!", Color3.fromRGB(255, 240, 200))
	local keyBoard = facing(roomPoint(building, room, 0.12, 8, 6.5), along(room, 1))
	Parts.Deco(building.decor, "KeyBoard", Vector3.new(5, 3, 0.2), keyBoard, COLORS.darkWood, M.Wood)
	for row = 0, 1 do
		for i = 0, 4 do
			Parts.Deco(building.decor, "KeyHook", Vector3.new(0.18, 0.8, 0.12), keyBoard * CFrame.new(-2 + i, 0.6 - row * 1.3, -0.14), COLORS.gold, M.Metal)
		end
	end
	Parts.Block(building.geometry, "Cabinet", Vector3.new(3, 6, 2), facing(roomPoint(building, room, 24.4, 4, 3), along(room, -1)), COLORS.wood, M.Wood)
	Parts.Lamp(building.decor, roomPoint(building, room, 13, 8, WALL_HEIGHT - 1), 1, 22)
end

-- Zamknięte mieszkanie: drzwi w przejściu i słoik pełen monet w środku
local function lockApartment(building, room)
	local doorCenter = roomPoint(building, room, 13, 0, DOOR_HEIGHT / 2)
	local frame = facing(doorCenter, inward(room))
	local door = Parts.Block(building.geometry, "LockedDoor", Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, 0.6), frame, COLORS.darkWood, M.Wood)
	for _, y in { -2.4, 2.2 } do
		Parts.Deco(building.decor, "DoorPanel", Vector3.new(3.4, 3.4, 0.1), frame * CFrame.new(0, y, 0.33), COLORS.wood, M.Wood)
	end
	Parts.Deco(building.decor, "Padlock", Vector3.new(0.9, 1.1, 0.4), frame * CFrame.new(1.6, -0.5, 0.45), COLORS.gold, M.Metal)
	Parts.Billboard(door, "🔒 ZAMKNIĘTE", Color3.fromRGB(255, 200, 90), 6, Vector2.new(200, 50))
	Parts.Deco(building.decor, "Rug", Vector3.new(9, 0.06, 9), CFrame.new(roomPoint(building, room, 13, 9, 0.04)), Color3.fromRGB(110, 40, 50), M.Carpet)
	local jarBase = roomPoint(building, room, 13, 9, 2.5)
	Parts.Block(building.geometry, "JarStand", Vector3.new(3.4, 1, 3.4), CFrame.new(jarBase + Vector3.new(0, -2, 0)), COLORS.darkWood, M.Wood)
	local jar = Parts.Block(building.geometry, "CoinJar", Vector3.new(3, 3, 3), CFrame.new(jarBase) * CFrame.Angles(0, 0, math.rad(90)), COLORS.jar, M.Glass)
	jar.Shape = Enum.PartType.Cylinder
	jar.Transparency = 0.3
	Parts.Deco(building.decor, "Coins", Vector3.new(2, 2.4, 2.4), CFrame.new(jarBase + Vector3.new(0, -0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), COLORS.gold, M.Neon, Enum.PartType.Cylinder)
	local glow = Instance.new("PointLight")
	glow.Color = COLORS.gold
	glow.Brightness = 1.2
	glow.Range = 10
	glow.Parent = jar
	building.locked = { door = door, room = room.id, floor = room.floor, jar = jar }
end

-- Framuga, otwarte skrzydło drzwi, wycieraczka i wisząca tabliczka (czytelna z obu stron korytarza)
local function doorway(building, room, text: string, rng: Random, withLeaf: boolean)
	local trim = COLORS.darkWood
	local center = roomPoint(building, room, 13, 0, 0)
	local frame = facing(center, inward(room))
	for _, side in { -1, 1 } do
		Parts.Deco(building.decor, "DoorJamb", Vector3.new(0.45, DOOR_HEIGHT, 1.3), frame * CFrame.new(side * (DOOR_WIDTH / 2 + 0.2), DOOR_HEIGHT / 2, 0), trim, M.Wood)
	end
	Parts.Deco(building.decor, "DoorHead", Vector3.new(DOOR_WIDTH + 0.9, 0.45, 1.3), frame * CFrame.new(0, DOOR_HEIGHT + 0.2, 0), trim, M.Wood)
	if withLeaf then
		-- Skrzydło otwarte do środka pokoju (ok. 100 stopni)
		local hinge = roomPoint(building, room, 13 - DOOR_WIDTH / 2 + 0.15, 0.55, DOOR_HEIGHT / 2)
		local tip = roomPoint(building, room, 13 - DOOR_WIDTH / 2 - 0.65, 0.55 + DOOR_WIDTH - 0.5, DOOR_HEIGHT / 2)
		local leaf = Parts.Deco(building.decor, "DoorLeaf", Vector3.new(0.3, DOOR_HEIGHT - 0.3, (tip - hinge).Magnitude), CFrame.lookAt((hinge + tip) / 2, tip), COLORS.wood, M.Wood)
		Parts.Deco(building.decor, "DoorKnob", Vector3.new(0.4, 0.4, 0.4), leaf.CFrame * CFrame.new(0.3, -0.4, -(tip - hinge).Magnitude / 2 + 0.6), COLORS.gold, M.Metal, Enum.PartType.Ball)
	end
	-- Wycieraczka w korytarzu
	Parts.Deco(building.decor, "Doormat", Vector3.new(3.6, 0.07, 1.5), frame * CFrame.new(0, 0.04, -1.45), pick(rng, COLORS.rug), M.Carpet)
	-- Tabliczka prostopadle do ściany
	local wide = if #text > 2 then 2.6 else 1.5
	local plate = Parts.Deco(building.decor, "DoorSign", Vector3.new(0.14, 1.2, wide), frame * CFrame.new(DOOR_WIDTH / 2 + 1.1, 8.4, -0.5 - wide / 2), COLORS.black)
	Parts.Deco(building.decor, "SignBracket", Vector3.new(0.1, 0.12, wide + 0.3), plate.CFrame * CFrame.new(0, 0.68, 0.1), COLORS.gold, M.Metal)
	Parts.Sign(plate, Enum.NormalId.Left, text, COLORS.gold)
	Parts.Sign(plate, Enum.NormalId.Right, text, COLORS.gold)
end

-- Klatka schodowa -------------------------------------------------------------------------------

-- Dwa biegi z podestem. Kolizję daje gładka pochylnia (pewne chodzenie i ścieżki potworów),
-- a stopnie to ozdoba leżąca na pochylni.
local function buildStairs(building, f: number)
	local o = building.origin
	local y0 = f * FLOOR_HEIGHT
	local g = building.geometry
	local steps = 14
	local run = 12 / steps
	local rise = 7 / steps
	Parts.Ramp(g, "StairsA", o + Vector3.new(55.25, y0, 16), o + Vector3.new(55.25, y0 + 7, 4), 5.5, COLORS.stairs, M.Wood)
	Parts.Box(g, "Landing", o + Vector3.new(52.5, y0 + 6, 0), o + Vector3.new(64, y0 + 7, 4), COLORS.tread, M.WoodPlanks)
	Parts.Ramp(g, "StairsB", o + Vector3.new(61, y0 + 7, 4), o + Vector3.new(61, y0 + 14, 16), 5.5, COLORS.stairs, M.Wood)
	Parts.Box(g, "StairDivider", o + Vector3.new(57.75, y0, 4), o + Vector3.new(58.25, y0 + FLOOR_HEIGHT, 16), COLORS.wainscot, M.WoodPlanks)
	for k = 1, steps do
		local color = if k % 2 == 0 then COLORS.tread else COLORS.tread:Lerp(Color3.new(0, 0, 0), 0.12)
		Parts.Deco(building.decor, "Step", Vector3.new(5.5, 0.7, run), CFrame.new(o + Vector3.new(55.25, y0 + k * rise - 0.35, 16 - (k - 0.5) * run)), color, M.WoodPlanks)
		Parts.Deco(building.decor, "Step", Vector3.new(5.5, 0.7, run), CFrame.new(o + Vector3.new(61, y0 + 7 + k * rise - 0.35, 4 + (k - 0.5) * run)), color, M.WoodPlanks)
	end
	-- Poręcze na ścianie między biegami
	local rails = {
		{ o + Vector3.new(57.6, y0 + 3.2, 16), o + Vector3.new(57.6, y0 + 10.2, 4) },
		{ o + Vector3.new(58.4, y0 + 10.2, 4), o + Vector3.new(58.4, y0 + 17.2, 16) },
	}
	for _, rail in rails do
		Parts.Deco(building.decor, "Handrail", Vector3.new(0.25, 0.25, (rail[2] - rail[1]).Magnitude), CFrame.lookAt((rail[1] + rail[2]) / 2, rail[2]), COLORS.darkWood, M.Wood)
	end
end

-- Barierka dookoła dziury po schodach na najwyższym piętrze
local function buildHoleRailing(building, f: number)
	local o = building.origin
	local y = f * FLOOR_HEIGHT
	Parts.Box(building.geometry, "Railing", o + Vector3.new(57.75, y, 4), o + Vector3.new(58.25, y + 3.5, 16), COLORS.wainscot, M.WoodPlanks)
	Parts.Box(building.geometry, "Railing", o + Vector3.new(58.25, y, 3.75), o + Vector3.new(W, y + 3.5, 4.25), COLORS.wainscot, M.WoodPlanks)
end

local function buildSlab(building, f: number)
	local o = building.origin
	local y = f * FLOOR_HEIGHT
	local g = building.geometry
	if f == 0 then
		Parts.Box(g, "GroundSlab", o + Vector3.new(-1, -1, -1), o + Vector3.new(W + 1, 0, D + 1), COLORS.slab, M.WoodPlanks)
		return
	end
	-- Podłoga piętra z dziurą nad biegiem schodów prowadzącym w górę (X 58..64, Z 4..16)
	Parts.Box(g, "Slab", o + Vector3.new(-1, y - 1, -1), o + Vector3.new(58, y, D + 1), COLORS.slab, M.WoodPlanks)
	Parts.Box(g, "Slab", o + Vector3.new(58, y - 1, 16), o + Vector3.new(W + 1, y, D + 1), COLORS.slab, M.WoodPlanks)
	Parts.Box(g, "Slab", o + Vector3.new(58, y - 1, -1), o + Vector3.new(W + 1, y, 4), COLORS.slab, M.WoodPlanks)
end

-- Jasny sufit (cienka ozdoba pod stropem), z dziurą nad schodami tam, gdzie strop ją ma
local function buildCeiling(building, f: number)
	local o = building.origin
	local y = f * FLOOR_HEIGHT + WALL_HEIGHT
	local function panel(x0: number, z0: number, x1: number, z1: number)
		Parts.Deco(building.decor, "Ceiling", Vector3.new(x1 - x0, 0.1, z1 - z0), CFrame.new(o + Vector3.new((x0 + x1) / 2, y - 0.06, (z0 + z1) / 2)), COLORS.ceiling, M.Plaster)
	end
	if f == FLOORS - 1 then
		panel(0, 0, W, D)
	else
		panel(0, 0, 58, D)
		panel(58, 16, W, D)
		panel(58, 0, W, 4)
	end
end

local function buildFloorWalls(building, f: number)
	local o = building.origin
	local y0 = f * FLOOR_HEIGHT
	local g = building.geometry
	local color = COLORS.wallFloor[f]
	local doorOpenings = {
		{ from = 13 - DOOR_WIDTH / 2, to = 13 + DOOR_WIDTH / 2, height = DOOR_HEIGHT },
		{ from = 39 - DOOR_WIDTH / 2, to = 39 + DOOR_WIDTH / 2, height = DOOR_HEIGHT },
	}
	-- Ściany zewnętrzne: od środka w kolorze piętra; fasada (zachód) ma osobną warstwę z cegły
	wallAlongX(g, o, -0.5, W + 1, -0.5, y0, color, {}, M.Plaster)
	wallAlongX(g, o, -0.5, W + 1, D + 0.5, y0, color, {}, M.Plaster)
	wallAlongZ(g, o, 0, D, W + 0.5, y0, color, {}, M.Plaster)
	local front = if f == 0 then { { from = 20 - DOOR_WIDTH / 2, to = 20 + DOOR_WIDTH / 2, height = DOOR_HEIGHT } } else {}
	wallAlongZ(g, o, 0, D, -0.25, y0, color, table.clone(front), M.Plaster, 0.25)
	wallAlongZ(g, o, -1, D + 1, -0.75, y0, COLORS.outer, table.clone(front), M.Brick, 0.25)
	-- Korytarz
	wallAlongX(g, o, 0, STAIR_X, CORRIDOR_MIN, y0, color, table.clone(doorOpenings), M.Plaster)
	wallAlongX(g, o, 0, STAIR_X, CORRIDOR_MAX, y0, color, table.clone(doorOpenings), M.Plaster)
	-- Ściany między pokojami i ściana klatki schodowej
	wallAlongZ(g, o, 0, CORRIDOR_MIN - 0.5, 26, y0, color, {}, M.Plaster)
	wallAlongZ(g, o, CORRIDOR_MAX + 0.5, D, 26, y0, color, {}, M.Plaster)
	wallAlongZ(g, o, 0, CORRIDOR_MIN - 0.5, STAIR_X, y0, color, {}, M.Plaster)
	wallAlongZ(g, o, CORRIDOR_MAX + 0.5, D, STAIR_X, y0, color, {}, M.Plaster)

	-- Korytarz: chodnik, ciemna boazeria z listwą, lampy
	local d = building.decor
	Parts.Deco(d, "Runner", Vector3.new(STAIR_X - 2, 0.05, 3), CFrame.new(o + Vector3.new(STAIR_X / 2, y0 + 0.03, 20)), COLORS.corridorFloor, M.Carpet)
	local segments = { { 0, 13 - DOOR_WIDTH / 2 - 0.45 }, { 13 + DOOR_WIDTH / 2 + 0.45, 39 - DOOR_WIDTH / 2 - 0.45 }, { 39 + DOOR_WIDTH / 2 + 0.45, STAIR_X } }
	for _, z in { CORRIDOR_MIN + 0.58, CORRIDOR_MAX - 0.58 } do
		for _, segment in segments do
			local length = segment[2] - segment[1]
			local x = (segment[1] + segment[2]) / 2
			Parts.Deco(d, "Wainscot", Vector3.new(length, 3.4, 0.16), CFrame.new(o + Vector3.new(x, y0 + 1.7, z)), COLORS.wainscot, M.WoodPlanks)
			Parts.Deco(d, "WainscotRail", Vector3.new(length, 0.3, 0.3), CFrame.new(o + Vector3.new(x, y0 + 3.5, z)), COLORS.darkWood, M.Wood)
		end
	end
	-- Parter jest jaśniejszy (bezpieczny), wyżej coraz ciemniej
	local brightness = ({ [0] = 0.9, [1] = 0.45, [2] = 0.2 })[f]
	for _, x in { 8, 26, 44 } do
		local light = Parts.Lamp(d, o + Vector3.new(x, y0 + WALL_HEIGHT - 1, 20), brightness, 18)
		table.insert(building.corridorLights, { light = light, floor = f })
	end
	Parts.Lamp(d, o + Vector3.new(58, y0 + WALL_HEIGHT - 1, 30), brightness * 0.8, 16)

	-- Obrazy między drzwiami i kwiat na końcu korytarza
	for _, z in { CORRIDOR_MIN + 0.6, CORRIDOR_MAX - 0.6 } do
		local towards = if z < 20 then Vector3.new(0, 0, 1) else Vector3.new(0, 0, -1)
		local frame = facing(o + Vector3.new(26 + (if z < 20 then -3 else 3), y0 + 7, z), towards)
		Parts.Deco(d, "PictureFrame", Vector3.new(3.2, 2.4, 0.16), frame, COLORS.darkWood, M.Wood)
		Parts.Deco(d, "Picture", Vector3.new(2.7, 1.9, 0.18), frame * CFrame.new(0, 0, -0.02), pick(building.rng, COLORS.picture), M.Fabric)
	end
	if f > 0 then
		Parts.Deco(d, "PlantPot", Vector3.new(1.4, 1.3, 1.3), CFrame.new(o + Vector3.new(1.4, y0 + 0.7, 22.4)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 90, 60), M.Slate, Enum.PartType.Cylinder)
		Parts.Blob(d, "Plant", Vector3.new(2.2, 3, 2.2), CFrame.new(o + Vector3.new(1.4, y0 + 2.6, 22.4)), COLORS.bush, M.Grass)
	end

	-- Zegar ścienny (godzinę wpisuje u siebie każdy gracz): widać czas bez patrzenia w HUD
	local clockCenter = o + Vector3.new(20, y0 + 8.6, CORRIDOR_MAX - 0.62)
	local clockFrame = CFrame.lookAt(clockCenter, clockCenter - Vector3.new(0, 0, 1))
	Parts.Deco(d, "WallClockRim", Vector3.new(0.2, 3.8, 3.8), clockFrame * CFrame.new(0, 0, 0.02) * CFrame.Angles(0, math.rad(90), 0), COLORS.darkWood, M.Wood, Enum.PartType.Cylinder)
	Parts.Deco(d, "WallClock", Vector3.new(0.22, 3.3, 3.3), clockFrame * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(245, 235, 210), M.SmoothPlastic, Enum.PartType.Cylinder)
	local board = Parts.Deco(d, "WallClockText", Vector3.new(2.6, 1.2, 0.05), clockFrame * CFrame.new(0, 0, -0.14), Color3.fromRGB(245, 235, 210))
	board.Transparency = 1
	local label = Parts.Sign(board, Enum.NormalId.Front, "20:00", Color3.fromRGB(60, 30, 30))
	label.Name = "ClockText"
	label:SetAttribute("NoTranslate", true)
	CollectionService:AddTag(label, "WallClock")

	-- Numer piętra na ścianie klatki schodowej (widać go z całego korytarza)
	local signCenter = o + Vector3.new(W - 0.12, y0 + 8.5, 20)
	local floorSign = Parts.Deco(d, "FloorSign", Vector3.new(6.5, 2.2, 0.2), CFrame.lookAt(signCenter, signCenter - Vector3.new(1, 0, 0)), COLORS.black)
	Parts.Sign(floorSign, Enum.NormalId.Front, if f == 0 then "PARTER" else "PIĘTRO " .. f, COLORS.gold)
end

-- Fasada i podwórko -----------------------------------------------------------------------------

local function buildFacade(building, rng: Random)
	local o = building.origin
	local d = building.decor
	local x = -1.02 -- zewnętrzne lico fasady
	local function facadeWindow(y: number, z: number, lit: boolean, cat: boolean)
		local center = o + Vector3.new(x, y, z)
		Parts.Deco(d, "FacadeWindowFrame", Vector3.new(0.3, 5.4, 4.2), CFrame.new(center), COLORS.trim, M.Plaster)
		Parts.Deco(d, "FacadeWindow", Vector3.new(0.34, 4.6, 3.4), CFrame.new(center + Vector3.new(-0.02, 0, 0)), if lit then COLORS.windowLit else COLORS.window, if lit then M.Neon else M.Glass)
		Parts.Deco(d, "FacadeWindowBar", Vector3.new(0.38, 4.6, 0.2), CFrame.new(center + Vector3.new(-0.03, 0, 0)), COLORS.trim, M.Plaster)
		Parts.Deco(d, "FacadeSill", Vector3.new(0.7, 0.35, 4.8), CFrame.new(center + Vector3.new(-0.2, -2.85, 0)), COLORS.trim, M.Plaster)
		if cat then
			-- Ktoś wygląda przez okno...
			for _, dz in { -0.6, 0.6 } do
				Parts.Deco(d, "CatEye", Vector3.new(0.45, 0.45, 0.45), CFrame.new(center + Vector3.new(-0.22, 0.3, dz)), Color3.fromRGB(255, 240, 80), M.Neon, Enum.PartType.Ball)
			end
		end
	end
	for f = 0, FLOORS - 1 do
		local y = f * FLOOR_HEIGHT + 6.5
		for _, z in { 5, 11.5, 28.5, 35 } do
			local cat = f == 2 and z == 28.5
			facadeWindow(y, z, not cat and rng:NextNumber() < 0.4, cat)
		end
		if f > 0 then
			facadeWindow(y, 20, rng:NextNumber() < 0.5, false)
			-- Gzyms między piętrami
			Parts.Deco(d, "Cornice", Vector3.new(0.6, 0.7, D + 2.4), CFrame.new(o + Vector3.new(x - 0.2, f * FLOOR_HEIGHT - 0.3, D / 2)), COLORS.trim, M.Plaster)
		end
	end
	Parts.Deco(d, "Cornice", Vector3.new(1.1, 1, D + 3), CFrame.new(o + Vector3.new(x - 0.4, FLOORS * FLOOR_HEIGHT - 0.6, D / 2)), COLORS.trim, M.Plaster)
	-- Portal drzwi, daszek z lampą i numer domu
	for _, z in { 20 - DOOR_WIDTH / 2 - 0.4, 20 + DOOR_WIDTH / 2 + 0.4 } do
		Parts.Deco(d, "PortalJamb", Vector3.new(0.6, DOOR_HEIGHT + 0.4, 0.8), CFrame.new(o + Vector3.new(x - 0.15, (DOOR_HEIGHT + 0.4) / 2, z)), COLORS.trim, M.Plaster)
	end
	Parts.Deco(d, "PortalHead", Vector3.new(0.6, 0.9, DOOR_WIDTH + 1.6), CFrame.new(o + Vector3.new(x - 0.15, DOOR_HEIGHT + 0.85, 20)), COLORS.trim, M.Plaster)
	Parts.Deco(d, "Canopy", Vector3.new(2.6, 0.3, DOOR_WIDTH + 2.4), CFrame.new(o + Vector3.new(x - 1.3, DOOR_HEIGHT + 1.5, 20)) * CFrame.Angles(0, 0, math.rad(-8)), COLORS.fence, M.Slate)
	Parts.Lamp(d, o + Vector3.new(x - 1.4, DOOR_HEIGHT + 0.6, 20), 1.2, 18, Color3.fromRGB(255, 210, 150), false)
	local number = Parts.Deco(d, "HouseNumber", Vector3.new(0.12, 1.3, 1.6), CFrame.new(o + Vector3.new(x - 0.08, 7, 20 + DOOR_WIDTH / 2 + 2.2)), COLORS.black)
	Parts.Sign(number, Enum.NormalId.Left, "13", COLORS.gold)
end

local function buildYard(building)
	local o = building.origin
	local g = building.geometry
	local d = building.decor
	Parts.Box(g, "Yard", o + Vector3.new(YARD_X - 6, -1, 2), o + Vector3.new(-1, 0, 38), COLORS.yard, M.Cobblestone)
	Parts.Deco(d, "YardPath", Vector3.new(-YARD_X + 4, 0.06, 6), CFrame.new(o + Vector3.new((YARD_X - 5) / 2, 0.03, 20)), COLORS.path, M.Cobblestone)
	-- Płot: boki i tył z bramą na środku
	for _, z in { 2, 38 } do
		Parts.Box(g, "Fence", o + Vector3.new(YARD_X, 0, z - 0.3), o + Vector3.new(-1, 7, z + 0.3), COLORS.fence, M.WoodPlanks)
	end
	Parts.Box(g, "Fence", o + Vector3.new(YARD_X - 0.3, 0, 2), o + Vector3.new(YARD_X + 0.3, 7, 15), COLORS.fence, M.WoodPlanks)
	Parts.Box(g, "Fence", o + Vector3.new(YARD_X - 0.3, 0, 25), o + Vector3.new(YARD_X + 0.3, 7, 38), COLORS.fence, M.WoodPlanks)
	for _, z in { 14.4, 25.6 } do
		Parts.Box(g, "GatePost", o + Vector3.new(YARD_X - 0.7, 0, z - 0.7), o + Vector3.new(YARD_X + 0.7, 10, z + 0.7), COLORS.outer, M.Brick)
		Parts.Lamp(d, o + Vector3.new(YARD_X + 1.1, 8.6, z), 1, 16, Color3.fromRGB(150, 255, 170), false)
	end
	-- Szyld nad bramą: miejsce ucieczki (po nim klient pokazuje strzałkę celu)
	local sign = Parts.Deco(d, "GateSign", Vector3.new(0.4, 2.4, 12.6), CFrame.new(o + Vector3.new(YARD_X, 11.2, 20)), Color3.fromRGB(40, 30, 25))
	Parts.Sign(sign, Enum.NormalId.Right, "🏃 WYJŚCIE", Color3.fromRGB(120, 255, 140))
	-- Otwarte skrzydła bramy
	for _, side in { -1, 1 } do
		Parts.Deco(d, "GateLeaf", Vector3.new(4.6, 6, 0.3), CFrame.new(o + Vector3.new(YARD_X - 3.2, 3.2, 20 + side * 4.6)) * CFrame.Angles(0, math.rad(side * 10), 0), COLORS.fence, M.Metal)
	end
	-- Niewidzialne ściany za bramą (gracz po ucieczce nie odejdzie w ciemność)
	for _, wall in { { YARD_X - 6.5, 14, YARD_X - 6, 26 }, { YARD_X - 6, 13.5, YARD_X, 14 }, { YARD_X - 6, 26, YARD_X, 26.5 } } do
		local barrier = Parts.Box(g, "Barrier", o + Vector3.new(wall[1], 0, wall[2]), o + Vector3.new(wall[3], 14, wall[4]), COLORS.black)
		barrier.Transparency = 1
		barrier.CastShadow = false
	end
	-- Latarnie, krzaki pod ścianą, ławka
	for _, z in { 7, 33 } do
		local post = Parts.Block(g, "LampPost", Vector3.new(0.6, 10, 0.6), CFrame.new(o + Vector3.new(-15, 5, z)), COLORS.fence, M.Metal)
		Parts.Lamp(d, post.CFrame.Position + Vector3.new(0, 5.4, 0), 1.2, 30, Color3.fromRGB(255, 210, 150), false)
	end
	for _, z in { 5, 11.5, 28.5, 35 } do
		Parts.Blob(d, "Bush", Vector3.new(3, 2.6, 4.4), CFrame.new(o + Vector3.new(-3, 1.1, z)), COLORS.bush, M.Grass)
	end
	local bench = CFrame.new(o + Vector3.new(-22, 0, 36))
	Parts.Block(g, "BenchSeat", Vector3.new(6, 0.4, 1.8), bench * CFrame.new(0, 1.6, 0), COLORS.wood, M.Wood)
	Parts.Block(g, "BenchBack", Vector3.new(6, 1.6, 0.3), bench * CFrame.new(0, 2.6, 0.8), COLORS.wood, M.Wood)
	for _, bx in { -2.6, 2.6 } do
		Parts.Deco(d, "BenchLeg", Vector3.new(0.3, 1.6, 1.6), bench * CFrame.new(bx, 0.8, 0), COLORS.fence, M.Metal)
	end
	-- Drzwi frontowe (zamknięte do zapłaty czynszu albo północy)
	local door = Parts.Block(g, "FrontDoor", Vector3.new(0.8, DOOR_HEIGHT, DOOR_WIDTH), CFrame.new(o + Vector3.new(-0.5, DOOR_HEIGHT / 2, 20)), COLORS.darkWood, M.Wood)
	Parts.Billboard(door, "🚪 Otworzy się po zapłacie czynszu", Color3.fromRGB(255, 230, 180), 6.5, Vector2.new(300, 50))
	building.frontDoor = door
	-- Strefa ucieczki: przejście przez bramę (sprawdzane w pętli rundy)
	building.exitMin = o + Vector3.new(YARD_X - 5.5, -1, 14.5)
	building.exitMax = o + Vector3.new(YARD_X + 2.5, 12, 25.5)
end

-- Skrzynia w zakamarku za klatką schodową (parter i 1. piętro; na 2. piętrze śpi tam Mruczek)
local function buildNook(building, f: number)
	local o = building.origin
	local y = f * FLOOR_HEIGHT
	local base = CFrame.new(o + Vector3.new(60.5, y + 1.25, 37))
	local chest = Parts.Block(building.geometry, "Chest", Vector3.new(4, 2.5, 2.6), base, COLORS.darkWood, M.Wood)
	Parts.Deco(building.decor, "ChestLid", Vector3.new(4.2, 0.5, 2.8), base * CFrame.new(0, 1.3, 0), COLORS.wood, M.Wood)
	for _, x in { -1.4, 1.4 } do
		Parts.Deco(building.decor, "ChestBand", Vector3.new(0.4, 3.1, 2.9), base * CFrame.new(x, 0.25, 0), COLORS.gold, M.Metal)
	end
	Parts.Block(building.geometry, "Barrel", Vector3.new(3, 2.6, 2.6), CFrame.new(o + Vector3.new(55, y + 1.5, 37.5)) * CFrame.Angles(0, 0, math.rad(90)), COLORS.wood, M.WoodPlanks).Shape = Enum.PartType.Cylinder
	table.insert(building.spots, { part = chest, label = "Skrzynia", floor = f, room = 0 })
end

-- Buduje kamienicę w `origin` (róg budynku na poziomie podłogi parteru)
function BuildingBuilder.Build(origin: Vector3, parent: Instance, seed: number)
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Kamienica"
	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = model
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model

	local building = {
		model = model,
		geometry = geometry,
		decor = decor,
		origin = origin,
		rng = rng,
		floorY = {},
		spots = {},
		wardrobes = {},
		corridorLights = {},
		patrol = {},
		peeks = {},
		rooms = {},
	}
	for f = 0, FLOORS - 1 do
		building.floorY[f] = origin.Y + f * FLOOR_HEIGHT
	end

	for f = 0, FLOORS - 1 do
		buildSlab(building, f)
		buildCeiling(building, f)
		buildFloorWalls(building, f)
		if f < FLOORS - 1 then
			buildStairs(building, f)
			buildNook(building, f)
		else
			buildHoleRailing(building, f)
		end
	end
	Parts.Box(geometry, "Roof", origin + Vector3.new(-1.6, FLOORS * FLOOR_HEIGHT - 1, -1.6), origin + Vector3.new(W + 1.6, FLOORS * FLOOR_HEIGHT, D + 1.6), COLORS.fence, M.Slate)
	buildFacade(building, rng)
	buildYard(building)

	-- Pokoje: na parterze biuro + 3 mieszkania, na piętrach po 4 mieszkania
	local apartments = {}
	local number = 1
	for f = 0, FLOORS - 1 do
		for _, def in { { x0 = 0, south = true }, { x0 = 26, south = true }, { x0 = 0, south = false }, { x0 = 26, south = false } } do
			local room = { id = #building.rooms + 1, x0 = def.x0, south = def.south, floor = f, mirror = rng:NextNumber() < 0.5 }
			table.insert(building.rooms, room)
			if f == 0 and def.x0 == 0 and def.south then
				room.mirror = false
				room.office = true
			else
				room.number = number
				number += 1
				table.insert(apartments, room)
			end
		end
	end

	-- Jedno zamknięte mieszkanie na piętrze 1 albo 2 (bez mebli do przeszukania, za to ze słoikiem)
	local upper = {}
	for _, room in apartments do
		if room.floor >= 1 then
			table.insert(upper, room)
		end
	end
	local lockedRoom = upper[rng:NextInteger(1, #upper)]
	for _, room in building.rooms do
		if room.office then
			furnishOffice(building, room)
			doorway(building, room, "BIURO", rng, true)
		elseif room == lockedRoom then
			window(building, room)
			lockApartment(building, room)
			doorway(building, room, tostring(room.number), rng, false)
		else
			furnishApartment(building, room, rng)
			doorway(building, room, tostring(room.number), rng, true)
		end
	end

	-- Punkty patrolu (korytarz) i zaglądania (za progiem mieszkań) na każdym piętrze
	for f = 0, FLOORS - 1 do
		local y = building.floorY[f]
		building.patrol[f] = {}
		for _, x in { 4, 14, 26, 39, 48 } do
			table.insert(building.patrol[f], Vector3.new(origin.X + x, y, origin.Z + 20))
		end
		building.peeks[f] = {}
		for _, room in building.rooms do
			if room.floor == f and not room.office and room ~= lockedRoom then
				table.insert(building.peeks[f], roomPoint(building, room, 13, 4, 0))
			end
		end
	end
	building.catBed = Vector3.new(origin.X + 58, building.floorY[2], origin.Z + 33)
	building.neighborStart = Vector3.new(origin.X + 39, building.floorY[1], origin.Z + 20)
	building.spawn = CFrame.lookAt(origin + Vector3.new(7, 3, 20), origin + Vector3.new(20, 3, 20))

	-- Legowisko Mruczka w zakamarku na 2. piętrze: poduszka i miska
	Parts.Deco(decor, "CatBed", Vector3.new(1.2, 7, 7), CFrame.new(building.catBed + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(170, 60, 90), M.Fabric, Enum.PartType.Cylinder)
	Parts.Deco(decor, "CatBowl", Vector3.new(0.6, 1.8, 1.8), CFrame.new(building.catBed + Vector3.new(-4.5, 0.3, 4)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(90, 150, 220), M.SmoothPlastic, Enum.PartType.Cylinder)

	-- Lampy w środku migają u graczy (AmbienceController): zapisujemy jasność wyjściową i piętro
	for _, descendant in decor:GetDescendants() do
		if descendant:IsA("PointLight") and descendant.Parent and descendant.Parent.Name == "Lamp" then
			local lamp = descendant.Parent :: BasePart
			local y = lamp.CFrame.Position.Y - origin.Y
			if y > 0 and lamp.CFrame.Position.X > origin.X then
				descendant:SetAttribute("Base", descendant.Brightness)
				descendant:SetAttribute("Floor", math.clamp(math.floor(y / FLOOR_HEIGHT), 0, FLOORS - 1))
				CollectionService:AddTag(descendant, "Flicker")
			end
		end
	end

	model.Parent = parent
	return building
end

-- Ilość monet do rozłożenia po meblach (używa Round)
function BuildingBuilder.CoinsFor(rent: number): number
	return math.floor(rent * GameConfig.COINS_IN_BUILDING_RATIO)
end

return BuildingBuilder

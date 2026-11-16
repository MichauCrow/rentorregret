-- Kamienica na jedną rozgrywkę: parter (biuro Klucznika) + 2 piętra z mieszkaniami, klatka schodowa,
-- meble do przeszukania, szafy do chowania się, jedno zamknięte mieszkanie, ganek z wyjściem.
-- Wszystko z prostych klocków, budowane od zera dla każdej rundy (losowe ustawienie mebli).
--
-- Układ (współrzędne lokalne, origin = róg kamienicy na poziomie podłogi parteru):
--   X 0..52 mieszkania i korytarz, X 52..64 klatka schodowa, Z 16..24 korytarz, Y piętra co 14.
--   Pokoje: X 0..26 / 26..52, Z 0..16 (południe) / 24..40 (północ). Drzwi frontowe w ścianie X = 0.
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
local DOOR_WIDTH, DOOR_HEIGHT = 5, 9

BuildingBuilder.FLOOR_HEIGHT = FLOOR_HEIGHT
BuildingBuilder.FLOORS = FLOORS

local COLORS = {
	slab = Color3.fromRGB(92, 72, 62),
	corridorFloor = Color3.fromRGB(120, 60, 55),
	wall = Color3.fromRGB(170, 150, 120),
	wallFloor = {
		[0] = Color3.fromRGB(190, 170, 130), -- parter: ciepły beż
		[1] = Color3.fromRGB(120, 140, 120), -- 1. piętro: zgniła zieleń
		[2] = Color3.fromRGB(110, 110, 145), -- 2. piętro: chłodny fiolet
	},
	outer = Color3.fromRGB(105, 80, 70),
	stairs = Color3.fromRGB(110, 85, 65),
	wood = Color3.fromRGB(120, 80, 50),
	darkWood = Color3.fromRGB(80, 52, 35),
	fabric = { Color3.fromRGB(150, 60, 70), Color3.fromRGB(60, 90, 150), Color3.fromRGB(90, 130, 80), Color3.fromRGB(170, 120, 60) },
	metal = Color3.fromRGB(190, 195, 200),
	window = Color3.fromRGB(30, 45, 90),
	porch = Color3.fromRGB(90, 85, 80),
	fence = Color3.fromRGB(60, 50, 45),
	gold = Color3.fromRGB(255, 200, 60),
	jar = Color3.fromRGB(180, 230, 255),
}

-- Pomoc: ściana wzdłuż osi X (stałe z) lub osi Z (stałe x), z otworami { from, to, height }
local function wallAlongX(folder: Instance, origin: Vector3, x0: number, x1: number, z: number, y0: number, color: Color3, openings)
	local cursor = x0
	table.sort(openings, function(a, b)
		return a.from < b.from
	end)
	for _, opening in openings do
		if opening.from > cursor then
			Parts.Box(folder, "Wall", origin + Vector3.new(cursor, y0, z - 0.5), origin + Vector3.new(opening.from, y0 + WALL_HEIGHT, z + 0.5), color)
		end
		Parts.Box(folder, "Lintel", origin + Vector3.new(opening.from, y0 + opening.height, z - 0.5), origin + Vector3.new(opening.to, y0 + WALL_HEIGHT, z + 0.5), color)
		cursor = opening.to
	end
	if cursor < x1 then
		Parts.Box(folder, "Wall", origin + Vector3.new(cursor, y0, z - 0.5), origin + Vector3.new(x1, y0 + WALL_HEIGHT, z + 0.5), color)
	end
end

local function wallAlongZ(folder: Instance, origin: Vector3, z0: number, z1: number, x: number, y0: number, color: Color3, openings)
	local cursor = z0
	table.sort(openings, function(a, b)
		return a.from < b.from
	end)
	for _, opening in openings do
		if opening.from > cursor then
			Parts.Box(folder, "Wall", origin + Vector3.new(x - 0.5, y0, cursor), origin + Vector3.new(x + 0.5, y0 + WALL_HEIGHT, opening.from), color)
		end
		Parts.Box(folder, "Lintel", origin + Vector3.new(x - 0.5, y0 + opening.height, opening.from), origin + Vector3.new(x + 0.5, y0 + WALL_HEIGHT, opening.to), color)
		cursor = opening.to
	end
	if cursor < z1 then
		Parts.Box(folder, "Wall", origin + Vector3.new(x - 0.5, y0, cursor), origin + Vector3.new(x + 0.5, y0 + WALL_HEIGHT, z1), color)
	end
end

-- Pokój: x0 (lewy brzeg), south (czy po stronie Z 0..16), floor. Punkty w pokoju podajemy jako (u, v):
-- u = 0..26 wzdłuż X, v = 0 przy ścianie korytarza, 16 przy ścianie zewnętrznej.
local function roomPoint(building, room, u: number, v: number, h: number): Vector3
	local z = if room.south then CORRIDOR_MIN - v else CORRIDOR_MAX + v
	local x = if room.mirror then room.x0 + 26 - u else room.x0 + u
	return building.origin + Vector3.new(x, building.floorY[room.floor] - building.origin.Y + h, z)
end

-- Kierunek "do środka pokoju od ściany zewnętrznej" (w stronę korytarza)
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

-- Meble ------------------------------------------------------------------------------------------
-- Każdy mebel do przeszukania zwraca część, na której pojawi się podpowiedź.

local function bed(building, room, rng: Random)
	local folder = building.geometry
	local base = facing(roomPoint(building, room, 6, 11.5, 1), inward(room))
	local fabric = COLORS.fabric[rng:NextInteger(1, #COLORS.fabric)]
	local frame = Parts.Block(folder, "Bed", Vector3.new(5, 2, 8), base, COLORS.wood)
	Parts.Deco(building.decor, "Blanket", Vector3.new(5.1, 0.4, 5.5), base * CFrame.new(0, 1.15, -1.2), fabric, Enum.Material.Fabric)
	Parts.Deco(building.decor, "Pillow", Vector3.new(3.4, 0.6, 1.4), base * CFrame.new(0, 1.3, 3), Color3.fromRGB(235, 235, 225), Enum.Material.Fabric)
	Parts.Block(folder, "Headboard", Vector3.new(5, 4, 0.5), base * CFrame.new(0, 1, 3.95), COLORS.darkWood)
	return frame, "Łóżko"
end

local function dresser(building, room, _rng: Random)
	local base = facing(roomPoint(building, room, 13, 14.5, 1.5), inward(room))
	local body = Parts.Block(building.geometry, "Dresser", Vector3.new(5, 3, 2), base, COLORS.wood)
	for i = -1, 1, 2 do
		Parts.Deco(building.decor, "Drawer", Vector3.new(4.4, 1.1, 0.1), base * CFrame.new(0, i * 0.65, -1.02), COLORS.darkWood)
		Parts.Deco(building.decor, "Knob", Vector3.new(0.3, 0.3, 0.2), base * CFrame.new(0, i * 0.65, -1.1), COLORS.gold, Enum.Material.Metal, Enum.PartType.Ball)
	end
	return body, "Komoda"
end

local function fridge(building, room, _rng: Random)
	local base = facing(roomPoint(building, room, 2, 6, 3.25), along(room, 1))
	local body = Parts.Block(building.geometry, "Fridge", Vector3.new(3, 6.5, 3), base, Color3.fromRGB(225, 230, 235))
	Parts.Deco(building.decor, "Handle", Vector3.new(0.2, 2, 0.2), base * CFrame.new(1.1, 0.8, -1.55), COLORS.metal, Enum.Material.Metal)
	Parts.Deco(building.decor, "Magnet", Vector3.new(0.5, 0.5, 0.1), base * CFrame.new(-0.5, 1.6, -1.52), Color3.fromRGB(255, 90, 120))
	return body, "Lodówka"
end

local function shelf(building, room, rng: Random)
	local base = facing(roomPoint(building, room, 24.75, 8, 3), along(room, -1))
	local body = Parts.Block(building.geometry, "Shelf", Vector3.new(5, 6, 1.5), base, COLORS.darkWood)
	for row = 0, 2 do
		for i = 1, rng:NextInteger(1, 3) do
			Parts.Deco(building.decor, "Jar", Vector3.new(0.8, 1, 0.8), base * CFrame.new(-2 + i * 1.1, -1.8 + row * 1.9, -0.85), COLORS.jar, Enum.Material.Glass, Enum.PartType.Cylinder).CFrame =
				base * CFrame.new(-2 + i * 1.1, -1.8 + row * 1.9, -0.85) * CFrame.Angles(0, 0, math.rad(90))
		end
	end
	return body, "Regał ze słoikami"
end

local function tableSet(building, room, _rng: Random)
	local base = facing(roomPoint(building, room, 16, 7, 1.5), inward(room))
	local top = Parts.Block(building.geometry, "Table", Vector3.new(5, 0.4, 3.5), base * CFrame.new(0, 1.3, 0), COLORS.wood)
	for _, x in { -2.2, 2.2 } do
		for _, z in { -1.4, 1.4 } do
			Parts.Deco(building.decor, "Leg", Vector3.new(0.3, 2.8, 0.3), base * CFrame.new(x, -0.1, z), COLORS.darkWood)
		end
	end
	Parts.Deco(building.decor, "Cloth", Vector3.new(3, 0.05, 3.6), base * CFrame.new(0, 1.52, 0), Color3.fromRGB(240, 235, 220), Enum.Material.Fabric)
	return top, "Stół"
end

local function boxes(building, room, rng: Random)
	local base = facing(roomPoint(building, room, 22, 2.5, 1.25), inward(room))
	local bottom = Parts.Block(building.geometry, "Boxes", Vector3.new(3, 2.5, 3), base, Color3.fromRGB(190, 150, 100), Enum.Material.Cardboard)
	Parts.Block(building.geometry, "Box", Vector3.new(2.2, 1.8, 2.2), base * CFrame.new(0.2, 2.15, 0.1) * CFrame.Angles(0, math.rad(rng:NextInteger(-20, 20)), 0), Color3.fromRGB(205, 165, 115), Enum.Material.Cardboard)
	return bottom, "Pudła"
end

local function wardrobe(building, room, _rng: Random)
	local base = facing(roomPoint(building, room, 19.5, 14.25, 3.75), inward(room))
	local body = Parts.Block(building.geometry, "Wardrobe", Vector3.new(4.5, 7.5, 2.5), base, COLORS.darkWood)
	Parts.Deco(building.decor, "DoorL", Vector3.new(2.1, 6.9, 0.1), base * CFrame.new(-1.1, 0, -1.27), COLORS.wood)
	Parts.Deco(building.decor, "DoorR", Vector3.new(2.1, 6.9, 0.1), base * CFrame.new(1.1, 0, -1.27), COLORS.wood)
	for _, x in { -0.3, 0.3 } do
		Parts.Deco(building.decor, "Knob", Vector3.new(0.25, 0.25, 0.2), base * CFrame.new(x, 0, -1.35), COLORS.gold, Enum.Material.Metal, Enum.PartType.Ball)
	end
	-- Szczelina z oczami w środku (dla klimatu, gdy ktoś się chowa, oczy świecą)
	local eyes = Parts.Deco(building.decor, "HideEyes", Vector3.new(1, 0.25, 0.05), base * CFrame.new(0, 1.6, -1.33), Color3.fromRGB(255, 255, 220), Enum.Material.Neon)
	eyes.Transparency = 1
	-- Postać w środku szafy: na wysokości bioder, przodem do drzwi
	local inside = base * CFrame.new(0, -0.75, 0)
	local outside = base * CFrame.new(0, -0.75, -4)
	table.insert(building.wardrobes, { part = body, eyes = eyes, floor = room.floor, inside = inside, outside = outside })
end

local SEARCHABLE = { bed, dresser, fridge, shelf, tableSet, boxes }

local function window(building, room)
	local center = roomPoint(building, room, 8, 15.45, 6)
	local frame = facing(center, inward(room))
	Parts.Deco(building.decor, "WindowFrame", Vector3.new(4.6, 4.6, 0.2), frame, COLORS.darkWood)
	local glass = Parts.Deco(building.decor, "Window", Vector3.new(4, 4, 0.25), frame, COLORS.window, Enum.Material.Glass)
	glass.Transparency = 0.15
	Parts.Deco(building.decor, "WindowBar", Vector3.new(0.2, 4, 0.3), frame, COLORS.darkWood)
	Parts.Deco(building.decor, "WindowBar", Vector3.new(4, 0.2, 0.3), frame, COLORS.darkWood)
	-- Księżyc za oknem: chłodny, słaby blask
	local moon = Instance.new("SurfaceLight")
	moon.Face = Enum.NormalId.Front
	moon.Brightness = 0.6
	moon.Range = 10
	moon.Angle = 70
	moon.Color = Color3.fromRGB(120, 150, 255)
	moon.Parent = glass
end

local function furnishApartment(building, room, rng: Random)
	window(building, room)
	wardrobe(building, room, rng)
	for _, builder in SEARCHABLE do
		if rng:NextNumber() < 0.85 then
			local part, label = builder(building, room, rng)
			table.insert(building.spots, { part = part, label = label, floor = room.floor, room = room.id })
		end
	end
	-- Lampa pod sufitem: nie w każdym mieszkaniu (ciemne pokoje = latarka)
	if rng:NextNumber() < 0.45 then
		Parts.Lamp(building.decor, roomPoint(building, room, 13, 8, WALL_HEIGHT - 0.6), 0.35, 14)
	end
end

local function furnishOffice(building, room)
	window(building, room)
	local deskFrame = facing(roomPoint(building, room, 13, 9, 1.5), inward(room))
	Parts.Block(building.geometry, "Desk", Vector3.new(8, 3, 3), deskFrame, COLORS.darkWood)
	local box = Parts.Block(building.geometry, "RentBox", Vector3.new(2.4, 1.6, 1.6), deskFrame * CFrame.new(0, 2.3, -0.4), COLORS.gold, Enum.Material.Metal)
	Parts.Deco(building.decor, "Slot", Vector3.new(1.4, 0.1, 0.25), deskFrame * CFrame.new(0, 3.12, -0.4), Color3.fromRGB(30, 25, 20))
	Parts.Billboard(box, "💰 SKRZYNKA NA CZYNSZ", Color3.fromRGB(255, 220, 90), 2.2)
	building.depositBox = box
	building.landlordCFrame = facing(roomPoint(building, room, 13, 12.5, 0), inward(room))
	building.landlordModel = LandlordBuilder.Build(building.landlordCFrame, "🙂", building.decor)
	-- Tablica z kalendarzem i zegarem na ścianie
	local board = Parts.Deco(building.decor, "Board", Vector3.new(6, 3.5, 0.2), facing(roomPoint(building, room, 4.5, 15.4, 6.5), inward(room)), Color3.fromRGB(60, 90, 60))
	Parts.Sign(board, Enum.NormalId.Front, "CZYNSZ DO PÓŁNOCY!", Color3.fromRGB(255, 240, 200))
	Parts.Lamp(building.decor, roomPoint(building, room, 13, 8, WALL_HEIGHT - 0.6), 1, 22)
end

-- Zamknięte mieszkanie: drzwi w przejściu i słoik pełen monet w środku
local function lockApartment(building, room)
	local doorCenter = roomPoint(building, room, 13, 0, DOOR_HEIGHT / 2)
	local door = Parts.Block(building.geometry, "LockedDoor", Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, 0.6), facing(doorCenter, inward(room)), COLORS.darkWood, Enum.Material.Wood)
	Parts.Deco(building.decor, "Padlock", Vector3.new(0.9, 1.1, 0.4), facing(doorCenter, inward(room)) * CFrame.new(1.6, -0.5, 0.45), COLORS.gold, Enum.Material.Metal)
	Parts.Billboard(door, "🔒 ZAMKNIĘTE", Color3.fromRGB(255, 200, 90), 5.5, Vector2.new(200, 50))
	local jarBase = roomPoint(building, room, 13, 9, 1.5)
	local jar = Parts.Block(building.geometry, "CoinJar", Vector3.new(3, 3, 3), CFrame.new(jarBase) * CFrame.Angles(0, 0, math.rad(90)), COLORS.jar, Enum.Material.Glass)
	jar.Shape = Enum.PartType.Cylinder
	jar.Transparency = 0.3
	Parts.Deco(building.decor, "Coins", Vector3.new(2, 2.4, 2.4), CFrame.new(jarBase + Vector3.new(0, -0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), COLORS.gold, Enum.Material.Neon, Enum.PartType.Cylinder)
	local glow = Instance.new("PointLight")
	glow.Color = COLORS.gold
	glow.Brightness = 1.2
	glow.Range = 10
	glow.Parent = jar
	building.locked = { door = door, room = room.id, floor = room.floor, jar = jar }
end

local function doorSign(building, room, text: string)
	local center = roomPoint(building, room, 13, -0.55, DOOR_HEIGHT + 1.2)
	local plate = Parts.Deco(building.decor, "DoorSign", Vector3.new(2.6, 1.4, 0.1), facing(center, inward(room)), Color3.fromRGB(40, 35, 30))
	Parts.Sign(plate, Enum.NormalId.Front, text, COLORS.gold)
end

-- Klatka schodowa: pochylnie w dwóch biegach z podestem, ścianka między biegami
local function buildStairs(building, f: number)
	local o = building.origin
	local y0 = f * FLOOR_HEIGHT
	local g = building.geometry
	Parts.Ramp(g, "StairsA", o + Vector3.new(55.25, y0, 16), o + Vector3.new(55.25, y0 + 7, 4), 5.5, COLORS.stairs, Enum.Material.Wood)
	Parts.Box(g, "Landing", o + Vector3.new(52.5, y0 + 6, 0), o + Vector3.new(64, y0 + 7, 4), COLORS.stairs, Enum.Material.Wood)
	Parts.Ramp(g, "StairsB", o + Vector3.new(61, y0 + 7, 4), o + Vector3.new(61, y0 + 14, 16), 5.5, COLORS.stairs, Enum.Material.Wood)
	Parts.Box(g, "StairDivider", o + Vector3.new(57.75, y0, 4), o + Vector3.new(58.25, y0 + FLOOR_HEIGHT, 16), COLORS.outer)
	-- Tabliczka z numerem piętra na ścianie klatki (widać ją po wejściu po schodach)
	local floorLabel = Parts.Deco(building.decor, "FloorSign", Vector3.new(3, 1.5, 0.1), CFrame.lookAt(o + Vector3.new(52.6, y0 + FLOOR_HEIGHT + 4, 30), o + Vector3.new(60, y0 + FLOOR_HEIGHT + 4, 30)), Color3.fromRGB(40, 35, 30))
	Parts.Sign(floorLabel, Enum.NormalId.Front, "PIĘTRO " .. (f + 1), COLORS.gold)
end

local function buildSlab(building, f: number)
	local o = building.origin
	local y = f * FLOOR_HEIGHT
	local g = building.geometry
	if f == 0 then
		Parts.Box(g, "GroundSlab", o + Vector3.new(-1, -1, -1), o + Vector3.new(W + 1, 0, D + 1), COLORS.slab, Enum.Material.WoodPlanks)
		return
	end
	-- Podłoga piętra z dziurą nad biegiem schodów prowadzącym w górę (X 58..64, Z 4..16)
	Parts.Box(g, "Slab", o + Vector3.new(-1, y - 1, -1), o + Vector3.new(58, y, D + 1), COLORS.slab, Enum.Material.WoodPlanks)
	Parts.Box(g, "Slab", o + Vector3.new(58, y - 1, 16), o + Vector3.new(W + 1, y, D + 1), COLORS.slab, Enum.Material.WoodPlanks)
	Parts.Box(g, "Slab", o + Vector3.new(58, y - 1, -1), o + Vector3.new(W + 1, y, 4), COLORS.slab, Enum.Material.WoodPlanks)
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
	-- Ściany zewnętrzne
	wallAlongX(g, o, -1, W + 1, -0.5, y0, COLORS.outer, {})
	wallAlongX(g, o, -1, W + 1, D + 0.5, y0, COLORS.outer, {})
	local front = if f == 0 then { { from = 17.5, to = 22.5, height = DOOR_HEIGHT } } else {}
	wallAlongZ(g, o, 0, D, -0.5, y0, COLORS.outer, front)
	wallAlongZ(g, o, 0, D, W + 0.5, y0, COLORS.outer, {})
	-- Korytarz
	wallAlongX(g, o, 0, STAIR_X, CORRIDOR_MIN, y0, color, table.clone(doorOpenings))
	wallAlongX(g, o, 0, STAIR_X, CORRIDOR_MAX, y0, color, table.clone(doorOpenings))
	-- Ściany między pokojami i ściana klatki schodowej
	wallAlongZ(g, o, 0, CORRIDOR_MIN - 0.5, 26, y0, color, {})
	wallAlongZ(g, o, CORRIDOR_MAX + 0.5, D, 26, y0, color, {})
	wallAlongZ(g, o, 0, CORRIDOR_MIN - 0.5, STAIR_X, y0, color, {})
	wallAlongZ(g, o, CORRIDOR_MAX + 0.5, D, STAIR_X, y0, color, {})
	-- Chodnik w korytarzu
	Parts.Deco(building.decor, "Runner", Vector3.new(STAIR_X - 2, 0.05, 3), CFrame.new(o + Vector3.new(STAIR_X / 2, y0 + 0.03, 20)), COLORS.corridorFloor, Enum.Material.Fabric)
	-- Lampy w korytarzu: parter jaśniejszy (bezpieczny), wyżej coraz ciemniej
	local brightness = ({ [0] = 0.9, [1] = 0.45, [2] = 0.2 })[f]
	for _, x in { 8, 26, 44 } do
		local light = Parts.Lamp(building.decor, o + Vector3.new(x, y0 + WALL_HEIGHT - 0.6, 20), brightness, 18)
		table.insert(building.corridorLights, { light = light, floor = f })
	end
	Parts.Lamp(building.decor, o + Vector3.new(58, y0 + WALL_HEIGHT - 0.6, 30), brightness * 0.8, 16)
end

local function buildPorch(building)
	local o = building.origin
	local g = building.geometry
	Parts.Box(g, "Porch", o + Vector3.new(-28, -1, 2), o + Vector3.new(-1, 0, 38), COLORS.porch, Enum.Material.Cobblestone)
	-- Płot dookoła podwórka (nie da się wyjść poza nie)
	for _, z in { 2, 38 } do
		Parts.Box(g, "Fence", o + Vector3.new(-28, 0, z - 0.3), o + Vector3.new(-1, 7, z + 0.3), COLORS.fence, Enum.Material.Wood)
	end
	Parts.Box(g, "Fence", o + Vector3.new(-28.6, 0, 2), o + Vector3.new(-28, 7, 38), COLORS.fence, Enum.Material.Wood)
	-- Brama z napisem: miejsce ucieczki
	local gate = Parts.Deco(building.decor, "GateSign", Vector3.new(0.3, 3, 10), CFrame.new(o + Vector3.new(-27.5, 9, 20)), Color3.fromRGB(40, 30, 25))
	Parts.Sign(gate, Enum.NormalId.Right, "🏃 WYJŚCIE", Color3.fromRGB(120, 255, 140))
	local lampPost = Parts.Block(g, "LampPost", Vector3.new(0.6, 10, 0.6), CFrame.new(o + Vector3.new(-14, 5, 6)), COLORS.fence, Enum.Material.Metal)
	Parts.Lamp(building.decor, lampPost.CFrame.Position + Vector3.new(0, 5.3, 0), 1.2, 30, Color3.fromRGB(255, 210, 150))
	-- Drzwi frontowe (zamknięte do zapłaty czynszu albo północy)
	local door = Parts.Block(g, "FrontDoor", Vector3.new(0.8, DOOR_HEIGHT, DOOR_WIDTH), CFrame.new(o + Vector3.new(-0.5, DOOR_HEIGHT / 2, 20)), COLORS.darkWood, Enum.Material.Wood)
	Parts.Billboard(door, "🚪 Otworzy się po zapłacie czynszu", Color3.fromRGB(255, 230, 180), 6, Vector2.new(300, 50))
	building.frontDoor = door
	-- Strefa ucieczki: prostokąt przy bramie (sprawdzany w pętli rundy)
	building.exitMin = o + Vector3.new(-27, -1, 6)
	building.exitMax = o + Vector3.new(-16, 10, 34)
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
		buildFloorWalls(building, f)
		if f < FLOORS - 1 then
			buildStairs(building, f)
		end
	end
	-- Dach
	Parts.Box(geometry, "Roof", origin + Vector3.new(-1, FLOORS * FLOOR_HEIGHT - 1, -1), origin + Vector3.new(W + 1, FLOORS * FLOOR_HEIGHT, D + 1), COLORS.outer)
	buildPorch(building)

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
				furnishOffice(building, room)
				doorSign(building, room, "BIURO")
			else
				room.number = number
				doorSign(building, room, tostring(number))
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
	for _, room in apartments do
		if room == lockedRoom then
			window(building, room)
			lockApartment(building, room)
		else
			furnishApartment(building, room, rng)
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

	-- Legowisko Mruczka przy schodach na 2. piętrze
	local cushion = Parts.Deco(decor, "CatBed", Vector3.new(1.2, 7, 7), CFrame.new(building.catBed + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(170, 60, 90), Enum.Material.Fabric, Enum.PartType.Cylinder)
	cushion.Name = "CatBed"

	model.Parent = parent
	return building
end

-- Ilość monet do rozłożenia po meblach (używa Round)
function BuildingBuilder.CoinsFor(rent: number): number
	return math.floor(rent * GameConfig.COINS_IN_BUILDING_RATIO)
end

return BuildingBuilder

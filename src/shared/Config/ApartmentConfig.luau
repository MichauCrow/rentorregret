-- Mieszkania, brud i ocena stanu mieszkania (zatwierdzone w Fazie 1).
-- Współrzędne są lokalne względem środka podłogi mieszkania (front = -Z, ulica).
local ApartmentConfig = {}

-- Układ kamienicy
ApartmentConfig.BUILDING_ORIGIN = Vector3.new(-45, 0, 40) -- środek mieszkania nr 1
ApartmentConfig.UNIT_SPACING = 30
ApartmentConfig.PREBUILT_UNITS = 4

-- Drzwi i teleporty
ApartmentConfig.DOOR_Z = -10.5 -- wszystko dalej niż to (w stronę +Z) jest w środku
ApartmentConfig.DOOR_USE_DISTANCE = 12
ApartmentConfig.ENTRY_CFRAME = CFrame.new(0, 4, -7) * CFrame.Angles(0, math.pi, 0)
ApartmentConfig.OUTSIDE_CFRAME = CFrame.new(0, 4, -15)

-- Brud
ApartmentConfig.MAX_DIRT = 35
ApartmentConfig.STARTER_DIRT = 8 -- mieszkanie na start jest zaniedbane
-- holdTime = ile sekund trzeba przytrzymać przycisk, żeby posprzątać
ApartmentConfig.Dirt = {
	trash = { penalty = 3, weight = 45, holdTime = 1, name = "Śmieci", action = "Podnieś" },
	stain = { penalty = 2, weight = 35, holdTime = 1, name = "Plama", action = "Zmyj" },
	dishes = { penalty = 2, weight = 20, holdTime = 2, name = "Brudne naczynia", action = "Umyj" },
	-- Szkodniki (weight = 0: nie pojawiają się jako zwykły brud, tylko przy zaniedbaniu)
	bug = { penalty = 5, weight = 0, holdTime = 0.5, name = "Robak", action = "Pacnij klapkiem" },
	mold = { penalty = 0, weight = 0, holdTime = 3, name = "Pleśń", action = "Szoruj", comfortPenalty = 10 },
}

-- Awarie: fixture = nazwa części w modelu mieszkania, penalty = ile odejmuje od Sprawności,
-- repairCost = cena Złotej Rączki (naprawa samemu jest zawsze darmowa)
ApartmentConfig.Failures = {
	faucet = { name = "Kran", fixture = "KitchenSink", icon = "💧", minMonth = 2, weight = 30, penalty = 20, repairCost = 30, effect = "stain", effectInterval = 20 },
	toilet = { name = "Toaleta", fixture = "Toilet", icon = "🤢", minMonth = 2, weight = 25, penalty = 30, repairCost = 40, comfortPenalty = 10 },
	light = { name = "Światło", fixture = "LightSwitch", icon = "💡", minMonth = 3, weight = 25, penalty = 25, repairCost = 25 },
	fridge = { name = "Lodówka", fixture = "Fridge", icon = "🧊", minMonth = 4, weight = 20, penalty = 25, repairCost = 60, effect = "trash", effectInterval = 30 },
}
ApartmentConfig.FAILURE_WINDOW = { 40, 300 } -- sekundy miesiąca, w których może coś się zepsuć
ApartmentConfig.SECOND_FAILURE_FROM_MONTH = 6
ApartmentConfig.SECOND_FAILURE_CHANCE = 0.3
ApartmentConfig.DIY_SCREWS = 3 -- naprawa samemu: dokręć tyle śrub
ApartmentConfig.DIY_SCREW_HOLD = 1.5

-- Szkodniki pojawiają się tylko przy długim zaniedbaniu
ApartmentConfig.Pests = {
	BUG_THRESHOLD = 40, -- czystość poniżej tego...
	BUG_DELAY = 60, -- ...przez tyle sekund = pierwszy robak
	BUG_INTERVAL = 20, -- kolejne robaki co tyle sekund
	MAX_BUGS = 8,
	MOLD_THRESHOLD = 25,
	MOLD_DELAY = 90,
	MOLD_INTERVAL = 30,
	MAX_MOLD = 4,
}

-- Szansa na awarię w miesiącu: 0 w miesiącu 1, potem rośnie do 80%
function ApartmentConfig.FailureChance(month: number): number
	if month < 2 then
		return 0
	end
	return math.min(0.8, 0.35 + 0.07 * (month - 2))
end

-- Sprzątanie
ApartmentConfig.CLEAN_DISTANCE = 10 -- maks. odległość gracza od brudu (serwer)
ApartmentConfig.CLEAN_PROMPT_DISTANCE = 7 -- zasięg podpowiedzi
ApartmentConfig.HOLD_TOLERANCE = 0.8 -- akceptujemy 80% czasu przytrzymania (opóźnienia sieci)
ApartmentConfig.MIN_CLEAN_INTERVAL = 0.3 -- sekundy między kolejnymi sprzątnięciami
ApartmentConfig.HELPER_COIN_PER_ITEM = 1 -- pomoc w cudzym mieszkaniu (od Fazy 10)
ApartmentConfig.HELPER_COIN_CAP = 30 -- na miesiąc

-- Ocena: Czystość 50% + Sprawność 30% + Komfort 20%
ApartmentConfig.ScoreWeights = { cleanliness = 0.5, functionality = 0.3, comfort = 0.2 }
ApartmentConfig.StarThresholds = { 85, 70, 50, 30 } -- progi dla 5, 4, 3 i 2 gwiazdek

-- Układ mieszkania liczony z wymiarów (te same zasady dla wszystkich typów mieszkań):
-- łazienka w prawym tylnym rogu, kuchnia przy tylnej ścianie po lewej, łóżko z przodu po lewej, drzwi na środku frontu.
-- Współrzędne lokalne: środek podłogi, front (drzwi) na -Z.
local function wallSpot(x: number, z: number, wall: string)
	-- przód mebla patrzy w stronę pokoju
	local yaw = ({ leftWall = math.rad(-90), rightWall = math.rad(90), backWall = 0, frontWall = math.pi })[wall]
	return { type = "floor", cframe = CFrame.new(x, 1, z) * CFrame.Angles(0, yaw, 0) }
end

local function layout(width: number, depth: number, props)
	local hw, hd = width / 2, depth / 2
	local tier = {
		width = width,
		depth = depth,
		spawnCFrame = CFrame.new(-3, 4, -hd + 8) * CFrame.Angles(0, math.pi, 0),
		entryCFrame = CFrame.new(0, 4, -hd + 4) * CFrame.Angles(0, math.pi, 0),
		outsideCFrame = CFrame.new(0, 4, -hd - 4),
		doorZ = -hd + 0.5, -- wszystko dalej (w stronę +Z) jest w środku
		dirtZones = {
			{ minX = -hw + 7, maxX = hw - 9, minZ = -hd + 2, maxZ = hd - 4 },
			{ minX = hw - 9, maxX = hw - 1.5, minZ = -hd + 2, maxZ = hd - 9.5 },
			{ minX = -hw + 1, maxX = -hw + 6, minZ = -hd + 10, maxZ = hd - 4 },
			{ minX = hw - 6.5, maxX = hw - 2, minZ = hd - 6.8, maxZ = hd - 4 },
		},
		dishSpots = {
			Vector3.new(-hw + 2, 0, hd - 2),
			Vector3.new(-hw + 3.5, 0, hd - 2),
			Vector3.new(-hw + 8.25, 0, hd - 2),
		},
		dishY = 4.95,
		furnitureSpots = {
			wallSpot(-hw + 2.8, 3.5, "leftWall"),
			wallSpot((-hw + 12.5 + hw - 8) / 2, hd - 2.7, "backWall"),
			wallSpot(hw - 2.8, -hd + 6, "rightWall"),
			wallSpot(-hw + 7, -hd + 2.4, "frontWall"),
			wallSpot(hw - 6.5, -hd + 2.4, "frontWall"),
			{ type = "rug", cframe = CFrame.new(-1, 1, -1) },
		},
	}
	for key, value in props do
		if key == "extraSpots" then
			for _, spot in value do
				table.insert(tier.furnitureSpots, spot)
			end
		else
			tier[key] = value
		end
	end
	return tier
end

-- Typ mieszkania = etap (dzielnica). rows: rzędy mieszkań { origin, step, yaw, count }. Kolejne mieszkania
-- zapełniają pierwszy rząd, potem następny (serwer na 6 graczy = maks. 6 gospodarstw na typ).
ApartmentConfig.Tiers = {
	[1] = layout(28, 22, {
		name = "Klitka",
		baseComfort = 20,
		height = 12,
		windowsPerSide = 1,
		wallColor = Color3.fromRGB(235, 215, 170),
		floorColor = Color3.fromRGB(176, 132, 92),
		bed = "mattress",
		rows = {
			-- Kamienica przy głównej ulicy (między marketem a biurem mieszczą się 4 mieszkania)
			{ origin = Vector3.new(-45, 0, 40), step = Vector3.new(30, 0, 0), yaw = 0, count = 4 },
			-- Drugi rząd za kamienicą, frontem do tylnej ulicy
			{ origin = Vector3.new(-45, 0, 78), step = Vector3.new(30, 0, 0), yaw = math.pi, count = 4 },
		},
		prebuilt = 4,
	}),
	[2] = layout(36, 26, {
		name = "Mieszkanie z balkonem",
		baseComfort = 30,
		height = 13,
		windowsPerSide = 2,
		wallColor = Color3.fromRGB(200, 225, 245),
		floorColor = Color3.fromRGB(190, 150, 110),
		bed = "bed",
		balcony = true,
		rows = {
			-- front w stronę ulicy po północnej stronie
			{ origin = Vector3.new(-60, 0, -112), step = Vector3.new(40, 0, 0), yaw = math.pi, count = 6 },
			{ origin = Vector3.new(-100, 0, -112), step = Vector3.new(-40, 0, 0), yaw = math.pi, count = 2 },
		},
		prebuilt = 0,
		extraSpots = {
			wallSpot(-15.2, -1.5, "leftWall"),
			wallSpot(-3, 10.3, "backWall"),
			wallSpot(7, 10.3, "backWall"),
			wallSpot(15.2, -1, "rightWall"),
			wallSpot(-6, -10.6, "frontWall"),
			wallSpot(6, -10.6, "frontWall"),
		},
	}),
	[3] = layout(44, 30, {
		name = "Loft na wzgórzu",
		baseComfort = 40,
		height = 16,
		windowsPerSide = 3,
		wallColor = Color3.fromRGB(230, 230, 235),
		floorColor = Color3.fromRGB(120, 90, 70),
		bed = "bed",
		loft = true,
		rows = {
			-- 6 loftów mieści się w murach miasta (x od -152 do 152)
			{ origin = Vector3.new(-130, 0, 202), step = Vector3.new(52, 0, 0), yaw = 0, count = 6 },
		},
		prebuilt = 0,
		extraSpots = {
			wallSpot(-19.2, -1.5, "leftWall"),
			wallSpot(-19.2, 8.5, "leftWall"),
			wallSpot(-7, 12.3, "backWall"),
			wallSpot(-2, 12.3, "backWall"),
			wallSpot(7, 12.3, "backWall"),
			wallSpot(11.5, 12.3, "backWall"),
			wallSpot(19.2, -3, "rightWall"),
			wallSpot(19.2, 3, "rightWall"),
			wallSpot(-10, -12.6, "frontWall"),
			wallSpot(-5.5, -12.6, "frontWall"),
			wallSpot(5.5, -12.6, "frontWall"),
			wallSpot(10, -12.6, "frontWall"),
			{ type = "floor", cframe = CFrame.new(6, 1, 1) },
			{ type = "rug", cframe = CFrame.new(8, 1, -5) },
		},
	}),
}

-- Dobudowane piętra (zakładka "Dom" w sklepie). Każde piętro to pokój nad mieszkaniem z drabiną,
-- dodatkowymi miejscami na meble i komfortem. Pięter można dobudować dowolnie dużo (limit techniczny MAX_ROOMS),
-- ale każde kolejne jest droższe (x1.6). Monety są pobierane dopiero po ukończeniu minigry budowy.
ApartmentConfig.MAX_ROOMS = 30
-- Sprzedaż mebla (R przy meblu): zwrot takiej części ceny sklepowej
ApartmentConfig.SELL_RATE = 0.5
ApartmentConfig.Rooms = {}
local ROOM_EMOJIS = { "🛏️", "🎮", "🎨", "📚", "🎵", "🧸", "🚀", "🌈" }
for k = 1, ApartmentConfig.MAX_ROOMS do
	ApartmentConfig.Rooms[k] = {
		name = if k == 1 then "Pokój na piętrze" else string.format("Piętro %d", k),
		emoji = ROOM_EMOJIS[(k - 1) % #ROOM_EMOJIS + 1],
		price = math.floor(800 * 1.6 ^ (k - 1) / 50 + 0.5) * 50,
		month = if k == 1 then 2 elseif k == 2 then 4 else 5,
		comfort = math.max(3, 9 - k),
	}
end
-- Etapy minigry budowy: trafienia w zielone pole na pasku (jak przy naprawie)
ApartmentConfig.BuildStages = {
	{ id = "walls", title = "Murowanie", tool = "🧱", task = "Ułóż cegły równo!", button = "MURUJ!", steps = 3 },
	{ id = "windows", title = "Okna", tool = "🪟", task = "Wstaw okna na miejsce!", button = "WSTAW!", steps = 3 },
	{ id = "decor", title = "Wykończenie", tool = "🎨", task = "Pomaluj i podłącz lampę!", button = "MALUJ!", steps = 3 },
}

-- Wysokość góry podłogi piętra k (k = 0 to zwykłe mieszkanie)
function ApartmentConfig.RoomFloorTop(tier, k: number): number
	return 1 + k * (tier.height + 1)
end

-- Drabina na piętro k: punkt na podłodze piętra poniżej (współrzędne lokalne). Kolejne drabiny są przesunięte,
-- żeby podpowiedzi "Na dół" i "Na górę" na tym samym piętrze się nie nakładały.
function ApartmentConfig.LadderPoint(tier, k: number): Vector3
	local hw, hd = tier.width / 2, tier.depth / 2
	local z = if k % 2 == 1 then hd - 5 else hd - 10
	return Vector3.new(hw - 8.6, ApartmentConfig.RoomFloorTop(tier, k - 1), z)
end

-- Miejsca na meble na piętrze k (dokładane do miejsc mieszkania)
function ApartmentConfig.RoomSpots(tier, k: number)
	local hw, hd = tier.width / 2, tier.depth / 2
	local y = ApartmentConfig.RoomFloorTop(tier, k)
	local function spot(x: number, z: number, yaw: number)
		return { type = "floor", cframe = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0) }
	end
	local spots = {
		spot(-hw + 2.8, 0, math.rad(-90)),
		spot(hw - 2.8, -2, math.rad(90)),
		spot(-hw + 6, hd - 2.7, 0),
		spot(-hw + 7, -hd + 2.4, math.pi),
		{ type = "rug", cframe = CFrame.new(-2, y, -1) },
	}
	if k >= 2 then
		table.insert(spots, 4, spot(hw - 7, -hd + 2.4, math.pi))
	end
	return spots
end

-- Malowanie ścian (zakładka "Dom"): kolor + wykończenie, cena = suma obu. Zapis: data.apartment.paint[pokój] = { c, f }
-- Pokoje: "main" (pokój), "bath" (łazienka), "room1", "room2"... (piętra)
ApartmentConfig.Paint = {
	Colors = {
		{ name = "Śnieżnobiały", color = Color3.fromRGB(248, 248, 250), price = 20 },
		{ name = "Kremowy", color = Color3.fromRGB(245, 230, 200), price = 20 },
		{ name = "Miętowy", color = Color3.fromRGB(180, 235, 205), price = 30 },
		{ name = "Błękitny", color = Color3.fromRGB(175, 215, 250), price = 30 },
		{ name = "Lawendowy", color = Color3.fromRGB(210, 190, 245), price = 30 },
		{ name = "Brzoskwiniowy", color = Color3.fromRGB(255, 205, 175), price = 30 },
		{ name = "Cytrynowy", color = Color3.fromRGB(255, 240, 150), price = 40 },
		{ name = "Różowy", color = Color3.fromRGB(255, 185, 215), price = 40 },
		{ name = "Limonkowy", color = Color3.fromRGB(190, 240, 120), price = 50 },
		{ name = "Turkusowy", color = Color3.fromRGB(90, 210, 210), price = 50 },
		{ name = "Malinowy", color = Color3.fromRGB(225, 70, 120), price = 60 },
		{ name = "Czekoladowy", color = Color3.fromRGB(125, 85, 60), price = 60 },
		{ name = "Kosmiczny granat", color = Color3.fromRGB(40, 45, 110), price = 80 },
		{ name = "Złoty", color = Color3.fromRGB(255, 205, 70), price = 150, shine = 0.15 },
	},
	Finishes = {
		{ name = "Gładka farba", material = Enum.Material.SmoothPlastic, price = 0 },
		{ name = "Tynk", material = Enum.Material.Plaster, price = 40 },
		{ name = "Tapeta", material = Enum.Material.Fabric, price = 60 },
		{ name = "Cegła", material = Enum.Material.Brick, price = 100 },
		{ name = "Drewno", material = Enum.Material.WoodPlanks, price = 120 },
		{ name = "Lód", material = Enum.Material.Ice, price = 150 },
		{ name = "Marmur", material = Enum.Material.Marble, price = 200 },
		{ name = "Blacha", material = Enum.Material.DiamondPlate, price = 250 },
	},
	ROOM_DEFAULT = Color3.fromRGB(250, 240, 225),
}

-- Lista pokoi do malowania: pokój, łazienka i każde dobudowane piętro
function ApartmentConfig.PaintRooms(roomCount: number)
	local list = {
		{ id = "main", name = "Pokój" },
		{ id = "bath", name = "Łazienka" },
	}
	for k = 1, roomCount do
		table.insert(list, { id = "room" .. k, name = string.format("Piętro %d", k), floor = k })
	end
	return list
end

-- Co ile sekund pojawia się nowy brud: 40 s w miesiącu 1, 25 s od miesiąca 10
function ApartmentConfig.DirtInterval(month: number): number
	return math.max(25, 40 - (month - 1) * 15 / 9)
end

function ApartmentConfig.StarsForScore(score: number): number
	for index, threshold in ApartmentConfig.StarThresholds do
		if score >= threshold then
			return 6 - index
		end
	end
	return 1
end

-- Czy mebel o promieniu radius zmieści się w punkcie (x, z) mieszkania (współrzędne lokalne).
-- others = { { x, z, radius, rug } } – już postawione meble na tym samym piętrze. Dywan może leżeć pod meblami,
-- ale nie na innym dywanie. floor = 0 (mieszkanie) albo nr piętra, rooms = ile pięter dobudowano.
-- Używane przez serwer (sprawdzenie) i klienta (zielony/czerwony podgląd). Zwraca (ok, powód).
function ApartmentConfig.CanPlaceFurniture(tier, x: number, z: number, radius: number, rug: boolean, others, floor: number?, rooms: number?): (boolean, string?)
	floor = floor or 0
	rooms = rooms or 0
	local hw, hd = tier.width / 2, tier.depth / 2
	local margin = if rug then radius * 0.6 else radius * 0.75
	if x - margin < -hw + 1 or x + margin > hw - 1 or z - margin < -hd + 1 or z + margin > hd - 1 then
		return false, "wall"
	end
	local function inRect(minX: number, maxX: number, minZ: number, maxZ: number): boolean
		return x + margin > minX and x - margin < maxX and z + margin > minZ and z - margin < maxZ
	end
	-- Drabiny: na górę z tego piętra i (na piętrze) właz z drabiną z dołu
	local function nearLadder(k: number): boolean
		local ladder = ApartmentConfig.LadderPoint(tier, k)
		return inRect(ladder.X - 1.6, ladder.X + 1.6, ladder.Z - 1.8, ladder.Z + 1.8)
	end
	if floor + 1 <= rooms and nearLadder(floor + 1) then
		return false, "ladder"
	end
	if floor > 0 then
		if nearLadder(floor) then
			return false, "ladder"
		end
	else
		-- Strefy zajęte w mieszkaniu: łazienka, kuchnia z lodówką, łóżko, wejście, drzwi balkonowe
		if inRect(hw - 8.4, hw, hd - 8.4, hd) then
			return false, "bathroom"
		end
		if inRect(-hw, -hw + 12.6, hd - 3.3, hd) then
			return false, "kitchen"
		end
		if not rug and inRect(-hw, -hw + 5.9, -hd + 1.6, -hd + 10.4) then
			return false, "bed"
		end
		if not rug and inRect(-4, 4, -hd, -hd + 5) then
			return false, "door"
		end
		if tier.balcony and not rug and inRect(-1, 5, hd - 3, hd) then
			return false, "door"
		end
	end
	for _, other in others do
		if rug == (other.rug == true) then
			local distance = math.sqrt((other.x - x) ^ 2 + (other.z - z) ^ 2)
			if distance < (other.radius + radius) * 0.8 then
				return false, "furniture"
			end
		end
	end
	return true, nil
end

-- Na którym piętrze jest punkt (wysokość lokalna mieszkania); 0 = mieszkanie
function ApartmentConfig.FloorAt(tier, localY: number, rooms: number): number
	local floor = math.floor((localY - 1 + 2) / (tier.height + 1))
	return math.clamp(floor, 0, rooms)
end

-- Położenie mieszkania nr index danego typu (rzędy z tier.rows, nadmiar idzie dalej w ostatnim rzędzie)
function ApartmentConfig.UnitOrigin(tier, index: number): CFrame
	local remaining = index
	for rowIndex, row in tier.rows do
		if remaining <= row.count or rowIndex == #tier.rows then
			return CFrame.new(row.origin + row.step * (remaining - 1)) * CFrame.Angles(0, row.yaw, 0)
		end
		remaining -= row.count
	end
	return CFrame.new()
end

return ApartmentConfig

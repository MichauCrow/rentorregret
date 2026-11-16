-- Przydział mieszkań, drzwi, brud i ocena stanu mieszkania.
-- Stan brudu jest zapisywany w danych gracza i odtwarzany po powrocie do gry.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ApartmentConfig = require(ReplicatedStorage.Shared.Config.ApartmentConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local ApartmentBuilder = require(ServerScriptService.World.ApartmentBuilder)
local FurnitureBuilder = require(ReplicatedStorage.Shared.Modules.FurnitureBuilder)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)

local ApartmentService = {}

local units = {} -- [tier][index] = { tier, index, origin, model, door, signLabel, dirtFolder, furnitureFolder, owner }
local movedCallbacks = {}
local unitByPlayer = {} -- [player] = unit
local dirtTimers = {} -- [player] = sekundy od ostatniego brudu
local cosmeticWall = {} -- [player] = kolor ścian z kosmetyku (nadpisuje farbę w pokoju głównym)
local apartmentsFolder = nil
local rng = Random.new()

-- Haki ustawiane przez RoommateService (bez cyklicznych require)
local accessChecker = function(owner: Player, player: Player): boolean
	return owner == player
end
local dirtPaused = function(_player: Player): boolean
	return false
end
local homeResolver = function(player: Player): Player
	return player
end

local function round1(value: number): number
	return math.floor(value * 10 + 0.5) / 10
end

local function tierOf(data)
	return ApartmentConfig.Tiers[data.apartment.tier] or ApartmentConfig.Tiers[1]
end

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(cframe)
	end
end

-- wantsInside: true = podpowiedź "Wejdź", false = "Wyjdź"
local function onDoor(unit, player: Player, wantsInside: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if (root.Position - unit.door.Position).Magnitude > ApartmentConfig.DOOR_USE_DISTANCE then
		return
	end
	-- Strona drzwi liczona na serwerze, nie wierzymy klientowi
	local tier = ApartmentConfig.Tiers[unit.tier]
	local isInside = unit.origin:PointToObjectSpace(root.Position).Z > tier.doorZ
	if isInside ~= not wantsInside then
		return
	end
	if isInside then
		character:PivotTo(unit.origin * tier.outsideCFrame)
	elseif unit.owner and accessChecker(unit.owner, player) then
		character:PivotTo(unit.origin * tier.entryCFrame)
	elseif unit.owner then
		StateService.Notify(player, "To mieszkanie należy do " .. unit.owner.DisplayName, "info")
	else
		StateService.Notify(player, "To mieszkanie jest wolne", "info")
	end
end

local function getUnit(tierIndex: number, index: number)
	units[tierIndex] = units[tierIndex] or {}
	local unit = units[tierIndex][index]
	if unit then
		return unit
	end
	local tier = ApartmentConfig.Tiers[tierIndex]
	local origin = ApartmentConfig.UnitOrigin(tier, index)
	local built = ApartmentBuilder.Build(index, origin, apartmentsFolder, tier, tierIndex)
	local furnitureFolder = Instance.new("Folder")
	furnitureFolder.Name = "Furniture"
	furnitureFolder.Parent = built.model
	unit = {
		furnitureFolder = furnitureFolder,
		tier = tierIndex,
		index = index,
		origin = origin,
		model = built.model,
		door = built.door,
		signLabel = built.signLabel,
		dirtFolder = built.dirtFolder,
		owner = nil,
	}
	built.enterPrompt.Triggered:Connect(function(player)
		onDoor(unit, player, true)
	end)
	built.exitPrompt.Triggered:Connect(function(player)
		onDoor(unit, player, false)
	end)
	units[tierIndex][index] = unit
	return unit
end

local function findFreeUnit(tierIndex: number)
	local row = units[tierIndex] or {}
	local index = 1
	while row[index] and row[index].owner do
		index += 1
	end
	return getUnit(tierIndex, index)
end

local WALL_GROUPS = {
	main = { "WallBack", "WallLeft", "WallRight", "PaintLinerMain" },
	bath = { "BathWallFrontL", "BathWallFrontR", "BathWallFrontTop", "BathWallSide", "PaintLinerBath" },
}
local ROOM_WALLS = { "WallBack", "WallLeft", "WallRight", "WallFront", "Partition" }

local function roomsOf(data): number
	return math.clamp(math.floor(tonumber(data.apartment.rooms) or 0), 0, #ApartmentConfig.Rooms)
end

-- Farba wybrana dla pokoju: (kolor albo nil, materiał, połysk)
local function paintChoice(data, key: string): (Color3?, Enum.Material, number)
	local choice = data and data.apartment.paint and data.apartment.paint[key]
	local color = type(choice) == "table" and ApartmentConfig.Paint.Colors[choice.c]
	local finish = type(choice) == "table" and ApartmentConfig.Paint.Finishes[choice.f]
	return if color then color.color else nil, if finish then finish.material else Enum.Material.SmoothPlastic, if color then color.shine or 0 else 0
end

-- Kolory i wykończenie wszystkich ścian w domu (data = nil: wygląd domyślny pustego mieszkania).
-- Pokój główny: kosmetyk z zakładki Styl ma pierwszeństwo przed farbą.
local function applyPaint(unit, data, player: Player?)
	local tier = ApartmentConfig.Tiers[unit.tier]
	local function paint(container: Instance, names, color: Color3, material: Enum.Material, shine: number)
		for _, child in container:GetChildren() do
			if child:IsA("BasePart") and table.find(names, child.Name) then
				child.Color = color
				child.Material = material
				child.Reflectance = shine
			end
		end
	end
	local color, material, shine = paintChoice(data, "main")
	paint(unit.model, WALL_GROUPS.main, (player and cosmeticWall[player]) or color or tier.wallColor, material, shine)
	color, material, shine = paintChoice(data, "bath")
	paint(unit.model, WALL_GROUPS.bath, color or tier.wallColor, material, shine)
	local rooms = unit.model:FindFirstChild("Rooms")
	if rooms then
		for _, room in rooms:GetChildren() do
			color, material, shine = paintChoice(data, "room" .. tostring(room:GetAttribute("RoomIndex")))
			paint(room, ROOM_WALLS, color or ApartmentConfig.Paint.ROOM_DEFAULT, material, shine)
		end
	end
end

-- Drabina na piętro k: up = wchodzimy na piętro k, inaczej schodzimy piętro niżej
local function useLadder(unit, player: Player, k: number, up: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not unit.owner or not accessChecker(unit.owner, player) then
		return
	end
	local tier = ApartmentConfig.Tiers[unit.tier]
	local ladder = ApartmentConfig.LadderPoint(tier, k)
	local fromTop = ApartmentConfig.RoomFloorTop(tier, if up then k - 1 else k)
	local toTop = ApartmentConfig.RoomFloorTop(tier, if up then k else k - 1)
	if (unit.origin:PointToWorldSpace(Vector3.new(ladder.X, fromTop + 3, ladder.Z)) - root.Position).Magnitude > 10 then
		return
	end
	character:PivotTo(unit.origin * CFrame.new(ladder.X - 2.5, toTop + 3, ladder.Z) * CFrame.Angles(0, math.rad(90), 0))
end

-- Dobudowane piętra gracza (model w folderze "Rooms" mieszkania)
-- Dach z attyką na parterze widać tylko bez dobudowanych pięter (wtedy dach ma najwyższe piętro)
local function setGroundRoof(unit, visible: boolean)
	local roof = unit.model:FindFirstChild("RoofCap")
	if roof then
		for _, piece in roof:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Transparency = if visible then 0 else 1
			end
		end
	end
end

local function renderRooms(player: Player)
	local unit = unitByPlayer[player]
	local data = DataService.Get(player)
	if not unit or not data then
		return
	end
	local old = unit.model:FindFirstChild("Rooms")
	if old then
		old:Destroy()
	end
	local count = roomsOf(data)
	setGroundRoof(unit, count == 0)
	if count > 0 then
		local folder = Instance.new("Folder")
		folder.Name = "Rooms"
		folder.Parent = unit.model
		local tier = ApartmentConfig.Tiers[unit.tier]
		for k = 1, count do
			local built = ApartmentBuilder.BuildRoom(unit.origin, tier, k, folder, k == count)
			built.upPrompt.Triggered:Connect(function(who)
				useLadder(unit, who, k, true)
			end)
			built.downPrompt.Triggered:Connect(function(who)
				useLadder(unit, who, k, false)
			end)
		end
	end
	applyPaint(unit, data, player)
end

local function vacate(unit)
	local rooms = unit.model:FindFirstChild("Rooms")
	if rooms then
		rooms:Destroy()
	end
	setGroundRoof(unit, true)
	applyPaint(unit, nil, nil)
	unit.owner = nil
	unit.model:SetAttribute("OwnerUserId", 0)
	unit.dirtFolder:ClearAllChildren()
	unit.furnitureFolder:ClearAllChildren()
	unit.signLabel.Text = "WOLNE"
end

local function recalculate(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local apartment = data.apartment
	local penalty = 0
	local comfortPenalty = 0
	for _, dirt in apartment.dirt do
		local definition = ApartmentConfig.Dirt[dirt.kind]
		if definition then
			penalty += definition.penalty
			comfortPenalty += definition.comfortPenalty or 0
		end
	end
	local functionality = 100
	for failureId in apartment.failures do
		local failure = ApartmentConfig.Failures[failureId]
		if failure then
			functionality -= failure.penalty
			comfortPenalty += failure.comfortPenalty or 0
		end
	end
	local furnitureComfort = 0
	for k = 1, roomsOf(data) do
		furnitureComfort += ApartmentConfig.Rooms[k].comfort
	end
	for _, item in apartment.furniture do
		local definition = type(item) == "table" and ShopConfig.Items[item.id]
		if definition and definition.comfort then
			furnitureComfort += definition.comfort
		end
	end
	local weights = ApartmentConfig.ScoreWeights
	apartment.cleanliness = math.clamp(100 - penalty, 0, 100)
	apartment.functionality = math.clamp(functionality, 0, 100)
	apartment.comfort = math.clamp(tierOf(data).baseComfort + furnitureComfort - comfortPenalty, 0, 100)
	apartment.score = math.floor(
		apartment.cleanliness * weights.cleanliness
			+ apartment.functionality * weights.functionality
			+ apartment.comfort * weights.comfort
			+ 0.5
	)
	StateService.Push(player)
end

local function renderDirt(unit, tier, dirt)
	local y = 1.9
	if dirt.kind == "dishes" then
		y = tier.dishY
	elseif dirt.kind == "stain" then
		y = 1.05
	elseif dirt.kind == "mold" then
		y = 1.04
	elseif dirt.kind == "bug" then
		y = 1.25
	end
	local dirtPart = ApartmentBuilder.CreateDirt(dirt.kind, unit.origin * CFrame.new(dirt.x, y, dirt.z))
	dirtPart.Name = "Dirt_" .. dirt.id
	dirtPart:SetAttribute("DirtId", dirt.id)
	dirtPart:SetAttribute("DirtKind", dirt.kind)

	-- Podpowiedź do sprzątania (działa myszką, klawiszem E i dotykiem). Obsługa: CleaningService.
	local definition = ApartmentConfig.Dirt[dirt.kind]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CleanPrompt"
	prompt.ActionText = definition.action
	prompt.ObjectText = definition.name
	prompt.HoldDuration = definition.holdTime
	prompt.MaxActivationDistance = ApartmentConfig.CLEAN_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = dirtPart

	dirtPart.Parent = unit.dirtFolder
end

local function pickKind(): string
	local total = 0
	for _, definition in ApartmentConfig.Dirt do
		total += definition.weight
	end
	local roll = rng:NextNumber(0, total)
	for kind, definition in ApartmentConfig.Dirt do
		if definition.weight > 0 then
			if roll <= definition.weight then
				return kind
			end
			roll -= definition.weight
		end
	end
	return "trash"
end

local function pickFloorPoint(tier): (number, number)
	local total = 0
	for _, zone in tier.dirtZones do
		total += (zone.maxX - zone.minX) * (zone.maxZ - zone.minZ)
	end
	local roll = rng:NextNumber(0, total)
	for _, zone in tier.dirtZones do
		local area = (zone.maxX - zone.minX) * (zone.maxZ - zone.minZ)
		if roll <= area then
			return rng:NextNumber(zone.minX, zone.maxX), rng:NextNumber(zone.minZ, zone.maxZ)
		end
		roll -= area
	end
	local first = tier.dirtZones[1]
	return rng:NextNumber(first.minX, first.maxX), rng:NextNumber(first.minZ, first.maxZ)
end

local function freeDishSpot(apartment, tier): number?
	local used = {}
	for _, dirt in apartment.dirt do
		if dirt.kind == "dishes" and dirt.spot then
			used[dirt.spot] = true
		end
	end
	for index in tier.dishSpots do
		if not used[index] then
			return index
		end
	end
	return nil
end

-- Dodaje jeden brud (bez przeliczania oceny). Zwraca true, jeśli się udało.
local function addDirt(player: Player, kind: string?): boolean
	local unit = unitByPlayer[player]
	local data = DataService.Get(player)
	if not unit or not data then
		return false
	end
	local apartment = data.apartment
	if #apartment.dirt >= ApartmentConfig.MAX_DIRT then
		return false
	end
	local tier = tierOf(data)
	local dirt = { id = apartment.nextDirtId, kind = kind or pickKind() }
	apartment.nextDirtId += 1

	if dirt.kind == "dishes" then
		local spot = freeDishSpot(apartment, tier)
		if spot then
			dirt.spot = spot
			dirt.x = tier.dishSpots[spot].X
			dirt.z = tier.dishSpots[spot].Z
		else
			dirt.kind = "trash" -- blat pełny, zamiast naczyń pojawiają się śmieci
		end
	end
	if dirt.kind ~= "dishes" then
		local x, z = pickFloorPoint(tier)
		dirt.x = round1(x)
		dirt.z = round1(z)
	end

	table.insert(apartment.dirt, dirt)
	renderDirt(unit, tier, dirt)
	return true
end

-- Mebel postawiony przez gracza: ma zapisane x, z, obrót, piętro i typ mieszkania (po przeprowadzce wraca
-- na miejsce automatyczne; po zniknięciu piętra też)
local function floorOf(item): number
	return math.max(0, math.floor(tonumber(item.floor) or 0))
end

local function isPlaced(item, data): boolean
	return type(item.x) == "number" and type(item.z) == "number" and item.tier == data.apartment.tier and floorOf(item) <= roomsOf(data)
end

-- Postawione meble na danym piętrze jako lista do sprawdzania kolizji (bez mebla o numerze skipIndex)
local function placedList(data, skipIndex: number?, floor: number?)
	local list = {}
	for index, item in data.apartment.furniture do
		local definition = type(item) == "table" and ShopConfig.Items[item.id]
		if definition and index ~= skipIndex and isPlaced(item, data) and (floor == nil or floorOf(item) == floor) then
			table.insert(list, { x = item.x, z = item.z, radius = FurnitureBuilder.Footprint(item.id), rug = definition.spot == "rug", floor = floorOf(item) })
		end
	end
	return list
end

local startPlacement
local pendingPlacement = {} -- [player] = { index, floor } – piętro, na którym gracz właśnie ustawia mebel

-- Miejsca automatyczne na meble: mieszkanie + dobudowane piętra (z numerem piętra)
local function spotsFor(data)
	local tier = tierOf(data)
	local spots = {}
	for _, spot in tier.furnitureSpots do
		table.insert(spots, { type = spot.type, cframe = spot.cframe, floor = 0 })
	end
	for k = 1, roomsOf(data) do
		for _, spot in ApartmentConfig.RoomSpots(tier, k) do
			table.insert(spots, { type = spot.type, cframe = spot.cframe, floor = k })
		end
	end
	return spots
end

-- Ile mebli zmieści dom: miejsca automatyczne + kilka ekstra (meble można też stawiać samemu gdziekolwiek)
local function capacityOf(data): number
	return #spotsFor(data) + 6
end

-- Mebel bez miejsca automatycznego: szukamy wolnego punktu na siatce (najpierw mieszkanie, potem piętra) i zapisujemy go
local function autoPlace(data, index: number, item, definition): boolean
	local tier = tierOf(data)
	local radius = FurnitureBuilder.Footprint(item.id)
	local rug = definition.spot == "rug"
	local hw, hd = tier.width / 2, tier.depth / 2
	for floor = 0, roomsOf(data) do
		local others = placedList(data, index, floor)
		for z = -hd + 2, hd - 2, 1.5 do
			for x = -hw + 2, hw - 2, 1.5 do
				if ApartmentConfig.CanPlaceFurniture(tier, x, z, radius, rug, others, floor, roomsOf(data)) then
					item.x, item.z, item.rot, item.floor, item.tier = round1(x), round1(z), 0, floor, data.apartment.tier
					return true
				end
			end
		end
	end
	return false
end

-- Ustawia meble: najpierw te postawione przez gracza, potem resztę na wolnych miejscach automatycznych.
-- Każdy mebel ma podpowiedź "Przestaw" (klawisz R) dla właściciela: przestawienie albo sprzedaż.
local function renderFurniture(player: Player)
	local unit = unitByPlayer[player]
	local data = DataService.Get(player)
	if not unit or not data then
		return
	end
	unit.furnitureFolder:ClearAllChildren()
	local tier = tierOf(data)
	local spots = spotsFor(data)
	local used = {}
	local placed = placedList(data, nil, nil)
	local function addMoveHandle(model: Model, cframe: CFrame, index: number, name: string)
		local handle = Instance.new("Part")
		handle.Name = "MoveHandle"
		handle.Size = Vector3.new(1, 1, 1)
		handle.CFrame = cframe * CFrame.new(0, 2, 0)
		handle.Transparency = 1
		handle.Anchored = true
		handle.CanCollide = false
		handle.CanQuery = false
		handle.CanTouch = false
		handle.Parent = model
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "MovePrompt"
		prompt.ActionText = "Przestaw / sprzedaj"
		prompt.ObjectText = name
		prompt.KeyboardKeyCode = Enum.KeyCode.R
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = handle
		prompt.Triggered:Connect(function(who)
			if who == player and unitByPlayer[player] == unit then
				startPlacement(player, index)
			end
		end)
	end
	for index, item in data.apartment.furniture do
		local definition = type(item) == "table" and ShopConfig.Items[item.id]
		if definition then
			local cframe = nil
			if not isPlaced(item, data) then
				for spotIndex, spot in spots do
					if not used[spotIndex] and spot.type == definition.spot then
						used[spotIndex] = true
						-- Miejsce automatyczne zajęte przez postawiony mebel na tym piętrze? Szukamy dalej
						local position = spot.cframe.Position
						local blocked = false
						for _, other in placed do
							if other.floor == spot.floor and (other.rug == (definition.spot == "rug")) and math.sqrt((other.x - position.X) ^ 2 + (other.z - position.Z) ^ 2) < 2.5 then
								blocked = true
							end
						end
						if not blocked then
							cframe = unit.origin * spot.cframe
							break
						end
					end
				end
				if not cframe and autoPlace(data, index, item, definition) then
					table.insert(placed, { x = item.x, z = item.z, radius = FurnitureBuilder.Footprint(item.id), rug = definition.spot == "rug", floor = floorOf(item) })
				end
			end
			if not cframe and isPlaced(item, data) then
				cframe = unit.origin * CFrame.new(item.x, ApartmentConfig.RoomFloorTop(tier, floorOf(item)), item.z) * CFrame.Angles(0, math.rad(tonumber(item.rot) or 0), 0)
			end
			if cframe then
				local model = FurnitureBuilder.Build(item.id, cframe)
				if model then
					model:SetAttribute("FurnitureIndex", index)
					addMoveHandle(model, cframe, index, definition.name)
					model.Parent = unit.furnitureFolder
				end
			end
		end
	end
end

-- Cena odsprzedaży (połowa ceny sklepowej); nagród nie da się sprzedać
local function sellPriceOf(definition): number
	if definition.category ~= "furniture" then
		return 0
	end
	return math.floor(definition.price * ApartmentConfig.SELL_RATE + 0.5)
end

-- Piętro, na którym stoi gracz (0 = mieszkanie)
local function playerFloor(player: Player, unit, data): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return 0
	end
	return ApartmentConfig.FloorAt(tierOf(data), unit.origin:PointToObjectSpace(root.Position).Y, roomsOf(data))
end

-- Wysyła klientowi polecenie ustawiania mebla nr index na piętrze, na którym stoi gracz
-- (półprzezroczysty podgląd, obrót, zatwierdzenie albo sprzedaż)
startPlacement = function(player: Player, index: number)
	local unit = unitByPlayer[player]
	local data = DataService.Get(player)
	local item = data and data.apartment.furniture[index]
	local definition = type(item) == "table" and ShopConfig.Items[item.id]
	if not unit or not definition then
		return
	end
	local floor = playerFloor(player, unit, data)
	pendingPlacement[player] = { index = index, floor = floor }
	RemoteService.Event(RemoteNames.Events.FurniturePlace):FireClient(player, {
		index = index,
		itemId = item.id,
		name = definition.name,
		emoji = definition.emoji,
		origin = unit.origin,
		tier = data.apartment.tier,
		floor = floor,
		floorY = ApartmentConfig.RoomFloorTop(tierOf(data), floor),
		rooms = roomsOf(data),
		rug = definition.spot == "rug",
		rot = tonumber(item.rot) or 0,
		others = placedList(data, index, floor),
		sellPrice = sellPriceOf(definition),
	})
end

local function sellFurniture(player: Player, data, index: number)
	local item = data.apartment.furniture[index]
	local definition = type(item) == "table" and ShopConfig.Items[item.id]
	local price = definition and sellPriceOf(definition) or 0
	if price <= 0 then
		StateService.Notify(player, "Tego nie da się sprzedać.", "warn")
		return
	end
	table.remove(data.apartment.furniture, index)
	pendingPlacement[player] = nil
	EconomyService.AddCoins(player, price, "sell:" .. item.id)
	renderFurniture(player)
	recalculate(player)
	StateService.Notify(player, string.format("💰 Sprzedano: %s %s (+%d monet)", definition.emoji, definition.name, price), "good")
end

-- Klient zatwierdził miejsce (albo sprzedaż): serwer sprawdza zasady jeszcze raz i zapisuje pozycję
local function onFurnitureAction(player: Player, index: any, action: any, x: any, z: any, rot: any)
	local data = DataService.Get(player)
	local unit = unitByPlayer[player]
	if not data or not unit or not RemoteService.IsInteger(index, 1, #data.apartment.furniture) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not ApartmentService.IsInside(player) then
		return
	end
	if action == "sell" then
		sellFurniture(player, data, index)
		return
	end
	if action ~= "place" then
		return
	end
	local item = data.apartment.furniture[index]
	local definition = type(item) == "table" and ShopConfig.Items[item.id]
	if not definition or type(x) ~= "number" or type(z) ~= "number" or type(rot) ~= "number" or x ~= x or z ~= z or rot ~= rot then
		return
	end
	local pending = pendingPlacement[player]
	local floor = if pending and pending.index == index then pending.floor else playerFloor(player, unit, data)
	pendingPlacement[player] = nil
	if floor ~= playerFloor(player, unit, data) then
		StateService.Notify(player, "Stań na tym piętrze, na którym ustawiasz mebel.", "warn")
		return
	end
	local tier = tierOf(data)
	local ok = ApartmentConfig.CanPlaceFurniture(tier, x, z, FurnitureBuilder.Footprint(item.id), definition.spot == "rug", placedList(data, index, floor), floor, roomsOf(data))
	if not ok then
		StateService.Notify(player, "Tu się nie zmieści. Wybierz inne miejsce!", "warn")
		return
	end
	item.x = round1(x)
	item.z = round1(z)
	item.rot = math.floor(rot % 360 + 0.5)
	item.floor = floor
	item.tier = data.apartment.tier
	renderFurniture(player)
	StateService.Notify(player, "✅ Mebel ustawiony: " .. definition.emoji .. " " .. definition.name, "good")
end

local function assign(player: Player, data)
	-- Nowy etap = lepsze mieszkanie (tylko w górę; eksmisja nie zabiera mieszkania).
	-- Przy przeprowadzce meble jadą z graczem, a nowe mieszkanie jest czyste i sprawne.
	local moved = false
	local wantedTier = math.clamp(data.stage, 1, #ApartmentConfig.Tiers)
	if data.apartment.tier < wantedTier then
		data.apartment.tier = wantedTier
		data.apartment.dirt = {}
		data.apartment.failures = {}
		moved = true
		local tierInfo = ApartmentConfig.Tiers[wantedTier]
		StateService.Notify(
			player,
			string.format("🎉 Przeprowadzka! Nowe mieszkanie: %s (%d miejsc na meble).", tierInfo.name, #tierInfo.furnitureSpots),
			"good"
		)
	end
	local unit = unitByPlayer[player]
	if unit and unit.tier ~= data.apartment.tier then
		vacate(unit)
		unitByPlayer[player] = nil
		unit = nil
		moved = true
	end
	if not unit then
		unit = findFreeUnit(data.apartment.tier)
		unit.owner = player
		unitByPlayer[player] = unit
		unit.model:SetAttribute("OwnerUserId", player.UserId)
		unit.signLabel.Text = "Dom: " .. player.DisplayName
	end

	-- Odtwórz zapisany brud (pomijając uszkodzone wpisy)
	unit.dirtFolder:ClearAllChildren()
	local tier = tierOf(data)
	local valid = {}
	for _, dirt in data.apartment.dirt do
		if type(dirt) == "table" and ApartmentConfig.Dirt[dirt.kind] and type(dirt.x) == "number" and type(dirt.z) == "number" then
			table.insert(valid, dirt)
			renderDirt(unit, tier, dirt)
		end
	end
	data.apartment.dirt = valid

	-- Pierwsze wejście: mieszkanie jest zaniedbane
	if not data.apartment.initialized then
		data.apartment.initialized = true
		for _ = 1, ApartmentConfig.STARTER_DIRT do
			addDirt(player)
		end
	end

	dirtTimers[player] = 0
	renderRooms(player)
	renderFurniture(player)
	recalculate(player)
	ApartmentService.TeleportToApartment(player, homeResolver(player))
	if moved then
		for _, callback in movedCallbacks do
			task.spawn(callback, player)
		end
	end
end

local function release(player: Player)
	local unit = unitByPlayer[player]
	if not unit then
		return
	end
	unitByPlayer[player] = nil
	dirtTimers[player] = nil
	cosmeticWall[player] = nil
	pendingPlacement[player] = nil
	vacate(unit)
end

local function onCharacterAdded(player: Player, character: Model)
	if not character:WaitForChild("HumanoidRootPart", 10) then
		return
	end
	task.wait() -- poczekaj, aż Roblox ustawi postać na SpawnLocation
	ApartmentService.TeleportToApartment(player, homeResolver(player))
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end

-- API dla innych serwisów --------------------------------------------------

function ApartmentService.GetUnit(player: Player)
	return unitByPlayer[player]
end

-- Zwraca właściciela mieszkania, do którego należy dany obiekt (np. brud)
function ApartmentService.GetOwnerOfInstance(instance: Instance): Player?
	for _, row in units do
		for _, unit in row do
			if unit.owner and instance:IsDescendantOf(unit.model) then
				return unit.owner
			end
		end
	end
	return nil
end

-- Wołane, gdy gracz przeniósł się do nowego mieszkania (callback(player))
function ApartmentService.OnMoved(callback)
	table.insert(movedCallbacks, callback)
end

-- Sprawdza, czy gracz powinien mieć już lepsze mieszkanie (np. po nowym miesiącu) i je przydziela
function ApartmentService.CheckUpgrade(player: Player)
	local data = DataService.Get(player)
	if data and data.apartment.tier < math.clamp(data.stage, 1, #ApartmentConfig.Tiers) then
		assign(player, data)
	end
end

-- Usuwa brud o podanym id z mieszkania gracza. Zwraca rodzaj brudu albo nil.
function ApartmentService.RemoveDirt(owner: Player, dirtId: number): string?
	local unit = unitByPlayer[owner]
	local data = DataService.Get(owner)
	if not unit or not data then
		return nil
	end
	for index, dirt in data.apartment.dirt do
		if dirt.id == dirtId then
			table.remove(data.apartment.dirt, index)
			local dirtPart = unit.dirtFolder:FindFirstChild("Dirt_" .. dirtId)
			if dirtPart then
				dirtPart:Destroy()
			end
			recalculate(owner)
			return dirt.kind
		end
	end
	return nil
end

-- Czy gracz może sprzątać i wchodzić do mieszkania właściciela (właściciel, współlokatorzy, "drzwi otwarte")
function ApartmentService.CanClean(owner: Player, player: Player): boolean
	return accessChecker(owner, player)
end

function ApartmentService.CanEnter(owner: Player, player: Player): boolean
	return accessChecker(owner, player)
end

function ApartmentService.SetAccessChecker(checker)
	accessChecker = checker
end

-- Gracz mieszkający u kogoś: w jego własnym mieszkaniu nie przybywa brudu
function ApartmentService.SetDirtPausedChecker(checker)
	dirtPaused = checker
end

-- Do czyjego mieszkania gracz wraca (własne albo gospodarza)
function ApartmentService.SetHomeResolver(resolver)
	homeResolver = resolver
end

function ApartmentService.TeleportToApartment(player: Player, owner: Player)
	local unit = unitByPlayer[owner] or unitByPlayer[player]
	local data = DataService.Get(owner) or DataService.Get(player)
	if unit and data then
		teleport(player, unit.origin * tierOf(data).spawnCFrame)
	end
end

-- Kolor ścian z kosmetyku (nil = brak, wtedy widać farbę kupioną w zakładce Dom)
function ApartmentService.PaintWalls(player: Player, color: Color3?)
	cosmeticWall[player] = color
	ApartmentService.ApplyPaint(player)
end

function ApartmentService.HasCosmeticWalls(player: Player): boolean
	return cosmeticWall[player] ~= nil
end

-- Odmalowuje ściany wg zapisanej farby (po zakupie farby)
function ApartmentService.ApplyPaint(player: Player)
	local unit = unitByPlayer[player]
	if unit then
		applyPaint(unit, DataService.Get(player), player)
	end
end

-- Po dobudowaniu piętra: nowe piętra, miejsca na meble i komfort
function ApartmentService.RenderRooms(player: Player)
	renderRooms(player)
	renderFurniture(player)
	recalculate(player)
end

-- Przenosi gracza na piętro k jego mieszkania (obok drabiny)
function ApartmentService.TeleportToRoom(player: Player, k: number)
	local unit = unitByPlayer[player]
	if unit then
		local tier = ApartmentConfig.Tiers[unit.tier]
		local ladder = ApartmentConfig.LadderPoint(tier, k)
		teleport(player, unit.origin * CFrame.new(ladder.X - 2.5, ApartmentConfig.RoomFloorTop(tier, k) + 3, ladder.Z) * CFrame.Angles(0, math.rad(90), 0))
	end
end

-- Czy gracz stoi w swoim mieszkaniu (na dowolnym piętrze)
function ApartmentService.IsInside(player: Player): boolean
	local unit = unitByPlayer[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not unit or not root then
		return false
	end
	local tier = ApartmentConfig.Tiers[unit.tier]
	local localPosition = unit.origin:PointToObjectSpace(root.Position)
	return math.abs(localPosition.X) < tier.width / 2 and math.abs(localPosition.Z) < tier.depth / 2 and localPosition.Y > 0
end

function ApartmentService.RenderFurniture(player: Player)
	renderFurniture(player)
end

-- Po zakupie mebla: gracz wybiera miejsce (podgląd u klienta)
function ApartmentService.StartPlacement(player: Player, index: number)
	startPlacement(player, index)
end

-- Ile mebli można jeszcze kupić (wspólny limit dla mebli i dywanów; spotType zostaje dla zgodności)
function ApartmentService.FreeSpots(player: Player, _spotType: string): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local count = 0
	for _, item in data.apartment.furniture do
		if type(item) == "table" and ShopConfig.Items[item.id] then
			count += 1
		end
	end
	return math.max(0, capacityOf(data) - count)
end

-- Usuwa pierwszy brud z podanych rodzajów (robot sprzątający). Zwraca rodzaj i pozycję.
function ApartmentService.RemoveOneDirt(owner: Player, kinds: { string }): (string?, Vector3?)
	local unit = unitByPlayer[owner]
	local data = DataService.Get(owner)
	if not unit or not data then
		return nil, nil
	end
	for _, dirt in data.apartment.dirt do
		if table.find(kinds, dirt.kind) then
			local dirtPart = unit.dirtFolder:FindFirstChild("Dirt_" .. dirt.id)
			local position = dirtPart and dirtPart.Position
			return ApartmentService.RemoveDirt(owner, dirt.id), position
		end
	end
	return nil, nil
end

function ApartmentService.GetDirtCount(owner: Player): number
	local data = DataService.Get(owner)
	return if data then #data.apartment.dirt else 0
end

function ApartmentService.Recalculate(player: Player)
	recalculate(player)
end

-- Dodaje brud konkretnego rodzaju (np. przez awarię albo szkodniki). Zwraca id brudu albo nil.
function ApartmentService.AddDirt(player: Player, kind: string): number?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local id = data.apartment.nextDirtId
	if addDirt(player, kind) then
		recalculate(player)
		return id
	end
	return nil
end

function ApartmentService.HasDirt(owner: Player, dirtId: number): boolean
	local data = DataService.Get(owner)
	if not data then
		return false
	end
	for _, dirt in data.apartment.dirt do
		if dirt.id == dirtId then
			return true
		end
	end
	return false
end

function ApartmentService.CountDirt(owner: Player, kind: string): number
	local data = DataService.Get(owner)
	local count = 0
	if data then
		for _, dirt in data.apartment.dirt do
			if dirt.kind == kind then
				count += 1
			end
		end
	end
	return count
end

-- Losowy punkt na podłodze mieszkania gracza (współrzędne świata, wysokość podłogi)
function ApartmentService.RandomFloorPoint(player: Player): Vector3?
	local unit = unitByPlayer[player]
	local data = DataService.Get(player)
	if not unit or not data then
		return nil
	end
	local x, z = pickFloorPoint(tierOf(data))
	return unit.origin:PointToWorldSpace(Vector3.new(x, 1, z))
end

function ApartmentService.SpawnDirt(player: Player, count: number): number
	local added = 0
	for _ = 1, count do
		if addDirt(player) then
			added += 1
		end
	end
	if added > 0 then
		recalculate(player)
	end
	return added
end

function ApartmentService.TeleportHome(player: Player)
	ApartmentService.TeleportToApartment(player, homeResolver(player))
end

function ApartmentService.Init()
	apartmentsFolder = Instance.new("Folder")
	apartmentsFolder.Name = "Apartments"
	apartmentsFolder.Parent = Workspace
	for tierIndex, tier in ApartmentConfig.Tiers do
		for index = 1, tier.prebuilt do
			getUnit(tierIndex, index)
		end
	end
	DataService.OnLoaded(assign)
	RemoteService.OnServerEvent(RemoteNames.Events.FurnitureAction, 4, onFurnitureAction)
end

function ApartmentService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- Brud pojawia się tylko wtedy, gdy gracz jest w grze
	task.spawn(function()
		while true do
			task.wait(1)
			for player in unitByPlayer do
				local data = DataService.Get(player)
				if data and not dirtPaused(player) then
					dirtTimers[player] = (dirtTimers[player] or 0) + 1
					if dirtTimers[player] >= ApartmentConfig.DirtInterval(data.month) then
						dirtTimers[player] = 0
						if addDirt(player) then
							recalculate(player)
						end
					end
				end
			end
		end
	end)
end

return ApartmentService

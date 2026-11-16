-- Zakładka "Dom": malowanie wszystkich ścian (kolor + wykończenie) i dobudowa pięter (bez limitu, każde kolejne droższe).
-- Budowa piętra to minigra w 3 etapach (mury, okna, wykończenie): nad mieszkaniem stoi półprzezroczysty
-- szkic pokoju z rusztowaniem i po każdym etapie pojawiają się kolejne części. Monety są pobierane
-- dopiero po ukończeniu budowy, a gracz od razu trafia do nowego pokoju.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local ApartmentConfig = require(ReplicatedStorage.Shared.Config.ApartmentConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local ApartmentBuilder = require(ServerScriptService.World.ApartmentBuilder)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local ApartmentService = require(Services.ApartmentService)

local HomeService = {}

local MIN_HIT_INTERVAL = 0.45
local BUILD_TIMEOUT = 180
local GHOST_TRANSPARENCY = 0.88
local SCAFFOLD_COLOR = Color3.fromRGB(255, 200, 40)

local builds = {} -- [player] = { k, stage, hits, lastHit, started, built, ghost }

local function roomsOf(data): number
	return math.clamp(math.floor(tonumber(data.apartment.rooms) or 0), 0, #ApartmentConfig.Rooms)
end

local function paintState(data)
	local paint = {}
	for key, choice in data.apartment.paint do
		if type(choice) == "table" then
			paint[key] = { c = choice.c, f = choice.f }
		end
	end
	return paint
end

-- Malowanie pokoju: "main", "bath" albo "roomN" (dobudowane piętro)
local function paintRoom(player: Player, roomId: any, colorIndex: any, finishIndex: any): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, "Chwila, wczytuję dane..."
	end
	local room = nil
	for _, entry in ApartmentConfig.PaintRooms(roomsOf(data)) do
		if entry.id == roomId then
			room = entry
		end
	end
	local paint = ApartmentConfig.Paint
	if not room or not RemoteService.IsInteger(colorIndex, 1, #paint.Colors) or not RemoteService.IsInteger(finishIndex, 1, #paint.Finishes) then
		return false, "Nieznany kolor."
	end
	local current = data.apartment.paint[room.id]
	if type(current) == "table" and current.c == colorIndex and current.f == finishIndex then
		return false, "Ten pokój już tak wygląda!"
	end
	local color, finish = paint.Colors[colorIndex], paint.Finishes[finishIndex]
	local price = color.price + finish.price
	if not EconomyService.TrySpend(player, price, "paint:" .. room.id) then
		return false, "Za mało monet."
	end
	data.apartment.paint[room.id] = { c = colorIndex, f = finishIndex }
	ApartmentService.ApplyPaint(player)
	StateService.Push(player)
	return true, string.format("🎨 Pomalowano: %s (%s, %s)!", room.name, color.name, finish.name)
end

local function buildState(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local count = roomsOf(data)
	-- Karty: ostatnie dobudowane piętro, następne do zbudowania i jedno dalej (podgląd ceny)
	local rooms = {}
	for k = math.max(1, count), math.min(count + 2, #ApartmentConfig.Rooms) do
		local room = ApartmentConfig.Rooms[k]
		table.insert(rooms, {
			index = k,
			name = room.name,
			emoji = room.emoji,
			price = room.price,
			month = room.month,
			comfort = room.comfort,
			spots = #ApartmentConfig.RoomSpots(ApartmentConfig.Tiers[1], k),
			built = k <= count,
			unlocked = data.highestMonth >= room.month,
			next = k == count + 1,
		})
	end
	return {
		coins = data.coins,
		rooms = rooms,
		roomCount = count,
		maxRooms = #ApartmentConfig.Rooms,
		paint = paintState(data),
		cosmeticWalls = ApartmentService.HasCosmeticWalls(player),
		building = builds[player] ~= nil,
	}
end

-- Budowa piętra ---------------------------------------------------------------------

local function sendGame(player: Player, action: string, payload)
	RemoteService.Event(RemoteNames.Events.BuildGame):FireClient(player, action, payload)
end

local function stagePayload(session)
	local stage = ApartmentConfig.BuildStages[session.stage]
	local room = ApartmentConfig.Rooms[session.k]
	return {
		roomName = room.name,
		emoji = room.emoji,
		stage = session.stage,
		stageCount = #ApartmentConfig.BuildStages,
		title = stage.title,
		tool = stage.tool,
		task = stage.task,
		button = stage.button,
		steps = stage.steps,
	}
end

-- Rusztowanie dookoła szkicu pokoju
local function addScaffold(model: Model, origin: CFrame, tier, floorTop: number)
	local folder = Instance.new("Folder")
	folder.Name = "Scaffold"
	local hw, hd = tier.width / 2 + 1.2, tier.depth / 2 + 1.2
	local function pole(size: Vector3, cframe: CFrame)
		local p = Instance.new("Part")
		p.Name = "Scaffold"
		p.Size = size
		p.CFrame = cframe
		p.Color = SCAFFOLD_COLOR
		p.Material = Enum.Material.Metal
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = folder
	end
	local h = tier.height + 1
	for _, x in { -hw, hw } do
		for _, z in { -hd, hd } do
			pole(Vector3.new(0.4, h, 0.4), origin * CFrame.new(x, floorTop + h / 2, z))
		end
		pole(Vector3.new(0.3, 0.3, hd * 2), origin * CFrame.new(x, floorTop + h * 0.5, 0))
		pole(Vector3.new(0.3, 0.3, hd * 2), origin * CFrame.new(x, floorTop + h - 0.3, 0))
	end
	for _, z in { -hd, hd } do
		pole(Vector3.new(hw * 2, 0.3, 0.3), origin * CFrame.new(0, floorTop + h * 0.5, z))
		pole(Vector3.new(hw * 2, 1, 1.6), origin * CFrame.new(0, floorTop + h * 0.5 - 0.6, z + (if z < 0 then -0.8 else 0.8)))
	end
	folder.Parent = model
end

local function destroyGhost(session)
	if session.ghost then
		session.ghost:Destroy()
		session.ghost = nil
	end
end

local function revealStage(session, stageId: string)
	for _, p in session.built.stages[stageId] or {} do
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Transparency = p:GetAttribute("BuildTransparency") or 0 }):Play()
		end
	end
	if stageId == "decor" then
		for _, light in session.built.model:GetDescendants() do
			if light:IsA("PointLight") then
				light.Enabled = true
			end
		end
	end
end

local function endBuild(player: Player, success: boolean, message: string?)
	local session = builds[player]
	if not session then
		return
	end
	builds[player] = nil
	destroyGhost(session)
	sendGame(player, "close", { success = success, message = message })
end

local function startBuild(player: Player, k: any): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, "Chwila, wczytuję dane..."
	end
	if builds[player] then
		return false, "Budowa już trwa!"
	end
	local room = ApartmentConfig.Rooms[k]
	if not RemoteService.IsInteger(k, 1, #ApartmentConfig.Rooms) or not room then
		return false, "Nieznany pokój."
	end
	if k <= roomsOf(data) then
		return false, "To piętro już stoi!"
	end
	if k ~= roomsOf(data) + 1 then
		return false, "Najpierw dobuduj poprzednie piętro."
	end
	if data.highestMonth < room.month then
		return false, string.format("Dostępne od miesiąca %d.", room.month)
	end
	if not EconomyService.CanAfford(player, room.price) then
		return false, string.format("Za mało monet (potrzeba %d 💰).", room.price)
	end
	local unit = ApartmentService.GetUnit(player)
	if not unit then
		return false, "Najpierw wprowadź się do mieszkania."
	end
	if not ApartmentService.IsInside(player) then
		ApartmentService.TeleportHome(player)
	end
	-- Szkic pokoju nad mieszkaniem: wszystko prawie przezroczyste, podpowiedzi i światło wyłączone
	local tier = ApartmentConfig.Tiers[unit.tier]
	local ghost = Instance.new("Model")
	ghost.Name = "RoomBuild"
	ghost.Parent = unit.model
	local built = ApartmentBuilder.BuildRoom(unit.origin, tier, k, ghost, true)
	for _, d in built.model:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetAttribute("BuildTransparency", d.Transparency)
			d.Transparency = if d.Transparency >= 1 then 1 else GHOST_TRANSPARENCY
			d.CanCollide = false
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = false
		elseif d:IsA("PointLight") then
			d.Enabled = false
		end
	end
	addScaffold(ghost, unit.origin, tier, ApartmentConfig.RoomFloorTop(tier, k))
	local now = os.clock()
	local session = { k = k, stage = 1, hits = 0, lastHit = now, started = now, built = built, ghost = ghost }
	builds[player] = session
	sendGame(player, "open", stagePayload(session))
	return true, string.format("🏗️ Budujemy: %s!", room.name)
end

local function finishBuild(player: Player, session)
	local room = ApartmentConfig.Rooms[session.k]
	local data = DataService.Get(player)
	if not data or roomsOf(data) ~= session.k - 1 then
		endBuild(player, false, "Coś poszło nie tak. Spróbuj jeszcze raz.")
		return
	end
	if not EconomyService.TrySpend(player, room.price, "room:" .. session.k) then
		endBuild(player, false, string.format("Za mało monet (potrzeba %d 💰).", room.price))
		return
	end
	data.apartment.rooms = session.k
	builds[player] = nil
	destroyGhost(session)
	ApartmentService.RenderRooms(player)
	StateService.Push(player)
	sendGame(player, "close", { success = true, message = string.format("%s %s gotowy! +%d komfortu", room.emoji, room.name, room.comfort) })
	StateService.Notify(player, string.format("🎉 Nowe piętro: %s! +%d komfortu i nowe miejsca na meble.", room.name, room.comfort), "good")
	-- Po chwili gracz staje w nowym pokoju (konfetti jak przy \"czysto\")
	task.delay(1.6, function()
		if player.Parent then
			ApartmentService.TeleportToRoom(player, session.k)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, root.Position + Vector3.new(0, 2, 0), "allClean", 0)
			end
		end
	end)
end

local function onBuildAction(player: Player, action: any)
	local session = builds[player]
	if not session then
		return
	end
	if action == "cancel" then
		endBuild(player, false, nil)
		return
	end
	if action ~= "hit" then
		return
	end
	local now = os.clock()
	if now - session.lastHit < MIN_HIT_INTERVAL then
		return
	end
	session.lastHit = now
	session.hits += 1
	local stage = ApartmentConfig.BuildStages[session.stage]
	if session.hits < stage.steps then
		return
	end
	revealStage(session, stage.id)
	session.stage += 1
	session.hits = 0
	if session.stage > #ApartmentConfig.BuildStages then
		finishBuild(player, session)
	else
		sendGame(player, "stage", stagePayload(session))
	end
end

local function onHomeAction(player: Player, action: any, a: any, b: any, c: any)
	if action == "get" then
		return { ok = true, state = buildState(player) }
	end
	local ok, message = false, "Nieznana akcja."
	if action == "build" then
		ok, message = startBuild(player, a)
	elseif action == "paint" then
		ok, message = paintRoom(player, a, b, c)
		if ok then
			StateService.Notify(player, message, "good")
		end
	end
	return { ok = ok, message = message, state = buildState(player) }
end

function HomeService.Init()
	RemoteService.OnServerInvoke(RemoteNames.Functions.HomeAction, 4, onHomeAction)
	RemoteService.OnServerEvent(RemoteNames.Events.BuildAction, 6, onBuildAction)
end

function HomeService.Start()
	Players.PlayerRemoving:Connect(function(player)
		local session = builds[player]
		if session then
			builds[player] = nil
			destroyGhost(session)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for player, session in builds do
				if now - session.started > BUILD_TIMEOUT then
					endBuild(player, false, "Budowa przerwana (za długo). Spróbuj jeszcze raz!")
				end
			end
		end
	end)
end

return HomeService

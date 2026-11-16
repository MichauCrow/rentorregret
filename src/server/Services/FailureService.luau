-- Awarie w mieszkaniu (kran, toaleta, światło, lodówka), szkodniki (robaki, pleśń) i awaria prądu.
-- Każdą awarię można naprawić za darmo (minigra: 3 trafienia w zielone pole na pasku, RepairController)
-- albo szybko za monety (Złota Rączka). Serwer liczy trafienia, pilnuje odstępu między nimi i odległości.
-- Stan awarii jest zapisywany w danych gracza i odtwarzany po powrocie do gry.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ApartmentConfig = require(ReplicatedStorage.Shared.Config.ApartmentConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local HoldPrompt = require(ServerScriptService.Lib.HoldPrompt)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local ApartmentService = require(Services.ApartmentService)
local MonthService = require(Services.MonthService)
local RoommateService = require(Services.RoommateService)

local FailureService = {}

local PESTS = ApartmentConfig.Pests
local DIY_PROMPT_HOLD = 1
local HANDYMAN_HOLD = 0.5
local BUG_WIGGLE_INTERVAL = 2
local BUG_WANDER = 1.5

local visuals = {} -- [player] = { unit, entries = { [failureId] = { instances } } }
local diy = {} -- [player] = { [failureId] = pozostałe śruby }
local plans = {} -- [player] = { month, times }
local effectTimers = {} -- [player] = { [failureId] = sekundy }
local pestState = {} -- [player] = { bugSince, moldSince, lastBug, lastMold }
local outages = {} -- [player] = { box, onFixed }
local repairSessions = {} -- [kto naprawia] = { owner, failureId, hits }
local MIN_HIT_INTERVAL = 0.5 -- szybciej niż to nie da się trafić w minigrze (ochrona przed spamem)
local REPAIR_DISTANCE = 16
local rng = Random.new()

local function repairsFolder(unit): Folder
	local folder = unit.model:FindFirstChild("Repairs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Repairs"
		folder.Parent = unit.model
	end
	return folder
end

local function getFixture(unit, failureId: string): BasePart?
	local definition = ApartmentConfig.Failures[failureId]
	return definition and unit.model:FindFirstChild(definition.fixture)
end

local function setLights(unit, on: boolean)
	for _, lamp in unit.model:GetChildren() do
		if lamp.Name == "Lamp" or lamp.Name == "BathLamp" or lamp.Name == "LampExtra" then
			lamp.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			local light = lamp:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = on
			end
		end
	end
end

local function updateLights(player: Player)
	local unit = ApartmentService.GetUnit(player)
	local data = DataService.Get(player)
	if unit and data then
		setLights(unit, not data.apartment.failures.light and not outages[player])
	end
end

local function iconBillboard(adornee: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, adornee.Size.Y / 2 + 1.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 60
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 120, 100)
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	return gui
end

local function clearEntry(player: Player, failureId: string)
	local state = visuals[player]
	local entry = state and state.entries[failureId]
	if entry then
		for _, instance in entry.instances do
			instance:Destroy()
		end
		state.entries[failureId] = nil
	end
	if diy[player] then
		diy[player][failureId] = nil
	end
end

-- Zamyka minigry naprawy tej awarii (po naprawie albo gdy ktoś inny ją naprawił)
local function closeRepairSessions(owner: Player, failureId: string, success: boolean)
	for who, session in repairSessions do
		if session.owner == owner and session.failureId == failureId then
			repairSessions[who] = nil
			if who.Parent then
				RemoteService.Event(RemoteNames.Events.RepairGame):FireClient(who, "close", { success = success })
			end
		end
	end
end

local function fix(owner: Player, failureId: string, byHandyman: boolean)
	local data = DataService.Get(owner)
	if not data or not data.apartment.failures[failureId] then
		return
	end
	closeRepairSessions(owner, failureId, not byHandyman)
	local unit = ApartmentService.GetUnit(owner)
	local fixture = unit and getFixture(unit, failureId)
	data.apartment.failures[failureId] = nil
	clearEntry(owner, failureId)
	if effectTimers[owner] then
		effectTimers[owner][failureId] = nil
	end
	updateLights(owner)
	ApartmentService.Recalculate(owner)
	local name = ApartmentConfig.Failures[failureId].name
	if byHandyman then
		StateService.Notify(owner, "Złota Rączka naprawiła: " .. name, "good")
	else
		StateService.Notify(owner, "Brawo! Naprawione własnymi rękami: " .. name, "good")
	end
	if fixture then
		RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(owner, fixture.Position, "repair", 0)
	end
end

local function startDiy(owner: Player, failureId: string, who: Player)
	local data = DataService.Get(owner)
	local unit = ApartmentService.GetUnit(owner)
	if not data or not unit or not data.apartment.failures[failureId] or not ApartmentService.CanClean(owner, who) then
		return
	end
	diy[owner] = diy[owner] or {}
	if diy[owner][failureId] then
		return -- śruby już leżą
	end
	local fixture = getFixture(unit, failureId)
	local entry = visuals[owner] and visuals[owner].entries[failureId]
	if not fixture or not entry then
		return
	end
	diy[owner][failureId] = nil
	-- Minigra u gracza, który naprawia (też współlokator); serwer liczy trafienia
	repairSessions[who] = { owner = owner, failureId = failureId, hits = 0, lastHit = os.clock() }
	local definition = ApartmentConfig.Failures[failureId]
	RemoteService.Event(RemoteNames.Events.RepairGame):FireClient(who, "open", {
		failureId = failureId,
		name = definition.name,
		icon = definition.icon,
		steps = ApartmentConfig.DIY_SCREWS,
	})
end

-- Trafienie w minigrze naprawy (albo jej zamknięcie)
local function onRepairAction(player: Player, failureId: any, action: any)
	local session = repairSessions[player]
	if not session or failureId ~= session.failureId or not RemoteService.IsOneOf(action, { "hit", "cancel" }) then
		return
	end
	if action == "cancel" then
		repairSessions[player] = nil
		return
	end
	local owner = session.owner
	local data = DataService.Get(owner)
	local unit = ApartmentService.GetUnit(owner)
	local fixture = unit and getFixture(unit, failureId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not data.apartment.failures[failureId] or not fixture or not root then
		repairSessions[player] = nil
		return
	end
	if (root.Position - fixture.Position).Magnitude > REPAIR_DISTANCE then
		repairSessions[player] = nil
		RemoteService.Event(RemoteNames.Events.RepairGame):FireClient(player, "close", { success = false })
		return
	end
	local now = os.clock()
	if now - session.lastHit < MIN_HIT_INTERVAL then
		return
	end
	session.lastHit = now
	session.hits += 1
	RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, fixture.Position, "repair", 0)
	if session.hits >= ApartmentConfig.DIY_SCREWS then
		fix(owner, failureId, false)
	end
end

local function callHandyman(owner: Player, failureId: string, who: Player)
	local data = DataService.Get(owner)
	if who ~= owner or not data or not data.apartment.failures[failureId] then
		return
	end
	local cost = ApartmentConfig.Failures[failureId].repairCost
	if EconomyService.TrySpend(owner, cost, "handyman:" .. failureId) then
		fix(owner, failureId, true)
	else
		StateService.Notify(owner, "Za mało monet. Napraw samodzielnie, to nic nie kosztuje!", "warn")
	end
end

local function showFailure(owner: Player, failureId: string)
	local unit = ApartmentService.GetUnit(owner)
	local fixture = unit and getFixture(unit, failureId)
	if not fixture then
		return
	end
	visuals[owner] = visuals[owner] or { unit = unit, entries = {} }
	clearEntry(owner, failureId)
	local definition = ApartmentConfig.Failures[failureId]
	local entry = { instances = {} }

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 70, 70)
	highlight.OutlineColor = Color3.fromRGB(255, 230, 80)
	highlight.FillTransparency = 0.5
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = fixture
	table.insert(entry.instances, highlight)
	table.insert(entry.instances, iconBillboard(fixture, definition.icon .. " Awaria!"))

	table.insert(entry.instances, HoldPrompt.Create(fixture, {
		action = "Napraw samodzielnie (za darmo)",
		object = definition.name,
		hold = DIY_PROMPT_HOLD,
		activation = 8,
		maxDistance = 12,
	}, function(who)
		startDiy(owner, failureId, who)
	end))

	local handyman = HoldPrompt.Create(fixture, {
		action = string.format("Złota Rączka (%d monet)", definition.repairCost),
		object = definition.name,
		hold = HANDYMAN_HOLD,
		activation = 8,
		maxDistance = 12,
	}, function(who)
		callHandyman(owner, failureId, who)
	end)
	-- Inny klawisz i przesunięcie, żeby obie podpowiedzi były widoczne naraz
	handyman.KeyboardKeyCode = Enum.KeyCode.F
	handyman.GamepadKeyCode = Enum.KeyCode.ButtonY
	handyman.UIOffset = Vector2.new(0, 80)
	table.insert(entry.instances, handyman)

	visuals[owner].entries[failureId] = entry
	updateLights(owner)
end

local function breakFixture(player: Player, failureId: string)
	local data = DataService.Get(player)
	if not data or data.apartment.failures[failureId] then
		return
	end
	data.apartment.failures[failureId] = true
	showFailure(player, failureId)
	ApartmentService.Recalculate(player)
	local definition = ApartmentConfig.Failures[failureId]
	StateService.Notify(
		player,
		string.format("%s Zepsuło się: %s! Napraw samodzielnie za darmo albo wezwij Złotą Rączkę.", definition.icon, definition.name),
		"warn"
	)
end

local function pickFailure(data, ignoreMonth: boolean): string?
	local candidates = {}
	local total = 0
	for failureId, definition in ApartmentConfig.Failures do
		if not data.apartment.failures[failureId] and (ignoreMonth or data.month >= definition.minMonth) then
			table.insert(candidates, failureId)
			total += definition.weight
		end
	end
	if #candidates == 0 then
		return nil
	end
	local roll = rng:NextNumber(0, total)
	for _, failureId in candidates do
		local weight = ApartmentConfig.Failures[failureId].weight
		if roll <= weight then
			return failureId
		end
		roll -= weight
	end
	return candidates[1]
end

local function clearVisuals(player: Player)
	local state = visuals[player]
	if state then
		for failureId in state.entries do
			clearEntry(player, failureId)
		end
		setLights(state.unit, true)
		local folder = state.unit.model:FindFirstChild("Repairs")
		if folder then
			folder:ClearAllChildren()
		end
	end
	visuals[player] = nil
	diy[player] = nil
end

local function onLoaded(player: Player, data)
	-- Mieszkanie jest przydzielane w ApartmentService w tym samym momencie; poczekaj chwilę, jeśli trzeba
	local unit = ApartmentService.GetUnit(player)
	for _ = 1, 50 do
		if unit or not player.Parent then
			break
		end
		task.wait(0.1)
		unit = ApartmentService.GetUnit(player)
	end
	if not unit then
		return
	end
	clearVisuals(player)
	visuals[player] = { unit = unit, entries = {} }
	for failureId in data.apartment.failures do
		if ApartmentConfig.Failures[failureId] then
			showFailure(player, failureId)
		end
	end
	updateLights(player)
	ApartmentService.Recalculate(player)
end

-- Planowanie awarii w miesiącu, efekty awarii i szkodniki (co sekundę)
local function tickPlayer(player: Player, data, now: number)
	-- Plan awarii na bieżący miesiąc
	local plan = plans[player]
	if not plan or plan.month ~= data.month then
		plan = { month = data.month, times = {} }
		if rng:NextNumber() < ApartmentConfig.FailureChance(data.month) then
			table.insert(plan.times, rng:NextInteger(ApartmentConfig.FAILURE_WINDOW[1], ApartmentConfig.FAILURE_WINDOW[2]))
		end
		if data.month >= ApartmentConfig.SECOND_FAILURE_FROM_MONTH and rng:NextNumber() < ApartmentConfig.SECOND_FAILURE_CHANCE then
			table.insert(plan.times, rng:NextInteger(ApartmentConfig.FAILURE_WINDOW[1], ApartmentConfig.FAILURE_WINDOW[2]))
		end
		table.sort(plan.times)
		-- Po powrocie do gry w tym samym miesiącu nie powtarzamy już wykorzystanych awarii
		for _ = 1, math.min(data.monthly.failures, #plan.times) do
			table.remove(plan.times, 1)
		end
		plans[player] = plan
	end
	if plan.times[1] and data.monthElapsed >= plan.times[1] and MonthService.IsRunning(player) then
		table.remove(plan.times, 1)
		local failureId = pickFailure(data, false)
		if failureId then
			data.monthly.failures += 1
			breakFixture(player, failureId)
		end
	end

	-- Efekty: cieknący kran robi plamy, zepsuta lodówka robi śmieci
	local timers = effectTimers[player] or {}
	effectTimers[player] = timers
	for failureId in data.apartment.failures do
		local definition = ApartmentConfig.Failures[failureId]
		if definition and definition.effect then
			timers[failureId] = (timers[failureId] or 0) + 1
			if timers[failureId] >= definition.effectInterval then
				timers[failureId] = 0
				ApartmentService.AddDirt(player, definition.effect)
			end
		end
	end

	-- Szkodniki przy długim zaniedbaniu
	local pests = pestState[player] or { lastBug = 0, lastMold = 0 }
	pestState[player] = pests
	local cleanliness = data.apartment.cleanliness
	if cleanliness < PESTS.BUG_THRESHOLD then
		pests.bugSince = pests.bugSince or now
		if now - pests.bugSince >= PESTS.BUG_DELAY
			and now - pests.lastBug >= PESTS.BUG_INTERVAL
			and ApartmentService.CountDirt(player, "bug") < PESTS.MAX_BUGS
		then
			pests.lastBug = now
			if ApartmentService.CountDirt(player, "bug") == 0 then
				StateService.Notify(player, "🐛 W bałaganie zalęgły się robaki! Pacnij je klapkiem i posprzątaj.", "warn")
			end
			ApartmentService.AddDirt(player, "bug")
		end
	else
		pests.bugSince = nil
	end
	if cleanliness < PESTS.MOLD_THRESHOLD then
		pests.moldSince = pests.moldSince or now
		if now - pests.moldSince >= PESTS.MOLD_DELAY
			and now - pests.lastMold >= PESTS.MOLD_INTERVAL
			and ApartmentService.CountDirt(player, "mold") < PESTS.MAX_MOLD
		then
			pests.lastMold = now
			StateService.Notify(player, "🦠 Pojawiła się pleśń! Wyszoruj ją, bo psuje komfort.", "warn")
			ApartmentService.AddDirt(player, "mold")
		end
	else
		pests.moldSince = nil
	end
end

-- Robaki się ruszają (tylko wygląd; po zapisie wracają na swoje miejsce)
local function wiggleBugs()
	for player in visuals do
		local unit = ApartmentService.GetUnit(player)
		if unit then
			for _, dirt in unit.dirtFolder:GetChildren() do
				if dirt:GetAttribute("DirtKind") == "bug" then
					local home = dirt:GetAttribute("Home")
					if not home then
						home = dirt.Position
						dirt:SetAttribute("Home", home)
					end
					local offset = Vector3.new(rng:NextNumber(-BUG_WANDER, BUG_WANDER), 0, rng:NextNumber(-BUG_WANDER, BUG_WANDER))
					dirt.CFrame = CFrame.new(home + offset) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				end
			end
		end
	end
end

-- Awaria prądu (EventService): ciemno, dopóki gracz nie włączy bezpieczników albo nie minie czas
function FailureService.SetOutage(player: Player, active: boolean, holdTime: number?, onFixed)
	local unit = ApartmentService.GetUnit(player)
	if not unit then
		return
	end
	if outages[player] then
		outages[player].box:Destroy()
		outages[player] = nil
	end
	if active then
		local box = Instance.new("Part")
		box.Name = "FuseBox"
		box.Size = Vector3.new(0.4, 2.4, 1.8)
		box.CFrame = unit.model.FuseBoxSpot.CFrame -- lewa ściana, z dala od drzwi
		box.Color = Color3.fromRGB(120, 125, 135)
		box.Material = Enum.Material.DiamondPlate
		box.Anchored = true
		iconBillboard(box, "⚡ Bezpieczniki")
		HoldPrompt.Create(box, { action = "Włącz bezpieczniki", object = "Skrzynka", hold = holdTime or 2, activation = 8, maxDistance = 12 }, function(who)
			if outages[player] and ApartmentService.CanClean(player, who) then
				onFixed()
			end
		end)
		box.Parent = repairsFolder(unit)
		outages[player] = { box = box }
	end
	updateLights(player)
end

-- Tylko do testów w Studio
function FailureService.DebugBreak(player: Player)
	local data = DataService.Get(player)
	local failureId = data and pickFailure(data, true)
	if failureId then
		breakFixture(player, failureId)
	end
end

function FailureService.DebugPests(player: Player)
	for _ = 1, 3 do
		ApartmentService.AddDirt(player, "bug")
	end
	ApartmentService.AddDirt(player, "mold")
end

function FailureService.Init()
	DataService.OnLoaded(onLoaded)
	RemoteService.OnServerEvent(RemoteNames.Events.RepairAction, 6, onRepairAction)
	-- Przeprowadzka: awarie zostały w starym mieszkaniu, nowe zaczyna od zera
	ApartmentService.OnMoved(function(player)
		local data = DataService.Get(player)
		if data then
			onLoaded(player, data)
		end
	end)
end

function FailureService.Start()
	Players.PlayerRemoving:Connect(function(player)
		repairSessions[player] = nil
		for who, session in repairSessions do
			if session.owner == player then
				repairSessions[who] = nil
				RemoteService.Event(RemoteNames.Events.RepairGame):FireClient(who, "close", { success = false })
			end
		end
		if outages[player] then
			outages[player].box:Destroy()
			outages[player] = nil
		end
		clearVisuals(player)
		plans[player] = nil
		effectTimers[player] = nil
		pestState[player] = nil
	end)
	task.spawn(function()
		local counter = 0
		while true do
			task.wait(1)
			counter += 1
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				-- Gracz mieszkający u kogoś: jego puste mieszkanie się nie psuje
				if data and visuals[player] and not RoommateService.IsGuest(player) then
					local ok, err = pcall(tickPlayer, player, data, now)
					if not ok then
						warn("[FailureService] " .. tostring(err))
					end
				end
			end
			if counter % BUG_WIGGLE_INTERVAL == 0 then
				wiggleBugs()
			end
		end
	end)
end

return FailureService

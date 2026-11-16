-- Opiekun zwierząt: gracz wybiera zwierzaka (dwa psy, kot albo królik – modele jak w zoo sklepie) i idzie
-- z nim na smyczy po wybiegu. Dojście do flagi (+1) uruchamia jedną z minigier (na zmianę):
--  • polecenia: zapamiętaj pokazaną kolejność i powtórz ją (+2),
--  • smaczki: zbierz je razem ze zwierzakiem przed końcem czasu (wszystkie +2, połowa +1),
--  • aport: oceń odległość do kółka i rzuć piłkę z odpowiednią siłą (trafienie +2); zwierzak ją przynosi.
-- Wszystko liczy serwer; klient pokazuje tylko przyciski wyboru (tryb "choice" w JobUI).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AssetsConfig = require(ReplicatedStorage.Shared.Config.AssetsConfig)
local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local PropBuilder = require(ServerScriptService.World.PropBuilder)
local PetBuilder = require(ServerScriptService.World.PetBuilder)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local JobService = require(Services.JobService)

local PetsitterJob = {
	JobId = "petsitter",
}

local CONFIG = JobsConfig.Jobs.petsitter
local CHECKPOINT_POINTS = 1
local GAME_POINTS = 2
local FOLLOW_DISTANCE = 4
local SNAP_DISTANCE = 40
local MIN_FLAG_DISTANCE = 15
local RUN_SPEED = 24
local GAMES = { "commands", "treats", "fetch" }
local FETCH_OPTIONS = {
	{ value = "near", label = "🎾 Blisko" },
	{ value = "mid", label = "🎾 Średnio" },
	{ value = "far", label = "🎾 Daleko" },
}
local SAY = { dog = "HAU! HAU! 🐶", cat = "MIAU! 🐱", rabbit = "*kic kic* 🐰" }

local area = nil
local obstacles = {} -- strefy parku bez flag i smaczków (fontanna, staw, tor agility...): { position, radius }
local rng = Random.new()

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function feetY(player: Player, root: BasePart): number
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return root.Position.Y - root.Size.Y / 2 - (if humanoid then humanoid.HipHeight else 2)
end

local function inArea(position: Vector3, margin: number): boolean
	local half = area.Size / 2 - Vector3.new(margin, 0, margin)
	local offset = position - area.Position
	return math.abs(offset.X) <= half.X and math.abs(offset.Z) <= half.Z
end

local function blocked(position: Vector3, margin: number): boolean
	for _, obstacle in obstacles do
		if flat(position - obstacle.position).Magnitude < obstacle.radius + margin then
			return true
		end
	end
	return false
end

-- Losowy punkt na wybiegu, z dala od fontanny, stawu i innych ozdób parku
local function randomAreaPoint(): Vector3
	local point
	for _ = 1, 30 do
		point = Vector3.new(
			area.Position.X + rng:NextNumber(-area.Size.X / 2 + 2, area.Size.X / 2 - 2),
			0.3,
			area.Position.Z + rng:NextNumber(-area.Size.Z / 2 + 2, area.Size.Z / 2 - 2)
		)
		if not blocked(point, 1.5) then
			break
		end
	end
	return point
end

local function commandsOf(state)
	return CONFIG.commands[state.species] or CONFIG.commands.dog
end

local function commandOptions(state)
	local options = {}
	for _, command in commandsOf(state) do
		table.insert(options, { value = command.id, label = command.label })
	end
	return options
end

local function labelFor(state, id: string): string
	for _, command in commandsOf(state) do
		if command.id == id then
			return command.label
		end
	end
	return id
end

-- Zwierzak: dymki i dźwięki -----------------------------------------------------------

local function bubble(state, text: string)
	local body = state.pet and state.pet.PrimaryPart
	if not body then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 60)
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	task.delay(1.8, function()
		gui:Destroy()
	end)
end

local function speak(state)
	bubble(state, SAY[state.species] or "💖")
	local body = state.pet and state.pet.PrimaryPart
	local soundId = AssetsConfig.Sounds.DogBark
	if state.species == "dog" and body and type(soundId) == "string" and soundId ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = AssetsConfig.Volumes.DogBark or 0.8
		sound.RollOffMaxDistance = 60
		sound.Parent = body
		sound:Play()
		task.delay(0.32, function()
			if sound.Parent then
				sound.TimePosition = 0
				sound:Play()
			end
		end)
		task.delay(2, function()
			sound:Destroy()
		end)
	end
end

local function setBody(state, cframe: CFrame, duration: number)
	local body = state.pet.PrimaryPart
	if duration <= 0 then
		state.pet:PivotTo(cframe)
	else
		TweenService:Create(body, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = cframe }):Play()
	end
end

-- Radosny obrót w miejscu (po dobrze wykonanej minigrze)
local function celebrate(state)
	state.busy = true
	task.spawn(function()
		local base = state.pet.PrimaryPart.CFrame
		for i = 1, 4 do
			setBody(state, base * CFrame.Angles(0, math.rad(90 * i), 0), 0.13)
			task.wait(0.13)
		end
		speak(state)
		state.busy = false
	end)
end

local function movePet(session, root: BasePart, dt: number)
	local state = session.state
	if state.busy then
		return
	end
	local body = state.pet.PrimaryPart
	local look = flat(root.CFrame.LookVector)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local target = root.Position - look * FOLLOW_DISTANCE
	target = Vector3.new(target.X, feetY(session.player, root) + state.height, target.Z)
	local offset = target - body.Position
	if offset.Magnitude < 0.5 then
		return
	end
	local facing = flat(offset)
	local goal = if facing.Magnitude > 0.1 then CFrame.lookAt(target, target + facing) else CFrame.new(target)
	setBody(state, goal, if offset.Magnitude > SNAP_DISTANCE then 0 else dt)
end

-- Smycz: czerwony pasek od obroży do dłoni gracza (sam wygląd)
local function attachLeash(session)
	local state = session.state
	local character = session.player.Character
	local grip = character and character:FindFirstChild("RightGripAttachment", true)
	local head = state.pet:FindFirstChild("Head")
	if not grip or not head then
		return
	end
	local collar = state.pet:FindFirstChild("Collar")
	if not collar then
		collar = Instance.new("Part")
		collar.Name = "Collar"
		collar.Size = Vector3.new(head.Size.X * 1.05, 0.22, head.Size.Z * 0.5)
		collar.CFrame = head.CFrame * CFrame.new(0, -head.Size.Y / 2 + 0.05, 0.1)
		collar.Color = Color3.fromRGB(230, 40, 70)
		collar.Material = Enum.Material.SmoothPlastic
		collar.CanCollide = false
		collar.CanTouch = false
		collar.CanQuery = false
		collar.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = state.pet.PrimaryPart
		weld.Part1 = collar
		weld.Parent = collar
		collar.Parent = state.pet
	end
	local hook = Instance.new("Attachment")
	hook.Name = "LeashHook"
	hook.Parent = collar
	local leash = Instance.new("Beam")
	leash.Name = "Leash"
	leash.Attachment0 = hook
	leash.Attachment1 = grip
	leash.Color = ColorSequence.new(Color3.fromRGB(230, 40, 70))
	leash.Width0 = 0.16
	leash.Width1 = 0.16
	leash.FaceCamera = true
	leash.Segments = 12
	leash.CurveSize0 = -1
	leash.CurveSize1 = 1
	leash.LightInfluence = 0.3
	leash.Parent = collar
end

-- Etapy spaceru ---------------------------------------------------------------------------

local startGame

local function newCheckpoint(session)
	local state = session.state
	state.phase = "walk"
	if state.flag then
		state.flag:Destroy()
	end
	local root = getRoot(session.player)
	local position
	for _ = 1, 12 do
		position = randomAreaPoint()
		if not root or flat(root.Position - position).Magnitude >= MIN_FLAG_DISTANCE then
			break
		end
	end
	state.flagPosition = position
	state.flag = PropBuilder.Flag(position)
	-- Świecące koło (tu trzeba wejść z pupilem) i słup światła widoczny z całego parku
	local ring = Instance.new("Part")
	ring.Name = "FlagZone"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, CONFIG.checkpointRadius * 2, CONFIG.checkpointRadius * 2)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 80, 120)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.6
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = state.flag
	TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.82 }):Play()
	local pillar = ring:Clone()
	pillar.Name = "FlagBeam"
	pillar.Size = Vector3.new(30, 1.2, 1.2)
	pillar.CFrame = CFrame.new(position + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Transparency = 0.55
	pillar.Parent = state.flag
	JobService.SetGuideTarget(state.flag, "🚩 Idź tu z pupilem")
	state.flag.Parent = session.folder
	JobService.UpdateProgress(session, state.points, state.goal, "🚩 Idź z pupilem do flagi (prowadzi żółta linia)")
end

local function choosePetPrompt(session)
	local options = {}
	for _, pet in CONFIG.pets do
		table.insert(options, { value = pet.id, label = pet.label })
	end
	JobService.UpdateProgress(session, 0, session.state.goal, "Wybierz zwierzaka na spacer", {
		mode = "choice",
		action = "pet",
		title = "Kogo wyprowadzasz?",
		prompt = "Wybierz zwierzaka!",
		options = options,
	})
end

local function onChoosePet(session, value: string)
	local state = session.state
	local choice = nil
	for _, pet in CONFIG.pets do
		if pet.id == value then
			choice = pet
		end
	end
	local root = getRoot(session.player)
	if not choice or not root then
		return
	end
	local start = CFrame.new(root.Position.X + 3, feetY(session.player, root), root.Position.Z)
	local model = PetBuilder.Build(choice.species, start, choice.variant)
	if not model then
		return
	end
	state.species = choice.species
	state.pet = model
	state.height = model:GetAttribute("BodyHeight") or 1
	model.Parent = session.folder
	attachLeash(session)
	speak(state)
	newCheckpoint(session)
end

-- Minigra: polecenia z pamięci
local function sendCommands(session, mistake: boolean)
	local state = session.state
	local labels = {}
	for _, id in state.sequence do
		table.insert(labels, labelFor(state, id))
	end
	JobService.UpdateProgress(session, state.points, state.goal, "Pokaż zwierzakowi polecenia w tej samej kolejności", {
		mode = "choice",
		action = "command",
		title = "Polecenia",
		reveal = (if mistake then "Ups, jeszcze raz: " else "Zapamiętaj: ") .. table.concat(labels, "  →  "),
		revealFor = CONFIG.revealTime,
		prompt = string.format("Teraz powtórz! (1/%d)", #state.sequence),
		options = commandOptions(state),
		mistake = mistake,
	})
end

local function startCommands(session)
	local state = session.state
	state.phase = "command"
	state.sequence = {}
	local commands = commandsOf(state)
	for i = 1, state.sequenceLength do
		state.sequence[i] = commands[rng:NextInteger(1, #commands)].id
	end
	state.index = 1
	sendCommands(session, false)
end

-- Minigra: smaczki do zebrania
local function treatsHint(session)
	local state = session.state
	local remaining = math.max(0, math.ceil(state.treatEnd - os.clock()))
	JobService.UpdateProgress(session, state.points, state.goal, string.format("Zbierz smaczki %s ze zwierzakiem! %d/%d  (zostało %d s)", CONFIG.treats[state.species] or "🦴", state.treatsTaken, #state.treats + state.treatsTaken, remaining))
end

local function spawnTreat(session, position: Vector3)
	local state = session.state
	local treat = Instance.new("Part")
	treat.Name = "Treat"
	treat.Shape = Enum.PartType.Ball
	treat.Size = Vector3.new(1.2, 1.2, 1.2)
	treat.Position = position + Vector3.new(0, 0.9, 0)
	treat.Color = Color3.fromRGB(255, 215, 90)
	treat.Material = Enum.Material.Neon
	treat.Transparency = 0.35
	treat.Anchored = true
	treat.CanCollide = false
	treat.CanQuery = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = treat
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = CONFIG.treats[state.species] or "🦴"
	label:SetAttribute("NoTranslate", true)
	label.Parent = gui
	-- Smaczek podskakuje, żeby był widoczny z daleka
	TweenService:Create(treat, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = treat.Position + Vector3.new(0, 0.6, 0) }):Play()
	JobService.SetGuideTarget(treat, "")
	treat.Parent = session.folder
	table.insert(state.treats, treat)
end

local function startTreats(session)
	local state = session.state
	state.phase = "treats"
	state.treats = {}
	state.treatsTaken = 0
	state.treatEnd = os.clock() + CONFIG.treatTime
	state.nextTreatHint = 0
	local root = getRoot(session.player)
	for _ = 1, CONFIG.treatCount do
		local position = randomAreaPoint()
		for _ = 1, 8 do
			if not root or flat(root.Position - position).Magnitude > 8 then
				break
			end
			position = randomAreaPoint()
		end
		spawnTreat(session, position)
	end
	bubble(state, "😋 Smaczki!")
	treatsHint(session)
end

local function finishTreats(session)
	local state = session.state
	local total = state.treatsTaken + #state.treats
	for _, treat in state.treats do
		treat:Destroy()
	end
	state.treats = {}
	local earned = if state.treatsTaken >= total then GAME_POINTS elseif state.treatsTaken * 2 >= total then 1 else 0
	if earned > 0 then
		state.points += earned
		RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(session.player, state.pet.PrimaryPart.Position, "dog", earned)
		celebrate(state)
	end
	newCheckpoint(session)
end

-- Minigra: aport do kółka
local function startFetch(session)
	local state = session.state
	local root = getRoot(session.player)
	if not root then
		newCheckpoint(session)
		return
	end
	state.phase = "fetch"
	-- Losowa odległość z jednego z trzech pasów i kierunek, w którym kółko mieści się na wybiegu
	local bandNames = { "near", "mid", "far" }
	local band = CONFIG.fetchBands[bandNames[rng:NextInteger(1, 3)]]
	local start = flat(root.Position)
	local ringPosition, distance = nil, nil
	for _ = 1, 24 do
		local angle = rng:NextNumber(0, math.pi * 2)
		distance = rng:NextNumber(band[1], band[2])
		local candidate = start + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		if inArea(candidate, 2) and not blocked(candidate, CONFIG.fetchTolerance) then
			ringPosition = candidate
			break
		end
	end
	if not ringPosition then
		-- Za mało miejsca (gracz przy ścianie): kółko blisko, w stronę środka wybiegu
		local toCenter = flat(area.Position) - start
		distance = math.clamp(toCenter.Magnitude, 6, 12)
		ringPosition = start + (if toCenter.Magnitude > 0.1 then toCenter.Unit else Vector3.new(1, 0, 0)) * distance
	end
	state.ringPosition = Vector3.new(ringPosition.X, 0.3, ringPosition.Z)
	state.ringDistance = distance
	local ring = Instance.new("Part")
	ring.Name = "FetchRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, CONFIG.fetchTolerance * 2, CONFIG.fetchTolerance * 2)
	ring.CFrame = CFrame.new(state.ringPosition + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 90, 140)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.35
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(70, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = ring
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = "🎯"
	label:SetAttribute("NoTranslate", true)
	label.Parent = gui
	ring.Parent = session.folder
	state.ring = ring
	JobService.UpdateProgress(session, state.points, state.goal, "Rzuć piłkę do kółka 🎯", {
		mode = "choice",
		action = "throw",
		title = "Aport",
		prompt = "Jak mocno rzucić, żeby piłka wpadła do kółka 🎯?",
		options = FETCH_OPTIONS,
	})
end

local function onThrow(session, value: string)
	local state = session.state
	local band = CONFIG.fetchBands[value]
	local root = getRoot(session.player)
	if not band or not root then
		return
	end
	state.phase = "fetching"
	JobService.UpdateProgress(session, state.points, state.goal, "🎾 Lecę po piłkę!")
	local start = root.Position + Vector3.new(0, 1, 0)
	local direction = flat(state.ringPosition - root.Position)
	direction = if direction.Magnitude > 0.1 then direction.Unit else flat(root.CFrame.LookVector).Unit
	local throwDistance = (band[1] + band[2]) / 2
	local landing = flat(root.Position) + direction * throwDistance + Vector3.new(0, 0.7, 0)
	local hit = math.abs(throwDistance - state.ringDistance) <= CONFIG.fetchTolerance

	local ball = Instance.new("Part")
	ball.Name = "FetchBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.8, 0.8, 0.8)
	ball.Color = Color3.fromRGB(200, 255, 60)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CFrame = CFrame.new(start)
	ball.Parent = session.folder
	local flight = 0.5 + throwDistance / 45
	local arc = 2 + throwDistance * 0.3
	local elapsed = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local t = math.min(elapsed / flight, 1)
		ball.CFrame = CFrame.new(start:Lerp(landing, t) + Vector3.new(0, arc * 4 * t * (1 - t), 0))
		if t >= 1 or not ball.Parent then
			connection:Disconnect()
		end
	end)
	state.busy = true
	task.spawn(function()
		bubble(state, "🎾 !!!")
		task.wait(0.25)
		-- Bieg do piłki
		local from = state.pet.PrimaryPart.Position
		local stop = Vector3.new(landing.X, from.Y, landing.Z)
		local way = flat(stop - from)
		local runTime = math.max(0.3, way.Magnitude / RUN_SPEED)
		if way.Magnitude > 0.1 then
			setBody(state, CFrame.lookAt(stop, stop + way.Unit), runTime)
		end
		task.wait(math.max(runTime, flight) + 0.1)
		if not JobService.IsActive(session) then
			return
		end
		ball:Destroy()
		if hit then
			bubble(state, "🎯 Trafione!")
		else
			bubble(state, "🎾 Mam ją!")
		end
		-- Powrót do opiekuna
		local owner = getRoot(session.player)
		if owner then
			local goal = owner.Position - flat(owner.CFrame.LookVector) * FOLLOW_DISTANCE
			goal = Vector3.new(goal.X, feetY(session.player, owner) + state.height, goal.Z)
			local back = flat(goal - state.pet.PrimaryPart.Position)
			local time = math.max(0.25, back.Magnitude / RUN_SPEED)
			if back.Magnitude > 0.1 then
				setBody(state, CFrame.lookAt(goal, goal + back.Unit), time)
			end
			task.wait(time + 0.05)
		end
		state.busy = false
		if not JobService.IsActive(session) then
			return
		end
		if state.ring then
			state.ring:Destroy()
			state.ring = nil
		end
		if hit then
			state.points += GAME_POINTS
			RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(session.player, state.pet.PrimaryPart.Position, "dog", GAME_POINTS)
			celebrate(state)
		else
			local hint = if throwDistance < state.ringDistance then "Za blisko! Następnym razem mocniej." else "Za daleko! Następnym razem lżej."
			RemoteService.Event(RemoteNames.Events.Notify):FireClient(session.player, "🎾 " .. hint, "info")
		end
		newCheckpoint(session)
	end)
end

startGame = function(session)
	local state = session.state
	local options = {}
	for _, name in GAMES do
		if name ~= state.lastGame then
			table.insert(options, name)
		end
	end
	local name = options[rng:NextInteger(1, #options)]
	state.lastGame = name
	if name == "commands" then
		startCommands(session)
	elseif name == "treats" then
		startTreats(session)
	else
		startFetch(session)
	end
end

function PetsitterJob.Init()
	local hotel = Workspace.Map.JobSites:WaitForChild("DogHotel")
	area = hotel:WaitForChild("WalkArea")
	local markers = hotel:FindFirstChild("ParkObstacles")
	if markers then
		for _, marker in markers:GetChildren() do
			table.insert(obstacles, { position = marker.Position, radius = marker:GetAttribute("Radius") or 2 })
		end
	end
end

function PetsitterJob.StartShift(session)
	local state = session.state
	state.goal = session.levelConfig.goal
	state.sequenceLength = session.levelConfig.sequence
	state.points = 0
	state.mistakes = 0
	state.lastAnswer = 0
	state.phase = "choose"
	choosePetPrompt(session)
end

function PetsitterJob.TickShift(session, dt: number)
	local state = session.state
	local root = getRoot(session.player)
	if not root or not state.pet then
		return
	end
	movePet(session, root, dt)

	local now = os.clock()
	local position = root.Position
	local teleported = false
	if state.lastPosition then
		teleported = (position - state.lastPosition).Magnitude > CONFIG.maxSpeed * (now - state.lastTime) + 2
	end
	state.lastPosition = position
	state.lastTime = now
	if teleported then
		return
	end

	if state.phase == "walk" then
		if flat(position - state.flagPosition).Magnitude <= CONFIG.checkpointRadius then
			state.points += CHECKPOINT_POINTS
			RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(session.player, state.flagPosition + Vector3.new(0, 3, 0), "flag", CHECKPOINT_POINTS)
			state.flag:Destroy()
			state.flag = nil
			startGame(session)
		end
	elseif state.phase == "treats" then
		local changed = false
		for i = #state.treats, 1, -1 do
			local treat = state.treats[i]
			if flat(position - treat.Position).Magnitude <= CONFIG.treatRadius then
				RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(session.player, treat.Position, "can", 0)
				treat:Destroy()
				table.remove(state.treats, i)
				state.treatsTaken += 1
				changed = true
			end
		end
		if #state.treats == 0 or now >= state.treatEnd then
			finishTreats(session)
		elseif changed or now >= state.nextTreatHint then
			state.nextTreatHint = now + 1
			treatsHint(session)
		end
	end
end

function PetsitterJob.OnAction(session, action: string, value: any)
	local state = session.state
	if not RemoteService.IsString(value, 16) then
		return
	end
	local now = os.clock()
	if now - state.lastAnswer < CONFIG.minAnswerInterval then
		return
	end
	state.lastAnswer = now
	if action == "pet" and state.phase == "choose" then
		onChoosePet(session, value)
	elseif action == "throw" and state.phase == "fetch" then
		onThrow(session, value)
	elseif action == "command" and state.phase == "command" then
		if value == state.sequence[state.index] then
			state.index += 1
			if state.index > #state.sequence then
				state.points += GAME_POINTS
				RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(session.player, state.pet.PrimaryPart.Position, "dog", GAME_POINTS)
				celebrate(state)
				newCheckpoint(session)
			else
				bubble(state, labelFor(state, value))
				JobService.UpdateProgress(session, state.points, state.goal, "Pokaż zwierzakowi polecenia w tej samej kolejności", {
					mode = "choice",
					action = "command",
					title = "Polecenia",
					prompt = string.format("Dobrze! Dalej (%d/%d)", state.index, #state.sequence),
					options = commandOptions(state),
				})
			end
		else
			state.mistakes += 1
			state.index = 1
			sendCommands(session, true)
		end
	end
end

function PetsitterJob.Evaluate(session): number
	local state = session.state
	return JobService.StarsFromFraction(state.points / state.goal)
end

return PetsitterJob

-- Cut scena po odblokowaniu nowej pracy (nowy miesiąc): widok z drona w zwolnionym tempie nad nowym miejscem pracy.
-- Ujęcie 1: dron powoli okrąża budynek z góry. Ujęcie 2: płynny zjazd przed miejsce startu pracy ze znacznikiem
-- "Przyjdź tutaj!". Kinowe pasy z nazwą pracy i opisem, jak się pracuje. Około 8 s, można pominąć.
-- Potem przewodnik (GuideController) prowadzi żółtą linią do nowej pracy.
-- Scena czeka, aż gracz skończy zmianę i zamknie okno Pana Klucznika.
-- PlayTour: wycieczka z drona po mieście dla nowego gracza (kilka ujęć z podpisami, start samouczka).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local JobsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("JobsConfig"))
local GuideController = require(script.Parent:WaitForChild("GuideController"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local CutsceneController = {}

local ICONS = { cleaner = "🧹", gardener = "🌱", cashier = "🛒", kebab = "🥙", pizza = "🍕", petsitter = "🐶", mechanic = "🔧", freelancer = "💻", scrapPro = "♻️" }
local ORBIT_TIME, GLIDE_TIME, HOLD_TIME = 3.8, 2.6, 1.8
local TOUR_SHOT_TIME = 8 -- jedno ujęcie wycieczki po mieście (przycisk "Dalej" przechodzi wcześniej)
local YELLOW = Color3.fromRGB(255, 220, 60)

local player = Players.LocalPlayer
local queue = {}
local playing = false
local skipped = false
local nextSlide = false -- przycisk "Dalej" w wycieczce po mieście
local refs = {}

-- Łagodny start (dron rusza powoli) i łagodne hamowanie; między ujęciami prędkość się nie zeruje
local function easeIn(t: number): number
	return 1 - math.cos(math.clamp(t, 0, 1) * math.pi / 2)
end

local function easeOut(t: number): number
	return math.sin(math.clamp(t, 0, 1) * math.pi / 2)
end

local function bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local u = 1 - t
	return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Miejsce pracy: środek budynku, punkt startu (podpowiedź "Praca: ...") i kierunek, z którego się do niego podchodzi
local function siteInfo(jobId: string)
	local job = JobsConfig.Jobs[jobId]
	local map = Workspace:FindFirstChild("Map")
	local sites = map and map:FindFirstChild("JobSites")
	local model = sites and job and job.site and sites:FindFirstChild(job.site)
	local start = model and model:FindFirstChild("StartPart")
	if not start then
		return nil
	end
	local attachment = start:FindFirstChild("StartAttachment")
	local startPosition = if attachment then attachment.WorldPosition else start.Position
	local front = flat(startPosition - start.Position)
	front = if front.Magnitude > 0.1 then front.Unit else flat(-start.CFrame.LookVector).Unit
	local box, size = model:GetBoundingBox()
	return {
		job = job,
		target = attachment or start,
		start = startPosition,
		front = front,
		center = box.Position,
		size = size,
	}
end

-- Kamera nie może stać za ścianą: przesuwamy ją przed pierwszą nieprzezroczystą przeszkodę (szyby nie przeszkadzają)
local function clearShot(focus: Vector3, camera: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	for _ = 1, 6 do
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(focus, camera - focus, params)
		if not hit then
			return camera
		end
		if hit.Instance.Transparency > 0.3 then
			table.insert(ignore, hit.Instance)
		else
			return hit.Position + (focus - camera).Unit * 1.2
		end
	end
	return camera
end

-- Znacznik nad miejscem startu w trakcie sceny: pulsujące koło i napis
local function spawnMarker(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "CutsceneMarker"
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.1, 4, 4)
	ring.CFrame = CFrame.new(position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = YELLOW
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.35
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Parent = model
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = Vector3.new(0.1, 6, 6), Transparency = 0.7 }):Play()
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 90)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = ring
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.5, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = YELLOW
	label.Text = "📍 Przyjdź tutaj!"
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	local pointer = label:Clone()
	pointer.Text = "⬇"
	pointer.Position = UDim2.fromScale(0, 0.5)
	pointer:SetAttribute("NoTranslate", true)
	pointer.Parent = billboard
	TweenService:Create(billboard, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { StudsOffsetWorldSpace = Vector3.new(0, 7.5, 0) }):Play()
	model.Parent = Workspace
	return model
end

local function isBusy(): boolean
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then
		return true
	end
	local jobUi = gui:FindFirstChild("JobUI")
	local hud = jobUi and jobUi:FindFirstChild("JobHud")
	if hud and hud.Visible then
		return true
	end
	for _, child in gui:GetChildren() do
		if child:IsA("ScreenGui") and child.Name:find("Landlord") and child.Enabled then
			return true
		end
	end
	local character = player.Character
	return not (character and character:FindFirstChild("HumanoidRootPart"))
end

-- Początek sceny: postać stoi w miejscu, reszta interfejsu znika, kamera jest nasza, wjeżdzają kinowe pasy
local function beginScene(tag: string)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not camera or not root or not humanoid then
		return nil
	end
	skipped = false
	local scene = { camera = camera, root = root, humanoid = humanoid, wasAnchored = root.Anchored, hidden = {}, oldFov = camera.FieldOfView }
	root.Anchored = true
	for _, child in player.PlayerGui:GetChildren() do
		if child:IsA("ScreenGui") and child.Enabled and child ~= refs.gui then
			child.Enabled = false
			table.insert(scene.hidden, child)
		end
	end
	camera.CameraType = Enum.CameraType.Scriptable
	scene.blur = Instance.new("DepthOfFieldEffect")
	scene.blur.Name = "CutsceneFocus"
	scene.blur.InFocusRadius = 18
	scene.blur.FarIntensity = 0.35
	scene.blur.NearIntensity = 0.25
	scene.blur.Parent = Lighting
	scene.tint = Instance.new("ColorCorrectionEffect")
	scene.tint.Name = "CutsceneTint"
	scene.tint.Saturation = 0.15
	scene.tint.Contrast = 0.06
	scene.tint.Parent = Lighting
	refs.tag.Text = tag
	refs.gui.Enabled = true
	refs.top.Position = UDim2.fromScale(0, -0.14)
	refs.bottom.Position = UDim2.fromScale(0, 1.22)
	TweenService:Create(refs.top, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0, 0) }):Play()
	TweenService:Create(refs.bottom, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0, 1) }):Play()
	refs.flash.BackgroundTransparency = 0.2
	TweenService:Create(refs.flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	pcall(SoundController.Play, "Success", 0.8)
	return scene
end

-- Przejście przez czerń (on = ściemnij, off = rozjaśnij)
local function blackout(on: boolean, seconds: number)
	refs.flash.BackgroundColor3 = Color3.new(0, 0, 0)
	local tween = TweenService:Create(refs.flash, TweenInfo.new(seconds), { BackgroundTransparency = if on then 0 else 1 })
	tween:Play()
	tween.Completed:Wait()
end

-- Koniec sceny: ściemnienie, sprzątanie (cleanup) i powrót kamery oraz interfejsu do gracza
local function endScene(scene, cleanup: () -> ())
	blackout(true, 0.25)
	cleanup()
	scene.blur:Destroy()
	scene.tint:Destroy()
	scene.camera.FieldOfView = scene.oldFov
	scene.camera.CameraType = Enum.CameraType.Custom
	scene.camera.CameraSubject = scene.humanoid
	if scene.root.Parent then
		scene.root.Anchored = scene.wasAnchored
	end
	for _, gui in scene.hidden do
		gui.Enabled = true
	end
	refs.top.Position = UDim2.fromScale(0, -0.14)
	refs.bottom.Position = UDim2.fromScale(0, 1.22)
	blackout(false, 0.35)
	refs.gui.Enabled = false
	refs.flash.BackgroundColor3 = Color3.new(1, 1, 1)
end

local function play(jobId: string)
	local info = siteInfo(jobId)
	if not info then
		return
	end
	local scene = beginScene("🔓 NOWA PRACA ODBLOKOWANA!")
	if not scene then
		return
	end
	local camera, blur = scene.camera, scene.blur
	local marker = spawnMarker(info.start)

	-- Tor kamery: łuk wokół budynku z góry, potem zjazd przed punkt startu (lekko z boku)
	local radius = math.clamp(math.max(info.size.X, info.size.Z) * 0.7 + 18, 34, 70)
	local frontAngle = math.atan2(info.front.Z, info.front.X)
	local fromAngle, toAngle = frontAngle + math.rad(80), frontAngle + math.rad(18)
	local function orbitPoint(t: number): Vector3
		local angle = fromAngle + (toAngle - fromAngle) * t
		local height = radius * (0.8 - 0.25 * t)
		return info.center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
	end
	-- Ostatnie ujęcie: punkt startu i napis "Przyjdź tutaj!" nad nim w kadrze
	local focus = info.start + Vector3.new(0, 3, 0)
	local side = Vector3.new(-info.front.Z, 0, info.front.X)
	local close = clearShot(focus, info.start + info.front * 17 + side * 4 + Vector3.new(0, 7, 0))
	local glideFrom = orbitPoint(1)

	-- Napisy: nazwa pracy, opis, jak pracować
	-- Trzy spacje oddzielają ikonę od nazwy (Lang tłumaczy części osobno)
	refs.name.Text = (ICONS[jobId] or "💼") .. "   " .. tostring(info.job.name)
	refs.description.Text = tostring(info.job.description or "")

	local total = ORBIT_TIME + GLIDE_TIME + HOLD_TIME
	local elapsed = 0
	local connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local position, lookAt, fov
		if elapsed < ORBIT_TIME then
			local t = easeIn(elapsed / ORBIT_TIME)
			position = orbitPoint(t)
			lookAt = info.center:Lerp(focus, t * 0.4)
			fov = 55 - 3 * t
		elseif elapsed < ORBIT_TIME + GLIDE_TIME then
			local t = easeOut((elapsed - ORBIT_TIME) / GLIDE_TIME)
			position = bezier(glideFrom, glideFrom + (close - glideFrom) * 0.25 + Vector3.new(0, 4, 0), close + Vector3.new(0, 7, 0), close, t)
			lookAt = info.center:Lerp(focus, 0.4 + 0.6 * t)
			fov = 52 - 2 * t
		else
			-- Powolny najazd na punkt startu (efekt zwolnionego tempa)
			local t = (elapsed - ORBIT_TIME - GLIDE_TIME) / HOLD_TIME
			position = close:Lerp(focus, 0.08 * t)
			lookAt = focus
			fov = 50 - 2 * t
		end
		camera.CFrame = CFrame.lookAt(position, lookAt)
		camera.FieldOfView = fov
		blur.FocusDistance = (position - lookAt).Magnitude
	end)
	while elapsed < total and not skipped do
		task.wait()
	end

	endScene(scene, function()
		connection:Disconnect()
		marker:Destroy()
	end)
	GuideController.SetTemporaryTarget(info.target, "💼 Nowa praca!", 600)
end

-- Ujęcia wycieczki po mieście dla nowego gracza (liczone w chwili startu, bo zależą od miejsca gracza)
local function tourShots()
	local map = Workspace:FindFirstChild("Map")
	local sites = map and map:FindFirstChild("JobSites")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local home = root and root.Position
	local function centerOf(model: Instance?): Vector3?
		return if model and model:IsA("Model") then model:GetBoundingBox().Position else nil
	end
	local shots = {}
	local function add(center: Vector3?, radius: number, angle: number, title: string, text: string)
		if center then
			table.insert(shots, { center = center, radius = radius, angle = math.rad(angle), title = title, text = text })
		end
	end
	-- Trzy spacje oddzielają ikonę od tytułu (Lang tłumaczy części osobno)
	add(Vector3.new(0, 0, 16), 95, 250, "👋   Witaj w RENT OR REGRET!", "Wynajmujesz swoje pierwsze mieszkanie. Twoje zadanie: co miesiąc zarobić na czynsz i dbać o dom.")
	add(home, 40, 200, "🏠   Twoje mieszkanie", "Tu mieszkasz. Sprzątaj i naprawiaj awarie: zadbane mieszkanie daje premię do zarobków.")
	add(centerOf(map and map:FindFirstChild("Kaucjomat")), 38, 300, "🍾   Park i kaucjomat", "W parku zbierasz butelki, a w kaucjomacie zamieniasz je na monety. To działa zawsze!")
	add(centerOf(sites and sites:FindFirstChild("Office")), 48, 230, "🏢   Biuro", "Twoja pierwsza praca: Sprzątacz. Podejdź do recepcji i naciśnij E, żeby zacząć zmianę.")
	add(centerOf(sites and sites:FindFirstChild("KebabStand")), 45, 280, "🔓   Nowe prace co miesiąc", "Ogród, kebaby, market, pizzeria i więcej. Każda kolejna praca płaci lepiej!")
	add(home, 70, 120, "💸   Czynsz", "Na koniec miesiąca Pan Klucznik przychodzi po czynsz. Zegar i kwotę widzisz u góry ekranu. Powodzenia!")
	return shots
end

-- Wycieczka z drona: każde ujęcie powoli okrąża miejsce z podpisem, między ujęciami krótka czerń
local function playTour(shots)
	if #shots == 0 then
		return
	end
	local scene = beginScene("🗺️ WITAJ W MIEŚCIE!")
	if not scene then
		return
	end
	local camera, blur = scene.camera, scene.blur
	local shot = shots[1]
	local elapsed = 0
	refs.next.Visible = true
	refs.counter.Visible = true
	local connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local t = math.clamp(elapsed / TOUR_SHOT_TIME, 0, 1)
		local angle = shot.angle + math.rad(35) * t
		local radius = shot.radius * (1 - 0.12 * t)
		local position = shot.center + Vector3.new(math.cos(angle) * radius, radius * (0.75 - 0.15 * t), math.sin(angle) * radius)
		local lookAt = shot.center + Vector3.new(0, 2, 0)
		camera.CFrame = CFrame.lookAt(position, lookAt)
		camera.FieldOfView = 55 - 5 * t
		blur.FocusDistance = (position - lookAt).Magnitude
	end)
	for index, nextShot in shots do
		if skipped then
			break
		end
		if index > 1 then
			blackout(true, 0.2)
		end
		shot = nextShot
		elapsed = 0
		nextSlide = false
		refs.name.Text = shot.title
		refs.description.Text = shot.text
		refs.counter.Text = string.format("%d/%d", index, #shots)
		refs.next.Text = if index == #shots then "Graj! ▶" else "Dalej ▶"
		if index > 1 then
			blackout(false, 0.25)
		end
		while elapsed < TOUR_SHOT_TIME and not skipped and not nextSlide do
			task.wait()
		end
	end
	refs.next.Visible = false
	refs.counter.Visible = false
	endScene(scene, function()
		connection:Disconnect()
	end)
end

local function runQueue()
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			task.wait(1.5)
			while isBusy() do
				task.wait(0.5)
			end
			local item = table.remove(queue, 1)
			local ok, err
			if item.kind == "tour" then
				ok, err = pcall(function()
					playTour(tourShots())
				end)
			else
				ok, err = pcall(play, item.jobId)
			end
			if not ok then
				warn("[Cutscene] " .. tostring(err))
				local camera = Workspace.CurrentCamera
				camera.CameraType = Enum.CameraType.Custom
				refs.gui.Enabled = false
			end
			if item.onDone then
				item.onDone()
			end
		end
		playing = false
	end)
end

-- jobIds z serwera (RemoteNames.Events.JobUnlocked): najwyżej dwie sceny pod rząd
function CutsceneController.OnJobUnlocked(jobIds: any)
	if type(jobIds) ~= "table" then
		return
	end
	for _, jobId in jobIds do
		if type(jobId) == "string" and JobsConfig.Jobs[jobId] and #queue < 3 then
			table.insert(queue, { kind = "job", jobId = jobId })
		end
	end
	runQueue()
end

-- Wycieczka po mieście (samouczek nowego gracza); onDone wołane po zakończeniu albo pominięciu
function CutsceneController.PlayTour(onDone: () -> ())
	table.insert(queue, 1, { kind = "tour", onDone = onDone })
	runQueue()
end

local function textLabel(name: string, props)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

function CutsceneController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CutsceneUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Enabled = false
	refs.gui = gui

	-- Kinowe pasy
	local top = Instance.new("Frame")
	top.Name = "TopBar"
	top.Size = UDim2.fromScale(1, 0.12)
	top.BackgroundColor3 = Color3.new(0, 0, 0)
	top.BorderSizePixel = 0
	top.Parent = gui
	refs.top = top
	local tag = textLabel("Tag", {
		Text = "🔓 NOWA PRACA ODBLOKOWANA!",
		Size = UDim2.fromScale(0.6, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = YELLOW,
	})
	tag.Parent = top
	refs.tag = tag
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.Size = UDim2.new(0, 120, 0.55, 0)
	skip.Position = UDim2.new(1, -16, 0.5, 0)
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	skip.Font = Enum.Font.FredokaOne
	skip.TextScaled = true
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.Text = "Pomiń ⏭"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = skip
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = skip
	skip.Activated:Connect(function()
		skipped = true
	end)
	skip.Parent = top

	local bottom = Instance.new("Frame")
	bottom.Name = "BottomBar"
	bottom.Size = UDim2.fromScale(1, 0.22)
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.BackgroundColor3 = Color3.new(0, 0, 0)
	bottom.BorderSizePixel = 0
	bottom.Parent = gui
	refs.bottom = bottom
	refs.name = textLabel("JobName", { Text = "", Size = UDim2.fromScale(0.6, 0.42), Position = UDim2.fromScale(0.5, 0.08), AnchorPoint = Vector2.new(0.5, 0) })
	-- Wycieczka po mieście: przycisk "Dalej" i numer slajdu (prawy górny róg dolnego paska)
	local nextButton = Instance.new("TextButton")
	nextButton.Name = "Next"
	nextButton.Size = UDim2.new(0, 150, 0.36, 0)
	nextButton.Position = UDim2.new(1, -16, 0.08, 0)
	nextButton.AnchorPoint = Vector2.new(1, 0)
	nextButton.BackgroundColor3 = Color3.fromRGB(60, 190, 90)
	nextButton.Font = Enum.Font.FredokaOne
	nextButton.TextScaled = true
	nextButton.TextColor3 = Color3.new(1, 1, 1)
	nextButton.Text = "Dalej ▶"
	nextButton.Visible = false
	local nextCorner = Instance.new("UICorner")
	nextCorner.CornerRadius = UDim.new(0, 10)
	nextCorner.Parent = nextButton
	local nextPadding = Instance.new("UIPadding")
	nextPadding.PaddingTop = UDim.new(0, 6)
	nextPadding.PaddingBottom = UDim.new(0, 6)
	nextPadding.Parent = nextButton
	nextButton.Activated:Connect(function()
		nextSlide = true
	end)
	nextButton.Parent = bottom
	refs.next = nextButton
	-- Numer slajdu na górnym pasku, obok "Pomiń"
	refs.counter = textLabel("Counter", {
		Text = "",
		Size = UDim2.new(0, 70, 0.4, 0),
		Position = UDim2.new(1, -150, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		TextColor3 = Color3.fromRGB(180, 185, 200),
		Visible = false,
	})
	refs.counter:SetAttribute("NoTranslate", true)
	refs.counter.Parent = top
	refs.name.Parent = bottom
	refs.description = textLabel("Description", {
		Text = "",
		Size = UDim2.fromScale(0.8, 0.4),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(220, 225, 235),
		TextWrapped = true,
	})
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.Parent = refs.description
	refs.description.Parent = bottom

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 10
	flash.Parent = gui
	refs.flash = flash
	gui.Parent = player:WaitForChild("PlayerGui")
end

return CutsceneController

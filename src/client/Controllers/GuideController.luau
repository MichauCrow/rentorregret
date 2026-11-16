-- Przewodnik po pracy: przerywana, płynąca linia na ziemi od postaci do najbliższego celu, znacznik z napisem nad celem
-- i strzałka przy krawędzi ekranu, gdy cel jest poza kadrem. Nic nie zasłania ekranu.
-- Cele to obiekty z atrybutem GuideTarget (napis: GuideLabel) we własnym folderze sesji pracy, o ile folder ma atrybut
-- Guide (serwer ustawia go przy pierwszej zmianie w danej pracy albo zawsze w pracach z alwaysGuide).
-- Linię wyznacza PathfindingService (omija ściany i lady); gdy ścieżki nie ma, linia biegnie prosto do celu.
local PathfindingService = game:GetService("PathfindingService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GuideController = {}

local COLOR = Color3.fromRGB(255, 230, 80)
local EDGE_COLOR = Color3.fromRGB(120, 60, 10) -- ciemna obwódka, żeby kreski było widać na jasnym chodniku
local DASH = 1.5 -- długość kreski
local STEP = 2.6 -- kreska + przerwa
local MAX_LENGTH = 140 -- dalej linii nie rysujemy (strzałka i znacznik i tak prowadzą)
local SCAN_INTERVAL = 0.25
local PATH_INTERVAL = 0.6
local ARRIVED = 4 -- tak blisko celu linia znika, zostaje znacznik

local player = Players.LocalPlayer
local fx = nil -- folder z kreskami i znacznikiem (tylko u tego gracza)
local dashes = {}
local marker = nil
local arrow = nil
local target = nil
local route = nil -- punkty ścieżki albo nil (prosto)
local routeTarget = nil
local lastScan, lastPath = 0, 0
local temporary = nil -- { target, label, untilTime }: cel spoza pracy (np. nowo odblokowane miejsce pracy)
local fixed = nil -- { target, label }: cel samouczka (najniższy priorytet, aż samouczek go zmieni)
local pathBusy = false
local flow = 0
local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 })
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function ownFolder(): Instance?
	local jobObjects = Workspace:FindFirstChild("JobObjects")
	if not jobObjects then
		return nil
	end
	for _, folder in jobObjects:GetChildren() do
		if folder:GetAttribute("JobOwner") == player.UserId and folder:GetAttribute("Guide") then
			return folder
		end
	end
	return nil
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return if instance.PrimaryPart then instance.PrimaryPart.Position else instance:GetPivot().Position
	elseif instance:IsA("Attachment") then
		return instance.WorldPosition
	end
	return nil
end

local function nearestTarget(folder: Instance, from: Vector3): Instance?
	local best, bestDistance = nil, math.huge
	for _, descendant in folder:GetDescendants() do
		if descendant:GetAttribute("GuideTarget") then
			local position = positionOf(descendant)
			if position then
				local distance = (position - from).Magnitude
				if distance < bestDistance then
					best, bestDistance = descendant, distance
				end
			end
		end
	end
	return best
end

-- Wysokość podłoża pod punktem (bez postaci, obiektów prac i samego przewodnika). Promień startuje nisko,
-- żeby kreski nie wskakiwały na blaty biurek.
local function groundAt(point: Vector3, fallback: number): number
	local ignore = { fx, Workspace:FindFirstChild("JobObjects") }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(point + Vector3.new(0, 1.5, 0), Vector3.new(0, -12, 0), rayParams)
	return if hit then hit.Position.Y else fallback
end

local function dashPart(name: string, size: Vector3, color: Color3, material: Enum.Material): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = fx
	return p
end

-- Kreska: świecący żółty pasek na trochę większej, ciemnej podkładce
local function getDash(index: number)
	local dash = dashes[index]
	if not dash then
		dash = {
			edge = dashPart("GuideDashEdge", Vector3.new(1.25, 0.1, DASH + 0.3), EDGE_COLOR, Enum.Material.SmoothPlastic),
			glow = dashPart("GuideDash", Vector3.new(0.9, 0.12, DASH), COLOR, Enum.Material.Neon),
		}
		dashes[index] = dash
	end
	return dash
end

local function hideDashes(from: number)
	for index = from, #dashes do
		dashes[index].edge.Transparency = 1
		dashes[index].glow.Transparency = 1
	end
end

local function ensureMarker()
	if marker then
		return
	end
	local ring = Instance.new("Part")
	ring.Name = "GuideRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.1, 3.4, 3.4)
	ring.Color = COLOR
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.45
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = fx
	TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = Vector3.new(0.1, 4.6, 4.6), Transparency = 0.7 }):Play()

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 86)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 400
	billboard.Parent = ring
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, 34)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = COLOR
	label.Text = ""
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Parent = label
	local pointer = Instance.new("TextLabel")
	pointer.Name = "Pointer"
	pointer.Size = UDim2.new(1, 0, 0, 46)
	pointer.Position = UDim2.fromOffset(0, 36)
	pointer.BackgroundTransparency = 1
	pointer.Font = Enum.Font.FredokaOne
	pointer.TextScaled = true
	pointer.TextColor3 = COLOR
	pointer.Text = "⬇"
	pointer:SetAttribute("NoTranslate", true)
	pointer.Parent = billboard
	local pointerStroke = Instance.new("UIStroke")
	pointerStroke.Thickness = 3
	pointerStroke.Parent = pointer
	TweenService:Create(billboard, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { StudsOffsetWorldSpace = Vector3.new(0, 5.6, 0) }):Play()
	marker = { ring = ring, label = label }
end

local function hideAll()
	hideDashes(1)
	if marker then
		marker.ring:Destroy()
		marker = nil
	end
	if arrow then
		arrow.Visible = false
	end
	target = nil
	route = nil
	routeTarget = nil
end

-- Ścieżka liczona w tle; wynik używany od kolejnej klatki
local function requestPath(from: Vector3, to: Vector3, forTarget: Instance)
	if pathBusy then
		return
	end
	pathBusy = true
	task.spawn(function()
		local ok = pcall(function()
			path:ComputeAsync(from, to)
		end)
		local points = nil
		if ok and path.Status == Enum.PathStatus.Success then
			points = {}
			for _, waypoint in path:GetWaypoints() do
				table.insert(points, waypoint.Position)
			end
		end
		if forTarget == target then
			route = points
			routeTarget = forTarget
		end
		pathBusy = false
	end)
end

-- Kreski wzdłuż łamanej (od stóp gracza do celu), przesuwające się w stronę celu
local function drawLine(points: { Vector3 }, feetY: number)
	local used = 0
	local travelled = 0
	local nextAt = flow
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flatA, flatB = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
		local length = (flatB - flatA).Magnitude
		if length > 0.05 then
			local direction = (flatB - flatA) / length
			while nextAt + DASH <= travelled + length and nextAt < MAX_LENGTH do
				local along = nextAt + DASH / 2 - travelled
				local point = flatA + direction * along
				local y = groundAt(Vector3.new(point.X, a.Y + (b.Y - a.Y) * (along / length), point.Z), feetY)
				used += 1
				local dash = getDash(used)
				local center = Vector3.new(point.X, y + 0.12, point.Z)
				local frame = CFrame.lookAt(center, center + direction)
				dash.edge.CFrame = frame * CFrame.new(0, -0.03, 0)
				dash.edge.Transparency = 0.35
				dash.glow.CFrame = frame
				dash.glow.Transparency = 0
				nextAt += STEP
			end
		end
		travelled += length
	end
	hideDashes(used + 1)
end

-- Strzałka przy krawędzi ekranu w stronę celu, gdy cel jest poza kadrem
local function updateArrow(position: Vector3)
	local camera = Workspace.CurrentCamera
	if not camera or not arrow then
		return
	end
	local screen, onScreen = camera:WorldToViewportPoint(position)
	local viewport = camera.ViewportSize
	if onScreen and screen.Z > 0 then
		arrow.Visible = false
		return
	end
	local center = viewport / 2
	local offset = Vector2.new(screen.X, screen.Y) - center
	if screen.Z < 0 then
		offset = -offset
	end
	if offset.Magnitude < 1 then
		offset = Vector2.new(0, 1)
	end
	local margin = 70
	local half = center - Vector2.new(margin, margin)
	local scale = math.min(half.X / math.max(math.abs(offset.X), 0.001), half.Y / math.max(math.abs(offset.Y), 0.001))
	local point = center + offset * scale
	arrow.Position = UDim2.fromOffset(point.X, point.Y)
	arrow.Rotation = math.deg(math.atan2(offset.Y, offset.X))
	arrow.Visible = true
end

local function step(dt: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		hideAll()
		return
	end
	local now = os.clock()
	if now - lastScan >= SCAN_INTERVAL then
		lastScan = now
		local folder = ownFolder()
		local found = folder and nearestTarget(folder, root.Position)
		if temporary then
			local reached = temporary.target.Parent and positionOf(temporary.target)
			local busy = false
			local jobObjects = Workspace:FindFirstChild("JobObjects")
			for _, session in (if jobObjects then jobObjects:GetChildren() else {}) do
				-- tylko zmiany prac (Session_*), nie rzadkie zlecenia
				if session:GetAttribute("JobOwner") == player.UserId and session.Name:sub(1, 8) == "Session_" then
					busy = true
				end
			end
			if not reached or now > temporary.untilTime or busy then
				temporary = nil
			elseif not found then
				found = temporary.target
			end
		end
		if not found and fixed and fixed.target.Parent then
			found = fixed.target
		end
		if found ~= target then
			if not found then
				-- Cel zniknął (np. krok samouczka bez miejsca): sprzątamy linię i znacznik
				hideAll()
			end
			target = found
			route = nil
			routeTarget = nil
			lastPath = 0
		end
	end
	local special = if temporary and target == temporary.target then temporary elseif fixed and target == fixed.target then fixed else nil
	if not target or not target.Parent or not (special or target:GetAttribute("GuideTarget")) then
		if target then
			hideAll()
		end
		return
	end
	local position = positionOf(target)
	if not position then
		hideAll()
		return
	end
	local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0)
	local goalY = groundAt(position, feet.Y)
	local goal = Vector3.new(position.X, goalY, position.Z)

	ensureMarker()
	marker.ring.CFrame = CFrame.new(goal + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	marker.label.Text = if special then special.label else tostring(target:GetAttribute("GuideLabel") or "")
	updateArrow(goal + Vector3.new(0, 2, 0))

	if (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(feet.X, 0, feet.Z)).Magnitude <= ARRIVED then
		hideDashes(1)
		return
	end
	if now - lastPath >= PATH_INTERVAL then
		lastPath = now
		requestPath(feet + Vector3.new(0, 1, 0), goal, target)
	end

	flow = (flow + dt * 5) % STEP
	local points = { feet }
	if route and routeTarget == target and #route >= 2 then
		-- Pomijamy punkty ścieżki, które gracz już minął (najbliższy punkt i wszystko przed nim)
		local closest, closestDistance = 1, math.huge
		for index, point in route do
			local distance = (point - feet).Magnitude
			if distance < closestDistance then
				closest, closestDistance = index, distance
			end
		end
		for index = closest + 1, #route do
			table.insert(points, route[index])
		end
	end
	table.insert(points, goal)
	drawLine(points, feet.Y)
end

-- Prowadzenie do miejsca spoza pracy (np. nowej pracy po cut scenie): znika po pierwszym E przy tym miejscu,
-- po rozpoczęciu zmiany albo po `seconds` sekundach
function GuideController.SetTemporaryTarget(instance: Instance, label: string, seconds: number)
	temporary = { target = instance, label = label, untilTime = os.clock() + seconds }
	lastScan = 0
end

-- Cel samouczka (nil = brak); prowadzi, dopóki samouczek go nie zmieni
function GuideController.SetFixedTarget(instance: Instance?, label: string?)
	fixed = if instance then { target = instance, label = label or "" } else nil
	lastScan = 0
end

function GuideController.Init()
	fx = Instance.new("Folder")
	fx.Name = "JobGuide"
	fx.Parent = Workspace
	-- Własny ScreenGui bez UIScale: strzałka stoi w pikselach ekranu (WorldToViewportPoint)
	local gui = Instance.new("ScreenGui")
	gui.Name = "GuideUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	arrow = Instance.new("TextLabel")
	arrow.Name = "EdgeArrow"
	arrow.Size = UDim2.fromOffset(64, 64)
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextScaled = true
	arrow.TextColor3 = COLOR
	arrow.Text = "➤"
	arrow.Visible = false
	arrow:SetAttribute("NoTranslate", true)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = arrow
	arrow.Parent = gui
	RunService.RenderStepped:Connect(step)
	-- Pierwsze E przy nowo odblokowanej pracy (podpowiedź w jej StartAttachment) zdejmuje napis "Nowa praca!"
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if temporary and (prompt.Parent == temporary.target or prompt:IsDescendantOf(temporary.target)) then
			temporary = nil
			lastScan = 0
		end
	end)
end

return GuideController

-- Wspólna podstawa potworów: model zakotwiczony (bez fizyki), ruch po ścieżce z PathfindingService
-- płynnie co klatkę, sprawdzanie widoczności gracza i łapanie. Zasady zachowania są w Monsters/*.
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)

local Monster = {}
Monster.__index = Monster

local EYE_HEIGHT = 5
local WAYPOINT_REACHED = 0.6
local TURN_SPEED = 10

-- model: Model z PrimaryPart "Root" w miejscu stóp, przód = -Z
function Monster.new(round, id: string, model: Model, position: Vector3)
	local self = setmetatable({}, Monster)
	self.round = round
	self.id = id
	self.model = model
	self.position = position
	self.look = Vector3.new(1, 0, 0)
	self.waypoints = nil
	self.waypointIndex = 0
	self.speed = 8
	self.pathRequest = 0
	self.pathPending = false
	self.lastPathAt = -math.huge
	self.bob = 0
	self.alive = true
	self.agent = {
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 4,
	}
	self.animated = {}
	self.mood = nil
	model:SetAttribute("MonsterId", id)
	model:SetAttribute("Hostile", false)
	self.moodLabel = Monster.MoodBillboard(model)
	model:PivotTo(CFrame.lookAt(position, position + self.look))
	model.Parent = round.building.model
	self.heartbeat = RunService.Heartbeat:Connect(function(dt)
		self:Step(dt)
	end)
	return self
end

-- Ikona nad głową (💤 ❓ ❗): dzieci od razu widzą, co potwór "myśli"
function Monster.MoodBillboard(model: Model): TextLabel
	local head = model:FindFirstChild("Head", true)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Mood"
	billboard.Size = UDim2.fromOffset(70, 70)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	billboard.Adornee = if head and head:IsA("BasePart") then head else model.PrimaryPart
	billboard.MaxDistance = 70
	billboard.AlwaysOnTop = true
	billboard.Parent = model
	local label = Instance.new("TextLabel")
	label.Name = "Icon"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = ""
	label.Parent = billboard
	return label
end

-- mood: "sleep" | "curious" | "alert" | nil (spokojny). alert = potwór goni (klient gra bicie serca)
local MOOD_ICONS = { sleep = "💤", curious = "❓", alert = "❗" }
function Monster:SetMood(mood: string?)
	if self.mood == mood then
		return
	end
	self.mood = mood
	self.moodLabel.Text = MOOD_ICONS[mood or ""] or ""
	self.model:SetAttribute("Hostile", mood == "alert")
	self.model:SetAttribute("Mood", mood)
end

-- Animowana część: fn(t, base) zwraca położenie części względem stóp potwora (base = położenie wyjściowe)
function Monster:Animate(partName: string, fn)
	local root = self.model.PrimaryPart
	for _, descendant in self.model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == partName then
			table.insert(self.animated, { part = descendant, base = root.CFrame:ToObjectSpace(descendant.CFrame), fn = fn })
		end
	end
end

-- Idź do punktu (liczy ścieżkę w tle). Zwraca od razu; IsMoving() mówi, czy jeszcze idzie.
function Monster:MoveTo(target: Vector3, speed: number)
	self.speed = speed
	self.goal = target
	self.pathRequest += 1
	local request = self.pathRequest
	self.pathPending = true
	self.lastPathAt = os.clock()
	-- Osobny obiekt Path na każde zapytanie: starsze, wolniejsze wyniki nie nadpiszą nowszych
	local path = PathfindingService:CreatePath(self.agent)
	task.spawn(function()
		local ok = pcall(function()
			path:ComputeAsync(self.position, target)
		end)
		if request ~= self.pathRequest or not self.alive then
			return
		end
		self.pathPending = false
		if ok and path.Status == Enum.PathStatus.Success then
			self.waypoints = path:GetWaypoints()
			self.waypointIndex = 2 -- pierwszy punkt to miejsce startu
		else
			self.waypoints = nil
			self.failedPath = true
		end
	end)
end

function Monster:Stop()
	self.pathRequest += 1
	self.pathPending = false
	self.waypoints = nil
end

function Monster:IsMoving(): boolean
	return self.pathPending or (self.waypoints ~= nil and self.waypointIndex <= #self.waypoints)
end

-- Ruch co klatkę wzdłuż punktów ścieżki
function Monster:Step(dt: number)
	if not self.alive then
		return
	end
	self.bob += dt
	local waypoints = self.waypoints
	if waypoints and self.waypointIndex <= #waypoints then
		local target = waypoints[self.waypointIndex].Position
		local offset = target - self.position
		local distance = offset.Magnitude
		local step = self.speed * dt
		if distance <= math.max(step, WAYPOINT_REACHED) then
			self.position = target
			self.waypointIndex += 1
		else
			self.position += offset.Unit * step
		end
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 0.05 then
			self.look = self.look:Lerp(flat.Unit, math.clamp(dt * TURN_SPEED, 0, 1))
		end
	end
	local look = Vector3.new(self.look.X, 0, self.look.Z)
	if look.Magnitude < 0.01 then
		look = Vector3.new(1, 0, 0)
	end
	-- Lekkie kołysanie przy chodzeniu, oddychanie w miejscu
	local moving = self:IsMoving()
	local bobY = if moving then math.abs(math.sin(self.bob * self.speed * 0.9)) * 0.35 else math.sin(self.bob * 2) * 0.08
	local tilt = if moving then math.sin(self.bob * self.speed * 0.45) * math.rad(4) else 0
	local pivot = CFrame.lookAt(self.position, self.position + look.Unit) * CFrame.new(0, bobY, 0) * CFrame.Angles(0, 0, tilt)
	self.model:PivotTo(pivot)
	for _, entry in self.animated do
		entry.part.CFrame = pivot * entry.fn(self.bob, entry.base)
	end
end

function Monster:EyePosition(): Vector3
	return self.position + Vector3.new(0, EYE_HEIGHT, 0)
end

function Monster:Floor(): number
	return self.round:FloorOf(self.position + Vector3.new(0, 1, 0))
end

-- Czy potwór widzi część (głowę gracza): promień trafia tylko w ściany i meble kamienicy
function Monster:CanSee(target: BasePart, maxDistance: number?): boolean
	local from = self:EyePosition()
	local offset = target.CFrame.Position - from
	if maxDistance and offset.Magnitude > maxDistance then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { self.round.building.geometry }
	return workspace:Raycast(from, offset, params) == nil
end

function Monster:DistanceTo(position: Vector3): number
	return (Vector3.new(position.X, 0, position.Z) - Vector3.new(self.position.X, 0, self.position.Z)).Magnitude
end

-- Łapie graczy w zasięgu na tym samym piętrze. Zwraca true, jeśli kogoś złapał.
function Monster:TryCatch(distance: number?): boolean
	local reach = distance or MonsterConfig.CATCH_DISTANCE
	local caught = false
	for _, target in self.round:Targets() do
		if math.abs(target.root.CFrame.Position.Y - 3 - self.position.Y) < 6 and self:DistanceTo(target.root.CFrame.Position) <= reach then
			self.round:Catch(target.player, self.id)
			caught = true
		end
	end
	return caught
end

-- Pozioma prędkość gracza (do słuchu Sąsiada)
function Monster.SpeedOf(root: BasePart): number
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

function Monster:Destroy()
	if not self.alive then
		return
	end
	self.alive = false
	self.pathRequest += 1
	if self.heartbeat then
		self.heartbeat:Disconnect()
	end
	self.model:Destroy()
end

return Monster

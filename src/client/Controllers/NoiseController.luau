-- Pierścień hałasu: świecące kółko pod postacią pokazuje, z jakiej odległości Cichy Sąsiad Cię słyszy.
-- Liczy je ten sam moduł Noise co serwer, więc gracz widzi dokładnie zasadę gry: bieg i pełne kieszenie
-- powiększają kółko, powolny chód z lekkimi kieszeniami je chowa. Pełne kieszenie przy chodzeniu brzęczą.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Noise = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Noise"))
local ClientState = require(script.Parent.ClientState)
local SoundController = require(script.Parent.SoundController)

local NoiseController = {}

local QUIET = Color3.fromRGB(120, 230, 140)
local MEDIUM = Color3.fromRGB(255, 210, 80)
local LOUD = Color3.fromRGB(255, 90, 90)
local JINGLE_INTERVAL = 0.45

local player = Players.LocalPlayer
local ring = nil
local shown = 0
local jingleTimer = 0

local function buildRing()
	ring = Instance.new("Part")
	ring.Name = "NoiseRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Transparency = 1
	ring.Size = Vector3.new(0.1, 1, 1)
	ring.Color = QUIET
	-- Pod kamerą: część istnieje tylko u tego gracza
	ring.Parent = Workspace.CurrentCamera or Workspace
end

local function update(dt: number)
	local round = ClientState.round
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local radius = 0
	local speed = 0
	if round and round.status == "inside" and not round.hidden and root and root:IsA("BasePart") and humanoid then
		local velocity = root.AssemblyLinearVelocity
		speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		radius = Noise.Radius(speed, round.carried, round.capacity, round.hearing or 1)
		-- Na parterze (przed północą) nikt nie słucha: kółko pokazujemy od 1. piętra
		if round.floor == 0 and round.phase ~= "hunt" then
			radius = 0
		end
	end
	shown += (radius - shown) * math.clamp(dt * 8, 0, 1)
	if shown < 0.5 or not root then
		ring.Transparency = 1
	else
		local feet = (root :: BasePart).CFrame.Position - Vector3.new(0, (humanoid :: Humanoid).HipHeight + (root :: BasePart).Size.Y / 2 - 0.1, 0)
		ring.Size = Vector3.new(0.05, shown * 2, shown * 2)
		ring.CFrame = CFrame.new(feet) * CFrame.Angles(0, 0, math.rad(90))
		ring.Color = if shown < 12 then QUIET elseif shown < 26 then MEDIUM else LOUD
		ring.Transparency = 0.82
	end
	-- Brzęk monet przy chodzeniu z pełnymi kieszeniami
	if round and round.status == "inside" and not round.hidden and speed > 2 and Noise.Jingles(round.carried, round.capacity) then
		jingleTimer -= dt
		if jingleTimer <= 0 then
			jingleTimer = JINGLE_INTERVAL
			SoundController.Play("Jingle", 1.3 + math.random() * 0.3)
		end
	end
end

function NoiseController.Init()
	buildRing()
end

function NoiseController.Start()
	RunService.RenderStepped:Connect(update)
end

return NoiseController

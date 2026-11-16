-- Poza na pojeździe: gdy serwer ustawi postaci atrybut "RidePose" ("stand" = hulajnoga, "sit" = skuter),
-- odtwarzamy animację stania albo siedzenia z najwyższym priorytetem (przykrywa chód i bieg), więc jedzie pojazd,
-- a nogi nie biegną po ziemi. Animacje w skrypcie Animate zostają nietknięte, więc po jeździe chód działa normalnie.
-- Animacje gracza widzą też inni (Roblox je przesyła).
-- Przy wheelie przechylamy postać o kąt pojazdu (wokół osi tylnego koła) u wszystkich jeżdżących graczy:
-- po animacji dokładamy obrót do Transform stawu biodrowego (Motor6D albo nowy AnimationConstraint).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RidePoseController = {}

local poseTrack: AnimationTrack? = nil

local function stopPose()
	if poseTrack then
		poseTrack:Stop(0.2)
		poseTrack:Destroy()
		poseTrack = nil
	end
end

-- AnimationId pozy z Animate postaci (pasuje do R15 i R6 oraz do paczek animacji awatara)
local function poseAnimationId(character: Model, pose: string): string?
	local animate = character:FindFirstChild("Animate")
	local config = animate and animate:FindFirstChild(if pose == "sit" then "sit" else "idle")
	if config then
		for _, child in config:GetChildren() do
			if child:IsA("Animation") and child.AnimationId ~= "" then
				return child.AnimationId
			end
		end
	end
	return nil
end

local function apply(character: Model)
	stopPose()
	local pose = character:GetAttribute("RidePose")
	if pose ~= "stand" and pose ~= "sit" then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local id = poseAnimationId(character, pose)
	if not animator or not id then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	poseTrack = animator:LoadAnimation(animation)
	poseTrack.Priority = Enum.AnimationPriority.Action4
	poseTrack.Looped = true
	poseTrack:Play(0.15)
end

local function bind(character: Model)
	stopPose()
	character:GetAttributeChangedSignal("RidePose"):Connect(function()
		apply(character)
	end)
	if character:GetAttribute("RidePose") then
		task.defer(apply, character)
	end
end

local VEHICLES = { "RentalScooter", "PizzaScooter", "KebabBike" }
local crankStart = setmetatable({}, { __mode = "k" }) -- [CrankWeld] = { c0, kąt }

-- Pedałowanie: korba roweru obraca się tym szybciej, im szybciej jedzie rowerzysta (stopy idą za pedałami przez IK)
local function spinCrank(vehicle: Instance, root: BasePart, dt: number)
	local crank = vehicle:FindFirstChild("Crank")
	local weld = crank and crank:FindFirstChild("CrankWeld")
	if not weld then
		return
	end
	local entry = crankStart[weld]
	if not entry then
		entry = { c0 = weld.C0, angle = 0 }
		crankStart[weld] = entry
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	entry.angle = (entry.angle + speed * dt * 0.45) % (math.pi * 2)
	weld.C0 = entry.c0 * CFrame.Angles(-entry.angle, 0, 0)
end

-- Staw biodrowy i jego punkt zaczepienia w układzie HumanoidRootPart (odpowiednik C0)
local function rootJoint(character: Model, root: BasePart): (Instance?, CFrame?)
	local lower = character:FindFirstChild("LowerTorso")
	local joint = lower and lower:FindFirstChild("Root") or root:FindFirstChild("RootJoint")
	if joint and joint:IsA("Motor6D") then
		return joint, joint.C0
	elseif joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
		return joint, root.CFrame:ToObjectSpace(joint.Attachment0.WorldCFrame)
	end
	return nil, nil
end

-- Po animacjach: obrót pojazdu względem HumanoidRootPart = kąt wheelie; ten sam obrót dla tułowia
local function tiltRiders(_time: number, dt: number)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and character:GetAttribute("RidePose") then
			local base = nil
			for _, name in VEHICLES do
				local vehicle = character:FindFirstChild(name)
				base = vehicle and vehicle.PrimaryPart
				if base then
					spinCrank(vehicle, root, dt)
					break
				end
			end
			local motor, c0 = nil, nil
			if base then
				motor, c0 = rootJoint(character, root)
			end
			if motor and c0 then
				local relative = root.CFrame:ToObjectSpace(base.CFrame)
				local rotation = relative - relative.Position
				if math.abs(rotation.LookVector.Y) > 0.01 then
					local pivot = CFrame.new(relative.Position)
					local world = pivot * rotation * pivot:Inverse()
					motor.Transform = c0:Inverse() * world * c0 * motor.Transform
				end
			end
		end
	end
end

function RidePoseController.Init()
	local player = Players.LocalPlayer
	if player.Character then
		bind(player.Character)
	end
	player.CharacterAdded:Connect(bind)
	RunService.Stepped:Connect(tiltRiders)
end

return RidePoseController

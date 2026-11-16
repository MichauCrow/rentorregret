-- Chód, sprint (Shift albo przycisk na telefonie) z kondycją, latarka (F albo przycisk) i blokada resetu w rundzie.
-- Prędkość postaci ustawiamy u gracza (postać jest jego), serwer słyszy bieganie po prędkości.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ShopConfig"))
local ClientState = require(script.Parent.ClientState)

local MovementController = {}

local LOBBY_WALK = 16
local LOBBY_SPRINT = 24

local player = Players.LocalPlayer
local wantSprint = false
local stamina = GameConfig.STAMINA
local exhausted = false
local flashlightOn = false
local resetBlocked = nil

MovementController.SprintChanged = Instance.new("BindableEvent")
MovementController.FlashlightChanged = Instance.new("BindableEvent")

local function staminaMax(): number
	local profile = ClientState.profile
	local level = if profile then profile.upgrades.stamina or 1 else 1
	local upgrade = ShopConfig.Upgrades.stamina
	return GameConfig.STAMINA * upgrade.levels[math.clamp(level, 1, #upgrade.levels)].value
end

function MovementController.Stamina(): (number, number)
	return stamina, staminaMax()
end

function MovementController.IsSprinting(): boolean
	return wantSprint and not exhausted
end

function MovementController.SetSprint(on: boolean)
	wantSprint = on
	MovementController.SprintChanged:Fire(on)
end

function MovementController.ToggleFlashlight()
	local round = ClientState.round
	if not round or round.status ~= "inside" or round.hidden then
		return
	end
	flashlightOn = not flashlightOn
	if flashlightOn and round.battery <= 0 then
		flashlightOn = false
	end
	ClientState.Remote("Flashlight"):FireServer(flashlightOn)
	MovementController.FlashlightChanged:Fire(flashlightOn)
end

function MovementController.FlashlightOn(): boolean
	return flashlightOn
end

local function setResetBlocked(blocked: boolean)
	if resetBlocked == blocked then
		return
	end
	task.spawn(function()
		for _ = 1, 10 do
			local ok = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", not blocked)
			end)
			if ok then
				resetBlocked = blocked
				return
			end
			task.wait(1)
		end
	end)
end

function MovementController.Init()
	ContextActionService:BindAction("Sprint", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			MovementController.SetSprint(true)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			MovementController.SetSprint(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)

	ContextActionService:BindAction("Flashlight", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			MovementController.ToggleFlashlight()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
end

function MovementController.Start()
	ClientState.OnRound(function(round)
		setResetBlocked(round ~= nil)
		-- Serwer jest źródłem prawdy o latarce (bateria, szafa, złapanie)
		local serverOn = round ~= nil and round.flashlight == true
		if serverOn ~= flashlightOn then
			flashlightOn = serverOn
			MovementController.FlashlightChanged:Fire(flashlightOn)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local round = ClientState.round
		local maxStamina = staminaMax()
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local sprinting = wantSprint and not exhausted and moving
		if round then
			if sprinting then
				stamina = math.max(0, stamina - dt)
				if stamina <= 0 then
					exhausted = true
				end
			else
				stamina = math.min(maxStamina, stamina + GameConfig.STAMINA_REGEN * dt)
				if exhausted and stamina >= maxStamina * 0.35 then
					exhausted = false
				end
			end
			humanoid.WalkSpeed = if sprinting then GameConfig.SPRINT_SPEED else GameConfig.WALK_SPEED
		else
			stamina = maxStamina
			exhausted = false
			humanoid.WalkSpeed = if wantSprint then LOBBY_SPRINT else LOBBY_WALK
		end
	end)
end

return MovementController

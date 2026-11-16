-- Bieganie: przytrzymaj Shift (komputer) albo włącz przycisk 🏃 (telefon, tablet). Prędkość x1.35.
-- Liczymy od aktualnej prędkości, więc działa też przy skuterze (praca pizzy ustawia prędkość na serwerze).
-- Gdy gra zmieni prędkość w trakcie biegu (np. start zmiany), przyjmujemy nową wartość i przerywamy bieg.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))

local SprintController = {}

local MULTIPLIER = 1.35
local SPRINT_KEYS = { [Enum.KeyCode.LeftShift] = true, [Enum.KeyCode.RightShift] = true, [Enum.KeyCode.ButtonL3] = true }

local humanoid = nil

-- WalkSpeed jest zapisywany z mniejszą dokładnością (21.6 -> 21.6000004), więc porównujemy z tolerancją
local function same(a: number?, b: number?): boolean
	return a ~= nil and b ~= nil and math.abs(a - b) < 0.01
end
local baseSpeed = nil -- prędkość sprzed biegu
local boostedSpeed = nil
local touchButton = nil

local function stop()
	if humanoid and boostedSpeed and same(humanoid.WalkSpeed, boostedSpeed) then
		humanoid.WalkSpeed = baseSpeed
	end
	baseSpeed, boostedSpeed = nil, nil
	if touchButton then
		touchButton.BackgroundColor3 = UIKit.COLORS.panel
	end
end

local function start()
	-- Na hulajnodze Shift robi wheelie zamiast biegu
	if not humanoid or boostedSpeed or (humanoid.Parent and humanoid.Parent:GetAttribute("Riding")) then
		return
	end
	baseSpeed = humanoid.WalkSpeed
	boostedSpeed = math.floor(baseSpeed * MULTIPLIER * 10 + 0.5) / 10
	humanoid.WalkSpeed = boostedSpeed
	boostedSpeed = humanoid.WalkSpeed
	if touchButton then
		touchButton.BackgroundColor3 = UIKit.COLORS.good
	end
end

local function bindCharacter(character: Model)
	baseSpeed, boostedSpeed = nil, nil
	humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		-- Zmiana z zewnątrz (serwer): kończymy bieg bez przywracania starej prędkości
		if boostedSpeed and not same(humanoid.WalkSpeed, boostedSpeed) then
			baseSpeed, boostedSpeed = nil, nil
			if touchButton then
				touchButton.BackgroundColor3 = UIKit.COLORS.panel
			end
		end
	end)
end

function SprintController.Init()
	local player = Players.LocalPlayer
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and SPRINT_KEYS[input.KeyCode] then
			start()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if SPRINT_KEYS[input.KeyCode] then
			stop()
		end
	end)

	-- Na ekranach dotykowych: przycisk włącz/wyłącz bieg nad przyciskiem skoku
	if UserInputService.TouchEnabled then
		local gui = UIKit.screenGui("SprintUI", 1, "hud")
		touchButton = UIKit.button("Sprint", "🏃", UIKit.COLORS.panel, {
			Size = UDim2.fromOffset(78, 78),
			Position = UDim2.new(1, -110, 1, -230),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextSize = 40,
		})
		touchButton:SetAttribute("NoTranslate", true)
		touchButton.Activated:Connect(function()
			if boostedSpeed then
				stop()
			else
				start()
			end
		end)
		touchButton.Parent = gui
	end
end

return SprintController

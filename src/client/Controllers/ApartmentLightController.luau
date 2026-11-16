-- Światło w mieszkaniu: gdy gracz jest w środku mieszkania, w którym lampy są wyłączone
-- (awaria światła albo prądu), wnętrze robi się dużo ciemniejsze. Zmiana tylko u tego gracza.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ApartmentLightController = {}

local DARK_AMBIENT = Color3.fromRGB(14, 12, 22)
local CHECK_INTERVAL = 0.25
local TWEEN = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local normalAmbient = nil
local dark = false
local shade = nil -- lokalna korekcja kolorów na czas ciemności

-- Mieszkanie, w którym stoi gracz (wnętrze = nad podłogą i pod sufitem)
local function apartmentAround(position: Vector3): Model?
	local apartments = Workspace:FindFirstChild("Apartments")
	if not apartments then
		return nil
	end
	for _, apartment in apartments:GetChildren() do
		local floor = apartment:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			local localPosition = floor.CFrame:PointToObjectSpace(position)
			if math.abs(localPosition.X) < floor.Size.X / 2 and math.abs(localPosition.Z) < floor.Size.Z / 2 and localPosition.Y > 0 and localPosition.Y < 18 then
				return apartment
			end
		end
	end
	return nil
end

local function lightsOff(apartment: Model): boolean
	local lamp = apartment:FindFirstChild("Lamp")
	local light = lamp and lamp:FindFirstChildOfClass("PointLight")
	return light ~= nil and not light.Enabled
end

local function setDark(value: boolean)
	if value == dark then
		return
	end
	dark = value
	if value then
		normalAmbient = Lighting.Ambient
	end
	TweenService:Create(Lighting, TWEEN, { Ambient = if value then DARK_AMBIENT else (normalAmbient or Lighting.Ambient) }):Play()
	TweenService:Create(shade, TWEEN, { Brightness = if value then -0.12 else 0, Saturation = if value then -0.25 else 0 }):Play()
end

function ApartmentLightController.Init()
	shade = Instance.new("ColorCorrectionEffect")
	shade.Name = "ApartmentDarkness"
	shade.Parent = Lighting
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local apartment = root and apartmentAround(root.Position)
			setDark(apartment ~= nil and lightsOff(apartment))
		end
	end)
end

return ApartmentLightController

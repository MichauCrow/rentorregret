-- Oświetlenie u gracza (zmiany Lighting z klienta nie idą do innych): ciepły wieczór w holu,
-- ciemna noc w kamienicy, fioletowy odcień o północy, jaśniejszy i wyblakły świat dla duszka.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local ClientState = require(script.Parent.ClientState)

local LightingController = {}

local PRESETS = {
	lobby = {
		lighting = { ClockTime = 18.4, Brightness = 2, Ambient = Color3.fromRGB(95, 85, 110), OutdoorAmbient = Color3.fromRGB(150, 125, 150), FogEnd = 280, FogColor = Color3.fromRGB(70, 55, 90), ExposureCompensation = 0 },
		correction = { Saturation = 0.15, Contrast = 0.05, Brightness = 0.02, TintColor = Color3.fromRGB(255, 240, 225) },
		atmosphere = { Density = 0.3, Color = Color3.fromRGB(200, 160, 190), Decay = Color3.fromRGB(120, 90, 140), Haze = 1 },
	},
	round = {
		lighting = { ClockTime = 0, Brightness = 0.4, Ambient = Color3.fromRGB(22, 20, 34), OutdoorAmbient = Color3.fromRGB(40, 40, 62), FogEnd = 160, FogColor = Color3.fromRGB(12, 10, 24), ExposureCompensation = 0.1 },
		correction = { Saturation = -0.1, Contrast = 0.12, Brightness = 0, TintColor = Color3.fromRGB(215, 215, 255) },
		atmosphere = { Density = 0.35, Color = Color3.fromRGB(60, 60, 100), Decay = Color3.fromRGB(30, 30, 60), Haze = 0.5 },
	},
	hunt = {
		lighting = { ClockTime = 0, Brightness = 0.4, Ambient = Color3.fromRGB(34, 18, 34), OutdoorAmbient = Color3.fromRGB(60, 30, 50), FogEnd = 140, FogColor = Color3.fromRGB(30, 8, 24), ExposureCompensation = 0.1 },
		correction = { Saturation = 0, Contrast = 0.18, Brightness = 0, TintColor = Color3.fromRGB(255, 205, 235) },
		atmosphere = { Density = 0.4, Color = Color3.fromRGB(100, 40, 80), Decay = Color3.fromRGB(60, 20, 50), Haze = 0.8 },
	},
	ghost = {
		lighting = { ClockTime = 0, Brightness = 0.8, Ambient = Color3.fromRGB(70, 75, 100), OutdoorAmbient = Color3.fromRGB(80, 85, 110), FogEnd = 220, FogColor = Color3.fromRGB(40, 50, 80), ExposureCompensation = 0.3 },
		correction = { Saturation = -0.6, Contrast = 0.05, Brightness = 0.03, TintColor = Color3.fromRGB(200, 230, 255) },
		atmosphere = { Density = 0.3, Color = Color3.fromRGB(120, 150, 200), Decay = Color3.fromRGB(80, 100, 150), Haze = 0.5 },
	},
}

local current = nil
local correction = nil
local atmosphere = nil

local function apply(name: string)
	if current == name then
		return
	end
	current = name
	local preset = PRESETS[name]
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, preset.lighting):Play()
	if correction then
		TweenService:Create(correction, info, preset.correction):Play()
	end
	if atmosphere then
		TweenService:Create(atmosphere, info, preset.atmosphere):Play()
	end
end

function LightingController.Init()
	correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not correction then
		correction = Instance.new("ColorCorrectionEffect")
		correction.Parent = Lighting
	end
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	-- Rozmycie tła przeszkadza w szukaniu monet
	local blur = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if blur then
		blur.Enabled = false
	end
	Lighting.GlobalShadows = true
end

function LightingController.Start()
	ClientState.OnRound(function(round)
		if not round then
			apply("lobby")
		elseif round.status == "ghost" then
			apply("ghost")
		elseif round.phase == "hunt" then
			apply("hunt")
		else
			apply("round")
		end
	end)
end

return LightingController

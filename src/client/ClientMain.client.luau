-- Punkt startowy klienta: Init() wszystkich kontrolerów (budowa interfejsu), potem Start() (podpięcie zdarzeń).
local RunService = game:GetService("RunService")

local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"ClientState",
	"UIKit",
	"SoundController",
	"LightingController",
	"MovementController",
	"AmbienceController",
	"HUDController",
	"ObjectiveController",
	"FxController",
	"ShopController",
	"SettingsController",
	"LanguageController", -- na końcu: śledzi teksty wszystkich zbudowanych już okien
}

local modules = {}
for _, name in ORDER do
	modules[name] = require(Controllers:WaitForChild(name))
end

for _, name in ORDER do
	local module = modules[name]
	if module.Init then
		local ok, err = pcall(module.Init)
		if not ok then
			warn("[ClientMain] " .. name .. ".Init: " .. tostring(err))
		end
	end
end

for _, name in ORDER do
	local module = modules[name]
	if module.Start then
		local ok, err = pcall(module.Start)
		if not ok then
			warn("[ClientMain] " .. name .. ".Start: " .. tostring(err))
		end
	end
end

-- W Studio: raport, które dźwięki z AssetsConfig się wczytują (okno Output)
if RunService:IsStudio() then
	task.delay(5, function()
		pcall(modules.SoundController.CheckAll)
	end)
end

-- Punkt startowy klienta: Init() wszystkich kontrolerów (budowa interfejsu), potem Start() (podpięcie zdarzeń).
local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"ClientState",
	"UIKit",
	"SoundController",
	"LightingController",
	"MovementController",
	"HUDController",
	"FxController",
	"ShopController",
	"SettingsController",
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

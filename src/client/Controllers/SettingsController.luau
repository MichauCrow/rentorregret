-- Ustawienia (zapisywane na serwerze): straszenie (jumpscare) wł./wył. i dźwięk (wszystko / bez muzyki / cisza).
local ClientState = require(script.Parent.ClientState)
local HUDController = require(script.Parent.HUDController)
local UIKit = require(script.Parent.UIKit)

local SettingsController = {}

local C = UIKit.COLORS
local SOUND_MODES = { "🔊 Wszystko", "🎵 Bez muzyki", "🔇 Cisza" }
local LANG_ORDER = { "auto", "pl", "en" }
local LANG_TEXT = { auto = "🌍 Język: automatycznie", pl = "🌍 Język: polski", en = "🌍 Language: English" }
local panel = nil
local scareButton = nil
local soundButton = nil
local langButton = nil
local captionsButton = nil

local function render()
	local profile = ClientState.profile
	if not profile or not panel then
		return
	end
	local scares = profile.settings.jumpscares ~= false
	scareButton.Text = if scares then "😱 Straszenie: WŁĄCZONE" else "😌 Straszenie: WYŁĄCZONE"
	scareButton.BackgroundColor3 = if scares then C.option else C.button
	soundButton.Text = SOUND_MODES[profile.settings.sound or 1] or SOUND_MODES[1]
	langButton.Text = LANG_TEXT[profile.settings.lang or "auto"] or LANG_TEXT.auto
	captionsButton.Text = if profile.settings.captions ~= false then "💬 Napisy dźwięków: WŁĄCZONE" else "💬 Napisy dźwięków: WYŁĄCZONE"
end

local function set(key: string, value: any)
	local profile = ClientState.profile
	if profile then
		profile.settings[key] = value
		ClientState.SetProfile(profile)
	end
	ClientState.Remote("SetSetting"):FireServer(key, value)
end

function SettingsController.Open()
	render()
	UIKit.popIn(panel)
end

function SettingsController.Init()
	local gui = UIKit.screenGui("Settings", 11)
	panel = UIKit.panel("Settings", UDim2.fromOffset(480, 450), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UIKit.closeButton(panel, function()
		panel.Visible = false
	end)
	UIKit.label("Title", { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 12), Text = "⚙️ USTAWIENIA", TextSize = 34, TextColor3 = C.title }).Parent = panel
	scareButton = UIKit.button("Scares", "", C.option, { Size = UDim2.new(1, -60, 0, 60), Position = UDim2.fromOffset(30, 80), TextSize = 22 })
	scareButton.Activated:Connect(function()
		local profile = ClientState.profile
		if profile then
			set("jumpscares", not (profile.settings.jumpscares ~= false))
		end
	end)
	scareButton.Parent = panel
	UIKit.label("ScareHint", { Size = UDim2.new(1, -60, 0, 30), Position = UDim2.fromOffset(30, 142), Text = "Wyłączone = bez nagłych buziek potworów przy złapaniu.", TextSize = 16, TextColor3 = Color3.fromRGB(210, 210, 240) }).Parent = panel
	soundButton = UIKit.button("Sound", "", C.option, { Size = UDim2.new(1, -60, 0, 60), Position = UDim2.fromOffset(30, 190), TextSize = 22 })
	soundButton.Activated:Connect(function()
		local profile = ClientState.profile
		if profile then
			set("sound", (profile.settings.sound or 1) % #SOUND_MODES + 1)
		end
	end)
	soundButton.Parent = panel
	langButton = UIKit.button("Language", "", C.option, { Size = UDim2.new(1, -60, 0, 60), Position = UDim2.fromOffset(30, 265), TextSize = 22 })
	langButton.Activated:Connect(function()
		local profile = ClientState.profile
		if profile then
			local current = table.find(LANG_ORDER, profile.settings.lang or "auto") or 1
			set("lang", LANG_ORDER[current % #LANG_ORDER + 1])
		end
	end)
	langButton.Parent = panel
	captionsButton = UIKit.button("Captions", "", C.option, { Size = UDim2.new(1, -60, 0, 60), Position = UDim2.fromOffset(30, 340), TextSize = 22 })
	captionsButton.Activated:Connect(function()
		local profile = ClientState.profile
		if profile then
			set("captions", profile.settings.captions == false)
		end
	end)
	captionsButton.Parent = panel
	panel.Parent = gui
end

function SettingsController.Start()
	HUDController.SetSettingsOpener(SettingsController.Open)
	ClientState.OnProfile(render)
end

return SettingsController

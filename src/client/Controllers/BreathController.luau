-- Minigra "Wstrzymaj oddech!": potwór zagląda do Twojej szafy. Trzymaj przycisk (spacja / klik / palec),
-- żeby wskaźnik szedł w prawo, puść, żeby wracał. Utrzymaj go w zielonym polu (ono się przesuwa) przez
-- większość czasu. Wynik idzie do serwera; nieudana minigra = potwór Cię znalazł.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClientState = require(script.Parent.ClientState)
local SoundController = require(script.Parent.SoundController)
local UIKit = require(script.Parent.UIKit)

local BreathController = {}

local C = UIKit.COLORS
local ZONE_WIDTH = 0.32
local PASS_RATIO = 0.55
local ACCELERATION = 2.6
local MAX_SPEED = 1.2
local MONSTER_FACES = { neighbor = "🤫", landlord = "🔑", cat = "🐱" }
local HOLD_INPUTS = {
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.ButtonA] = true,
}

local gui = nil
local panel = nil
local zone = nil
local needle = nil
local meter = nil
local face = nil
local active = nil -- { duration, elapsed, inZone, p, v, phase }
local holding = 0

local function isHoldInput(input: InputObject): boolean
	return HOLD_INPUTS[input.KeyCode] == true
		or input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function finish()
	local run = active
	active = nil
	panel.Visible = false
	if not run then
		return
	end
	local success = run.inZone / math.max(0.01, run.duration) >= PASS_RATIO
	ClientState.Remote("BreathResult"):FireServer(success)
end

local function step(dt: number)
	local run = active
	if not run then
		return
	end
	run.elapsed += dt
	-- Wskaźnik: przytrzymanie pcha w prawo, puszczenie ściąga w lewo
	run.v = math.clamp(run.v + (if holding > 0 then ACCELERATION else -ACCELERATION) * dt, -MAX_SPEED, MAX_SPEED)
	run.p += run.v * dt
	if run.p <= 0 or run.p >= 1 then
		run.p = math.clamp(run.p, 0, 1)
		run.v = 0
	end
	-- Zielone pole płynnie wędruje
	local t = run.elapsed + run.phase
	local center = 0.5 + math.sin(t * 1.3) * 0.28 + math.sin(t * 3.1) * 0.06
	center = math.clamp(center, ZONE_WIDTH / 2, 1 - ZONE_WIDTH / 2)
	local inside = math.abs(run.p - center) <= ZONE_WIDTH / 2
	if inside then
		run.inZone += dt
	end
	zone.Position = UDim2.fromScale(center, 0.5)
	zone.BackgroundColor3 = if inside then C.good else Color3.fromRGB(70, 160, 90)
	needle.Position = UDim2.fromScale(run.p, 0.5)
	meter.Size = UDim2.fromScale(math.clamp(run.inZone / (run.duration * PASS_RATIO), 0, 1), 1)
	face.Rotation = math.sin(run.elapsed * 8) * 6
	if run.elapsed >= run.duration then
		finish()
	end
end

local function start(data)
	active = {
		duration = if type(data.duration) == "number" then data.duration else 4,
		elapsed = 0,
		inZone = 0,
		p = 0.5,
		v = 0,
		phase = math.random() * 10,
	}
	holding = 0
	face.Text = MONSTER_FACES[data.monster] or "👀"
	panel.Visible = true
	UIKit.popIn(panel)
	SoundController.Play("Warning")
end

function BreathController.Init()
	gui = UIKit.screenGui("Breath", 30)
	panel = UIKit.panel("Breath", UDim2.fromOffset(620, 260), UDim2.fromScale(0.5, 0.55), Vector2.new(0.5, 0.5))
	panel.BackgroundColor3 = Color3.fromRGB(25, 15, 40)
	UIKit.label("Title", { Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 12), Text = "🫣 WSTRZYMAJ ODDECH!", TextSize = 36, TextColor3 = Color3.fromRGB(255, 140, 140) }).Parent = panel
	face = UIKit.label("Face", { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(1, -20, 0, 6), AnchorPoint = Vector2.new(1, 0), Text = "👀", TextScaled = true })
	face:SetAttribute("NoTranslate", true)
	face.Parent = panel
	local track = UIKit.create("Frame", {
		Name = "Track",
		Size = UDim2.new(1, -60, 0, 54),
		Position = UDim2.fromOffset(30, 76),
		BackgroundColor3 = Color3.fromRGB(45, 35, 70),
	}, { UIKit.corner(12), UIKit.border(C.stroke, 2) })
	zone = UIKit.create("Frame", {
		Name = "Zone",
		Size = UDim2.fromScale(ZONE_WIDTH, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = C.good,
	}, { UIKit.corner(10) })
	zone.Parent = track
	needle = UIKit.create("Frame", {
		Name = "Needle",
		Size = UDim2.new(0, 10, 1, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	}, { UIKit.corner(5), UIKit.border(Color3.fromRGB(20, 15, 30), 2) })
	needle.Parent = track
	track.Parent = panel
	local meterBack = UIKit.create("Frame", { Size = UDim2.new(1, -60, 0, 16), Position = UDim2.fromOffset(30, 142), BackgroundColor3 = Color3.fromRGB(45, 35, 70) }, { UIKit.corner(8) })
	meter = UIKit.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(120, 200, 255) }, { UIKit.corner(8) })
	meter.Parent = meterBack
	meterBack.Parent = panel
	UIKit.label("Hint", {
		Size = UDim2.new(1, -40, 0, 60),
		Position = UDim2.fromOffset(20, 170),
		Text = if UserInputService.TouchEnabled then "Trzymaj palec na ekranie = w prawo, puść = w lewo.\nUtrzymaj biały wskaźnik w zielonym polu!" else "Trzymaj SPACJĘ albo przycisk myszy = w prawo, puść = w lewo.\nUtrzymaj biały wskaźnik w zielonym polu!",
		TextSize = 18,
	}).Parent = panel
	panel.Parent = gui
end

function BreathController.Start()
	ClientState.OnRoundEvent(function(kind, data)
		if kind == "breath" and type(data) == "table" then
			start(data)
		elseif kind == "end" or kind == "caught" then
			active = nil
			panel.Visible = false
		end
	end)
	ClientState.OnRound(function(round)
		if not round and active then
			active = nil
			panel.Visible = false
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if active and isHoldInput(input) then
			holding += 1
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isHoldInput(input) then
			holding = math.max(0, holding - 1)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return BreathController

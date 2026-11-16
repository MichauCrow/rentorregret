-- Koło nagród: okno z kolorowymi polami nagród dookoła, przycisk KRĘĆ! w środku i wskazówka u góry.
-- Serwer losuje nagrodę i odpowiada od razu, a klient kręci kołem tak, żeby zatrzymało się dokładnie na niej.
-- Obroty: darmowy raz dziennie i po jednym za każdy nowy poziom. Koła nie da się kupić.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local WheelController = {}

local SIZE = 420
local RING = 138 -- odległość pól od środka
local BULBS = 16
local TURNS = 5
local STYLE = {
	coins = { icon = "💰", color = Color3.fromRGB(255, 165, 40) },
	xp = { icon = "⭐", color = Color3.fromRGB(70, 200, 255) },
	tokens = { icon = "🔑", color = Color3.fromRGB(90, 110, 255) },
}
local JACKPOT = Color3.fromRGB(255, 80, 170)

local callbacks = {}
local refs = {}
local state = nil
local spinning = false
local stateAt = 0

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
end

local function prizeText(prize): string
	return "+" .. tostring(prize.value)
end

local function updateInfo()
	if not refs.info or not state then
		return
	end
	local spins = tonumber(state.spins) or 0
	if spinning then
		refs.info.Text = "Kręci się..."
	elseif spins > 0 then
		refs.info.Text = if state.free then "🎁 Darmowy obrót dostępny!" else "Obroty do wykorzystania: " .. spins
	else
		local left = (tonumber(state.nextFreeIn) or 0) - (os.clock() - stateAt)
		refs.info.Text = "Następny darmowy obrót za " .. clock(left)
	end
	local ready = spins > 0 and not spinning
	refs.hub.BackgroundColor3 = if ready then UIKit.COLORS.button else UIKit.COLORS.locked
	refs.hub.Text = if spinning then "🎲" else "KRĘĆ!"
end

local function applyState(newState)
	if type(newState) ~= "table" then
		return
	end
	state = newState
	stateAt = os.clock()
	if type(state.prizes) == "table" then
		for index, slot in refs.slots do
			local prize = state.prizes[index]
			if type(prize) == "table" then
				local style = STYLE[prize.kind] or STYLE.coins
				slot.icon.Text = style.icon
				slot.value.Text = prizeText(prize)
				slot.frame.BackgroundColor3 = if index == #refs.slots then JACKPOT else style.color
			end
		end
	end
	updateInfo()
end

local function build()
	local gui = UIKit.screenGui("WheelUI", 25)
	local panel = UIKit.panel("Wheel", UDim2.fromOffset(560, 654), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UIKit.closeButton(panel, function()
		if not spinning then
			panel.Visible = false
		end
	end)
	UIKit.label("Title", {
		Text = "🎡 KOŁO NAGRÓD",
		Size = UDim2.new(1, -120, 0, 40),
		Position = UDim2.fromOffset(60, 14),
		TextSize = 34,
		TextColor3 = UIKit.COLORS.title,
	}).Parent = panel
	UIKit.label("Subtitle", {
		Text = "Darmowy obrót codziennie i za każdy nowy poziom!",
		Size = UDim2.new(1, -40, 0, 24),
		Position = UDim2.fromOffset(20, 54),
		TextSize = 18,
	}).Parent = panel

	-- Talerz z żarówkami na obwodzie
	local plate = UIKit.create("Frame", {
		Name = "Plate",
		Size = UDim2.fromOffset(SIZE, SIZE),
		Position = UDim2.new(0.5, 0, 0, 118),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(40, 24, 90),
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.border(UIKit.COLORS.title, 6),
	})
	refs.bulbs = {}
	for index = 0, BULBS - 1 do
		local angle = math.rad(index * 360 / BULBS)
		local bulb = UIKit.create("Frame", {
			Name = "Bulb" .. index,
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(0.5, math.sin(angle) * (SIZE / 2 - 14), 0.5, -math.cos(angle) * (SIZE / 2 - 14)),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 240, 150),
			ZIndex = 2,
		}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		bulb.Parent = plate
		refs.bulbs[index + 1] = bulb
	end

	-- Wirnik z polami nagród (obraca się cały; zawartość pól jest obracana w drugą stronę, żeby stała prosto)
	local rotor = UIKit.create("Frame", {
		Name = "Rotor",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	refs.slots = {}
	local count = 8
	for index = 1, count do
		local angle = math.rad((index - 1) * 360 / count)
		local frame = UIKit.create("Frame", {
			Name = "Slot" .. index,
			Size = UDim2.fromOffset(100, 100),
			Position = UDim2.new(0.5, math.sin(angle) * RING, 0.5, -math.cos(angle) * RING),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = STYLE.coins.color,
			ZIndex = 3,
		}, {
			UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UIKit.border(UIKit.COLORS.stroke, 3),
		})
		UIKit.gloss(frame)
		local pop = UIKit.create("UIScale", {})
		pop.Parent = frame
		local icon = UIKit.label("Icon", {
			Text = "💰",
			Size = UDim2.new(1, 0, 0, 44),
			Position = UDim2.fromOffset(0, 10),
			TextSize = 36,
			TextWrapped = false,
			ZIndex = 4,
		})
		icon.Parent = frame
		local value = UIKit.label("Value", {
			Text = "",
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 54),
			TextSize = 24,
			TextWrapped = false,
			ZIndex = 4,
		})
		value:SetAttribute("NoTranslate", true)
		value.Parent = frame
		frame.Parent = rotor
		refs.slots[index] = { frame = frame, icon = icon, value = value, pop = pop }
	end
	rotor.Parent = plate
	refs.rotor = rotor

	-- Przycisk w środku
	local hub = UIKit.button("Spin", "KRĘĆ!", UIKit.COLORS.button, {
		Size = UDim2.fromOffset(124, 124),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextSize = 32,
		ZIndex = 6,
	})
	local hubCorner = hub:FindFirstChildOfClass("UICorner")
	if hubCorner then
		hubCorner.CornerRadius = UDim.new(1, 0)
	end
	local hubStroke = hub:FindFirstChildOfClass("UIStroke")
	if hubStroke then
		hubStroke.Thickness = 5
	end
	-- Pulsowanie używa skali z UIKit.squish (druga UIScale na tym samym przycisku by się gryźć)
	refs.hubPulse = hub:FindFirstChildOfClass("UIScale")
	hub.Activated:Connect(function()
		WheelController.Spin()
	end)
	hub.Parent = plate
	refs.hub = hub

	-- Wskazówka u góry (nie kręci się)
	local pointer = UIKit.label("Pointer", {
		Text = "▼",
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.new(0.5, 0, 0, -10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextSize = 46,
		TextWrapped = false,
		TextColor3 = Color3.fromRGB(255, 80, 90),
		ZIndex = 8,
	})
	local pointerStroke = pointer:FindFirstChildOfClass("UIStroke")
	if pointerStroke then
		pointerStroke.Color = Color3.new(1, 1, 1)
		pointerStroke.Thickness = 3
	end
	pointer.Parent = plate
	refs.pointer = pointer
	plate.Parent = panel

	refs.info = UIKit.label("Info", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 30),
		Position = UDim2.fromOffset(20, 548),
		TextSize = 22,
	})
	refs.info.Parent = panel
	refs.result = UIKit.label("Result", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.fromOffset(20, 588),
		TextSize = 40,
		TextWrapped = false,
		TextColor3 = UIKit.COLORS.title,
	})
	refs.resultPop = UIKit.create("UIScale", {})
	refs.resultPop.Parent = refs.result
	refs.result.Parent = panel

	panel.Parent = gui
	refs.gui = gui
	refs.panel = panel

	-- Żarówki migają (szybciej w trakcie kręcenia), przycisk pulsuje, gdy jest obrót
	RunService.Heartbeat:Connect(function()
		if not panel.Visible then
			return
		end
		local speed = if spinning then 14 else 3
		local phase = math.floor(os.clock() * speed) % 2
		for index, bulb in refs.bulbs do
			local lit = (index % 2 == phase)
			bulb.BackgroundColor3 = if lit then Color3.fromRGB(255, 240, 120) else Color3.fromRGB(150, 90, 200)
		end
		local ready = state and (tonumber(state.spins) or 0) > 0 and not spinning
		refs.hubPulse.Scale = if ready then 1 + math.sin(os.clock() * 6) * 0.05 else 1
		if not spinning then
			updateInfo()
		end
	end)
end

local function setRotation(rotation: number)
	refs.rotor.Rotation = rotation
	for _, slot in refs.slots do
		slot.frame.Rotation = -rotation
	end
end

local function celebrate(index: number, label: string, jackpot: boolean)
	local slot = refs.slots[index]
	if slot then
		slot.pop.Scale = 1.35
		TweenService:Create(slot.pop, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Scale = 1.12 }):Play()
		local stroke = slot.frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = UIKit.COLORS.title
			stroke.Thickness = 6
		end
	end
	refs.result.Text = label .. "!"
	refs.resultPop.Scale = 0.2
	TweenService:Create(refs.resultPop, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	SoundController.Play("Success", 1.05)
	if jackpot then
		SoundController.Play("RentPaid")
		UIKit.confetti(refs.gui, 160)
	else
		UIKit.confetti(refs.gui, 70)
	end
end

local function resetHighlights()
	for _, slot in refs.slots do
		slot.pop.Scale = 1
		local stroke = slot.frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = UIKit.COLORS.stroke
			stroke.Thickness = 3
		end
	end
	refs.result.Text = ""
end

function WheelController.Spin()
	if spinning or not state or (tonumber(state.spins) or 0) <= 0 then
		if state and (tonumber(state.spins) or 0) <= 0 and not spinning then
			SoundController.Play("Warning")
		end
		return
	end
	spinning = true
	resetHighlights()
	updateInfo()
	local result = callbacks.spin and callbacks.spin()
	if type(result) ~= "table" or not result.ok then
		spinning = false
		if type(result) == "table" and type(result.message) == "string" and callbacks.toast then
			callbacks.toast(result.message, "warn")
		end
		local fresh = callbacks.get and callbacks.get()
		applyState(fresh)
		return
	end
	local index = tonumber(result.index) or 1
	local count = #refs.slots
	local slotAngle = (index - 1) * 360 / count
	local start = refs.rotor.Rotation
	local jitter = (math.random() - 0.5) * (360 / count) * 0.6
	local target = start + TURNS * 360 + ((-slotAngle - start) % 360) + jitter
	local duration = math.max(2, (tonumber(state.spinTime) or 4.6) - 0.15)
	local driver = Instance.new("NumberValue")
	driver.Value = start
	local lastTick = math.floor((start + 180 / count) / (360 / count))
	driver.Changed:Connect(function(value)
		setRotation(value)
		local tick = math.floor((value + 180 / count) / (360 / count))
		if tick ~= lastTick then
			lastTick = tick
			SoundController.Play("UIClick", 1.4)
			refs.pointer.Rotation = -18
			TweenService:Create(refs.pointer, TweenInfo.new(0.12), { Rotation = 0 }):Play()
		end
	end)
	local tween = TweenService:Create(driver, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Value = target })
	tween.Completed:Once(function()
		driver:Destroy()
		setRotation(target % 360)
		spinning = false
		applyState(result.state)
		celebrate(index, tostring(result.label or ""), index == count)
	end)
	tween:Play()
end

function WheelController.Open()
	if not refs.panel then
		build()
	end
	if not spinning then
		resetHighlights()
	end
	UIKit.popIn(refs.panel)
	local fresh = callbacks.get and callbacks.get()
	applyState(fresh)
end

function WheelController.Toggle()
	if refs.panel and refs.panel.Visible then
		if not spinning then
			refs.panel.Visible = false
		end
		return
	end
	WheelController.Open()
end

-- Liczba obrotów ze stanu gracza (plakietka na przycisku robi HUD)
function WheelController.ApplyState(snapshot: any)
	if type(snapshot) == "table" and state and not spinning and tonumber(snapshot.wheelSpins) then
		if tonumber(snapshot.wheelSpins) ~= tonumber(state.spins) then
			state.spins = tonumber(snapshot.wheelSpins)
			state.free = state.free and state.spins > 0
			updateInfo()
		end
	end
end

-- newCallbacks: get() -> stan koła, spin() -> wynik, toast(tekst, rodzaj)
function WheelController.Init(newCallbacks)
	callbacks = newCallbacks or {}
end

return WheelController

-- Pasek jazdy hulajnogą: czas, zapłacone monety, przyciski "Wheelie" (przytrzymaj) i "Koniec".
-- Shift na klawiaturze też robi wheelie. Opłaty liczy serwer (RentalService).
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local RentalController = {}

local COLORS = UIKit.COLORS
local WHEELIE_KEYS = { [Enum.KeyCode.LeftShift] = true, [Enum.KeyCode.RightShift] = true, [Enum.KeyCode.ButtonL3] = true }

local actions = nil
local refs = {}
local ride = nil -- { started, paid, perTick, tickSeconds, wheelie }

local function setWheelie(on: boolean)
	if not ride or ride.wheelie == on then
		return
	end
	ride.wheelie = on
	actions.send("wheelie", on)
	refs.wheelie.BackgroundColor3 = if on then COLORS.good else COLORS.option
	if on then
		SoundController.Play("UIClick", 1.4)
	end
end

local function refresh()
	if not ride then
		return
	end
	local seconds = math.floor(os.clock() - ride.started)
	refs.info.Text = string.format("🛴 %d:%02d  ·  %d 💰", seconds // 60, seconds % 60, ride.paid)
end

function RentalController.OnServer(action: any, payload: any)
	if action == "start" and type(payload) == "table" then
		ride = {
			started = os.clock(),
			paid = tonumber(payload.paid) or 0,
			perTick = tonumber(payload.perTick) or 1,
			tickSeconds = tonumber(payload.tickSeconds) or 10,
			wheelie = false,
		}
		refs.cost.Text = string.format("%d 💰 co %d s", ride.perTick, ride.tickSeconds)
		refs.wheelie.BackgroundColor3 = COLORS.option
		refresh()
		UIKit.popIn(refs.panel)
	elseif action == "tick" and ride and type(payload) == "table" then
		ride.paid = tonumber(payload.paid) or ride.paid
		refresh()
	elseif action == "stop" then
		ride = nil
		refs.panel.Visible = false
	end
end

function RentalController.Init(callbacks)
	actions = callbacks
	local gui = UIKit.screenGui("RentalGui", 6, "hud")
	-- Nad dolnym menu, żeby nie zasłaniać licznika czynszu u góry
	local panel = UIKit.panel("Ride", UDim2.fromOffset(420, 120), UDim2.new(0.5, 0, 1, -96), Vector2.new(0.5, 1))
	refs.info = UIKit.label("Info", { Text = "", Size = UDim2.new(0, 220, 0, 40), Position = UDim2.fromOffset(16, 10), TextSize = 28, TextColor3 = COLORS.title, TextXAlignment = Enum.TextXAlignment.Left })
	refs.info:SetAttribute("NoTranslate", true)
	refs.info.Parent = panel
	refs.cost = UIKit.label("Cost", { Text = "", Size = UDim2.new(1, -32, 0, 22), Position = UDim2.fromOffset(16, 50), TextSize = 16, TextColor3 = COLORS.accent, TextXAlignment = Enum.TextXAlignment.Left })
	refs.cost.Parent = panel
	refs.wheelie = UIKit.button("Wheelie", "🤸 Wheelie (Shift)", COLORS.option, {
		Size = UDim2.fromOffset(210, 40),
		Position = UDim2.new(0, 16, 1, -10),
		AnchorPoint = Vector2.new(0, 1),
		TextSize = 20,
	})
	-- Wheelie trwa, dopóki przycisk jest wciśnięty (mysz i dotyk)
	refs.wheelie.MouseButton1Down:Connect(function()
		setWheelie(true)
	end)
	refs.wheelie.MouseButton1Up:Connect(function()
		setWheelie(false)
	end)
	refs.wheelie.MouseLeave:Connect(function()
		setWheelie(false)
	end)
	refs.wheelie.Parent = panel
	local stop = UIKit.button("Stop", "⏹ Koniec", COLORS.cancel, {
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(1, -16, 1, -10),
		AnchorPoint = Vector2.new(1, 1),
		TextSize = 20,
	})
	stop.Activated:Connect(function()
		if ride then
			actions.send("stop")
		end
	end)
	stop.Parent = panel
	refs.panel = panel
	panel.Parent = gui

	UserInputService.InputBegan:Connect(function(input, processed)
		if ride and not processed and WHEELIE_KEYS[input.KeyCode] then
			setWheelie(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if WHEELIE_KEYS[input.KeyCode] then
			setWheelie(false)
		end
	end)
	local last = 0
	RunService.Heartbeat:Connect(function()
		if ride and os.clock() - last >= 0.5 then
			last = os.clock()
			refresh()
		end
	end)
end

return RentalController

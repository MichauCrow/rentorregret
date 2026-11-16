-- Minigra naprawy awarii w mieszkaniu: wskaźnik jeździ po pasku, trzeba go zatrzymać na zielonym polu.
-- 3 trafienia = naprawione. Pudło nic nie kosztuje (gra dla dzieci), tylko pasek się trzęsie.
-- Każde trafienie idzie do serwera (FailureService liczy trafienia i sam naprawia awarię).
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local RepairController = {}

local COLORS = UIKit.COLORS
local ZONE_COLOR = Color3.fromRGB(90, 230, 110)
local MISS_COLOR = Color3.fromRGB(255, 90, 100)
local MISS_COOLDOWN = 0.45
-- Motyw zależny od awarii: emoji narzędzia, polecenie i napis na przycisku
local THEMES = {
	faucet = { tool = "🔧", task = "Dokręć zawór kranu!", button = "DOKRĘĆ!" },
	toilet = { tool = "🪠", task = "Przepchnij toaletę!", button = "PRZEPCHNIJ!" },
	light = { tool = "💡", task = "Wkręć nową żarówkę!", button = "WKRĘĆ!" },
	fridge = { tool = "🔩", task = "Napraw silniczek lodówki!", button = "NAPRAW!" },
}
local DEFAULT_THEME = { tool = "🔧", task = "Napraw usterkę!", button = "NAPRAW!" }

local refs = {}
local actions = {}
local game_ = nil -- { failureId, steps, hits, zoneCenter, zoneWidth, speed, started, blockedUntil, done }
local rng = Random.new()

local function setZone()
	local step = game_.hits + 1
	game_.zoneWidth = math.max(0.12, 0.26 - (step - 1) * 0.05)
	game_.speed = 1.7 + (step - 1) * 0.45
	game_.zoneCenter = rng:NextNumber(0.2, 0.8)
	refs.zone.Size = UDim2.fromScale(game_.zoneWidth, 1)
	refs.zone.Position = UDim2.fromScale(game_.zoneCenter, 0.5)
end

local function markerPosition(): number
	local t = os.clock() - game_.started
	return (math.sin(t * game_.speed - math.pi / 2) + 1) / 2
end

local function updateDots()
	for i, dot in refs.dots do
		dot.BackgroundColor3 = if i <= game_.hits then ZONE_COLOR else COLORS.locked
		dot.Visible = i <= game_.steps
	end
end

local function close()
	game_ = nil
	refs.panel.Visible = false
	ProximityPromptService.Enabled = true
end

local function cancel()
	if game_ and not game_.done then
		actions.send(game_.failureId, "cancel")
	end
	close()
end

local function shake()
	local base = refs.barHolder.Position
	for _, dx in { 10, -10, 6, -6, 0 } do
		refs.barHolder.Position = base + UDim2.fromOffset(dx, 0)
		task.wait(0.04)
	end
	refs.barHolder.Position = base
end

local function press()
	if not game_ or game_.done then
		return
	end
	local now = os.clock()
	if now < game_.blockedUntil then
		return
	end
	local position = markerPosition()
	if math.abs(position - game_.zoneCenter) <= game_.zoneWidth / 2 then
		-- Trafienie: narzędzie się kręci, kropka się zapala, dźwięk coraz wyżej
		game_.hits += 1
		game_.blockedUntil = now + 0.55
		actions.send(game_.failureId, "hit")
		SoundController.Play("UIClick", 1 + game_.hits * 0.25)
		refs.tool.Rotation = 0
		TweenService:Create(refs.tool, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Rotation = 360 }):Play()
		refs.toolPop.Scale = 1.4
		TweenService:Create(refs.toolPop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		refs.feedback.Text = "Super! ✨"
		refs.feedback.TextColor3 = ZONE_COLOR
		updateDots()
		if game_.hits >= game_.steps then
			game_.done = true
			refs.feedback.Text = "Naprawione! 🎉"
			SoundController.Play("Success")
			UIKit.confetti(refs.gui, 70)
			task.delay(1.4, function()
				if game_ and game_.done then
					close()
				end
			end)
		else
			setZone()
		end
	else
		game_.blockedUntil = now + MISS_COOLDOWN
		refs.feedback.Text = "Prawie! Spróbuj jeszcze raz"
		refs.feedback.TextColor3 = MISS_COLOR
		refs.bar.BackgroundColor3 = MISS_COLOR
		task.delay(0.25, function()
			refs.bar.BackgroundColor3 = COLORS.card
		end)
		task.spawn(shake)
	end
end

function RepairController.Open(data: any)
	if type(data) ~= "table" or type(data.failureId) ~= "string" then
		return
	end
	local theme = THEMES[data.failureId] or DEFAULT_THEME
	game_ = {
		failureId = data.failureId,
		steps = math.clamp(tonumber(data.steps) or 3, 1, 5),
		hits = 0,
		started = os.clock(),
		blockedUntil = os.clock() + 0.3,
		done = false,
	}
	refs.title.Text = string.format("%s Naprawa: %s", tostring(data.icon or "🔧"), tostring(data.name or ""))
	refs.task.Text = theme.task
	refs.tool.Text = theme.tool
	refs.button.Text = theme.button
	refs.feedback.Text = "Kliknij, gdy wskaźnik jest na zielonym!"
	refs.feedback.TextColor3 = COLORS.text
	setZone()
	updateDots()
	-- W trakcie minigry podpowiedzi "E" są ukryte, żeby E działało jak przycisk naprawy
	ProximityPromptService.Enabled = false
	UIKit.popIn(refs.panel)
end

function RepairController.OnServer(action: any, data: any)
	if action == "open" then
		RepairController.Open(data)
	elseif action == "close" and game_ then
		if type(data) == "table" and data.success then
			if not game_.done then
				game_.done = true
				refs.feedback.Text = "Naprawione! 🎉"
				task.delay(1, close)
			end
		else
			close()
		end
	end
end

-- newActions: send(failureId, "hit" | "cancel")
function RepairController.Init(newActions)
	actions = newActions
	local gui = UIKit.screenGui("RepairUI", 7)
	refs.gui = gui
	local panel = UIKit.panel("Repair", UDim2.fromOffset(520, 330), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	refs.panel = panel
	refs.title = UIKit.label("Title", {
		Text = "",
		Size = UDim2.new(1, -80, 0, 34),
		Position = UDim2.fromOffset(20, 12),
		TextSize = 26,
		TextColor3 = COLORS.title,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.title.Parent = panel
	UIKit.closeButton(panel, cancel)

	refs.task = UIKit.label("Task", { Text = "", Size = UDim2.new(1, -150, 0, 30), Position = UDim2.fromOffset(130, 58), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left })
	refs.task.Parent = panel
	refs.tool = UIKit.label("Tool", { Text = "🔧", Size = UDim2.fromOffset(90, 90), Position = UDim2.fromOffset(24, 50), TextSize = 64 })
	refs.toolPop = UIKit.create("UIScale", {})
	refs.toolPop.Parent = refs.tool
	refs.tool.Parent = panel

	-- Kropki postępu (ile trafień zostało)
	local dots = UIKit.create("Frame", {
		Name = "Dots",
		Size = UDim2.fromOffset(200, 26),
		Position = UDim2.fromOffset(130, 96),
		BackgroundTransparency = 1,
	}, {
		UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.dots = {}
	for i = 1, 5 do
		local dot = UIKit.create("Frame", {
			Name = "Dot" .. i,
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = COLORS.locked,
			LayoutOrder = i,
		}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }), UIKit.border(COLORS.stroke, 2) })
		dot.Parent = dots
		refs.dots[i] = dot
	end
	dots.Parent = panel

	-- Pasek z zielonym polem i jeżdżącym wskaźnikiem
	refs.barHolder = UIKit.create("Frame", {
		Name = "BarHolder",
		Size = UDim2.new(1, -60, 0, 46),
		Position = UDim2.fromOffset(30, 144),
		BackgroundTransparency = 1,
	})
	refs.bar = UIKit.create("Frame", {
		Name = "Bar",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLORS.card,
		ClipsDescendants = true,
	}, { UIKit.corner(14), UIKit.border(COLORS.stroke, 3) })
	refs.zone = UIKit.create("Frame", {
		Name = "Zone",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.25, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = ZONE_COLOR,
	}, { UIKit.corner(10) })
	UIKit.gloss(refs.zone)
	refs.zone.Parent = refs.bar
	refs.marker = UIKit.create("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 10, 1, 10),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	}, { UIKit.corner(5), UIKit.border(Color3.fromRGB(40, 20, 70), 2) })
	refs.marker.Parent = refs.barHolder
	refs.bar.Parent = refs.barHolder
	refs.barHolder.Parent = panel

	refs.feedback = UIKit.label("Feedback", { Text = "", Size = UDim2.new(1, -40, 0, 28), Position = UDim2.fromOffset(20, 198), TextSize = 20 })
	refs.feedback.Parent = panel

	refs.button = UIKit.button("Press", "DOKRĘĆ!", COLORS.button, {
		Size = UDim2.fromOffset(260, 64),
		Position = UDim2.new(0.5, 0, 1, -18),
		AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 30,
		Modal = true, -- odblokowuje myszkę, gdy kamera jest blisko postaci
	})
	refs.button.Activated:Connect(press)
	refs.button.Parent = panel
	panel.Parent = gui

	-- Klawisze: E, spacja albo przycisk A na padzie
	UserInputService.InputBegan:Connect(function(input, processed)
		if not game_ or processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			press()
		end
	end)

	RunService.RenderStepped:Connect(function()
		if game_ and refs.panel.Visible and not game_.done then
			refs.marker.Position = UDim2.fromScale(markerPosition(), 0.5)
		end
	end)
end

return RepairController

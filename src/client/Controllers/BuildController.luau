-- Minigra budowy piętra: 3 etapy (mury, okna, wykończenie), w każdym trafienia w zielone pole paska.
-- Trafienia liczy serwer (HomeService); po każdym etapie nad mieszkaniem pojawiają się kolejne części pokoju.
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local BuildController = {}

local COLORS = UIKit.COLORS
local ZONE_COLOR = Color3.fromRGB(90, 230, 110)
local MISS_COLOR = Color3.fromRGB(255, 90, 100)
local MISS_COOLDOWN = 0.45

local refs = {}
local actions = {}
local game_ = nil -- { steps, hits, stage, stageCount, zoneCenter, zoneWidth, speed, started, blockedUntil, waiting, done }
local rng = Random.new()

local function setZone()
	local step = game_.hits + 1 + (game_.stage - 1)
	game_.zoneWidth = math.max(0.13, 0.27 - (step - 1) * 0.02)
	game_.speed = 1.6 + (step - 1) * 0.15
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
	for i, chip in refs.stages do
		chip.BackgroundColor3 = if i < game_.stage then ZONE_COLOR elseif i == game_.stage then COLORS.warn else COLORS.locked
		chip.Visible = i <= game_.stageCount
	end
end

local function close()
	game_ = nil
	refs.panel.Visible = false
	ProximityPromptService.Enabled = true
end

local function cancel()
	if game_ and not game_.done then
		actions.send("cancel")
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

local function applyStage(data)
	game_.stage = math.clamp(tonumber(data.stage) or 1, 1, 5)
	game_.stageCount = math.clamp(tonumber(data.stageCount) or 3, 1, 5)
	game_.steps = math.clamp(tonumber(data.steps) or 3, 1, 5)
	game_.hits = 0
	game_.waiting = false
	refs.title.Text = string.format("%s Budowa: %s", tostring(data.emoji or "🏗️"), tostring(data.roomName or ""))
	refs.task.Text = string.format("Etap %d/%d: %s", game_.stage, game_.stageCount, tostring(data.title or ""))
	refs.hint.Text = tostring(data.task or "")
	refs.tool.Text = tostring(data.tool or "🔨")
	refs.button.Text = tostring(data.button or "BUDUJ!")
	setZone()
	updateDots()
end

local function press()
	if not game_ or game_.done or game_.waiting then
		return
	end
	local now = os.clock()
	if now < game_.blockedUntil then
		return
	end
	if math.abs(markerPosition() - game_.zoneCenter) <= game_.zoneWidth / 2 then
		game_.hits += 1
		game_.blockedUntil = now + 0.55
		actions.send("hit")
		SoundController.Play("UIClick", 1 + (game_.hits + game_.stage) * 0.15)
		refs.tool.Rotation = -20
		TweenService:Create(refs.tool, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
		refs.toolPop.Scale = 1.4
		TweenService:Create(refs.toolPop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		refs.feedback.Text = "Super! ✨"
		refs.feedback.TextColor3 = ZONE_COLOR
		updateDots()
		if game_.hits >= game_.steps then
			-- Etap zrobiony: czekamy, aż serwer poda następny (albo zakończy budowę)
			game_.waiting = true
			refs.feedback.Text = if game_.stage >= game_.stageCount then "Ostatnie poprawki... 🎉" else "Etap gotowy! 🎉"
			UIKit.confetti(refs.gui, 30)
			SoundController.Play("Success")
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

function BuildController.OnServer(action: any, data: any)
	if action == "open" and type(data) == "table" then
		game_ = { started = os.clock(), blockedUntil = os.clock() + 0.3, done = false }
		applyStage(data)
		refs.feedback.Text = "Kliknij, gdy wskaźnik jest na zielonym!"
		refs.feedback.TextColor3 = COLORS.text
		ProximityPromptService.Enabled = false
		UIKit.popIn(refs.panel)
	elseif action == "stage" and game_ and type(data) == "table" then
		applyStage(data)
		refs.feedback.Text = "Następny etap!"
		refs.feedback.TextColor3 = COLORS.title
	elseif action == "close" and game_ then
		local message = if type(data) == "table" then data.message else nil
		if type(data) == "table" and data.success then
			game_.done = true
			refs.feedback.Text = tostring(message or "Gotowe! 🎉")
			refs.feedback.TextColor3 = ZONE_COLOR
			UIKit.confetti(refs.gui, 90)
			SoundController.Play("Success")
			task.delay(1.6, close)
		else
			if message then
				actions.toast(message, "warn")
			end
			close()
		end
	end
end

function BuildController.Init(newActions)
	actions = newActions
	local gui = UIKit.screenGui("BuildUI", 7)
	refs.gui = gui
	local panel = UIKit.panel("Build", UDim2.fromOffset(540, 370), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	refs.panel = panel
	refs.title = UIKit.label("Title", { Text = "", Size = UDim2.new(1, -80, 0, 34), Position = UDim2.fromOffset(20, 12), TextSize = 26, TextColor3 = COLORS.title, TextXAlignment = Enum.TextXAlignment.Left })
	refs.title.Parent = panel
	UIKit.closeButton(panel, cancel)

	-- Etapy budowy jako kolorowe kafelki
	local stages = UIKit.create("Frame", { Name = "Stages", Size = UDim2.fromOffset(300, 14), Position = UDim2.fromOffset(130, 50), BackgroundTransparency = 1 }, {
		UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.stages = {}
	for i = 1, 5 do
		local chip = UIKit.create("Frame", { Name = "Stage" .. i, Size = UDim2.fromOffset(60, 12), BackgroundColor3 = COLORS.locked, LayoutOrder = i }, { UIKit.corner(6) })
		chip.Parent = stages
		refs.stages[i] = chip
	end
	stages.Parent = panel

	refs.task = UIKit.label("Task", { Text = "", Size = UDim2.new(1, -150, 0, 28), Position = UDim2.fromOffset(130, 68), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left })
	refs.task.Parent = panel
	refs.hint = UIKit.label("Hint", { Text = "", Size = UDim2.new(1, -150, 0, 22), Position = UDim2.fromOffset(130, 96), TextSize = 17, TextColor3 = COLORS.accent, TextXAlignment = Enum.TextXAlignment.Left })
	refs.hint.Parent = panel
	refs.tool = UIKit.label("Tool", { Text = "🧱", Size = UDim2.fromOffset(90, 90), Position = UDim2.fromOffset(24, 48), TextSize = 64 })
	refs.toolPop = UIKit.create("UIScale", {})
	refs.toolPop.Parent = refs.tool
	refs.tool.Parent = panel

	local dots = UIKit.create("Frame", { Name = "Dots", Size = UDim2.fromOffset(200, 26), Position = UDim2.fromOffset(130, 124), BackgroundTransparency = 1 }, {
		UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.dots = {}
	for i = 1, 5 do
		local dot = UIKit.create("Frame", { Name = "Dot" .. i, Size = UDim2.fromOffset(26, 26), BackgroundColor3 = COLORS.locked, LayoutOrder = i }, {
			UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UIKit.border(COLORS.stroke, 2),
		})
		dot.Parent = dots
		refs.dots[i] = dot
	end
	dots.Parent = panel

	refs.barHolder = UIKit.create("Frame", { Name = "BarHolder", Size = UDim2.new(1, -60, 0, 46), Position = UDim2.fromOffset(30, 170), BackgroundTransparency = 1 })
	refs.bar = UIKit.create("Frame", { Name = "Bar", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLORS.card, ClipsDescendants = true }, { UIKit.corner(14), UIKit.border(COLORS.stroke, 3) })
	refs.zone = UIKit.create("Frame", { Name = "Zone", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.25, 1), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = ZONE_COLOR }, { UIKit.corner(10) })
	UIKit.gloss(refs.zone)
	refs.zone.Parent = refs.bar
	refs.marker = UIKit.create("Frame", { Name = "Marker", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 10, 1, 10), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3 }, {
		UIKit.corner(5),
		UIKit.border(Color3.fromRGB(40, 20, 70), 2),
	})
	refs.marker.Parent = refs.barHolder
	refs.bar.Parent = refs.barHolder
	refs.barHolder.Parent = panel

	refs.feedback = UIKit.label("Feedback", { Text = "", Size = UDim2.new(1, -40, 0, 28), Position = UDim2.fromOffset(20, 226), TextSize = 20 })
	refs.feedback.Parent = panel
	refs.button = UIKit.button("Press", "MURUJ!", COLORS.button, {
		Size = UDim2.fromOffset(260, 64),
		Position = UDim2.new(0.5, 0, 1, -18),
		AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 30,
		Modal = true,
	})
	refs.button.Activated:Connect(press)
	refs.button.Parent = panel
	panel.Parent = gui

	UserInputService.InputBegan:Connect(function(input, processed)
		if game_ and not processed and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA) then
			press()
		end
	end)
	RunService.RenderStepped:Connect(function()
		if game_ and refs.panel.Visible and not game_.done and not game_.waiting then
			refs.marker.Position = UDim2.fromScale(markerPosition(), 0.5)
		end
	end)
end

return BuildController

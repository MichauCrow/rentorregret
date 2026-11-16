-- HUD: w holu monety i przyciski (sklep, ustawienia); w rundzie zegar i pasek czynszu, kieszenie, klucz,
-- bateria latarki, kondycja, drużyna, przyciski dotykowe (latarka, sprint, duszek) i komunikaty.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Format"))
local ClientState = require(script.Parent.ClientState)
local MovementController = require(script.Parent.MovementController)
local SoundController = require(script.Parent.SoundController)
local UIKit = require(script.Parent.UIKit)

local HUDController = {}

local C = UIKit.COLORS
local gui = nil
local refs = {}
local toastHolder = nil
local openShop = nil
local openSettings = nil
local lastTick = nil

local STATUS_ICON = { inside = "🏠", ghost = "👻", escaped = "🏃", left = "🚪" }
local FLOOR_NAME = { [0] = "Parter", [1] = "1. piętro", [2] = "2. piętro" }

local function bar(name: string, size: UDim2, position: UDim2, color: Color3, parent: Instance)
	local back = UIKit.create("Frame", {
		Name = name,
		Size = size,
		Position = position,
		BackgroundColor3 = Color3.fromRGB(25, 20, 40),
		BackgroundTransparency = 0.2,
	}, { UIKit.corner(8), UIKit.border(C.stroke, 2) })
	local fill = UIKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = color,
	}, { UIKit.corner(8) })
	fill.Parent = back
	local text = UIKit.label("Text", { Size = UDim2.fromScale(1, 1), TextSize = 16, ZIndex = 2 })
	text.Parent = back
	back.Parent = parent
	return back, fill, text
end

local function setBar(fill: Frame, ratio: number)
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
end

-- Komunikat w górnej części ekranu (znika po kilku sekundach)
function HUDController.Toast(text: string, kind: string?)
	if not toastHolder then
		return
	end
	local color = ({ good = C.good, warn = C.warn, bad = C.bad })[kind or ""] or C.panel
	local toast = UIKit.create("Frame", {
		Size = UDim2.fromOffset(560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.1,
	}, { UIKit.corner(12), UIKit.border(C.stroke, 2), UIKit.create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
	local label = UIKit.label("Text", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text, TextSize = 19 })
	label.Parent = toast
	toast.Parent = toastHolder
	local children = toastHolder:GetChildren()
	local frames = {}
	for _, child in children do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	if #frames > 3 then
		frames[1]:Destroy()
	end
	task.delay(4, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.45)
			toast:Destroy()
		end
	end)
end

-- Duży napis na środku ekranu (ostrzeżenia potworów, znaleziony klucz)
function HUDController.Alert(text: string, kind: string?)
	local label = refs.alert
	label.Text = text
	label.TextColor3 = ({ good = C.good, bad = Color3.fromRGB(255, 120, 120) })[kind or ""] or C.title
	label.TextTransparency = 0
	label.Visible = true
	local scale = label:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.7
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local token = os.clock()
	refs.alertToken = token
	task.delay(2.6, function()
		if refs.alertToken == token then
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
	end)
end

function HUDController.SetShopOpener(callback)
	openShop = callback
end

function HUDController.SetSettingsOpener(callback)
	openSettings = callback
end

local function buildLobby()
	local lobby = UIKit.create("Frame", { Name = "Lobby", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local coins = UIKit.create("Frame", {
		Name = "Coins",
		Size = UDim2.fromOffset(210, 52),
		Position = UDim2.fromOffset(16, 16),
		BackgroundColor3 = C.panel,
	}, { UIKit.corner(14), UIKit.border(C.stroke, 3) })
	UIKit.gloss(coins)
	refs.coins = UIKit.label("Text", { Size = UDim2.fromScale(1, 1), Text = "💰 0", TextSize = 28, TextColor3 = C.title })
	refs.coins.Parent = coins
	coins.Parent = lobby

	local shop = UIKit.button("Shop", "🛒 SKLEP", C.button, { Size = UDim2.fromOffset(150, 56), Position = UDim2.fromOffset(16, 80), TextSize = 22 })
	shop.Activated:Connect(function()
		if openShop then
			openShop()
		end
	end)
	shop.Parent = lobby
	local settings = UIKit.button("Settings", "⚙️", C.option, { Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(172, 80), TextSize = 26 })
	settings.Activated:Connect(function()
		if openSettings then
			openSettings()
		end
	end)
	settings.Parent = lobby

	local hint = UIKit.label("Hint", {
		Size = UDim2.fromOffset(520, 40),
		Position = UDim2.new(0.5, 0, 1, -20),
		AnchorPoint = Vector2.new(0.5, 1),
		Text = "🚪 Stań na zielonej wycieraczce przed kamienicą, żeby zacząć!",
		TextSize = 20,
		TextColor3 = Color3.fromRGB(180, 255, 180),
	})
	hint.Parent = lobby
	lobby.Parent = gui
	refs.lobby = lobby
end

local function buildRound()
	local round = UIKit.create("Frame", { Name = "Round", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })

	-- Góra: zegar i czynsz
	local top = UIKit.create("Frame", {
		Name = "Top",
		Size = UDim2.fromOffset(420, 92),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(35, 25, 60),
		BackgroundTransparency = 0.15,
	}, { UIKit.corner(16), UIKit.border(C.stroke, 3) })
	refs.clock = UIKit.label("Clock", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 4), Text = "🕗 20:00", TextSize = 32, TextColor3 = C.title })
	UIKit.create("UIScale", {}).Parent = refs.clock
	refs.clock.Parent = top
	local _, rentFill, rentText = bar("Rent", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 48), C.good, top)
	refs.rentFill, refs.rentText = rentFill, rentText
	top.Parent = round

	-- Lewo: kieszenie, klucz, piętro
	local left = UIKit.create("Frame", {
		Name = "Left",
		Size = UDim2.fromOffset(230, 128),
		Position = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.fromRGB(35, 25, 60),
		BackgroundTransparency = 0.15,
	}, { UIKit.corner(14), UIKit.border(C.stroke, 2) })
	refs.pockets = UIKit.label("Pockets", { Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 6), Text = "🎒 0/50", TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left })
	refs.pockets.Parent = left
	refs.key = UIKit.label("Key", { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 44), Text = "🔑 Masz klucz!", TextSize = 20, TextColor3 = C.title, TextXAlignment = Enum.TextXAlignment.Left, Visible = false })
	refs.key.Parent = left
	refs.floor = UIKit.label("Floor", { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 90), Text = "Parter", TextSize = 18, TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Left })
	refs.floor.Parent = left
	left.Parent = round

	-- Lewy dół: bateria i kondycja
	local _, batteryFill, batteryText = bar("Battery", UDim2.fromOffset(230, 30), UDim2.new(0, 16, 1, -86), Color3.fromRGB(255, 220, 80), round)
	refs.batteryFill, refs.batteryText = batteryFill, batteryText
	local _, staminaFill, staminaText = bar("Stamina", UDim2.fromOffset(230, 30), UDim2.new(0, 16, 1, -48), Color3.fromRGB(120, 200, 255), round)
	refs.staminaFill, refs.staminaText = staminaFill, staminaText

	-- Prawo: drużyna
	local team = UIKit.create("Frame", {
		Name = "Team",
		Size = UDim2.fromOffset(220, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -16, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(35, 25, 60),
		BackgroundTransparency = 0.15,
	}, {
		UIKit.corner(14),
		UIKit.border(C.stroke, 2),
		UIKit.create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
		UIKit.create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	team.Parent = round
	refs.team = team

	-- Prawy dół: przyciski (duże, wygodne na telefonie)
	local buttons = UIKit.create("Frame", {
		Name = "Buttons",
		Size = UDim2.fromOffset(300, 96),
		Position = UDim2.new(1, -16, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
	}, { UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 10) }) })
	refs.flashButton = UIKit.button("Flashlight", "🔦", Color3.fromRGB(90, 80, 130), { Size = UDim2.fromOffset(92, 92), TextSize = 40, LayoutOrder = 1 })
	refs.flashButton.Activated:Connect(MovementController.ToggleFlashlight)
	refs.flashButton.Parent = buttons
	refs.sprintButton = UIKit.button("Sprint", "🏃", Color3.fromRGB(70, 130, 200), { Size = UDim2.fromOffset(92, 92), TextSize = 40, LayoutOrder = 2, Visible = UserInputService.TouchEnabled })
	refs.sprintButton.Activated:Connect(function()
		MovementController.SetSprint(not MovementController.IsSprinting())
	end)
	refs.sprintButton.Parent = buttons
	refs.pingButton = UIKit.button("Ping", "👻", Color3.fromRGB(120, 190, 230), { Size = UDim2.fromOffset(92, 92), TextSize = 40, LayoutOrder = 3, Visible = false })
	refs.pingButton.Activated:Connect(function()
		ClientState.Remote("GhostPing"):FireServer()
	end)
	refs.pingButton.Parent = buttons
	buttons.Parent = round
	local keysHint = UIKit.label("KeysHint", {
		Size = UDim2.fromOffset(300, 24),
		Position = UDim2.new(1, -16, 1, -116),
		AnchorPoint = Vector2.new(1, 1),
		Text = "F: latarka   Shift: bieg   E: szukaj",
		TextSize = 15,
		TextColor3 = Color3.fromRGB(200, 200, 230),
		Visible = not UserInputService.TouchEnabled,
	})
	keysHint.Parent = round

	-- Nakładki: szafa i duszek
	refs.hiddenOverlay = UIKit.create("Frame", { Name = "Hidden", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Visible = false, ZIndex = 0 })
	local hiddenText = UIKit.label("Text", { Size = UDim2.fromOffset(600, 60), Position = UDim2.fromScale(0.5, 0.72), AnchorPoint = Vector2.new(0.5, 0.5), Text = "🚪 Siedzisz w szafie. Potwory Cię nie znajdą.\nUżyj podpowiedzi „Wyjdź”, żeby wyjść.", TextSize = 22 })
	hiddenText.Parent = refs.hiddenOverlay
	refs.hiddenOverlay.Parent = round
	refs.ghostBanner = UIKit.label("Ghost", {
		Size = UDim2.fromOffset(640, 60),
		Position = UDim2.new(0.5, 0, 0, 112),
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "👻 Jesteś duszkiem! Potwory Cię nie widzą.\nNaciśnij 👻, żeby wskazać drużynie monety.",
		TextSize = 20,
		TextColor3 = Color3.fromRGB(190, 230, 255),
		Visible = false,
	})
	refs.ghostBanner.Parent = round

	round.Parent = gui
	refs.round = round
end

local function renderTeam(team)
	local container = refs.team
	for _, child in container:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for index, member in team do
		local icon = STATUS_ICON[member.status] or "❔"
		local label = UIKit.label("Member", {
			Size = UDim2.new(1, 0, 0, 24),
			Text = string.format("%s %s%s", icon, member.name, if member.carried > 0 then "  🎒" .. member.carried else ""),
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			LayoutOrder = index,
		})
		label.Parent = container
	end
end

local function renderRound(round)
	refs.lobby.Visible = round == nil
	refs.round.Visible = round ~= nil
	if not round then
		return
	end
	if round.phase == "hunt" then
		refs.clock.Text = "🏃 UCIEKAJ! " .. Format.Time(round.huntLeft)
		refs.clock.TextColor3 = C.bad
	else
		refs.clock.Text = "🕗 " .. round.clock
		refs.clock.TextColor3 = if round.timeLeft <= 60 then C.warn else C.title
		-- Ostatnia minuta: zegar tyka i pulsuje (widać to też bez dźwięku)
		if round.phase == "play" and not round.rentPaid and round.timeLeft <= 60 and round.timeLeft ~= lastTick then
			lastTick = round.timeLeft
			SoundController.Play("ClockTick", if round.timeLeft <= 15 then 1.25 else 1)
			local pulse = refs.clock:FindFirstChildOfClass("UIScale")
			pulse.Scale = if round.timeLeft <= 15 then 1.3 else 1.15
			TweenService:Create(pulse, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
		end
	end
	if round.rentPaid then
		setBar(refs.rentFill, 1)
		refs.rentText.Text = "✅ Czynsz zapłacony! Brama otwarta"
		refs.rentFill.BackgroundColor3 = C.good
	else
		setBar(refs.rentFill, round.deposited / round.rent)
		refs.rentText.Text = string.format("💰 Czynsz: %s / %s", Format.Number(round.deposited), Format.Number(round.rent))
		refs.rentFill.BackgroundColor3 = if round.phase == "hunt" then C.bad else C.warn
	end
	refs.pockets.Text = string.format("🎒 %d/%d", round.carried, round.capacity)
	refs.pockets.TextColor3 = if round.carried >= round.capacity then C.warn else C.text
	refs.key.Visible = round.hasKey
	refs.floor.Text = "📍 " .. (FLOOR_NAME[round.floor] or "")
	setBar(refs.batteryFill, round.battery / math.max(1, round.batteryMax))
	refs.batteryText.Text = "🔦 Bateria"
	refs.batteryFill.BackgroundColor3 = if round.battery / math.max(1, round.batteryMax) < 0.25 then C.bad else Color3.fromRGB(255, 220, 80)

	local ghost = round.status == "ghost"
	refs.ghostBanner.Visible = ghost
	refs.pingButton.Visible = ghost
	refs.pingButton.BackgroundColor3 = if round.pingReady then Color3.fromRGB(120, 190, 230) else C.locked
	refs.flashButton.Visible = not ghost
	refs.hiddenOverlay.Visible = round.hidden and not ghost
	renderTeam(round.team)
end

function HUDController.Init()
	gui = UIKit.screenGui("HUD", 5, "hud")
	toastHolder = UIKit.create("Frame", {
		Name = "Toasts",
		Size = UDim2.fromOffset(560, 300),
		Position = UDim2.new(0.5, 0, 0, 180),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
	}, { UIKit.create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	toastHolder.Parent = gui
	refs.alert = UIKit.label("Alert", {
		Size = UDim2.fromOffset(900, 80),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextSize = 34,
		Visible = false,
		ZIndex = 10,
	})
	UIKit.create("UIScale", {}).Parent = refs.alert
	refs.alert.Parent = gui
	buildLobby()
	buildRound()
end

function HUDController.Start()
	ClientState.OnProfile(function(profile)
		refs.coins.Text = "💰 " .. Format.Number(profile.coins)
	end)
	ClientState.OnRound(renderRound)
	ClientState.OnNotify(function(text, kind)
		if type(text) == "string" then
			HUDController.Toast(text, kind)
		end
	end)
	MovementController.FlashlightChanged.Event:Connect(function(on)
		refs.flashButton.BackgroundColor3 = if on then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(90, 80, 130)
	end)
	MovementController.SprintChanged.Event:Connect(function(on)
		refs.sprintButton.BackgroundColor3 = if on then Color3.fromRGB(120, 220, 255) else Color3.fromRGB(70, 130, 200)
	end)
	-- Kondycja zmienia się co klatkę (liczona u gracza)
	RunService.RenderStepped:Connect(function()
		if refs.round.Visible then
			local value, max = MovementController.Stamina()
			setBar(refs.staminaFill, value / math.max(0.01, max))
			refs.staminaText.Text = "💨 Kondycja"
		end
	end)
end

return HUDController

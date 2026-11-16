-- HUD. Zasada: w horrorze ekran ma być czysty. Na górze na środku zawsze tylko zegar i czynsz,
-- pod nimi jedna linijka stanu (kieszenie, klucz, piętro) i cel. Paski baterii i kondycji pojawiają się
-- tylko wtedy, gdy mają znaczenie. Przyciski są na prawej krawędzi (z dala od przycisku skoku na telefonie),
-- a lewy górny róg zostaje wolny dla czatu Roblox.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local NightConfig = require(Shared:WaitForChild("Config"):WaitForChild("NightConfig"))
local Format = require(Shared:WaitForChild("Modules"):WaitForChild("Format"))
local Noise = require(Shared:WaitForChild("Modules"):WaitForChild("Noise"))
local ClientState = require(script.Parent.ClientState)
local MovementController = require(script.Parent.MovementController)
local SoundController = require(script.Parent.SoundController)
local UIKit = require(script.Parent.UIKit)

local HUDController = {}

local C = UIKit.COLORS
local DARK = Color3.fromRGB(30, 22, 52)
local MAX_TOASTS = 2
local STATUS_ICON = { inside = "🏠", ghost = "👻", escaped = "🏃", left = "🚪" }
local FLOOR_NAME = { [0] = "Parter", [1] = "1. piętro", [2] = "2. piętro" }

local gui = nil
local refs = {}
local toastHolder = nil
local openShop = nil
local openSettings = nil
local lastTick = nil
local toastOrder = 0

local function pill(name: string, size: UDim2, position: UDim2, anchor: Vector2?): Frame
	return UIKit.create("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = anchor or Vector2.new(0.5, 0),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.2,
	}, { UIKit.corner(14), UIKit.border(C.stroke, 2) })
end

local function bar(name: string, size: UDim2, position: UDim2, color: Color3, parent: Instance)
	local back = UIKit.create("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(25, 20, 40),
		BackgroundTransparency = 0.2,
	}, { UIKit.corner(8), UIKit.border(C.stroke, 2) })
	local fill = UIKit.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = color }, { UIKit.corner(8) })
	fill.Parent = back
	local text = UIKit.label("Text", { Size = UDim2.fromScale(1, 1), TextSize = 15, ZIndex = 2 })
	text.Parent = back
	back.Parent = parent
	return back, fill, text
end

local function setBar(fill: Frame, ratio: number)
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
end

-- Komunikat pod celem (najwyżej dwa naraz, znika po kilku sekundach)
function HUDController.Toast(text: string, kind: string?)
	if not toastHolder then
		return
	end
	local color = ({ good = C.good, warn = C.warn, bad = C.bad })[kind or ""] or C.panel
	toastOrder += 1
	local toast = UIKit.create("Frame", {
		Size = UDim2.fromOffset(560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.1,
		LayoutOrder = toastOrder,
	}, { UIKit.corner(12), UIKit.border(C.stroke, 2), UIKit.create("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
	local label = UIKit.label("Text", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text, TextSize = 18 })
	label.Parent = toast
	toast.Parent = toastHolder
	local frames = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	table.sort(frames, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #frames - MAX_TOASTS do
		frames[i]:Destroy()
	end
	task.delay(3.5, function()
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

-- Napis dźwięku na dole ekranu (np. "👣 Kroki · z lewej · blisko"); pusty tekst chowa napis
function HUDController.Caption(text: string?)
	refs.caption.Visible = text ~= nil and text ~= ""
	if text and text ~= "" and refs.caption.Text ~= text then
		refs.caption.Text = text
	end
end

function HUDController.SetShopOpener(callback)
	openShop = callback
end

function HUDController.SetSettingsOpener(callback)
	openSettings = callback
end

local function quickChat(index: number)
	if ClientState.round then
		ClientState.Remote("QuickChat"):FireServer(index)
		refs.commsMenu.Visible = false
	end
end

local function buildLobby()
	local lobby = UIKit.create("Frame", { Name = "Lobby", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local row = UIKit.create("Frame", {
		Name = "TopRow",
		Size = UDim2.fromOffset(440, 54),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
	}, { UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local coins = pill("Coins", UDim2.fromOffset(200, 54), UDim2.new(), Vector2.zero)
	coins.LayoutOrder = 1
	refs.coins = UIKit.label("Text", { Size = UDim2.fromScale(1, 1), Text = "💰 0", TextSize = 28, TextColor3 = C.title })
	refs.coins.Parent = coins
	coins.Parent = row
	local shop = UIKit.button("Shop", "🛒 SKLEP", C.button, { Size = UDim2.fromOffset(150, 54), TextSize = 22, LayoutOrder = 2 })
	shop.Activated:Connect(function()
		if openShop then
			openShop()
		end
	end)
	shop.Parent = row
	local settings = UIKit.button("Settings", "⚙️", C.option, { Size = UDim2.fromOffset(54, 54), TextSize = 26, LayoutOrder = 3 })
	settings.Activated:Connect(function()
		if openSettings then
			openSettings()
		end
	end)
	settings.Parent = row
	row.Parent = lobby
	refs.night = UIKit.label("Night", {
		Size = UDim2.fromOffset(700, 30),
		Position = UDim2.new(0.5, 0, 0, 72),
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "",
		TextSize = 19,
		TextColor3 = Color3.fromRGB(255, 225, 150),
	})
	refs.night.Parent = lobby
	local hint = UIKit.label("Hint", {
		Size = UDim2.fromOffset(620, 40),
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

local function roundButton(name: string, text: string, color: Color3, order: number, parent: Instance): TextButton
	local button = UIKit.button(name, text, color, { Size = UDim2.fromOffset(84, 84), TextSize = 38, LayoutOrder = order })
	button.Parent = parent
	return button
end

local function buildRound()
	local round = UIKit.create("Frame", { Name = "Round", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })

	-- Góra: zegar i czynsz
	local top = pill("Top", UDim2.fromOffset(420, 92), UDim2.new(0.5, 0, 0, 8))
	refs.clock = UIKit.label("Clock", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 4), Text = "🕗 20:00", TextSize = 32, TextColor3 = C.title })
	UIKit.create("UIScale", {}).Parent = refs.clock
	refs.clock.Parent = top
	local rentBack = UIKit.create("Frame", { Name = "Rent", Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 48), BackgroundColor3 = Color3.fromRGB(25, 20, 40) }, { UIKit.corner(8), UIKit.border(C.stroke, 2) })
	refs.rentFill = UIKit.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.warn }, { UIKit.corner(8) })
	refs.rentFill.Parent = rentBack
	refs.rentText = UIKit.label("Text", { Size = UDim2.fromScale(1, 1), TextSize = 18, ZIndex = 2 })
	refs.rentText.Parent = rentBack
	rentBack.Parent = top
	top.Parent = round

	-- Jedna linijka stanu: kieszenie, klucz, piętro
	local status = pill("Status", UDim2.fromOffset(420, 30), UDim2.new(0.5, 0, 0, 104))
	refs.status = UIKit.label("Text", { Size = UDim2.fromScale(1, 1), Text = "", TextSize = 18 })
	refs.status.Parent = status
	status.Parent = round

	-- Drużyna (prawy górny róg; lista graczy Roblox jest wyłączona)
	local team = UIKit.create("Frame", {
		Name = "Team",
		Size = UDim2.fromOffset(200, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -12, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.25,
	}, {
		UIKit.corner(12),
		UIKit.border(C.stroke, 2),
		UIKit.create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
		UIKit.create("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	team.Parent = round
	refs.team = team

	-- Prawa krawędź: przyciski w kolumnie (pod listą drużyny, nad przyciskiem skoku na telefonie)
	local column = UIKit.create("Frame", {
		Name = "Buttons",
		Size = UDim2.fromOffset(84, 400),
		Position = UDim2.new(1, -12, 0, 150),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
	}, { UIKit.create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	refs.flashButton = roundButton("Flashlight", "🔦", Color3.fromRGB(90, 80, 130), 1, column)
	refs.flashButton.Activated:Connect(MovementController.ToggleFlashlight)
	refs.sprintButton = roundButton("Sprint", "🏃", Color3.fromRGB(70, 130, 200), 2, column)
	refs.sprintButton.Visible = UserInputService.TouchEnabled
	refs.sprintButton.Activated:Connect(function()
		MovementController.SetSprint(not MovementController.IsSprinting())
	end)
	refs.commsButton = roundButton("Comms", "📣", Color3.fromRGB(200, 120, 60), 3, column)
	refs.commsButton.Activated:Connect(function()
		refs.commsMenu.Visible = not refs.commsMenu.Visible
	end)
	refs.pingButton = roundButton("Ping", "👻", Color3.fromRGB(120, 190, 230), 4, column)
	refs.pingButton.Visible = false
	refs.pingButton.Activated:Connect(function()
		ClientState.Remote("GhostPing"):FireServer()
	end)
	column.Parent = round

	-- Menu szybkich komunikatów (obok przycisku 📣)
	local comms = UIKit.create("Frame", {
		Name = "CommsMenu",
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -108, 0, 150),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Visible = false,
	}, { UIKit.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for index, text in GameConfig.QUICK_CHAT do
		local button = UIKit.button("Chat" .. index, text, Color3.fromRGB(70, 60, 120), { Size = UDim2.fromOffset(250, 48), TextSize = 18, LayoutOrder = index })
		button.Activated:Connect(function()
			quickChat(index)
		end)
		button.Parent = comms
	end
	comms.Parent = round
	refs.commsMenu = comms

	-- Dół na środku: paski (tylko gdy mają znaczenie), napisy dźwięków, podpowiedź klawiszy
	local battery, batteryFill, batteryText = bar("Battery", UDim2.fromOffset(190, 24), UDim2.new(0.5, -100, 1, -30), Color3.fromRGB(255, 220, 80), round)
	refs.battery, refs.batteryFill, refs.batteryText = battery, batteryFill, batteryText
	local stamina, staminaFill, staminaText = bar("Stamina", UDim2.fromOffset(190, 24), UDim2.new(0.5, 100, 1, -30), Color3.fromRGB(120, 200, 255), round)
	refs.stamina, refs.staminaFill, refs.staminaText = stamina, staminaFill, staminaText
	refs.batteryText.Text = "🔦 Bateria"
	refs.staminaText.Text = "💨 Kondycja"
	refs.caption = UIKit.label("Caption", {
		Size = UDim2.fromOffset(560, 32),
		Position = UDim2.new(0.5, 0, 1, -64),
		AnchorPoint = Vector2.new(0.5, 1),
		Text = "",
		TextSize = 20,
		TextColor3 = Color3.fromRGB(230, 230, 255),
		BackgroundTransparency = 0.45,
		BackgroundColor3 = Color3.new(0, 0, 0),
		Visible = false,
	})
	UIKit.corner(8).Parent = refs.caption
	refs.caption.Parent = round
	local keysHint = UIKit.label("KeysHint", {
		Size = UDim2.fromOffset(640, 20),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		Text = "F latarka · Shift bieg · E szukaj · 1-4 komunikaty",
		TextSize = 14,
		TextColor3 = Color3.fromRGB(190, 190, 220),
		Visible = not UserInputService.TouchEnabled,
	})
	keysHint.Parent = round

	-- Nakładki: szafa i duszek
	refs.hiddenOverlay = UIKit.create("Frame", { Name = "Hidden", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Visible = false, ZIndex = 0 })
	local hiddenText = UIKit.label("Text", { Size = UDim2.fromOffset(600, 60), Position = UDim2.fromScale(0.5, 0.72), AnchorPoint = Vector2.new(0.5, 0.5), Text = "🚪 Siedzisz w szafie. Potwory Cię nie znajdą.\nUżyj podpowiedzi „Wyjdź”, żeby wyjść.", TextSize = 22 })
	hiddenText.Parent = refs.hiddenOverlay
	refs.hiddenOverlay.Parent = round
	refs.ghostBanner = UIKit.label("Ghost", {
		Size = UDim2.fromOffset(640, 54),
		Position = UDim2.new(0.5, 0, 0, 140),
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "👻 Jesteś duszkiem! Potwory Cię nie widzą.\nNaciśnij 👻, żeby wskazać drużynie monety.",
		TextSize = 19,
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
		local label = UIKit.label("Member", {
			Size = UDim2.new(1, 0, 0, 22),
			Text = string.format("%s %s%s", STATUS_ICON[member.status] or "❔", member.name, if member.carried > 0 then "  🎒" .. member.carried else ""),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			LayoutOrder = index,
		})
		label:SetAttribute("NoTranslate", true)
		label.Parent = container
	end
end

local function renderLobbyNight(profile)
	local night = NightConfig.ById(profile and profile.night)
	refs.night.Text = "🌙 Dzisiejsza noc: " .. night.icon .. " " .. night.name
end

local function renderRound(round)
	refs.lobby.Visible = round == nil
	refs.round.Visible = round ~= nil
	if not round then
		refs.commsMenu.Visible = false
		return
	end
	local finale = round.finale and not round.rentPaid
	if round.phase == "hunt" then
		refs.clock.Text = "🏃 UCIEKAJ! " .. Format.Time(round.huntLeft)
		refs.clock.TextColor3 = C.bad
	else
		refs.clock.Text = "🕗 " .. round.clock
		refs.clock.TextColor3 = if finale then C.bad elseif round.timeLeft <= 60 then C.warn else C.title
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
		refs.rentFill.BackgroundColor3 = if round.phase == "hunt" or finale then C.bad else C.warn
	end

	-- Linijka stanu: "🎒 23/50 🔔 · 🔑 · 📍 1. piętro"
	local pockets = string.format("🎒 %d/%d", round.carried, round.capacity)
	if Noise.Jingles(round.carried, round.capacity) then
		pockets ..= " 🔔"
	end
	local parts = { pockets }
	if round.hasKey then
		table.insert(parts, "🔑")
	end
	table.insert(parts, "📍 " .. (FLOOR_NAME[round.floor] or ""))
	refs.status.Text = table.concat(parts, " · ")
	refs.status.TextColor3 = if round.carried >= round.capacity then C.warn else C.text

	local batteryRatio = round.battery / math.max(1, round.batteryMax)
	setBar(refs.batteryFill, batteryRatio)
	refs.batteryFill.BackgroundColor3 = if batteryRatio < 0.25 then C.bad else Color3.fromRGB(255, 220, 80)
	refs.battery.Visible = round.status == "inside" and (round.flashlight or batteryRatio < 0.99)

	local ghost = round.status == "ghost"
	refs.ghostBanner.Visible = ghost
	refs.pingButton.Visible = ghost
	refs.pingButton.BackgroundColor3 = if round.pingReady then Color3.fromRGB(120, 190, 230) else C.locked
	refs.flashButton.Visible = not ghost
	refs.hiddenOverlay.Visible = round.hidden and not ghost
	renderTeam(round.team)
end

local function disableCoreGui()
	for _, kind in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health } do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(kind, false)
		end)
	end
end

function HUDController.Init()
	disableCoreGui()
	gui = UIKit.screenGui("HUD", 5, "hud")
	toastHolder = UIKit.create("Frame", {
		Name = "Toasts",
		Size = UDim2.fromOffset(560, 200),
		Position = UDim2.new(0.5, 0, 0, 200),
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
		renderLobbyNight(profile)
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
	-- Szybkie komunikaty z klawiatury: 1-4
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
	ContextActionService:BindAction("QuickChat", function(_, inputState, input)
		if inputState == Enum.UserInputState.Begin and ClientState.round then
			local index = table.find(keys, input.KeyCode)
			if index then
				quickChat(index)
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(keys))
	-- Kondycja zmienia się co klatkę (liczona u gracza); pasek widać tylko, gdy nie jest pełna
	RunService.RenderStepped:Connect(function()
		if refs.round.Visible then
			local value, max = MovementController.Stamina()
			setBar(refs.staminaFill, value / math.max(0.01, max))
			refs.stamina.Visible = value < max - 0.05
		end
	end)
end

return HUDController

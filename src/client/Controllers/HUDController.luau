-- Główny HUD: monety, klucze, miesiąc, zegar, pasek do czynszu, ocena mieszkania, komunikaty.
-- Cały interfejs jest tworzony z kodu i skaluje się do ekranu (komputer, telefon, tablet).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Format"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local HUDController = {}

local FONT = Enum.Font.FredokaOne
local COLORS = {
	panel = Color3.fromRGB(70, 45, 150),
	panelStroke = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(255, 255, 255),
	textStroke = Color3.fromRGB(25, 15, 45),
	accent = Color3.fromRGB(120, 220, 255),
	coin = Color3.fromRGB(255, 200, 40),
	coinRing = Color3.fromRGB(200, 130, 20),
	token = Color3.fromRGB(90, 170, 255),
	tokenRing = Color3.fromRGB(40, 90, 200),
	barBack = Color3.fromRGB(35, 22, 80),
	good = Color3.fromRGB(90, 220, 110),
	warn = Color3.fromRGB(255, 170, 40),
	bad = Color3.fromRGB(255, 80, 90),
	star = Color3.fromRGB(255, 215, 60),
	starOff = Color3.fromRGB(95, 85, 130),
}
local TOAST_COLORS = {
	info = Color3.fromRGB(80, 110, 230),
	good = Color3.fromRGB(40, 190, 90),
	warn = Color3.fromRGB(245, 150, 30),
	bad = Color3.fromRGB(225, 60, 80),
}
-- Kolory przycisków menu na dole ekranu
local MENU_COLORS = {
	Shop = Color3.fromRGB(255, 140, 40),
	Home = Color3.fromRGB(70, 160, 255),
	Social = Color3.fromRGB(240, 90, 170),
	Progress = Color3.fromRGB(60, 200, 110),
	Wheel = Color3.fromRGB(170, 90, 255),
}

local refs = {}
local handlers = {}
local lastCoins = nil
local hadRent = nil -- czy gracz miał już pieniądze na czynsz (konfetti przy pierwszym osiągnięciu)
local toastOrder = 0
-- Stan zegara: klient odlicza lokalnie między aktualizacjami z serwera
local timerState = {
	month = 1,
	elapsed = 0,
	duration = 0,
	running = false,
	phase = "month",
	overtimeRemaining = 0,
	receivedAt = 0,
}
local contractState = nil -- { name, reward, endsIn, receivedAt }
local eventState = nil -- { name, endsIn, receivedAt }
local wheelSpins = 0

local function create(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end

local function corner(radius: number)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function borderStroke(color: Color3, thickness: number)
	return create("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function panel(name: string, size: UDim2, position: UDim2, anchor: Vector2)
	local frame = create("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.1,
	}, { corner(16), borderStroke(COLORS.panelStroke, 3) })
	UIKit.gloss(frame)
	return frame
end

local function label(name: string, props)
	local base = {
		Name = name,
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = COLORS.text,
	}
	for key, value in props do
		base[key] = value
	end
	return create("TextLabel", base, {
		create("UIStroke", { Color = COLORS.textStroke, Thickness = 2 }),
	})
end

local function build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	refs.gui = gui
	refs.scale = create("UIScale", {})
	refs.scale.Parent = gui

	-- Monety (lewy górny róg)
	local coinsPanel = panel("CoinsPanel", UDim2.fromOffset(200, 56), UDim2.fromOffset(12, 12), Vector2.zero)
	refs.coinsBump = create("UIScale", {})
	refs.coinsBump.Parent = coinsPanel
	create("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = COLORS.coin,
	}, {
		create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		borderStroke(COLORS.coinRing, 3),
	}).Parent = coinsPanel
	refs.coins = label("Amount", {
		Text = "0",
		Size = UDim2.new(1, -62, 1, 0),
		Position = UDim2.fromOffset(56, 0),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.coins.Parent = coinsPanel
	coinsPanel.Parent = gui
	-- Licznik monet "nabija się" płynnie do nowej wartości
	refs.coinValue = create("NumberValue", { Value = 0 })
	refs.coinValue.Changed:Connect(function(value)
		refs.coins.Text = Format.Number(math.floor(value + 0.5))
	end)

	-- Klucze Lokatora (pod monetami i panelem poziomu z LevelController)
	local tokensPanel = panel("TokensPanel", UDim2.fromOffset(140, 44), UDim2.fromOffset(12, 128), Vector2.zero)
	-- Ta sama ikona kluczy co w sklepie (🔑)
	create("TextLabel", {
		Name = "Icon",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(0, 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = "🔑",
		TextSize = 26,
		Font = FONT,
	}).Parent = tokensPanel
	refs.tokens = label("Amount", {
		Text = "0",
		Size = UDim2.new(1, -56, 1, 0),
		Position = UDim2.fromOffset(50, 0),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.tokens.Parent = tokensPanel
	tokensPanel.Parent = gui

	-- Miesiąc, zegar i kwota do zapłaty (góra, środek)
	local monthPanel = panel("MonthPanel", UDim2.fromOffset(260, 96), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0))
	refs.month = label("Month", {
		Text = "MIESIĄC 1",
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 6),
		TextSize = 22,
		TextColor3 = COLORS.accent,
	})
	refs.month.Parent = monthPanel
	refs.timer = label("Timer", {
		Text = "6:00",
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 30),
		TextSize = 34,
	})
	refs.timer.Parent = monthPanel
	refs.due = label("Due", {
		Text = "Do zapłaty: 100",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 68),
		TextSize = 18,
	})
	refs.due.Parent = monthPanel
	monthPanel.Parent = gui

	-- Pasek postępu do czynszu
	local bar = create("Frame", {
		Name = "RentBar",
		Size = UDim2.fromOffset(260, 24),
		Position = UDim2.new(0.5, 0, 0, 116),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = COLORS.barBack,
		ClipsDescendants = true,
	}, { corner(12), borderStroke(COLORS.panelStroke, 2) })
	refs.barFill = create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.warn,
	}, { corner(12) })
	UIKit.gloss(refs.barFill)
	refs.barFill.Parent = bar
	refs.barText = label("Text", {
		Text = "0 / 100",
		Size = UDim2.fromScale(1, 1),
		TextSize = 16,
		ZIndex = 2,
	})
	refs.barText.Parent = bar
	bar.Parent = gui

	refs.goal = label("Goal", {
		Text = "",
		Size = UDim2.fromOffset(320, 26),
		Position = UDim2.new(0.5, 0, 0, 146),
		AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 20,
	})
	refs.goal.Parent = gui

	-- Ocena mieszkania (pod kluczami; prawy górny róg zajmuje lista graczy Roblox)
	local starsPanel = panel("StarsPanel", UDim2.fromOffset(190, 50), UDim2.fromOffset(12, 180), Vector2.zero)
	local starsRow = create("Frame", {
		Name = "Row",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	})
	refs.stars = {}
	for i = 1, 5 do
		local star = label("Star" .. i, {
			Text = "★",
			Size = UDim2.fromOffset(32, 40),
			TextSize = 34,
			LayoutOrder = i,
			TextColor3 = COLORS.starOff,
		})
		star.Parent = starsRow
		refs.stars[i] = star
	end
	starsRow.Parent = starsPanel
	starsPanel.Parent = gui

	-- Stan pod gwiazdkami (czystość, worek, premie, zlecenie, wydarzenie): każda linia na ciemnej "pigułce",
	-- żeby była czytelna na jasnym tle; puste linie się chowają, a reszta przesuwa się w górę
	local stack = create("Frame", {
		Name = "StatusStack",
		Size = UDim2.fromOffset(360, 200),
		Position = UDim2.fromOffset(12, 238),
		BackgroundTransparency = 1,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
	})
	local function statusLine(name: string, color: Color3, order: number): TextLabel
		local pill = create("Frame", {
			Name = name .. "Pill",
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(25, 18, 50),
			BackgroundTransparency = 0.25,
			LayoutOrder = order,
			Visible = false,
		}, { corner(10), create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
		local text = label(name, {
			Text = "",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
		})
		text:GetPropertyChangedSignal("Text"):Connect(function()
			pill.Visible = text.Text ~= ""
		end)
		text.Parent = pill
		pill.Parent = stack
		return text
	end
	refs.cleanliness = statusLine("Cleanliness", COLORS.text, 1)
	refs.bag = statusLine("Bag", COLORS.accent, 2)
	refs.buff = statusLine("Buff", COLORS.text, 3)
	refs.contract = statusLine("Contract", COLORS.star, 4)
	refs.event = statusLine("Event", COLORS.warn, 5)
	stack.Parent = gui

	-- Przyciski na dole ekranu (środek: na telefonie lewy dół to joystick, a prawy dół to skok)
	local bar = create("Frame", {
		Name = "MenuBar",
		Size = UDim2.fromOffset(820, 68),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	for order, entry in {
		{ name = "Shop", text = "🛒 SKLEP", handler = "onShop" },
		{ name = "Home", text = "🏠 DOM", handler = "onHome" },
		{ name = "Social", text = "👥 EKIPA", handler = "onSocial" },
		{ name = "Progress", text = "📋 ZADANIA", handler = "onProgress" },
		{ name = "Wheel", text = "🎡 KOŁO", handler = "onWheel" },
	} do
		-- Duże przyciski: na telefonie muszą być łatwe do trafienia palcem
		local menuButton = create("TextButton", {
			Name = entry.name,
			Size = UDim2.fromOffset(152, 66),
			BackgroundColor3 = MENU_COLORS[entry.name] or COLORS.panel,
			Font = FONT,
			Text = entry.text,
			TextSize = 24,
			TextColor3 = COLORS.text,
			LayoutOrder = order,
		}, { corner(14), borderStroke(COLORS.panelStroke, 3), create("UIStroke", { Color = COLORS.textStroke, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }) })
		UIKit.gloss(menuButton)
		UIKit.squish(menuButton)
		menuButton.Activated:Connect(function()
			local handler = handlers[entry.handler]
			if handler then
				handler()
			end
		end)
		menuButton.Parent = bar
		if entry.name == "Progress" then
			-- Czerwona kropka: nagroda dnia czeka na odbiór
			refs.progressBadge = create("Frame", {
				Name = "Badge",
				Size = UDim2.fromOffset(18, 18),
				Position = UDim2.new(1, -4, 0, 4),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = COLORS.bad,
				Visible = false,
			}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }), borderStroke(COLORS.panelStroke, 2) })
			refs.progressBadge.Parent = menuButton
		elseif entry.name == "Wheel" then
			-- Liczba obrotów kołem do wykorzystania; przycisk podskakuje, gdy jest darmowy obrót
			refs.wheelBadge = create("TextLabel", {
				Name = "Badge",
				Size = UDim2.fromOffset(26, 26),
				Position = UDim2.new(1, 4, 0, -6),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = COLORS.bad,
				Font = FONT,
				Text = "1",
				TextSize = 18,
				TextColor3 = COLORS.text,
				Visible = false,
				ZIndex = 3,
			}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }), borderStroke(COLORS.panelStroke, 2) })
			refs.wheelBadge.Parent = menuButton
			refs.wheelButton = menuButton
			-- Ta sama skala, którą UIKit.squish zgniata przycisk (dwie UIScale na jednym przycisku się gryzą)
			refs.wheelBounce = menuButton:FindFirstChildOfClass("UIScale")
		end
	end
	bar.Parent = gui

	-- Dług i przycisk spłaty (pod celem)
	local debtPanel = panel("DebtPanel", UDim2.fromOffset(330, 44), UDim2.new(0.5, 0, 0, 176), Vector2.new(0.5, 0))
	debtPanel.BackgroundColor3 = Color3.fromRGB(130, 35, 55)
	debtPanel.Visible = false
	refs.debtText = label("Text", {
		Text = "",
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.debtText.Parent = debtPanel
	local payButton = create("TextButton", {
		Name = "PayDebt",
		Size = UDim2.fromOffset(96, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.good,
		Font = FONT,
		Text = "SPŁAĆ",
		TextSize = 20,
		TextColor3 = COLORS.text,
	}, { corner(10), borderStroke(COLORS.panelStroke, 2) })
	UIKit.gloss(payButton)
	UIKit.squish(payButton)
	payButton.Activated:Connect(function()
		if handlers.onPayDebt then
			handlers.onPayDebt()
		end
	end)
	payButton.Parent = debtPanel
	debtPanel.Parent = gui
	refs.debtPanel = debtPanel

	-- Komunikaty
	refs.toasts = create("Frame", {
		Name = "Toasts",
		Size = UDim2.fromOffset(420, 220),
		Position = UDim2.new(0.5, 0, 0, 230),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
	}, {
		create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	refs.toasts.Parent = gui

	gui.Parent = playerGui
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if not camera or not refs.scale then
		return
	end
	refs.scale.Scale = UIKit.ScaleFor(camera.ViewportSize, "hud")
end

local function coinPopup(delta: number)
	local positive = delta > 0
	local popup = label("CoinPopup", {
		Text = (if positive then "+" else "") .. Format.Number(delta),
		Size = UDim2.fromOffset(160, 36),
		Position = UDim2.fromOffset(220, 24),
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if positive then COLORS.good else COLORS.bad,
	})
	popup.Parent = refs.gui
	local tween = TweenService:Create(
		popup,
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(220, -6), TextTransparency = 1 }
	)
	local popupStroke = popup:FindFirstChildOfClass("UIStroke")
	if popupStroke then
		TweenService:Create(popupStroke, TweenInfo.new(1), { Transparency = 1 }):Play()
	end
	tween.Completed:Once(function()
		popup:Destroy()
	end)
	tween:Play()

	refs.coinsBump.Scale = 1.15
	TweenService:Create(refs.coinsBump, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Złote monetki lecą ze środka ekranu do licznika monet
local function flyCoins(delta: number)
	local count = math.clamp(math.ceil(delta / 8), 3, 10)
	for i = 1, count do
		local coin = create("Frame", {
			Name = "FlyingCoin",
			Size = UDim2.fromOffset(30, 30),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.random(-90, 90), 0.55, math.random(-50, 50)),
			BackgroundColor3 = COLORS.coin,
			ZIndex = 20,
		}, {
			create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			borderStroke(COLORS.coinRing, 3),
		})
		local pop = create("UIScale", { Scale = 0 })
		pop.Parent = coin
		coin.Parent = refs.gui
		TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		local fly = TweenService:Create(
			coin,
			TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.15 + i * 0.06),
			{ Position = UDim2.fromOffset(41, 40) }
		)
		fly.Completed:Once(function()
			coin:Destroy()
			refs.coinsBump.Scale = 1.12
			TweenService:Create(refs.coinsBump, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end)
		fly:Play()
	end
end

local function updateTimer()
	if not refs.timer then
		return
	end
	if contractState then
		local left = contractState.endsIn - (os.clock() - contractState.receivedAt)
		refs.contract.Text = string.format("⭐ %s: %s (nagroda %s)", contractState.name, Format.Time(left), Format.Number(contractState.reward))
	else
		refs.contract.Text = ""
	end
	if eventState then
		local left = eventState.endsIn - (os.clock() - eventState.receivedAt)
		refs.event.Text = string.format("⚠ %s: %s", eventState.name, Format.Time(left))
	else
		refs.event.Text = ""
	end
	local state = timerState
	local sinceUpdate = os.clock() - state.receivedAt
	if state.phase == "overtime" then
		refs.month.Text = "DOGRYWKA!"
		refs.month.TextColor3 = COLORS.bad
		refs.timer.Text = Format.Time(state.overtimeRemaining - sinceUpdate)
		refs.timer.TextColor3 = COLORS.bad
	elseif state.phase == "visit" then
		refs.month.Text = "MIESIĄC " .. state.month
		refs.month.TextColor3 = COLORS.accent
		refs.timer.Text = "CZYNSZ!"
		refs.timer.TextColor3 = COLORS.warn
	else
		local remaining = state.duration - state.elapsed - (if state.running then sinceUpdate else 0)
		refs.month.Text = "MIESIĄC " .. state.month
		refs.month.TextColor3 = COLORS.accent
		refs.timer.Text = Format.Time(remaining)
		refs.timer.TextColor3 = if remaining <= 60 then COLORS.bad else COLORS.text
	end
end

function HUDController.Update(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	local coins = tonumber(snapshot.coins) or 0
	if lastCoins ~= nil and coins ~= lastCoins then
		coinPopup(coins - lastCoins)
		if coins > lastCoins then
			flyCoins(coins - lastCoins)
		end
		TweenService:Create(refs.coinValue, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = coins }):Play()
	else
		refs.coinValue.Value = coins
		refs.coins.Text = Format.Number(coins)
	end
	lastCoins = coins

	refs.tokens.Text = Format.Number(tonumber(snapshot.tokens) or 0)
	timerState.month = tonumber(snapshot.month) or 1
	timerState.elapsed = tonumber(snapshot.monthElapsed) or 0
	timerState.duration = tonumber(snapshot.monthDuration) or 0
	timerState.running = snapshot.timerRunning == true
	timerState.phase = if type(snapshot.phase) == "string" then snapshot.phase else "month"
	timerState.overtimeRemaining = tonumber(snapshot.overtimeRemaining) or 0
	timerState.receivedAt = os.clock()
	updateTimer()

	local due = tonumber(snapshot.due) or 0
	refs.due.Text = "Do zapłaty: " .. Format.Number(due)
	local progress = if due > 0 then math.clamp(coins / due, 0, 1) else 1
	TweenService:Create(refs.barFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(progress, 1) }):Play()
	refs.barFill.BackgroundColor3 = if progress >= 1 then COLORS.good else COLORS.warn
	refs.barText.Text = Format.Number(math.min(coins, due)) .. " / " .. Format.Number(due)

	local hasRent = due > 0 and coins >= due
	if hasRent and hadRent == false then
		UIKit.confetti(refs.gui, 70)
	end
	hadRent = hasRent
	if coins >= due then
		refs.goal.Text = "Masz na czynsz! 🎉"
		refs.goal.TextColor3 = COLORS.good
	elseif timerState.phase == "overtime" then
		refs.goal.Text = "Szybko! Brakuje " .. Format.Number(due - coins)
		refs.goal.TextColor3 = COLORS.bad
	else
		refs.goal.Text = "Zarób jeszcze " .. Format.Number(due - coins)
		refs.goal.TextColor3 = COLORS.text
	end

	local stars = tonumber(snapshot.apartmentStars) or 0
	for i, star in refs.stars do
		star.TextColor3 = if i <= stars then COLORS.star else COLORS.starOff
	end

	local debt = tonumber(snapshot.debt) or 0
	refs.debtPanel.Visible = debt > 0 and timerState.phase == "month"
	refs.debtText.Text = string.format("Dług: %s   Ostrzeżenia: %d/3", Format.Number(debt), tonumber(snapshot.warnings) or 0)

	local bag = snapshot.bag
	if type(bag) == "table" then
		refs.bag.Text = string.format("%s: %d/%d", tostring(bag.label), tonumber(bag.count) or 0, tonumber(bag.capacity) or 0)
	else
		refs.bag.Text = ""
	end

	if refs.progressBadge then
		refs.progressBadge.Visible = snapshot.progressBadge == true
	end
	if refs.wheelBadge then
		local spins = tonumber(snapshot.wheelSpins) or 0
		refs.wheelBadge.Visible = spins > 0
		refs.wheelBadge.Text = tostring(spins)
		wheelSpins = spins
	end

	local contract = snapshot.contract
	if type(contract) == "table" then
		contractState = {
			name = tostring(contract.name),
			reward = tonumber(contract.reward) or 0,
			endsIn = tonumber(contract.endsIn) or 0,
			receivedAt = os.clock(),
		}
	else
		contractState = nil
	end

	local event = snapshot.event
	if type(event) == "table" then
		eventState = {
			name = tostring(event.name),
			endsIn = tonumber(event.endsIn) or 0,
			receivedAt = os.clock(),
		}
	else
		eventState = nil
	end

	local bonus = tonumber(snapshot.payBonus)
	if bonus and bonus > 0 then
		refs.buff.Text = "Premia do wypłat: +" .. bonus .. "%"
		refs.buff.TextColor3 = COLORS.good
	elseif bonus and bonus < 0 then
		refs.buff.Text = "Kara do wypłat: " .. bonus .. "%"
		refs.buff.TextColor3 = COLORS.bad
	else
		refs.buff.Text = ""
	end

	local cleanliness = tonumber(snapshot.cleanliness)
	if cleanliness then
		refs.cleanliness.Text = "Czystość: " .. math.floor(cleanliness) .. "%"
		if cleanliness >= 80 then
			refs.cleanliness.TextColor3 = COLORS.good
		elseif cleanliness >= 50 then
			refs.cleanliness.TextColor3 = COLORS.warn
		else
			refs.cleanliness.TextColor3 = COLORS.bad
		end
	end
end

-- Konfetti na cały ekran (zapłacony czynsz, osiągnięcia)
function HUDController.Celebrate()
	if refs.gui then
		UIKit.confetti(refs.gui, 90)
	end
end

-- kind: "info", "good", "warn", "bad"
function HUDController.Toast(text: any, kind: any)
	if type(text) ~= "string" or not refs.toasts then
		return
	end
	toastOrder += 1
	local toastStroke = borderStroke(Color3.new(1, 1, 1), 2)
	local toast = create("Frame", {
		Name = "Toast",
		Size = UDim2.fromOffset(400, 40),
		BackgroundColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info,
		LayoutOrder = toastOrder,
	}, { corner(12), toastStroke })
	UIKit.gloss(toast)
	local textLabel = label("Text", {
		Text = text,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextSize = 20,
		TextWrapped = true,
	})
	textLabel.Parent = toast
	UIKit.popIn(toast)
	toast.Parent = refs.toasts

	task.delay(3, function()
		local info = TweenInfo.new(0.4)
		TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(toastStroke, info, { Transparency = 1 }):Play()
		TweenService:Create(textLabel, info, { TextTransparency = 1 }):Play()
		local textStroke = textLabel:FindFirstChildOfClass("UIStroke")
		if textStroke then
			TweenService:Create(textStroke, info, { Transparency = 1 }):Play()
		end
		task.wait(0.4)
		toast:Destroy()
	end)
end

-- newHandlers: onPayDebt ("SPŁAĆ"), onShop, onHome, onSocial, onProgress, onWheel (przyciski na dole ekranu)
function HUDController.Init(newHandlers)
	handlers = newHandlers or {}
	build()
	task.spawn(function()
		while true do
			task.wait(0.2)
			updateTimer()
		end
	end)
	-- Przycisk koła podskakuje co chwilę, dopóki czeka obrót
	task.spawn(function()
		while true do
			task.wait(2.5)
			if wheelSpins > 0 and refs.wheelBounce then
				refs.wheelBounce.Scale = 1.12
				TweenService:Create(refs.wheelBounce, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
			end
		end
	end)
	local function bindCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
		end
		updateScale()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
end

return HUDController

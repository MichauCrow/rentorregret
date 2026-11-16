-- Prezenty za czas gry i kody nagród: przycisk 🎁 w HUD (odliczanie do następnego prezentu albo "ODBIERZ!"),
-- okno z 8 pudełkami (potrząśnięcie, pokrywka odlatuje, nagroda wyskakuje) i pole do wpisania kodu.
-- Wszystko sprawdza serwer; klient tylko odlicza czas między aktualizacjami.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local GiftsController = {}

local GIFT_COLOR = Color3.fromRGB(240, 80, 130)
local CARD = Color3.fromRGB(48, 30, 110)
local RIBBON = Color3.fromRGB(255, 215, 60)
local BOX_COLORS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(120, 220, 100),
	Color3.fromRGB(255, 160, 50),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(80, 140, 255),
	Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(255, 200, 40),
}

local callbacks = {}
local refs = {}
local cards = {}
local state = nil
local stateAt = 0
local busy = false
local hudReady = 0
local hudNextAt = nil -- os.clock(), kiedy odblokuje się następny prezent

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function darker(color: Color3): Color3
	return color:Lerp(Color3.new(0, 0, 0), 0.25)
end

-- Przycisk w HUD ------------------------------------------------------------------

local function buildHudButton()
	local gui = UIKit.screenGui("GiftsHud", 1, "hud")
	local button = UIKit.button("Gifts", "🎁", GIFT_COLOR, {
		Size = UDim2.fromOffset(124, 50),
		Position = UDim2.fromOffset(210, 180),
		TextSize = 18,
		TextWrapped = false,
	})
	button.Activated:Connect(function()
		GiftsController.Toggle()
	end)
	refs.hudBounce = button:FindFirstChildOfClass("UIScale")
	refs.hudBadge = UIKit.create("TextLabel", {
		Name = "Badge",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, 6, 0, -8),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = UIKit.COLORS.bad,
		Font = UIKit.FONT,
		Text = "1",
		TextSize = 17,
		TextColor3 = UIKit.COLORS.text,
		Visible = false,
		ZIndex = 3,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }), UIKit.border(UIKit.COLORS.stroke, 2) })
	refs.hudBadge:SetAttribute("NoTranslate", true)
	refs.hudBadge.Parent = button
	button.Parent = gui
	refs.hudButton = button
end

local function updateHud()
	if not refs.hudButton then
		return
	end
	refs.hudBadge.Visible = hudReady > 0
	refs.hudBadge.Text = tostring(hudReady)
	if hudReady > 0 then
		refs.hudButton.Text = "🎁 ODBIERZ!"
	elseif hudNextAt then
		refs.hudButton.Text = "🎁 " .. clock(hudNextAt - os.clock())
	else
		refs.hudButton.Text = "🎁 Jutro"
	end
end

-- Okno --------------------------------------------------------------------------------

local function buildCard(index: number)
	local color = BOX_COLORS[(index - 1) % #BOX_COLORS + 1]
	local card = UIKit.create("TextButton", {
		Name = "Gift" .. index,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = CARD,
		LayoutOrder = index,
	}, { UIKit.corner(14) })
	local stroke = UIKit.border(UIKit.COLORS.stroke, 2)
	stroke.Parent = card
	local time = UIKit.label("Time", {
		Text = "",
		Size = UDim2.new(1, -12, 0, 18),
		Position = UDim2.fromOffset(8, 5),
		TextSize = 14,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UIKit.COLORS.accent,
	})
	time.Parent = card

	-- Pudełko z kokardą (obraca się całe przy potrząsaniu)
	local box = UIKit.create("Frame", {
		Name = "Box",
		Size = UDim2.fromOffset(90, 84),
		Position = UDim2.new(0.5, 0, 0, 14),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
	})
	local body = UIKit.create("Frame", {
		Name = "Body",
		Size = UDim2.fromOffset(70, 48),
		Position = UDim2.fromOffset(10, 36),
		BackgroundColor3 = color,
	}, { UIKit.corner(6), UIKit.border(Color3.new(1, 1, 1), 2) })
	UIKit.gloss(body)
	body.Parent = box
	UIKit.create("Frame", {
		Name = "RibbonV",
		Size = UDim2.fromOffset(12, 48),
		Position = UDim2.fromOffset(29, 0),
		BackgroundColor3 = RIBBON,
		BorderSizePixel = 0,
	}).Parent = body
	local lid = UIKit.create("Frame", {
		Name = "Lid",
		Size = UDim2.fromOffset(80, 18),
		Position = UDim2.fromOffset(5, 22),
		BackgroundColor3 = darker(color),
		ZIndex = 2,
	}, { UIKit.corner(5), UIKit.border(Color3.new(1, 1, 1), 2) })
	UIKit.create("Frame", {
		Name = "RibbonLid",
		Size = UDim2.fromOffset(12, 18),
		Position = UDim2.fromOffset(34, 0),
		BackgroundColor3 = RIBBON,
		BorderSizePixel = 0,
		ZIndex = 2,
	}).Parent = lid
	local bow = UIKit.label("Bow", {
		Text = "🎀",
		Size = UDim2.fromOffset(40, 28),
		Position = UDim2.new(0.5, 0, 0, -26),
		AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 26,
		TextWrapped = false,
		ZIndex = 3,
	})
	bow.Parent = lid
	lid.Parent = box
	local check = UIKit.label("Done", {
		Text = "✅",
		Size = UDim2.fromScale(1, 1),
		TextSize = 46,
		Visible = false,
		ZIndex = 4,
	})
	check.Parent = box
	box.Parent = card

	local reward = UIKit.label("Reward", {
		Text = "",
		Size = UDim2.new(1, -8, 0, 28),
		Position = UDim2.fromOffset(4, 102),
		TextSize = 22,
		TextWrapped = false,
	})
	reward:SetAttribute("NoTranslate", true)
	local rewardPop = UIKit.create("UIScale", {})
	rewardPop.Parent = reward
	reward.Parent = card
	local status = UIKit.label("Status", {
		Text = "",
		Size = UDim2.new(1, -8, 0, 24),
		Position = UDim2.fromOffset(4, 132),
		TextSize = 17,
		TextWrapped = false,
	})
	status.Parent = card
	local flash = UIKit.create("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, { UIKit.corner(14) })
	flash.Parent = card
	local pop = UIKit.create("UIScale", {})
	pop.Parent = card

	card.Activated:Connect(function()
		GiftsController.Claim(index)
	end)
	return {
		card = card,
		stroke = stroke,
		time = time,
		box = box,
		body = body,
		lid = lid,
		bow = bow,
		check = check,
		reward = reward,
		rewardPop = rewardPop,
		status = status,
		flash = flash,
		pop = pop,
		lidHome = lid.Position,
	}
end

local function giftState(index: number): string
	local gift = state and state.gifts and state.gifts[index]
	if type(gift) ~= "table" then
		return "locked"
	end
	if gift.state == "locked" and (tonumber(gift.unlockIn) or 0) - (os.clock() - stateAt) <= 0 then
		return "ready"
	end
	return gift.state
end

local function renderCard(index: number)
	local entry = cards[index]
	local gift = state and state.gifts and state.gifts[index]
	if not entry or type(gift) ~= "table" then
		return
	end
	local current = giftState(index)
	entry.time.Text = "⏱ " .. tostring(gift.minutes) .. " min"
	entry.reward.Text = tostring(gift.label or "")
	entry.lid.Position = entry.lidHome
	entry.lid.Rotation = 0
	entry.lid.Visible = current ~= "claimed"
	entry.body.Visible = current ~= "claimed"
	entry.check.Visible = current == "claimed"
	if current ~= "ready" then
		entry.box.Rotation = 0
	end
	if current == "claimed" then
		entry.status.Text = "Odebrano"
		entry.status.TextColor3 = UIKit.COLORS.good
		entry.card.BackgroundColor3 = Color3.fromRGB(35, 26, 70)
		entry.stroke.Color = Color3.fromRGB(120, 110, 160)
		entry.stroke.Thickness = 2
	elseif current == "ready" then
		entry.status.Text = "OTWÓRZ!"
		entry.status.TextColor3 = UIKit.COLORS.title
		entry.card.BackgroundColor3 = Color3.fromRGB(90, 50, 160)
		entry.stroke.Color = UIKit.COLORS.title
		entry.stroke.Thickness = 3
	else
		local left = (tonumber(gift.unlockIn) or 0) - (os.clock() - stateAt)
		entry.status.Text = "za " .. clock(left)
		entry.status.TextColor3 = UIKit.COLORS.text
		entry.card.BackgroundColor3 = CARD
		entry.stroke.Color = UIKit.COLORS.stroke
		entry.stroke.Thickness = 2
	end
end

local function readyInWindow(): number
	local count = 0
	for index in cards do
		if giftState(index) == "ready" then
			count += 1
		end
	end
	return count
end

local function render()
	if not refs.panel or not state then
		return
	end
	local minutes = math.floor(((tonumber(state.seconds) or 0) + (os.clock() - stateAt)) / 60)
	refs.subtitle.Text = "Graj i odbieraj prezenty! Dzisiaj w grze: " .. minutes .. " min"
	for index in cards do
		renderCard(index)
	end
	refs.claimAll.Visible = readyInWindow() >= 2 and not busy
end

local function applyState(newState)
	if type(newState) == "table" and type(newState.gifts) == "table" then
		state = newState
		stateAt = os.clock()
		render()
	end
end

-- Otwieranie: pudełko się trzęsie, pokrywka odlatuje, błysk i nagroda wyskakuje
local function animateOpen(index: number, label: string)
	local entry = cards[index]
	if not entry then
		return
	end
	for step, angle in { -14, 14, -10, 10, -6, 0 } do
		TweenService:Create(entry.box, TweenInfo.new(0.07), { Rotation = angle }):Play()
		SoundController.Play("UIClick", 1 + step * 0.08)
		task.wait(0.075)
	end
	TweenService:Create(entry.lid, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = entry.lidHome + UDim2.fromOffset(22, -52),
		Rotation = 45,
	}):Play()
	entry.flash.BackgroundTransparency = 0.15
	TweenService:Create(entry.flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	entry.pop.Scale = 1.12
	TweenService:Create(entry.pop, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	entry.reward.Text = label
	entry.reward.TextColor3 = UIKit.COLORS.title
	entry.rewardPop.Scale = 1.9
	TweenService:Create(entry.rewardPop, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	SoundController.Play("Success", 1.05 + index * 0.03)
	UIKit.confetti(refs.gui, 45)
	task.wait(0.7)
	entry.reward.TextColor3 = UIKit.COLORS.text
	renderCard(index)
end

local function playClaims(result)
	local claimed = if type(result.claimed) == "table" then result.claimed else {}
	local shortLabels = {}
	if state and type(state.gifts) == "table" then
		for _, item in claimed do
			local gift = state.gifts[tonumber(item.index) or 0]
			shortLabels[tonumber(item.index) or 0] = if gift then tostring(gift.label) else tostring(item.label)
		end
	end
	for order, item in claimed do
		local index = tonumber(item.index) or 0
		if order < #claimed then
			task.spawn(animateOpen, index, shortLabels[index] or "")
			task.wait(0.3)
		else
			animateOpen(index, shortLabels[index] or "")
		end
	end
	if #claimed > 1 then
		SoundController.Play("RentPaid")
	end
	applyState(result.state)
end

function GiftsController.Claim(index: number)
	if busy or giftState(index) ~= "ready" then
		if giftState(index) == "locked" then
			SoundController.Play("Warning")
		end
		return
	end
	busy = true
	local result = callbacks.gifts and callbacks.gifts("claim", index)
	if type(result) == "table" and result.ok then
		playClaims(result)
	else
		applyState(type(result) == "table" and result.state or (callbacks.gifts and callbacks.gifts("get")))
	end
	busy = false
	render()
end

local function claimAll()
	if busy then
		return
	end
	busy = true
	refs.claimAll.Visible = false
	local result = callbacks.gifts and callbacks.gifts("claimAll")
	if type(result) == "table" and result.ok then
		playClaims(result)
	else
		applyState(type(result) == "table" and result.state)
	end
	busy = false
	render()
end

local function redeem()
	local text = refs.codeBox.Text
	if text == "" or busy then
		return
	end
	local result = callbacks.redeem and callbacks.redeem(text)
	if type(result) ~= "table" then
		refs.codeResult.Text = "Spróbuj jeszcze raz za chwilę."
		refs.codeResult.TextColor3 = UIKit.COLORS.bad
		return
	end
	refs.codeResult.Text = tostring(result.message or "")
	if result.ok then
		refs.codeResult.TextColor3 = UIKit.COLORS.good
		refs.codeBox.Text = ""
		SoundController.Play("Success", 1.1)
		UIKit.confetti(refs.gui, 70)
	else
		refs.codeResult.TextColor3 = UIKit.COLORS.bad
		SoundController.Play("Warning")
		refs.codeBox.Position = UDim2.fromOffset(28, 522)
		TweenService:Create(refs.codeBox, TweenInfo.new(0.35, Enum.EasingStyle.Elastic), { Position = UDim2.fromOffset(20, 522) }):Play()
	end
end

local function build()
	local gui = UIKit.screenGui("GiftsUI", 25)
	local panel = UIKit.panel("Gifts", UDim2.fromOffset(660, 606), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UIKit.closeButton(panel, function()
		panel.Visible = false
	end)
	UIKit.label("Title", {
		Text = "🎁 PREZENTY ZA GRĘ",
		Size = UDim2.new(1, -120, 0, 40),
		Position = UDim2.fromOffset(60, 14),
		TextSize = 34,
		TextColor3 = UIKit.COLORS.title,
	}).Parent = panel
	refs.subtitle = UIKit.label("Subtitle", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 24),
		Position = UDim2.fromOffset(20, 56),
		TextSize = 18,
	})
	refs.subtitle.Parent = panel

	local grid = UIKit.create("Frame", {
		Name = "Grid",
		Size = UDim2.new(1, -40, 0, 340),
		Position = UDim2.fromOffset(20, 90),
		BackgroundTransparency = 1,
	}, {
		UIKit.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(146, 164),
			CellPadding = UDim2.fromOffset(10, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index = 1, 8 do
		local entry = buildCard(index)
		entry.card.Parent = grid
		cards[index] = entry
	end
	grid.Parent = panel

	refs.claimAll = UIKit.button("ClaimAll", "🎁 ODBIERZ WSZYSTKO", UIKit.COLORS.button, {
		Size = UDim2.fromOffset(300, 44),
		Position = UDim2.new(0.5, 0, 0, 438),
		AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 22,
		Visible = false,
	})
	refs.claimAll.Activated:Connect(claimAll)
	refs.claimAll.Parent = panel

	-- Kody nagród
	UIKit.label("CodeTitle", {
		Text = "🎫 Masz kod? Wpisz go tutaj:",
		Size = UDim2.new(1, -40, 0, 24),
		Position = UDim2.fromOffset(20, 492),
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel
	refs.codeBox = UIKit.create("TextBox", {
		Name = "Code",
		Size = UDim2.fromOffset(390, 46),
		Position = UDim2.fromOffset(20, 522),
		BackgroundColor3 = Color3.fromRGB(250, 248, 255),
		Font = UIKit.FONT,
		Text = "",
		PlaceholderText = "KOD / CODE",
		PlaceholderColor3 = Color3.fromRGB(150, 140, 180),
		TextColor3 = Color3.fromRGB(40, 25, 90),
		TextSize = 24,
		ClearTextOnFocus = false,
	}, { UIKit.corner(12), UIKit.border(UIKit.COLORS.stroke, 2) })
	refs.codeBox:SetAttribute("NoTranslate", true)
	refs.codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)
	refs.codeBox.Parent = panel
	local redeemButton = UIKit.button("Redeem", "ODBIERZ", UIKit.COLORS.button, {
		Size = UDim2.fromOffset(210, 46),
		Position = UDim2.fromOffset(426, 522),
		TextSize = 22,
	})
	redeemButton.Activated:Connect(redeem)
	redeemButton.Parent = panel
	refs.codeResult = UIKit.label("CodeResult", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 26),
		Position = UDim2.fromOffset(20, 572),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.codeResult.Parent = panel

	panel.Parent = gui
	refs.gui = gui
	refs.panel = panel
end

function GiftsController.Open()
	if not refs.panel then
		build()
	end
	refs.codeResult.Text = ""
	UIKit.popIn(refs.panel)
	applyState(callbacks.gifts and callbacks.gifts("get"))
end

function GiftsController.Toggle()
	if refs.panel and refs.panel.Visible then
		refs.panel.Visible = false
		return
	end
	GiftsController.Open()
end

-- Stan gracza: liczba prezentów do odebrania i czas do następnego
function GiftsController.ApplyState(snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end
	local ready = tonumber(snapshot.giftReady)
	local changed = ready ~= nil and ready ~= hudReady
	if ready then
		hudReady = ready
	end
	local nextIn = tonumber(snapshot.giftNextIn)
	hudNextAt = if nextIn then os.clock() + nextIn else nil
	updateHud()
	-- Otwarte okno nie zgadza się z serwerem (np. nowy dzień albo przeskok czasu): pobierz stan od nowa
	if changed and refs.panel and refs.panel.Visible and not busy and ready ~= readyInWindow() then
		task.spawn(function()
			local fresh = callbacks.gifts and callbacks.gifts("get")
			if not busy then
				applyState(fresh)
			end
		end)
	end
end

-- newCallbacks: gifts(akcja, nr) -> wynik, redeem(tekst) -> wynik
function GiftsController.Init(newCallbacks)
	callbacks = newCallbacks or {}
	buildHudButton()
	task.spawn(function()
		local lastBounce = 0
		while true do
			task.wait(0.25)
			if hudNextAt and hudReady == 0 and hudNextAt - os.clock() <= 0 then
				-- Odliczanie dobiegło końca: serwer zaraz potwierdzi prezent
				refs.hudButton.Text = "🎁 ODBIERZ!"
			else
				updateHud()
			end
			if hudReady > 0 and refs.hudBounce and os.clock() - lastBounce > 2.2 then
				lastBounce = os.clock()
				refs.hudBounce.Scale = 1.15
				TweenService:Create(refs.hudBounce, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
			end
			if refs.panel and refs.panel.Visible and not busy then
				render()
			end
		end
	end)
	-- Gotowe pudełka kolebą się płynnie, żeby chciało się je otworzyć
	RunService.Heartbeat:Connect(function()
		if not refs.panel or not refs.panel.Visible or busy then
			return
		end
		for index, entry in cards do
			if giftState(index) == "ready" then
				entry.box.Rotation = math.sin(os.clock() * 7 + index) * 7
			end
		end
	end)
end

return GiftsController

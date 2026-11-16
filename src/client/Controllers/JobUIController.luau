-- Interfejs prac: menu wyboru poziomu, panel zmiany (czas, postęp, wskazówka), wynik z gwiazdkami
-- i okienko minigier (kasa oraz ogólny wybór odpowiedzi: mode = "choice").
-- Ukrywa też obiekty prac innych graczy (każdy widzi wyraźnie tylko swoje).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Modules"):WaitForChild("Format"))
local JobsConfig = require(Shared:WaitForChild("Config"):WaitForChild("JobsConfig"))
local LevelConfig = require(Shared:WaitForChild("Config"):WaitForChild("LevelConfig"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))
local EmoteController = require(script.Parent:WaitForChild("EmoteController"))

local JobUIController = {}

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne
local COLORS = {
	panel = Color3.fromRGB(70, 45, 150),
	stroke = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(255, 255, 255),
	textStroke = Color3.fromRGB(25, 15, 45),
	title = Color3.fromRGB(255, 215, 60),
	good = Color3.fromRGB(90, 220, 110),
	bad = Color3.fromRGB(255, 80, 90),
	button = Color3.fromRGB(60, 190, 90),
	locked = Color3.fromRGB(95, 85, 130),
	option = Color3.fromRGB(70, 110, 200),
	cancel = Color3.fromRGB(200, 70, 80),
	barBack = Color3.fromRGB(35, 22, 80),
	goal = Color3.fromRGB(255, 200, 40),
	star = Color3.fromRGB(255, 215, 60),
	starOff = Color3.fromRGB(95, 85, 130),
}

local refs = {}
local actions = {}
local current = nil
local receivedAt = 0
local resultToken = 0
local revealToken = 0
local goalReached = false
local lastCombo = 0
local comboToken = 0
local raysSpin: RBXScriptConnection? = nil

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

local function border(color: Color3, thickness: number)
	return create("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(name: string, props)
	local base = {
		Name = name,
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = COLORS.text,
		TextWrapped = true,
	}
	for key, value in props do
		base[key] = value
	end
	return create("TextLabel", base, {
		create("UIStroke", { Color = COLORS.textStroke, Thickness = 2 }),
	})
end

local function button(name: string, text: string, color: Color3, props)
	local base = {
		Name = name,
		Text = text,
		BackgroundColor3 = color,
		Font = FONT,
		TextSize = 22,
		TextColor3 = COLORS.text,
		TextWrapped = true,
	}
	for key, value in props do
		base[key] = value
	end
	local pressable = create("TextButton", base, { corner(12), border(COLORS.stroke, 2) })
	UIKit.gloss(pressable)
	UIKit.squish(pressable)
	return pressable
end

local function panel(name: string, size: UDim2, position: UDim2, anchor: Vector2)
	local frame = create("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, { corner(18), border(COLORS.stroke, 3) })
	UIKit.gloss(frame)
	return frame
end

-- Niewidoczny przycisk z Modal = true: odblokowuje myszkę, gdy kamera jest blisko postaci
-- (w ciasnym warsztacie kamera wchodzi w pierwszą osobę i myszka zostaje przypięta do środka ekranu)
local function unlockMouse(parent: GuiObject)
	create("TextButton", {
		Name = "MouseUnlock",
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		Modal = true,
		Selectable = false,
	}).Parent = parent
end

local function productLabel(id: any): string
	local product = if type(id) == "string" then JobsConfig.GetProduct(id) else nil
	if product then
		return product.emoji .. " " .. product.name
	end
	return tostring(id)
end

-- Menu wyboru poziomu -------------------------------------------------------

local function buildMenu(gui: ScreenGui)
	local menu = panel("JobMenu", UDim2.fromOffset(460, 370), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	refs.menuTitle = label("Title", {
		Text = "",
		Size = UDim2.new(1, -80, 0, 36),
		Position = UDim2.fromOffset(20, 12),
		TextSize = 30,
		TextColor3 = COLORS.title,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.menuTitle.Parent = menu
	refs.menuDesc = label("Description", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 64),
		Position = UDim2.fromOffset(20, 52),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	refs.menuDesc.Parent = menu
	refs.menuShift = label("Shift", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 22),
		Position = UDim2.fromOffset(20, 118),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.menuShift.Parent = menu

	refs.levelButtons = {}
	for level = 1, 3 do
		local levelButton = button("Level" .. level, "", COLORS.button, {
			Size = UDim2.new(1, -40, 0, 56),
			Position = UDim2.fromOffset(20, 148 + (level - 1) * 68),
			TextSize = 20,
		})
		levelButton.Activated:Connect(function()
			local info = refs.menuLevels and refs.menuLevels[level]
			if type(info) == "table" and info.unlocked and refs.menuJobId then
				menu.Visible = false
				actions.startJob(refs.menuJobId, level)
			end
		end)
		levelButton.Parent = menu
		refs.levelButtons[level] = levelButton
	end

	local close = button("Close", "X", COLORS.cancel, {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -12, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 24,
	})
	close.Activated:Connect(function()
		menu.Visible = false
	end)
	close.Parent = menu
	unlockMouse(menu)

	menu.Parent = gui
	refs.menu = menu
end

function JobUIController.ShowMenu(payload: any)
	if type(payload) ~= "table" or type(payload.levels) ~= "table" or not refs.menu then
		return
	end
	refs.menuJobId = payload.jobId
	refs.menuLevels = payload.levels
	refs.menuTitle.Text = tostring(payload.name or "")
	refs.menuDesc.Text = tostring(payload.description or "")
	refs.menuShift.Text = "Zmiana trwa " .. (tonumber(payload.shift) or 0) .. " s"
	for level, levelButton in refs.levelButtons do
		local info = payload.levels[level]
		if type(info) ~= "table" then
			levelButton.Visible = false
		elseif info.unlocked then
			levelButton.Visible = true
			levelButton.Text = string.format("%s  ·  ok. %s monet", tostring(info.name), Format.Number(tonumber(info.pay) or 0))
			levelButton.BackgroundColor3 = COLORS.button
		else
			levelButton.Visible = true
			levelButton.Text = string.format("🔒 %s  ·  %s", tostring(info.name), tostring(info.requirement or ""))
			levelButton.BackgroundColor3 = COLORS.locked
		end
	end
	UIKit.popIn(refs.menu)
end

-- Panel zmiany ------------------------------------------------------------------

local function buildHud(gui: ScreenGui)
	local hud = panel("JobHud", UDim2.fromOffset(270, 180), UDim2.new(1, -12, 0.5, 0), Vector2.new(1, 0.5))
	hud.BackgroundTransparency = 0.1
	refs.hudTitle = label("Title", {
		Text = "",
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 8),
		TextSize = 20,
		TextColor3 = COLORS.title,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.hudTitle.Parent = hud
	refs.hudTimer = label("Timer", {
		Text = "",
		Size = UDim2.new(1, -24, 0, 32),
		Position = UDim2.fromOffset(12, 34),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.hudTimer.Parent = hud

	local bar = create("Frame", {
		Name = "Bar",
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.fromOffset(12, 72),
		BackgroundColor3 = COLORS.barBack,
		ClipsDescendants = true,
	}, { corner(10) })
	refs.hudFill = create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = COLORS.good }, { corner(10) })
	UIKit.gloss(refs.hudFill)
	refs.hudPop = create("UIScale", {})
	refs.hudPop.Parent = hud
	refs.hudFill.Parent = bar
	refs.hudBarText = label("Text", { Text = "", Size = UDim2.fromScale(1, 1), TextSize = 15, ZIndex = 2 })
	refs.hudBarText.Parent = bar
	bar.Parent = hud

	refs.hudHint = label("Hint", {
		Text = "",
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(12, 96),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	refs.hudHint.Parent = hud

	local cancel = button("Cancel", "PRZERWIJ", COLORS.cancel, {
		Size = UDim2.fromOffset(130, 32),
		Position = UDim2.new(1, -12, 1, -10),
		AnchorPoint = Vector2.new(1, 1),
		TextSize = 16,
	})
	cancel.Activated:Connect(function()
		actions.cancelJob()
	end)
	cancel.Parent = hud
	refs.hudCancel = cancel

	-- Złota plakietka nad panelem po osiągnięciu celu
	refs.goalBanner = create("Frame", {
		Name = "GoalBanner",
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.new(0, 0, 0, -8),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = COLORS.goal,
		Visible = false,
	}, { corner(12), border(COLORS.stroke, 2) })
	UIKit.gloss(refs.goalBanner)
	label("Text", {
		Text = "🎯 CEL! Możesz skończyć (KONIEC).\nKażde kolejne zadanie = BONUS 💰",
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		TextSize = 15,
	}).Parent = refs.goalBanner
	refs.goalBanner.Parent = hud

	-- Combo: licznik serii po lewej stronie panelu (zadanie za zadaniem bez długich przerw)
	local combo = create("Frame", {
		Name = "Combo",
		Size = UDim2.fromOffset(150, 76),
		Position = UDim2.new(0, -10, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(45, 20, 75),
		BackgroundTransparency = 0.1,
		Visible = false,
	}, { corner(14), border(COLORS.stroke, 2) })
	UIKit.gloss(combo)
	refs.comboPop = create("UIScale", {})
	refs.comboPop.Parent = combo
	refs.comboText = label("Count", {
		Text = "",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 4),
		TextSize = 34,
		TextWrapped = false,
		TextColor3 = COLORS.goal,
	})
	refs.comboText:SetAttribute("NoTranslate", true)
	refs.comboText.Parent = combo
	label("Caption", {
		Text = "COMBO",
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 42),
		TextSize = 15,
	}).Parent = combo
	local comboBar = create("Frame", {
		Name = "Bar",
		Size = UDim2.new(1, -20, 0, 8),
		Position = UDim2.new(0, 10, 1, -13),
		BackgroundColor3 = COLORS.barBack,
		ClipsDescendants = true,
	}, { corner(4) })
	refs.comboFill = create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 140, 40),
	}, { corner(4) })
	refs.comboFill.Parent = comboBar
	comboBar.Parent = combo
	combo.Parent = hud
	refs.combo = combo

	hud.Parent = gui
	refs.hud = hud
end

-- Seria rośnie z każdym zadaniem w oknie czasu; pasek pokazuje, ile zostało do następnego zadania
local function hideCombo()
	comboToken += 1
	lastCombo = 0
	if refs.combo then
		refs.combo.Visible = false
	end
end

local function updateCombo(payload)
	local combo = tonumber(payload.combo) or 0
	local left = tonumber(payload.comboLeft) or 0
	local window = math.max(0.1, tonumber(payload.comboWindow) or 1)
	if combo < 2 or left <= 0 then
		hideCombo()
		lastCombo = combo
		return
	end
	refs.combo.Visible = true
	if combo >= 10 then
		refs.comboText.Text = "🔥🔥 x" .. combo
		refs.comboText.TextColor3 = Color3.fromRGB(255, 90, 140)
	elseif combo >= 5 then
		refs.comboText.Text = "🔥 x" .. combo
		refs.comboText.TextColor3 = Color3.fromRGB(255, 150, 50)
	else
		refs.comboText.Text = "x" .. combo
		refs.comboText.TextColor3 = COLORS.goal
	end
	comboToken += 1
	local token = comboToken
	refs.comboFill.Size = UDim2.fromScale(math.clamp(left / window, 0, 1), 1)
	local drain = TweenService:Create(refs.comboFill, TweenInfo.new(left, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
	drain.Completed:Once(function(playbackState)
		if token == comboToken and playbackState == Enum.PlaybackState.Completed then
			hideCombo()
		end
	end)
	drain:Play()
	if combo > lastCombo then
		refs.comboPop.Scale = 1.45
		TweenService:Create(refs.comboPop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		SoundController.Play("Coins", math.min(LevelConfig.COMBO_SOUND_MAX, 1 + combo * 0.06))
	end
	lastCombo = combo
end

local function updateTimer()
	if not current or not refs.hudTimer then
		return
	end
	local remaining = (tonumber(current.endsIn) or 0) - (os.clock() - receivedAt)
	refs.hudTimer.Text = "⏱ " .. Format.Time(remaining)
	refs.hudTimer.TextColor3 = if remaining <= 10 then COLORS.bad else COLORS.text
end

-- Okienko kasy (Kasjer) ------------------------------------------------------

local function buildCashier(gui: ScreenGui)
	local cashier = panel("Cashier", UDim2.fromOffset(540, 250), UDim2.new(0.5, 0, 1, -20), Vector2.new(0.5, 1))
	refs.cashTitle = label("Title", {
		Text = "",
		Size = UDim2.new(1, -32, 0, 28),
		Position = UDim2.fromOffset(16, 10),
		TextSize = 22,
		TextColor3 = COLORS.title,
	})
	refs.cashTitle.Parent = cashier
	refs.cashPrompt = label("Prompt", {
		Text = "",
		Size = UDim2.new(1, -32, 0, 44),
		Position = UDim2.fromOffset(16, 38),
		TextSize = 24,
		TextScaled = true,
	})
	create("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 12 }).Parent = refs.cashPrompt
	refs.cashPrompt.Parent = cashier

	local grid = create("Frame", {
		Name = "Options",
		Size = UDim2.new(1, -32, 0, 150),
		Position = UDim2.fromOffset(16, 88),
		BackgroundTransparency = 1,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(160, 66),
			CellPadding = UDim2.fromOffset(10, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	refs.cashButtons = {}
	refs.cashValues = {}
	for index = 1, 6 do
		local option = button("Option" .. index, "", COLORS.option, { LayoutOrder = index, TextSize = 22 })
		option.Activated:Connect(function()
			local value = refs.cashValues[index]
			local extra = current and current.extra
			if value ~= nil and type(extra) == "table" then
				local action = if extra.mode == "choice" then extra.action elseif extra.mode == "change" then "change" else "scan"
				if type(action) == "string" then
					actions.jobAction(action, value)
				end
			end
		end)
		option.Parent = grid
		refs.cashButtons[index] = option
	end
	grid.Parent = cashier

	unlockMouse(cashier)
	cashier.Parent = gui
	refs.cashier = cashier
end

-- Ogólny wybór odpowiedzi: { title, prompt, options = { { value, label } }, action,
-- opcjonalnie reveal + revealFor: tekst do zapamiętania pokazywany na chwilę przed przyciskami }
local function renderChoice(extra)
	refs.cashTitle.Text = tostring(extra.title or "")
	local options = if type(extra.options) == "table" then extra.options else {}
	for index, option in refs.cashButtons do
		local entry = options[index]
		local value = if type(entry) == "table" then entry.value else nil
		refs.cashValues[index] = value
		option.Text = if type(entry) == "table" then tostring(entry.label or entry.value) else ""
		option.Visible = value ~= nil
	end
	local function showPrompt()
		refs.cashPrompt.Text = tostring(extra.prompt or "")
		refs.cashPrompt.TextColor3 = if extra.mistake then COLORS.bad else COLORS.text
	end
	local revealFor = tonumber(extra.revealFor)
	if type(extra.reveal) == "string" and revealFor and revealFor > 0 then
		refs.cashPrompt.Text = extra.reveal
		refs.cashPrompt.TextColor3 = if extra.mistake then COLORS.bad else COLORS.title
		for _, option in refs.cashButtons do
			option.Visible = false
		end
		local token = revealToken
		task.delay(math.min(revealFor, 10), function()
			if token ~= revealToken then
				return
			end
			showPrompt()
			for index, option in refs.cashButtons do
				option.Visible = refs.cashValues[index] ~= nil
			end
		end)
	else
		showPrompt()
	end
end

local function renderCashier(extra: any)
	revealToken += 1
	if type(extra) ~= "table" or (extra.mode ~= "scan" and extra.mode ~= "change" and extra.mode ~= "choice") then
		refs.cashier.Visible = false
		return
	end
	refs.cashier.Visible = true
	if extra.mode == "choice" then
		renderChoice(extra)
		return
	end
	refs.cashTitle.Text = string.format("Klient nr %d   (cel: %d)", tonumber(extra.customer) or 0, tonumber(extra.goal) or 0)
	if extra.mode == "scan" then
		local text = string.format("Skanuj (%d/%d): %s", tonumber(extra.step) or 1, tonumber(extra.steps) or 1, productLabel(extra.target))
		refs.cashPrompt.Text = if extra.mistake then "Ups! " .. text else text
		refs.cashPrompt.TextColor3 = if extra.mistake then COLORS.bad else COLORS.text
	else
		refs.cashPrompt.Text = string.format(
			"Rachunek: %s. Klient daje %s. Ile reszty?",
			Format.Number(tonumber(extra.total) or 0),
			Format.Number(tonumber(extra.paid) or 0)
		)
		refs.cashPrompt.TextColor3 = COLORS.text
	end
	local options = if type(extra.options) == "table" then extra.options else {}
	for index, option in refs.cashButtons do
		local value = options[index]
		refs.cashValues[index] = value
		option.Visible = value ~= nil
		if value ~= nil then
			option.Text = if extra.mode == "scan" then productLabel(value) else Format.Number(tonumber(value) or 0) .. " monet"
		end
	end
end

-- W trakcie zmiany podpowiedzi "Praca: ..." znikają, żeby nie zasłaniały podpowiedzi zadań
-- (Roblox pokazuje tylko najbliższą podpowiedź na ten sam klawisz)
local function setStartPromptsEnabled(enabled: boolean)
	local map = Workspace:FindFirstChild("Map")
	local sites = map and map:FindFirstChild("JobSites")
	if not sites then
		return
	end
	for _, descendant in sites:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "StartPrompt" then
			descendant.Enabled = enabled
		end
	end
end

function JobUIController.Update(payload: any)
	if not refs.hud then
		return
	end
	if type(payload) ~= "table" or not payload.active then
		goalReached = false
		current = nil
		refs.hud.Visible = false
		refs.cashier.Visible = false
		hideCombo()
		setStartPromptsEnabled(true)
		return
	end
	if not current then
		setStartPromptsEnabled(false)
		goalReached = false
	end
	current = payload
	receivedAt = os.clock()
	refs.menu.Visible = false
	refs.hud.Visible = true
	refs.hudTitle.Text = string.format("%s (%s)", tostring(payload.name), tostring(payload.levelName))
	local total = tonumber(payload.total) or 0
	local done = tonumber(payload.done) or 0
	TweenService:Create(refs.hudFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(if total > 0 then math.clamp(done / total, 0, 1) else 0, 1),
	}):Play()
	local reached = done >= total and total > 0
	refs.hudFill.BackgroundColor3 = if reached then COLORS.goal else COLORS.good
	refs.hudBarText.Text = if reached then done .. " / " .. total .. "  CEL! ⭐" else done .. " / " .. total
	refs.goalBanner.Visible = reached
	refs.hudCancel.Text = if reached then "✅ KONIEC" else "PRZERWIJ"
	refs.hudCancel.BackgroundColor3 = if reached then COLORS.button else COLORS.cancel
	if reached and not goalReached then
		-- Cel zmiany osiągnięty: panel podskakuje, słychać fanfarę
		refs.hudPop.Scale = 1.15
		TweenService:Create(refs.hudPop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		SoundController.Play("Success", 1.1)
	end
	goalReached = reached
	refs.hudHint.Text = tostring(payload.hint or "")
	updateTimer()
	renderCashier(payload.extra)
	updateCombo(payload)
end

-- Wynik zmiany -------------------------------------------------------------------

local function buildResult(gui: ScreenGui)
	-- Złote promienie za oknem przy 3 gwiazdkach i rekordzie (osobna ramka pod oknem)
	local rays = create("Frame", {
		Name = "ResultRays",
		Size = UDim2.fromOffset(640, 640),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Visible = false,
	})
	for index = 0, 9 do
		local ray = create("Frame", {
			Name = "Ray" .. index,
			Size = UDim2.new(0, 40, 1, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = index * 18,
			BackgroundColor3 = COLORS.star,
			BorderSizePixel = 0,
			ZIndex = 0,
		})
		create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}).Parent = ray
		ray.Parent = rays
	end
	rays.Parent = gui
	refs.resRays = rays

	local result = panel("JobResult", UDim2.fromOffset(400, 300), UDim2.fromScale(0.5, 0.42), Vector2.new(0.5, 0.5))
	refs.resultPop = create("UIScale", {})
	refs.resultPop.Parent = result
	refs.resTitle = label("Title", {
		Text = "",
		Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.fromOffset(10, 12),
		TextSize = 26,
		TextColor3 = COLORS.title,
	})
	refs.resTitle.Parent = result
	local row = create("Frame", {
		Name = "Stars",
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 48),
		BackgroundTransparency = 1,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	refs.resStars = {}
	for index = 1, 3 do
		local star = label("Star" .. index, { Text = "★", Size = UDim2.fromOffset(56, 60), TextSize = 56, LayoutOrder = index })
		create("UIScale", { Name = "Pop" }).Parent = star
		star.Parent = row
		refs.resStars[index] = star
	end
	row.Parent = result
	refs.resPay = label("Pay", { Text = "", Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 112), TextSize = 32 })
	refs.resPay.Parent = result
	refs.resInfo = label("Info", {
		Text = "",
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 150),
		TextSize = 19,
		TextColor3 = COLORS.goal,
	})
	refs.resInfo.Parent = result
	refs.resXp = label("Xp", {
		Text = "",
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.fromOffset(10, 176),
		TextSize = 24,
		TextColor3 = Color3.fromRGB(120, 220, 255),
	})
	refs.resXp.Parent = result
	refs.resNote = label("Note", { Text = "", Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 208), TextSize = 19 })
	refs.resNote.Parent = result

	-- Pieczątka "NOWY REKORD!" w rogu okna
	refs.resRecord = label("Record", {
		Text = "🏆 NOWY REKORD!",
		Size = UDim2.fromOffset(200, 40),
		Position = UDim2.new(1, 24, 0, -16),
		AnchorPoint = Vector2.new(1, 0),
		Rotation = 10,
		TextSize = 21,
		TextWrapped = false,
		BackgroundColor3 = Color3.fromRGB(230, 60, 100),
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 5,
	})
	corner(12).Parent = refs.resRecord
	border(COLORS.stroke, 3).Parent = refs.resRecord
	refs.recordPop = create("UIScale", {})
	refs.recordPop.Parent = refs.resRecord
	refs.resRecord.Parent = result
	result.Parent = gui
	refs.result = result
end

local function setRays(visible: boolean)
	refs.resRays.Visible = visible
	if raysSpin then
		raysSpin:Disconnect()
		raysSpin = nil
	end
	if visible then
		raysSpin = game:GetService("RunService").Heartbeat:Connect(function(dt)
			refs.resRays.Rotation = (refs.resRays.Rotation + dt * 30) % 360
		end)
	end
end

function JobUIController.ShowResult(payload: any)
	if type(payload) ~= "table" or not refs.result then
		return
	end
	local stars = math.clamp(tonumber(payload.stars) or 0, 0, 3)
	local amount = tonumber(payload.amount) or 0
	refs.resTitle.Text = tostring(payload.name or "Praca") .. ": koniec zmiany!"
	resultToken += 1
	local token = resultToken
	-- Gwiazdki wskakują po kolei, każda z wyższym dźwiękiem
	for index, star in refs.resStars do
		star.TextColor3 = COLORS.starOff
		star.Pop.Scale = 1
		if index <= stars then
			task.delay(0.25 + index * 0.3, function()
				if token ~= resultToken then
					return
				end
				star.TextColor3 = COLORS.star
				star.Pop.Scale = 1.8
				TweenService:Create(star.Pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				SoundController.Play("UIClick", 1 + index * 0.25)
			end)
		end
	end
	-- Wypłata "nabija się" od zera
	refs.resPay.TextColor3 = if amount > 0 then COLORS.good else COLORS.bad
	if amount > 0 then
		task.spawn(function()
			local steps = 20
			for step = 1, steps do
				if token ~= resultToken then
					return
				end
				local shown = math.floor(amount * step / steps + 0.5)
				refs.resPay.Text = "+" .. Format.Number(shown) .. " " .. Format.Plural(shown, "moneta", "monety", "monet")
				task.wait(0.04)
			end
		end)
	else
		refs.resPay.Text = "Bez wypłaty"
	end
	if stars == 3 or payload.levelUnlocked then
		task.delay(0.25 + stars * 0.3, function()
			if token == resultToken and refs.result.Parent then
				UIKit.confetti(refs.result.Parent, 80)
			end
		end)
	end
	if stars == 3 then
		EmoteController.Play("cheer")
	end

	-- Combo, Złota godzina i XP pod wypłatą
	local info = {}
	local combo = tonumber(payload.combo) or 0
	if combo >= 2 then
		local bonus = tonumber(payload.comboBonus) or 0
		table.insert(info, if bonus > 0 then "🔥 Combo x" .. combo .. ": +" .. bonus .. "%" else "🔥 Combo x" .. combo)
	end
	if payload.golden then
		table.insert(info, "✨ Złota godzina ×2")
	end
	refs.resInfo.Text = table.concat(info, "   ")
	local xp = tonumber(payload.xp) or 0
	refs.resXp.Text = if xp > 0 then "+" .. Format.Number(xp) .. " XP" else ""

	-- Rekord: pieczątka spada z góry po gwiazdkach
	refs.resRecord.Visible = false
	if payload.record then
		task.delay(0.45 + stars * 0.3, function()
			if token ~= resultToken then
				return
			end
			refs.resRecord.Visible = true
			refs.recordPop.Scale = 2.6
			TweenService:Create(refs.recordPop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			SoundController.Play("Success", 1.3)
			if refs.result.Parent then
				UIKit.confetti(refs.result.Parent, 60)
			end
		end)
	end
	setRays(stars == 3 or payload.record == true)
	if payload.tooFast then
		refs.resNote.Text = "Zbyt szybko, zmiana się nie liczy. Pracuj spokojnie!"
	elseif payload.levelUnlocked then
		refs.resNote.Text = "Nowy poziom: " .. tostring(payload.levelUnlocked) .. "!"
	elseif payload.coop then
		refs.resNote.Text = "Praca w ekipie: +20%!"
	elseif stars == 3 then
		refs.resNote.Text = "Perfekcyjnie!"
	elseif stars == 0 then
		refs.resNote.Text = "Następnym razem pójdzie lepiej!"
	else
		refs.resNote.Text = "Dobra robota!"
	end

	refs.result.Visible = true
	refs.resultPop.Scale = 0.7
	TweenService:Create(refs.resultPop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(6, function()
		if token == resultToken then
			refs.result.Visible = false
			setRays(false)
		end
	end)
end

-- Obiekty prac innych graczy: wyblakłe i bez podpowiedzi --------------------

local function ownerOf(instance: Instance, root: Instance): number?
	local node = instance
	while node and node ~= root do
		local owner = node:GetAttribute("JobOwner")
		if owner then
			return owner
		end
		node = node.Parent
	end
	return nil
end

local function applyVisibility(instance: Instance, root: Instance)
	local owner = ownerOf(instance, root)
	if not owner or owner == player.UserId then
		return
	end
	if instance:IsA("ProximityPrompt") or instance:IsA("Highlight") or instance:IsA("Beam") then
		instance.Enabled = false
	elseif instance:IsA("BillboardGui") then
		instance.Enabled = false
	elseif instance:IsA("BasePart") then
		instance.Transparency = math.max(instance.Transparency, 0.8)
		-- Cudze obiekty prac (np. drugie auto u mechanika) nie blokują ruchu (zmiana tylko u tego gracza)
		instance.CanCollide = false
	end
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera and refs.scale then
		refs.scale.Scale = UIKit.ScaleFor(camera.ViewportSize)
	end
end

-- newActions: startJob(jobId, poziom), cancelJob(), jobAction(akcja, wartość)
function JobUIController.Init(newActions)
	actions = newActions
	local gui = create("ScreenGui", { Name = "JobUI", ResetOnSpawn = false, DisplayOrder = 4 })
	refs.scale = create("UIScale", {})
	refs.scale.Parent = gui
	buildMenu(gui)
	buildHud(gui)
	buildCashier(gui)
	buildResult(gui)
	gui.Parent = player:WaitForChild("PlayerGui")

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()

	task.spawn(function()
		while true do
			task.wait(0.2)
			updateTimer()
		end
	end)

	task.spawn(function()
		local jobObjects = Workspace:WaitForChild("JobObjects")
		jobObjects.DescendantAdded:Connect(function(instance)
			applyVisibility(instance, jobObjects)
		end)
		for _, instance in jobObjects:GetDescendants() do
			applyVisibility(instance, jobObjects)
		end
	end)
end

return JobUIController

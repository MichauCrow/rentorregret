-- Minigra robienia pizzy (praca w pizzerii): okienko na dole ekranu z pizzą na desce i bilecikiem zamówienia.
-- Kroki: wałkowanie ciasta (ciasto rośnie), sos, ser, składniki z zamówienia, piec (pasek z zielonym polem)
-- i pakowanie. Stan przychodzi z serwera w JobUpdate (extra.mode = "pizzaMaker"); klient wysyła tylko kliknięcia
-- (akcja "pizza"), a serwer sprawdza kolejność i czas w piecu.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))

local PizzaMakerController = {}

local COLORS = UIKit.COLORS
local TOPPINGS = {
	salami = { label = "🔴 Salami", color = Color3.fromRGB(190, 40, 45) },
	ham = { label = "🥓 Szynka", color = Color3.fromRGB(245, 150, 160) },
	mushroom = { label = "🍄 Pieczarki", color = Color3.fromRGB(225, 205, 170) },
	pepper = { label = "🌶️ Papryka", color = Color3.fromRGB(70, 170, 60) },
	pineapple = { label = "🍍 Ananas", color = Color3.fromRGB(255, 205, 70) },
	olive = { label = "⚫ Oliwki", color = Color3.fromRGB(40, 40, 35) },
}
local DOUGH = Color3.fromRGB(250, 228, 180)
local BAKED = Color3.fromRGB(225, 160, 80)

local refs = {}
local send = function(_value: string) end
local current = nil -- ostatni stan z serwera
local ovenStartedAt = nil
local autoTaken = false
local shownToppings = {} -- [składnik] = true, kropki już narysowane
local rng = Random.new()

local function circle(name: string, scale: number, color: Color3, z: number): Frame
	return UIKit.create("Frame", {
		Name = name,
		Size = UDim2.fromScale(scale, scale),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		ZIndex = z,
		Visible = false,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
end

local function clearToppings()
	for _, child in refs.toppingLayer:GetChildren() do
		child:Destroy()
	end
	table.clear(shownToppings)
end

-- Składnik na pizzy: kilka kropek w losowych miejscach na serze
local function drawTopping(id: string)
	local topping = TOPPINGS[id]
	if not topping or shownToppings[id] then
		return
	end
	shownToppings[id] = true
	for _ = 1, 7 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = math.sqrt(rng:NextNumber()) * 0.34
		local dot = circle("Topping", 0.13, topping.color, 6)
		dot.Position = UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.5 + math.sin(angle) * radius)
		dot.Visible = true
		local pop = UIKit.create("UIScale", { Scale = 0 })
		pop.Parent = dot
		TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		dot.Parent = refs.toppingLayer
	end
end

local function showButtons(names: { string })
	for name, button in refs.buttons do
		button.Visible = table.find(names, name) ~= nil
	end
	refs.toppingGrid.Visible = table.find(names, "toppings") ~= nil
	refs.ovenBar.Visible = table.find(names, "bar") ~= nil
end

local function render(extra)
	local step = extra.step
	refs.panel.Visible = true
	-- Bilecik zamówienia z odhaczonymi składnikami
	local order = extra.order or {}
	local placed = if type(extra.placed) == "table" then extra.placed else {}
	local lines = {}
	for _, id in (if type(order.toppings) == "table" then order.toppings else {}) do
		local topping = TOPPINGS[id]
		-- Trzy spacje oddzielają części tłumaczone osobno (Lang)
		table.insert(lines, (if table.find(placed, id) then "✅   " else "⬜   ") .. (if topping then topping.label else id))
	end
	refs.orderName.Text = "🧾   " .. tostring(order.name or "")
	refs.orderList.Text = if #lines > 0 then table.concat(lines, "\n") else "🧀"
	-- Pizza na desce
	local rolls = tonumber(extra.rolls) or 0
	local needed = math.max(1, tonumber(extra.rollsNeeded) or 5)
	local started = step ~= "dough" or rolls > 0
	refs.dough.Visible = true
	TweenService:Create(refs.dough, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
		Size = if started then UDim2.fromScale(0.45 + 0.47 * math.min(rolls / needed, 1), 0.45 + 0.47 * math.min(rolls / needed, 1)) else UDim2.fromScale(0.36, 0.36),
	}):Play()
	local afterDough = step ~= "dough"
	if afterDough then
		refs.dough.Size = UDim2.fromScale(0.92, 0.92)
	end
	local baked = step == "pack"
	refs.dough.BackgroundColor3 = if baked then BAKED else DOUGH
	refs.sauce.Visible = step == "cheese" or step == "toppings" or step == "oven" or step == "baking" or step == "pack"
	refs.cheese.Visible = step == "toppings" or step == "oven" or step == "baking" or step == "pack"
	refs.cheese.BackgroundColor3 = if baked then Color3.fromRGB(255, 190, 70) else Color3.fromRGB(255, 225, 120)
	if step == "dough" and rolls == 0 then
		clearToppings()
	end
	for _, id in placed do
		drawTopping(id)
	end
	-- Krok, uwaga z serwera i przyciski
	refs.step.Text = tostring(current and current.hint or "")
	refs.note.Text = tostring(extra.note or "")
	refs.note.TextColor3 = if extra.noteBad then COLORS.bad else COLORS.good
	if step == "dough" then
		refs.buttons.roll.Text = string.format("👐 Wałkuj (%d/%d)", rolls, needed)
		showButtons({ "roll" })
	elseif step == "sauce" then
		showButtons({ "sauce" })
	elseif step == "cheese" then
		showButtons({ "cheese" })
	elseif step == "toppings" then
		showButtons({ "toppings" })
		local list = if type(extra.toppings) == "table" then extra.toppings else {}
		for index, button in refs.toppingButtons do
			local id = list[index]
			button.Visible = id ~= nil
			button:SetAttribute("Topping", id)
			if id and TOPPINGS[id] then
				button.Text = TOPPINGS[id].label
				button.BackgroundColor3 = if table.find(placed, id) then COLORS.locked else COLORS.option
			end
		end
	elseif step == "oven" then
		ovenStartedAt = nil
		showButtons({ "oven" })
	elseif step == "baking" then
		if not ovenStartedAt then
			ovenStartedAt = os.clock()
			autoTaken = false
		end
		local zone = if type(extra.zone) == "table" then extra.zone else { 0.55, 0.8 }
		refs.ovenZone.Position = UDim2.fromScale(zone[1], 0)
		refs.ovenZone.Size = UDim2.fromScale(zone[2] - zone[1], 1)
		showButtons({ "take", "bar" })
	elseif step == "pack" then
		ovenStartedAt = nil
		showButtons({ "pack" })
	end
end

-- Pasek pieca wypełnia się lokalnie (czas liczy też serwer); po przepełnieniu pizza wyjmuje się sama (przypalona)
local function tickOven()
	if not ovenStartedAt or not current or type(current.extra) ~= "table" or current.extra.step ~= "baking" then
		return
	end
	local total = tonumber(current.extra.ovenTime) or 6
	local fraction = (os.clock() - ovenStartedAt) / total
	refs.ovenFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	refs.ovenFill.BackgroundColor3 = if fraction > 0.8 then COLORS.bad else COLORS.warn
	if fraction >= 1.1 and not autoTaken then
		autoTaken = true
		send("take")
	end
end

function PizzaMakerController.Update(payload: any)
	if not refs.panel then
		return
	end
	local extra = type(payload) == "table" and payload.active and payload.extra
	if type(extra) ~= "table" or extra.mode ~= "pizzaMaker" then
		if refs.panel.Visible then
			refs.panel.Visible = false
			clearToppings()
		end
		current = nil
		ovenStartedAt = nil
		return
	end
	local opening = not refs.panel.Visible
	current = payload
	render(extra)
	if opening then
		UIKit.popIn(refs.panel)
	end
end

-- newActions: send(wartość) wysyła akcję "pizza" do serwera
function PizzaMakerController.Init(newActions)
	send = newActions.send
	local gui = UIKit.screenGui("PizzaMakerUI", 5)
	local panel = UIKit.panel("PizzaMaker", UDim2.fromOffset(640, 300), UDim2.new(0.5, 0, 1, -84), Vector2.new(0.5, 1))
	refs.panel = panel
	-- Odblokowanie myszy w widoku z pierwszej osoby
	UIKit.create("TextButton", { Name = "Modal", Modal = true, BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(0, 0) }).Parent = panel

	-- Deska z pizzą
	local board = UIKit.create("Frame", {
		Name = "Board",
		Size = UDim2.fromOffset(250, 250),
		Position = UDim2.fromOffset(25, 25),
		BackgroundColor3 = Color3.fromRGB(190, 140, 90),
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UIKit.border(Color3.fromRGB(120, 80, 45), 4) })
	refs.dough = circle("Dough", 0.36, DOUGH, 3)
	refs.dough.Parent = board
	refs.sauce = circle("Sauce", 0.82, Color3.fromRGB(205, 45, 35), 4)
	refs.sauce.Parent = board
	refs.cheese = circle("Cheese", 0.74, Color3.fromRGB(255, 225, 120), 5)
	refs.cheese.BackgroundTransparency = 0.1
	refs.cheese.Parent = board
	refs.toppingLayer = UIKit.create("Frame", { Name = "Toppings", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6 })
	refs.toppingLayer.Parent = board
	board.Parent = panel

	-- Prawa strona: zamówienie, krok, uwaga, przyciski
	refs.orderName = UIKit.label("OrderName", { Text = "", Size = UDim2.fromOffset(150, 30), Position = UDim2.fromOffset(300, 16), TextSize = 22, TextColor3 = COLORS.title, TextXAlignment = Enum.TextXAlignment.Left })
	refs.orderName.Parent = panel
	refs.orderList = UIKit.label("OrderList", { Text = "", Size = UDim2.fromOffset(170, 80), Position = UDim2.fromOffset(300, 48), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	refs.orderList.Parent = panel
	refs.step = UIKit.label("Step", { Text = "", Size = UDim2.fromOffset(160, 70), Position = UDim2.fromOffset(465, 16), TextSize = 19, TextYAlignment = Enum.TextYAlignment.Top })
	refs.step.Parent = panel
	refs.note = UIKit.label("Note", { Text = "", Size = UDim2.fromOffset(320, 26), Position = UDim2.fromOffset(300, 128), TextSize = 18 })
	refs.note.Parent = panel

	local area = UDim2.fromOffset(300, 162)
	refs.buttons = {}
	local function bigButton(name: string, text: string, color: Color3, value: string)
		local button = UIKit.button(name, text, color, { Size = UDim2.fromOffset(320, 64), Position = area, TextSize = 26, Visible = false })
		button.Activated:Connect(function()
			send(value)
		end)
		button.Parent = panel
		refs.buttons[name] = button
	end
	bigButton("roll", "👐 Wałkuj (0/5)", COLORS.option, "roll")
	bigButton("sauce", "🍅 Sos", Color3.fromRGB(205, 60, 50), "sauce")
	bigButton("cheese", "🧀 Ser", Color3.fromRGB(230, 170, 40), "cheese")
	bigButton("oven", "🔥 Do pieca", COLORS.warn, "oven")
	bigButton("take", "✋ Wyjmij!", COLORS.button, "take")
	bigButton("pack", "📦 Zapakuj", Color3.fromRGB(190, 130, 70), "pack")
	refs.buttons.take.Position = UDim2.fromOffset(300, 200)
	refs.buttons.take.Size = UDim2.fromOffset(320, 56)

	-- Siatka składników
	local grid = UIKit.create("Frame", { Name = "ToppingGrid", Size = UDim2.fromOffset(320, 120), Position = area, BackgroundTransparency = 1, Visible = false }, {
		UIKit.create("UIGridLayout", { CellSize = UDim2.fromOffset(100, 54), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.toppingButtons = {}
	for index = 1, 6 do
		local button = UIKit.button("Topping" .. index, "", COLORS.option, { LayoutOrder = index, TextSize = 16 })
		button.Activated:Connect(function()
			local id = button:GetAttribute("Topping")
			if type(id) == "string" then
				send("t:" .. id)
			end
		end)
		button.Parent = grid
		refs.toppingButtons[index] = button
	end
	grid.Parent = panel
	refs.toppingGrid = grid

	-- Pasek pieca z zielonym polem
	local bar = UIKit.create("Frame", { Name = "OvenBar", Size = UDim2.fromOffset(320, 26), Position = UDim2.fromOffset(300, 164), BackgroundColor3 = Color3.fromRGB(40, 30, 60), Visible = false, ClipsDescendants = true }, { UIKit.corner(10), UIKit.border(COLORS.stroke, 2) })
	refs.ovenZone = UIKit.create("Frame", { Name = "Zone", BackgroundColor3 = COLORS.good, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 2 })
	refs.ovenZone.Parent = bar
	refs.ovenFill = UIKit.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = COLORS.warn, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 3 })
	refs.ovenFill.Parent = bar
	bar.Parent = panel
	refs.ovenBar = bar

	panel.Parent = gui
	RunService.RenderStepped:Connect(tickOven)
end

return PizzaMakerController

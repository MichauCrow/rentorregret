-- Okno "Mój dom": dobudowa pięter (minigra budowy; bez limitu, każde kolejne droższe) i malowanie wszystkich
-- ścian w domu (pokój, łazienka, każde piętro; kolor + wykończenie, cena = suma).
-- Otwierane z zakładki "🏠 Dom" w sklepie. Ceny i zakupy sprawdza serwer (HomeService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ApartmentConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ApartmentConfig"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local HomeController = {}

local COLORS = UIKit.COLORS
local PAINT = ApartmentConfig.Paint

local actions = nil
local refs = {}
local state = nil
local tab = "build"
local selection = { room = "main", c = 1, f = 1 }
local busy = false

local render

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function request(action: string, a: any, b: any, c: any)
	if busy then
		return nil
	end
	busy = true
	local result = actions.home(action, a, b, c)
	busy = false
	if type(result) ~= "table" then
		return nil
	end
	if type(result.state) == "table" then
		state = result.state
	end
	if result.message then
		refs.message.Text = tostring(result.message)
		refs.message.TextColor3 = if result.ok then COLORS.good else COLORS.bad
	end
	return result
end

local function selectRoom(roomId: string)
	selection.room = roomId
	local current = state and state.paint and state.paint[roomId]
	if type(current) == "table" then
		selection.c = tonumber(current.c) or 1
		selection.f = tonumber(current.f) or 1
	end
	render()
end

-- Rozbudowa ----------------------------------------------------------------------------

local function roomCard(room, order: number)
	local frame = UIKit.create("Frame", { Name = "Room" .. room.index, LayoutOrder = order, BackgroundColor3 = COLORS.card }, {
		UIKit.corner(14),
		UIKit.border(UIKit.RAINBOW[room.index % #UIKit.RAINBOW + 1], 3),
	})
	UIKit.label("Emoji", { Text = room.emoji, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 8), TextSize = 50 }).Parent = frame
	UIKit.label("Name", { Text = room.name, Size = UDim2.new(1, -12, 0, 28), Position = UDim2.fromOffset(6, 70), TextSize = 21, TextColor3 = COLORS.title }).Parent = frame
	UIKit.label("Comfort", { Text = string.format("+%d komfortu", room.comfort), Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 100), TextSize = 17 }).Parent = frame
	UIKit.label("Spots", { Text = string.format("+%d miejsc na meble", room.spots), Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 122), TextSize = 17, TextColor3 = COLORS.accent }).Parent = frame
	local text, color, enabled
	if room.built then
		text, color, enabled = "✔ GOTOWE", COLORS.good, false
	elseif not room.unlocked then
		text, color, enabled = "🔒 Miesiąc " .. room.month, COLORS.locked, false
	elseif not room.next then
		text, color, enabled = string.format("Potem: %d 💰", room.price), COLORS.locked, false
	else
		text = string.format("🏗️ BUDUJ · %d 💰", room.price)
		color = if (state.coins or 0) >= room.price then COLORS.button else COLORS.option
		enabled = true
	end
	local button = UIKit.button("Build", text, color, { Size = UDim2.new(1, -20, 0, 44), Position = UDim2.new(0, 10, 1, -10), AnchorPoint = Vector2.new(0, 1), TextSize = 19, AutoButtonColor = enabled })
	if enabled then
		button.Activated:Connect(function()
			local result = request("build", room.index)
			if result and result.ok then
				refs.panel.Visible = false
			else
				render()
			end
		end)
	end
	button.Parent = frame
	return frame
end

local function renderBuild()
	refs.info.Text = string.format("Masz: %d 💰   Pięter w domu: %d 🏠", tonumber(state.coins) or 0, tonumber(state.roomCount) or 0)
	refs.hint.Text = "Każde nowe piętro daje komfort i miejsca na meble. Kolejne piętra są coraz droższe!"
	for order, room in state.rooms do
		roomCard(room, order).Parent = refs.buildList
	end
end

-- Malowanie ----------------------------------------------------------------------------

local function renderPaint()
	local color = PAINT.Colors[selection.c]
	local finish = PAINT.Finishes[selection.f]
	refs.info.Text = string.format("Masz: %d 💰   Wybierz pokój, kolor i wykończenie ściany.", tonumber(state.coins) or 0)
	refs.hint.Text = ""
	for index, room in ApartmentConfig.PaintRooms(tonumber(state.roomCount) or 0) do
		local button = UIKit.button("Room" .. room.id, room.name, if selection.room == room.id then COLORS.warn else COLORS.locked, { LayoutOrder = index, Size = UDim2.fromOffset(120, 34), TextSize = 16 })
		button.Activated:Connect(function()
			selectRoom(room.id)
		end)
		button.Parent = refs.roomRow
	end
	for index, entry in PAINT.Colors do
		local swatch = UIKit.create("TextButton", {
			Name = "Color" .. index,
			LayoutOrder = index,
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = entry.color,
		}, { UIKit.corner(10), UIKit.border(if index == selection.c then COLORS.title else COLORS.stroke, if index == selection.c then 4 else 1) })
		local price = UIKit.label("Price", { Text = tostring(entry.price), Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -18), TextSize = 13 })
		price:SetAttribute("NoTranslate", true)
		price.Parent = swatch
		UIKit.squish(swatch)
		swatch.Activated:Connect(function()
			selection.c = index
			render()
		end)
		swatch.Parent = refs.colorGrid
	end
	for index, entry in PAINT.Finishes do
		local label = entry.name .. (if entry.price > 0 then " +" .. entry.price else "")
		local button = UIKit.button("Finish" .. index, label, if index == selection.f then COLORS.warn else COLORS.option, { LayoutOrder = index, Size = UDim2.fromOffset(146, 34), TextSize = 15 })
		button.Activated:Connect(function()
			selection.f = index
			render()
		end)
		button.Parent = refs.finishGrid
	end
	local total = color.price + finish.price
	local current = state.paint and state.paint[selection.room]
	local same = type(current) == "table" and current.c == selection.c and current.f == selection.f
	refs.summary.Text = string.format("%s · %s = %d 💰", color.name, finish.name, total)
	refs.paintButton.Text = if same then "✔ TAK JEST" else "🎨 MALUJ"
	refs.paintButton.BackgroundColor3 = if same then COLORS.locked elseif (state.coins or 0) >= total then COLORS.button else COLORS.option
	refs.cosmeticNote.Visible = state.cosmeticWalls == true and selection.room == "main"
end

render = function()
	if not state then
		return
	end
	for id, button in refs.tabs do
		button.BackgroundColor3 = if id == tab then COLORS.option else COLORS.locked
	end
	refs.buildPage.Visible = tab == "build"
	refs.paintPage.Visible = tab == "paint"
	clear(refs.buildList)
	clear(refs.roomRow)
	clear(refs.colorGrid)
	clear(refs.finishGrid)
	if tab == "build" then
		renderBuild()
	else
		renderPaint()
	end
end

function HomeController.Open()
	local result = actions.home("get")
	if type(result) ~= "table" or type(result.state) ~= "table" then
		return
	end
	state = result.state
	if state.building then
		actions.toast("Budowa już trwa!", "warn")
		return
	end
	refs.message.Text = ""
	selectRoom(selection.room)
	UIKit.popIn(refs.panel)
end

function HomeController.Init(callbacks)
	actions = callbacks
	local gui = UIKit.screenGui("HomeUI", 6)
	local panel = UIKit.panel("Home", UDim2.fromOffset(820, 500), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	refs.panel = panel
	UIKit.label("Title", { Text = "🏠 MÓJ DOM", Size = UDim2.new(1, -80, 0, 36), Position = UDim2.fromOffset(20, 12), TextSize = 30, TextColor3 = COLORS.title, TextXAlignment = Enum.TextXAlignment.Left }).Parent = panel
	UIKit.closeButton(panel, function()
		panel.Visible = false
	end)
	refs.tabs = {}
	for index, entry in { { id = "build", name = "🏗️ Rozbudowa" }, { id = "paint", name = "🎨 Malowanie" } } do
		local button = UIKit.button("Tab" .. entry.id, entry.name, COLORS.locked, { Size = UDim2.fromOffset(170, 38), Position = UDim2.fromOffset(20 + (index - 1) * 180, 56) })
		button.Activated:Connect(function()
			tab = entry.id
			render()
		end)
		button.Parent = panel
		refs.tabs[entry.id] = button
	end
	refs.info = UIKit.label("Info", { Text = "", Size = UDim2.new(1, -40, 0, 24), Position = UDim2.fromOffset(20, 100), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left })
	refs.info.Parent = panel
	refs.hint = UIKit.label("Hint", { Text = "", Size = UDim2.new(1, -40, 0, 20), Position = UDim2.fromOffset(20, 124), TextSize = 15, TextColor3 = COLORS.accent, TextXAlignment = Enum.TextXAlignment.Left })
	refs.hint.Parent = panel

	-- Rozbudowa
	refs.buildPage = UIKit.create("Frame", { Name = "BuildPage", Size = UDim2.new(1, -40, 0, 250), Position = UDim2.fromOffset(20, 152), BackgroundTransparency = 1 })
	refs.buildList = UIKit.create("Frame", { Name = "List", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		UIKit.create("UIGridLayout", { CellSize = UDim2.fromOffset(240, 240), CellPadding = UDim2.fromOffset(20, 0), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.buildList.Parent = refs.buildPage
	refs.buildPage.Parent = panel

	-- Malowanie: pokoje w przewijanym rzędzie (pięter może być dużo)
	local paintPage = UIKit.create("Frame", { Name = "PaintPage", Size = UDim2.new(1, -40, 0, 320), Position = UDim2.fromOffset(20, 130), BackgroundTransparency = 1, Visible = false })
	refs.roomRow = UIKit.create("ScrollingFrame", {
		Name = "Rooms",
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
	}, {
		UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.roomRow.Parent = paintPage
	refs.colorGrid = UIKit.create("Frame", { Name = "Colors", Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 52), BackgroundTransparency = 1 }, {
		UIKit.create("UIGridLayout", { CellSize = UDim2.fromOffset(98, 52), CellPadding = UDim2.fromOffset(10, 9), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.colorGrid.Parent = paintPage
	refs.finishGrid = UIKit.create("Frame", { Name = "Finishes", Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 180), BackgroundTransparency = 1 }, {
		UIKit.create("UIGridLayout", { CellSize = UDim2.fromOffset(180, 34), CellPadding = UDim2.fromOffset(12, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.finishGrid.Parent = paintPage
	refs.summary = UIKit.label("Summary", { Text = "", Size = UDim2.new(1, -220, 0, 30), Position = UDim2.fromOffset(0, 272), TextSize = 20, TextColor3 = COLORS.title, TextXAlignment = Enum.TextXAlignment.Left })
	refs.summary.Parent = paintPage
	refs.paintButton = UIKit.button("Paint", "🎨 MALUJ", COLORS.button, { Size = UDim2.fromOffset(200, 46), Position = UDim2.new(1, 0, 0, 266), AnchorPoint = Vector2.new(1, 0), TextSize = 22 })
	refs.paintButton.Activated:Connect(function()
		local result = request("paint", selection.room, selection.c, selection.f)
		if result and result.ok then
			UIKit.confetti(gui, 60)
			SoundController.Play("Success")
		end
		render()
	end)
	refs.paintButton.Parent = paintPage
	refs.cosmeticNote = UIKit.label("CosmeticNote", { Text = "Masz założony kolor ścian ze Stylu. Zdejmij go, żeby zobaczyć farbę.", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 302), TextSize = 14, TextColor3 = COLORS.warn, Visible = false })
	refs.cosmeticNote.Parent = paintPage
	refs.paintPage = paintPage
	paintPage.Parent = panel

	refs.message = UIKit.label("Message", { Text = "", Size = UDim2.new(1, -40, 0, 26), Position = UDim2.new(0, 20, 1, -36), TextSize = 18 })
	refs.message.Parent = panel
	panel.Parent = gui
end

return HomeController

-- Okno sklepu "Mebelkowo" (zakładki Meble / Sprzęt / Styl) oraz krótsze przytrzymanie w podpowiedziach
-- sprzątania dla kupionego sprzętu. Ceny i zakupy liczy serwer; klient tylko pokazuje katalog.
-- Styl = kosmetyki za Klucze Lokatora albo Robux (tylko wygląd).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Modules"):WaitForChild("Format"))
local ApartmentConfig = require(Shared:WaitForChild("Config"):WaitForChild("ApartmentConfig"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local ShopController = {}

local COLORS = UIKit.COLORS
local refs = {}
local actions = {}
local catalog = nil
local currentTab = "furniture"
local busy = false
local holdMultipliers = {}

local render

local function onBuy(itemId: string)
	if busy then
		return
	end
	busy = true
	local result = actions.buy(itemId)
	busy = false
	if type(result) ~= "table" then
		return
	end
	if type(result.catalog) == "table" then
		catalog = result.catalog
	end
	refs.message.Text = tostring(result.message or "")
	refs.message.TextColor3 = if result.ok then COLORS.good else COLORS.bad
	render()
end

local function onCosmetic(action: string, itemId: string)
	if busy then
		return
	end
	busy = true
	local result = actions.cosmetic(action, itemId)
	busy = false
	if type(result) ~= "table" then
		return
	end
	if type(result.cosmetics) == "table" then
		catalog.cosmetics = result.cosmetics
	end
	refs.message.Text = tostring(result.message or "")
	refs.message.TextColor3 = if result.ok then COLORS.good else COLORS.bad
	render()
end

local function cosmeticCard(item)
	local frame = UIKit.create("Frame", { Name = item.id, BackgroundColor3 = COLORS.card }, { UIKit.corner(14) })
	UIKit.label("Emoji", { Text = tostring(item.emoji), Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 6), TextSize = 44 }).Parent = frame
	UIKit.label("Name", { Text = tostring(item.name), Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 60), TextSize = 18, TextColor3 = COLORS.title }).Parent = frame
	UIKit.label("Kind", { Text = tostring(item.kindName or ""), Size = UDim2.new(1, -12, 0, 36), Position = UDim2.fromOffset(6, 86), TextSize = 15 }).Parent = frame

	local text, color, onPress
	if item.equipped then
		text, color = "✔ ZDEJMIJ", COLORS.good
		onPress = function()
			onCosmetic("unequip", item.id)
		end
	elseif item.owned then
		text, color = "ZAŁÓŻ", COLORS.option
		onPress = function()
			onCosmetic("equip", item.id)
		end
	elseif item.tokens then
		text = "KUP · 🔑 " .. tostring(item.tokens)
		color = if (catalog.cosmetics.tokens or 0) >= item.tokens then COLORS.button else COLORS.locked
		onPress = function()
			onCosmetic("buy", item.id)
		end
	elseif item.passId then
		text = "KUP · R$ " .. tostring(item.robuxPrice or "?")
		color = Color3.fromRGB(255, 170, 30)
		onPress = function()
			actions.promptPass(item.passId)
		end
	elseif item.productId then
		text = "KUP · R$ " .. tostring(item.robuxPrice or "?")
		color = COLORS.button
		onPress = function()
			actions.promptProduct(item.productId)
		end
	else
		text, color = "Wkrótce", COLORS.locked
	end
	local button = UIKit.button("Action", text, color, {
		Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.new(0, 8, 1, -8),
		AnchorPoint = Vector2.new(0, 1),
		TextSize = 18,
		AutoButtonColor = onPress ~= nil,
	})
	if onPress then
		button.Activated:Connect(onPress)
	end
	button.Parent = frame
	return frame
end

local function card(item)
	local frame = UIKit.create("Frame", { Name = item.id, BackgroundColor3 = COLORS.card }, { UIKit.corner(14) })
	UIKit.label("Emoji", { Text = tostring(item.emoji), Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 6), TextSize = 44 }).Parent = frame
	UIKit.label("Name", { Text = tostring(item.name), Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 60), TextSize = 18, TextColor3 = COLORS.title }).Parent = frame
	local description = tostring(item.description or "")
	if (tonumber(item.ownedCount) or 0) > 0 then
		description ..= "  (masz: " .. item.ownedCount .. ")"
	end
	UIKit.label("Description", { Text = description, Size = UDim2.new(1, -12, 0, 36), Position = UDim2.fromOffset(6, 86), TextSize = 15 }).Parent = frame

	local text, color, enabled
	local freeSpots = catalog.freeSpots or {}
	if not item.unlocked then
		text, color, enabled = "🔒 Miesiąc " .. tostring(item.unlockMonth), COLORS.locked, false
	elseif item.owned then
		text, color, enabled = "✔ MASZ", COLORS.locked, false
	elseif item.category == "furniture" and (tonumber(freeSpots[item.spot]) or 0) <= 0 then
		text, color, enabled = "Brak miejsca", COLORS.locked, false
	else
		text = "KUP · " .. Format.Number(tonumber(item.price) or 0)
		if (tonumber(item.price) or 0) < (tonumber(item.basePrice) or 0) then
			text ..= " 🏷"
		end
		color = if (catalog.coins or 0) >= (tonumber(item.price) or 0) then COLORS.button else COLORS.option
		enabled = true
	end
	local buyButton = UIKit.button("Buy", text, color, {
		Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.new(0, 8, 1, -8),
		AnchorPoint = Vector2.new(0, 1),
		TextSize = 18,
		AutoButtonColor = enabled,
	})
	if enabled then
		buyButton.Activated:Connect(function()
			onBuy(item.id)
		end)
	end
	buyButton.Parent = frame
	return frame
end

render = function()
	if not catalog then
		return
	end
	for _, child in refs.grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if currentTab == "style" then
		local cosmetics = catalog.cosmetics or { items = {} }
		for order, item in cosmetics.items or {} do
			local frame = cosmeticCard(item)
			frame.LayoutOrder = order
			frame.Parent = refs.grid
		end
		refs.info.Text = "Masz: 🔑 " .. Format.Number(tonumber(cosmetics.tokens) or 0) .. " kluczy. Kosmetyki zmieniają tylko wygląd."
		for tabId, tabButton in refs.tabs do
			tabButton.BackgroundColor3 = if tabId == currentTab then COLORS.option else COLORS.locked
		end
		return
	end
	for order, item in catalog.items or {} do
		if item.category == currentTab then
			local frame = card(item)
			frame.LayoutOrder = order
			frame.Parent = refs.grid
		end
	end
	local info = "Masz: " .. Format.Number(tonumber(catalog.coins) or 0) .. " monet"
	if currentTab == "furniture" then
		local free = catalog.freeSpots or {}
		info ..= string.format("   Wolne miejsca na meble: %d 🪑", tonumber(free.floor) or 0)
	end
	if (tonumber(catalog.discount) or 0) > 0 then
		info ..= "   🏷 WYPRZEDAŻ -" .. math.floor(catalog.discount * 100 + 0.5) .. "%!"
	end
	refs.info.Text = info
	for tabId, tabButton in refs.tabs do
		tabButton.BackgroundColor3 = if tabId == currentTab then COLORS.option else COLORS.locked
	end
end

function ShopController.Open()
	local fresh = actions.getShop()
	if type(fresh) ~= "table" then
		return
	end
	catalog = fresh
	refs.message.Text = ""
	render()
	UIKit.popIn(refs.panel)
end

function ShopController.Toggle()
	if refs.panel.Visible then
		refs.panel.Visible = false
	else
		ShopController.Open()
	end
end

-- Krótsze przytrzymanie przy sprzątaniu (serwer sprawdza ten sam czas)
local function applyPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") or prompt.Name ~= "CleanPrompt" or not prompt.Parent then
		return
	end
	local kind = prompt.Parent:GetAttribute("DirtKind")
	local definition = ApartmentConfig.Dirt[kind]
	if definition then
		prompt.HoldDuration = definition.holdTime * (tonumber(holdMultipliers[kind]) or 1)
	end
end

function ShopController.ApplyState(snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end
	holdMultipliers = if type(snapshot.holdMultipliers) == "table" then snapshot.holdMultipliers else {}
	local apartments = Workspace:FindFirstChild("Apartments")
	if apartments then
		for _, descendant in apartments:GetDescendants() do
			applyPrompt(descendant)
		end
	end
end

-- newActions: getShop() -> katalog, buy(itemId) -> { ok, message, catalog },
-- cosmetic(akcja, id) -> { ok, message, cosmetics }, promptProduct(productId), promptPass(passId)
function ShopController.Init(newActions)
	actions = newActions
	-- Po zakupie za Robux serwer przyznaje przedmiot; odświeżamy widok po chwili
	local function refreshAfterPurchase()
		if refs.panel.Visible then
			task.wait(1.5)
			local fresh = actions.getShop()
			if type(fresh) == "table" then
				catalog = fresh
				render()
			end
		end
	end
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _productId, purchased)
		if purchased and userId == Players.LocalPlayer.UserId then
			refreshAfterPurchase()
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _passId, purchased)
		if purchased and player == Players.LocalPlayer then
			refreshAfterPurchase()
		end
	end)
	local gui = UIKit.screenGui("ShopUI", 6)
	local panel = UIKit.panel("Shop", UDim2.fromOffset(660, 480), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	refs.panel = panel
	UIKit.label("Title", {
		Text = "🛒 MEBELKOWO",
		Size = UDim2.new(1, -80, 0, 36),
		Position = UDim2.fromOffset(20, 12),
		TextSize = 30,
		TextColor3 = COLORS.title,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel
	UIKit.closeButton(panel, function()
		panel.Visible = false
	end)

	refs.tabs = {}
	for index, tab in { { id = "furniture", name = "🛋️ Meble" }, { id = "equipment", name = "🧹 Sprzęt" }, { id = "style", name = "✨ Styl" }, { id = "home", name = "🏠 Dom" } } do
		local tabButton = UIKit.button("Tab" .. tab.id, tab.name, COLORS.locked, {
			Size = UDim2.fromOffset(150, 38),
			Position = UDim2.fromOffset(20 + (index - 1) * 160, 56),
		})
		tabButton.Activated:Connect(function()
			-- "Dom" to osobne okno (rozbudowa i malowanie)
			if tab.id == "home" then
				panel.Visible = false
				if actions.openHome then
					actions.openHome()
				end
				return
			end
			currentTab = tab.id
			render()
		end)
		tabButton.Parent = panel
		refs.tabs[tab.id] = tabButton
	end

	refs.info = UIKit.label("Info", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 24),
		Position = UDim2.fromOffset(20, 100),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.info.Parent = panel

	refs.grid = UIKit.create("ScrollingFrame", {
		Name = "Grid",
		Size = UDim2.new(1, -32, 1, -176),
		Position = UDim2.fromOffset(16, 130),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, {
		UIKit.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(196, 172),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	refs.grid.Parent = panel

	refs.message = UIKit.label("Message", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 26),
		Position = UDim2.new(0, 20, 1, -38),
		TextSize = 18,
	})
	refs.message.Parent = panel
	panel.Parent = gui

	task.spawn(function()
		local apartments = Workspace:WaitForChild("Apartments")
		apartments.DescendantAdded:Connect(applyPrompt)
	end)
end

return ShopController

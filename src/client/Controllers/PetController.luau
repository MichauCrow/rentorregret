-- Zoo sklep (okno zakupu), menu poleceń zwierzaka (podpowiedź "Polecenia" widzi tylko właściciel)
-- i minigra rzutu piłką przy aporcie. O wszystkim decyduje serwer (PetService).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PetConfig"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local PetController = {}

local COLORS = UIKit.COLORS
local MENU_CLOSE_DISTANCE = 16
local AIM_PERIOD = 1.6 -- sekundy na pełny ruch paska tam i z powrotem
local GOOD_POWER = 0.8

local player = Players.LocalPlayer
local actions = nil
local refs = {}
local menuPet: Model? = nil
local aim = nil -- { petId, started }

local function petRoot(model: Model): BasePart?
	return model.PrimaryPart
end

local function filterPrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") and prompt.Name == "PetPrompt" then
		prompt.Enabled = prompt:GetAttribute("OwnerUserId") == player.UserId
	end
end

-- Sklep -------------------------------------------------------------------------

local renderShop

local function buy(speciesId: string)
	local result = actions.buyPet(speciesId)
	if not result then
		return
	end
	if result.ok then
		UIKit.confetti(refs.gui, 70)
		SoundController.Play("Success")
	else
		actions.toast(result.message, "warn")
	end
	if result.catalog then
		renderShop(result.catalog)
	end
end

renderShop = function(catalog)
	refs.coins.Text = "💰 " .. tostring(catalog.coins)
	for _, child in refs.grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, entry in catalog.species do
		local card = UIKit.create("Frame", {
			Name = entry.id,
			LayoutOrder = index,
			BackgroundColor3 = COLORS.card,
		}, { UIKit.corner(14), UIKit.border(UIKit.RAINBOW[(index - 1) % #UIKit.RAINBOW + 1], 3) })
		UIKit.label("Emoji", { Text = entry.emoji, Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 6), TextSize = 58 }).Parent = card
		UIKit.label("Name", { Text = entry.name, Size = UDim2.new(1, -10, 0, 44), Position = UDim2.fromOffset(5, 76), TextSize = 19 }).Parent = card
		UIKit.label("Price", { Text = "💰 " .. entry.price, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 120), TextSize = 20, TextColor3 = COLORS.title }).Parent = card
		UIKit.label("Owned", { Text = string.format("Masz: %d/%d", entry.owned, entry.max), Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 146), TextSize = 15, TextColor3 = COLORS.accent }).Parent = card
		local full = entry.owned >= entry.max
		local poor = catalog.coins < entry.price
		local text = if full then "Masz max" elseif poor then "Za mało" else "Kup"
		local color = if full or poor then COLORS.locked else COLORS.button
		local button = UIKit.button("Buy", text, color, {
			Size = UDim2.new(1, -20, 0, 42),
			Position = UDim2.new(0, 10, 1, -52),
			TextSize = 20,
		})
		button.Activated:Connect(function()
			if not full and not poor then
				buy(entry.id)
			elseif poor then
				actions.toast("Za mało monet.", "warn")
			end
		end)
		button.Parent = card
		card.Parent = refs.grid
	end
end

local function openShop()
	local catalog = actions.getPets()
	if not catalog then
		return
	end
	renderShop(catalog)
	UIKit.popIn(refs.shop)
end

-- Menu poleceń --------------------------------------------------------------------

local function closeMenu()
	menuPet = nil
	refs.menu.Visible = false
end

local function closeAim()
	if aim then
		aim = nil
		ProximityPromptService.Enabled = true
	end
	refs.aim.Visible = false
end

local function startAim(model: Model)
	aim = { petId = model:GetAttribute("PetId"), started = os.clock() }
	ProximityPromptService.Enabled = false
	refs.aimResult.Text = ""
	UIKit.popIn(refs.aim)
end

local function throw()
	if not aim then
		return
	end
	local t = (os.clock() - aim.started) / AIM_PERIOD * 2
	local power = 1 - math.abs(t % 2 - 1)
	actions.petAction(aim.petId, "fetch", power)
	if power >= GOOD_POWER then
		actions.toast("🎾 Super rzut!", "good")
	else
		actions.toast("🎾 Rzut!", "info")
	end
	SoundController.Play("UIClick", 1.2)
	closeAim()
end

local function openMenu(model: Model)
	local config = PetConfig.Species[model:GetAttribute("Species")]
	if not config then
		return
	end
	closeAim()
	menuPet = model
	refs.menuTitle.Text = config.emoji .. " " .. tostring(model:GetAttribute("PetName"))
	for _, child in refs.menuButtons:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, command in config.commands do
		local definition = PetConfig.Commands[command]
		local label = definition.label
		if command == "stay" and model:GetAttribute("Home") then
			label = definition.alt
		end
		local button = UIKit.button(command, label, if command == "stay" then COLORS.warn else COLORS.option, {
			LayoutOrder = index,
			Size = UDim2.fromOffset(150, 54),
			TextSize = 18,
		})
		button.Activated:Connect(function()
			if command == "fetch" then
				closeMenu()
				startAim(model)
				return
			end
			actions.petAction(model:GetAttribute("PetId"), command)
			if command == "stay" then
				closeMenu()
			end
		end)
		button.Parent = refs.menuButtons
	end
	refs.menu.Size = UDim2.fromOffset(math.max(340, #config.commands * 160 + 30), 140)
	UIKit.popIn(refs.menu)
end

-- Budowa okien ---------------------------------------------------------------------

local function build()
	local gui = UIKit.screenGui("PetGui", 14)
	refs.gui = gui

	-- Sklep
	local shop = UIKit.panel("PetShop", UDim2.fromOffset(960, 420), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UIKit.label("Title", { Text = "🐾 Zoo sklep", Size = UDim2.new(1, -120, 0, 44), Position = UDim2.fromOffset(20, 12), TextSize = 32, TextColor3 = COLORS.title, TextXAlignment = Enum.TextXAlignment.Left }).Parent = shop
	refs.coins = UIKit.label("Coins", { Text = "", Size = UDim2.fromOffset(200, 36), Position = UDim2.new(1, -70, 0, 16), AnchorPoint = Vector2.new(1, 0), TextSize = 24, TextXAlignment = Enum.TextXAlignment.Right })
	refs.coins.Parent = shop
	UIKit.label("Hint", { Text = "Psy i koty możesz mieć po 2, resztę po 1. Kliknij zwierzaka, żeby dać mu polecenie!", Size = UDim2.new(1, -40, 0, 26), Position = UDim2.fromOffset(20, 56), TextSize = 17, TextColor3 = COLORS.accent }).Parent = shop
	local grid = UIKit.create("Frame", { Name = "Grid", Size = UDim2.new(1, -40, 0, 300), Position = UDim2.fromOffset(20, 96), BackgroundTransparency = 1 })
	UIKit.create("UIGridLayout", {
		CellSize = UDim2.fromOffset(170, 290),
		CellPadding = UDim2.fromOffset(12, 0),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = grid
	refs.grid = grid
	grid.Parent = shop
	UIKit.closeButton(shop, function()
		shop.Visible = false
	end)
	refs.shop = shop
	shop.Parent = gui

	-- Menu poleceń (na dole ekranu, nie zasłania postaci)
	local menu = UIKit.panel("PetMenu", UDim2.fromOffset(500, 140), UDim2.new(0.5, 0, 1, -150), Vector2.new(0.5, 1))
	refs.menuTitle = UIKit.label("Title", { Text = "", Size = UDim2.new(1, -80, 0, 36), Position = UDim2.fromOffset(16, 8), TextSize = 26, TextColor3 = COLORS.title, TextXAlignment = Enum.TextXAlignment.Left })
	refs.menuTitle.Parent = menu
	local buttons = UIKit.create("Frame", { Name = "Buttons", Size = UDim2.new(1, -20, 0, 60), Position = UDim2.fromOffset(10, 64), BackgroundTransparency = 1 })
	UIKit.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = buttons
	refs.menuButtons = buttons
	buttons.Parent = menu
	UIKit.closeButton(menu, closeMenu)
	refs.menu = menu
	menu.Parent = gui

	-- Minigra aportu: pasek siły jeździ tam i z powrotem, rzut w stronę, w którą patrzy postać
	local aimPanel = UIKit.panel("FetchAim", UDim2.fromOffset(460, 250), UDim2.new(0.5, 0, 1, -150), Vector2.new(0.5, 1))
	UIKit.label("Title", { Text = "🎾 Aport!", Size = UDim2.new(1, -80, 0, 38), Position = UDim2.fromOffset(16, 8), TextSize = 30, TextColor3 = COLORS.title, TextXAlignment = Enum.TextXAlignment.Left }).Parent = aimPanel
	UIKit.label("Hint", { Text = "Obróć się tam, gdzie chcesz rzucić. Rzuć, gdy pasek jest w zielonym polu!", Size = UDim2.new(1, -32, 0, 44), Position = UDim2.fromOffset(16, 46), TextSize = 17, TextColor3 = COLORS.accent }).Parent = aimPanel
	local bar = UIKit.create("Frame", { Name = "Bar", Size = UDim2.new(1, -60, 0, 30), Position = UDim2.fromOffset(30, 100), BackgroundColor3 = COLORS.card, ClipsDescendants = true }, { UIKit.corner(15), UIKit.border(COLORS.stroke, 2) })
	UIKit.create("Frame", { Name = "Sweet", Size = UDim2.fromScale(1 - GOOD_POWER, 1), Position = UDim2.fromScale(GOOD_POWER, 0), BackgroundColor3 = Color3.fromRGB(70, 200, 90), BackgroundTransparency = 0.35, BorderSizePixel = 0 }).Parent = bar
	refs.aimFill = UIKit.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 210, 60), BackgroundTransparency = 0.15 }, { UIKit.corner(15) })
	refs.aimFill.Parent = bar
	bar.Parent = aimPanel
	refs.aimResult = UIKit.label("Result", { Text = "", Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 134), TextSize = 17 })
	refs.aimResult.Parent = aimPanel
	local throwButton = UIKit.button("Throw", "RZUĆ! 🎾", COLORS.button, {
		Size = UDim2.fromOffset(220, 58),
		Position = UDim2.new(0.5, 0, 1, -14),
		AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 28,
	})
	throwButton.Activated:Connect(throw)
	throwButton.Parent = aimPanel
	UIKit.closeButton(aimPanel, closeAim)
	refs.aim = aimPanel
	aimPanel.Parent = gui
end

function PetController.Init(callbacks)
	actions = callbacks
	build()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "PetShopPrompt" then
			openShop()
		elseif prompt.Name == "PetPrompt" and prompt:GetAttribute("OwnerUserId") == player.UserId then
			local model = prompt:FindFirstAncestorOfClass("Model")
			if model then
				openMenu(model)
			end
		end
	end)

	-- Podpowiedzi cudzych zwierzaków są ukryte
	task.spawn(function()
		local pets = Workspace:WaitForChild("Pets", 60)
		if not pets then
			return
		end
		for _, child in pets:GetDescendants() do
			filterPrompt(child)
		end
		pets.DescendantAdded:Connect(filterPrompt)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if aim and not processed and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonA) then
			throw()
		end
	end)

	RunService.Heartbeat:Connect(function()
		if aim then
			local t = (os.clock() - aim.started) / AIM_PERIOD * 2
			local power = 1 - math.abs(t % 2 - 1)
			refs.aimFill.Size = UDim2.fromScale(power, 1)
			refs.aimFill.BackgroundColor3 = if power >= GOOD_POWER then Color3.fromRGB(90, 230, 110) else Color3.fromRGB(255, 210, 60)
			if os.clock() - aim.started > 25 then
				closeAim()
			end
		end
		if menuPet then
			local root = petRoot(menuPet)
			local character = player.Character
			local me = character and character:FindFirstChild("HumanoidRootPart")
			if not menuPet.Parent or not root or not me or (root.Position - me.Position).Magnitude > MENU_CLOSE_DISTANCE then
				closeMenu()
			end
		end
	end)
end

return PetController

-- Sklepik w holu: karty ulepszeń (latarka, cichobiegi, kieszenie, kondycja) z poziomem i ceną.
-- Otwiera się przy budce (ProximityPrompt z atrybutem Action = "Shop") albo przyciskiem w HUD.
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Format"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ShopConfig"))
local ClientState = require(script.Parent.ClientState)
local HUDController = require(script.Parent.HUDController)
local UIKit = require(script.Parent.UIKit)

local ShopController = {}

local C = UIKit.COLORS
local panel = nil
local cards = {}
local coinsLabel = nil
local busy = false

local function render()
	local profile = ClientState.profile
	if not profile or not panel then
		return
	end
	coinsLabel.Text = "💰 " .. Format.Number(profile.coins)
	for id, card in cards do
		local upgrade = ShopConfig.Upgrades[id]
		local level = profile.upgrades[id] or 1
		local nextLevel = upgrade.levels[level + 1]
		card.level.Text = string.format("Poziom %d/%d", level, #upgrade.levels)
		if nextLevel then
			card.buy.Text = "KUP: " .. Format.Number(nextLevel.cost) .. " 💰"
			card.buy.BackgroundColor3 = if profile.coins >= nextLevel.cost then C.button else C.locked
		else
			card.buy.Text = "MAKS ⭐"
			card.buy.BackgroundColor3 = C.locked
		end
	end
end

local function buy(id: string)
	if busy then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return ClientState.Remote("BuyUpgrade"):InvokeServer(id)
	end)
	busy = false
	if not ok or type(result) ~= "table" then
		HUDController.Toast("Nie udało się kupić. Spróbuj jeszcze raz.", "warn")
		return
	end
	if type(result.state) == "table" then
		ClientState.SetProfile(result.state)
	end
	HUDController.Toast(result.message or "", if result.ok then "good" else "warn")
end

function ShopController.Open()
	if ClientState.InRound() or not panel then
		return
	end
	render()
	UIKit.popIn(panel)
end

function ShopController.Close()
	if panel then
		panel.Visible = false
	end
end

function ShopController.Init()
	local gui = UIKit.screenGui("Shop", 10)
	panel = UIKit.panel("Shop", UDim2.fromOffset(820, 470), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UIKit.closeButton(panel, ShopController.Close)
	local title = UIKit.label("Title", { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 10), Text = "🛒 SKLEPIK", TextSize = 38, TextColor3 = C.title })
	title.Parent = panel
	coinsLabel = UIKit.label("Coins", { Size = UDim2.fromOffset(220, 40), Position = UDim2.fromOffset(20, 16), Text = "💰 0", TextSize = 26, TextColor3 = C.title, TextXAlignment = Enum.TextXAlignment.Left })
	coinsLabel.Parent = panel

	local grid = UIKit.create("Frame", { Size = UDim2.new(1, -40, 1, -90), Position = UDim2.fromOffset(20, 76), BackgroundTransparency = 1 }, {
		UIKit.create("UIGridLayout", { CellSize = UDim2.fromOffset(180, 370), CellPadding = UDim2.fromOffset(12, 0), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	grid.Parent = panel
	for index, id in ShopConfig.Order do
		local upgrade = ShopConfig.Upgrades[id]
		local card = UIKit.create("Frame", { Name = id, BackgroundColor3 = C.card, LayoutOrder = index }, { UIKit.corner(14), UIKit.border(C.stroke, 2) })
		UIKit.label("Icon", { Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 10), Text = upgrade.icon, TextSize = 64 }).Parent = card
		UIKit.label("Name", { Size = UDim2.new(1, -10, 0, 34), Position = UDim2.fromOffset(5, 92), Text = upgrade.name, TextSize = 24, TextColor3 = C.title }).Parent = card
		UIKit.label("Description", { Size = UDim2.new(1, -16, 0, 110), Position = UDim2.fromOffset(8, 130), Text = upgrade.description, TextSize = 17, TextYAlignment = Enum.TextYAlignment.Top }).Parent = card
		local level = UIKit.label("Level", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 250), Text = "Poziom 1", TextSize = 19, TextColor3 = C.accent })
		level.Parent = card
		local buyButton = UIKit.button("Buy", "KUP", C.button, { Size = UDim2.new(1, -20, 0, 50), Position = UDim2.new(0, 10, 1, -62), TextSize = 19 })
		buyButton.Activated:Connect(function()
			buy(id)
		end)
		buyButton.Parent = card
		card.Parent = grid
		cards[id] = { level = level, buy = buyButton }
	end
	panel.Parent = gui
end

function ShopController.Start()
	HUDController.SetShopOpener(ShopController.Open)
	ClientState.OnProfile(render)
	ClientState.OnRound(function(round)
		if round then
			ShopController.Close()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Action") == "Shop" then
			ShopController.Open()
		end
	end)
end

return ShopController

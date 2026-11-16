-- Panel z przyciskami testowymi. Tworzony tylko w Roblox Studio.
-- Serwer i tak sprawdza IsStudio(), więc panel nie daje niczego na żywym serwerze.
local Players = game:GetService("Players")

local DebugPanelController = {}

local BUTTONS = {
	{ text = "+80 XP", command = "addXp", arg = 80 },
	{ text = "+600 XP", command = "addXp", arg = 600 },
	{ text = "Koło: +1 obrót", command = "wheelSpin" },
	{ text = "Złota godzina teraz", command = "goldenHour" },
	{ text = "Poziom od nowa", command = "resetLevel" },
	{ text = "Prezenty: +5 min", command = "giftTime", arg = 300 },
	{ text = "Prezenty i kody od nowa", command = "resetGifts" },
	{ text = "+50 monet", command = "addCoins", arg = 50 },
	{ text = "+500 monet", command = "addCoins", arg = 500 },
	{ text = "Wydaj 30", command = "spendCoins", arg = 30 },
	{ text = "+5 brudu", command = "spawnDirt", arg = 5 },
	{ text = "Do domu", command = "home" },
	{ text = "Czas +60 s", command = "skipTime", arg = 60 },
	{ text = "Koniec miesiąca", command = "skipTime", arg = 360 },
	{ text = "Odblokuj prace", command = "unlockLevels" },
	{ text = "Samouczek od nowa", command = "tutorial" },
	{ text = "Cut scena: miesiąc 2", command = "monthUnlock", arg = 2 },
	{ text = "Cut scena: miesiąc 4", command = "monthUnlock", arg = 4 },
	{ text = "Rzadkie zlecenie", command = "rareContract" },
	{ text = "Awaria", command = "breakFixture" },
	{ text = "Robaki i pleśń", command = "pests" },
	{ text = "Kontrola", command = "event", arg = 1 },
	{ text = "Wyprzedaż", command = "event", arg = 2 },
	{ text = "Awaria prądu", command = "event", arg = 3 },
	{ text = "Zalanie", command = "event", arg = 4 },
	{ text = "Szop", command = "event", arg = 5 },
	{ text = "Prośba sąsiada", command = "event", arg = 6 },
	{ text = "Nowy dzień", command = "newDay" },
	{ text = "+100 kluczy", command = "addTokens" },
	{ text = "Rankingi teraz", command = "leaderboard" },
	{ text = "Miesiąc 4 (Śródmieście)", command = "setMonth", arg = 4 },
	{ text = "Miesiąc 7 (Wzgórze)", command = "setMonth", arg = 7 },
	{ text = "Zapisz teraz", command = "save" },
	{ text = "Reset danych", command = "reset" },
}

function DebugPanelController.Init(remote: RemoteEvent)
	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10

	-- Przewijany panel, bo przycisków testowych jest dużo
	local frame = Instance.new("ScrollingFrame")
	frame.Name = "Panel"
	frame.Size = UDim2.fromOffset(170, math.min(34 + #BUTTONS * 38, 330))
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.ScrollBarThickness = 6
	frame.Position = UDim2.new(0, 12, 1, -12)
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.2
	frame.Parent = gui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 10)
	frameCorner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(255, 220, 90)
	title.Text = "DEBUG (Studio)"
	title.LayoutOrder = 0
	title.Parent = frame

	for index, definition in BUTTONS do
		local button = Instance.new("TextButton")
		button.Name = definition.command .. index
		button.Size = UDim2.new(1, 0, 0, 34)
		button.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 14
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Text = definition.text
		button.LayoutOrder = index
		button.Parent = frame

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button

		button.Activated:Connect(function()
			remote:FireServer(definition.command, definition.arg)
		end)
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return DebugPanelController

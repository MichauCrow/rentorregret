-- Panel "Zadania": nagroda dnia (kalendarz), zadania dnia, wyzwania tygodnia, wyzwanie serwera,
-- osiągnięcia i rankingi tygodniowe. Ukrywa też krasnale, które gracz już znalazł.
local Workspace = game:GetService("Workspace")

local UIKit = require(script.Parent:WaitForChild("UIKit"))

local ProgressController = {}

local COLORS = UIKit.COLORS
local refs = {}
local actions = {}
local currentTab = "today"
local progress = nil
local ranking = nil
local currentBoard = 1
local claiming = false

local TABS = {
	{ id = "today", name = "🎁 Dziś" },
	{ id = "week", name = "📅 Tydzień" },
	{ id = "achievements", name = "🏅 Osiągnięcia" },
	{ id = "ranking", name = "🏆 Ranking" },
}

local render

local function clearContent()
	for _, child in refs.content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function header(text: string, order: number)
	UIKit.label("Header", {
		Text = text,
		Size = UDim2.new(1, -10, 0, 26),
		TextSize = 20,
		TextColor3 = COLORS.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	}).Parent = refs.content
end

-- Wiersz zadania z paskiem postępu
local function taskRow(text: string, current: number, target: number, done: boolean, reward: string?, order: number)
	local row = UIKit.create("Frame", { Name = "Task", Size = UDim2.new(1, -10, 0, 58), BackgroundColor3 = COLORS.card, LayoutOrder = order }, { UIKit.corner(10) })
	UIKit.label("Text", {
		Text = (if done then "✅ " else "") .. text,
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 4),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if done then COLORS.good else COLORS.text,
	}).Parent = row
	local bar = UIKit.create("Frame", { Name = "Bar", Size = UDim2.new(0.55, 0, 0, 14), Position = UDim2.fromOffset(10, 34), BackgroundColor3 = Color3.fromRGB(20, 16, 40) }, { UIKit.corner(7) })
	UIKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(if target > 0 then math.clamp(current / target, 0, 1) else 0, 1),
		BackgroundColor3 = if done then COLORS.good else COLORS.warn,
	}, { UIKit.corner(7) }).Parent = bar
	bar.Parent = row
	UIKit.label("Count", {
		Text = string.format("%d/%d", current, target) .. (if reward then "   " .. reward else ""),
		Size = UDim2.new(0.45, -24, 0, 20),
		Position = UDim2.new(0.55, 18, 0, 31),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = row
	row.Parent = refs.content
end

local function renderToday()
	local calendar = progress.calendar
	header("Kalendarz Lokatora (przerwa niczego nie zeruje)", 1)
	local days = UIKit.create("Frame", { Name = "Days", Size = UDim2.new(1, -10, 0, 74), BackgroundTransparency = 1, LayoutOrder = 2 }, {
		UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for index, label in calendar.rewards do
		local isNext = index == calendar.next
		local cell = UIKit.create("Frame", {
			Name = "Day" .. index,
			Size = UDim2.fromOffset(80, 74),
			BackgroundColor3 = if isNext then (if calendar.canClaim then COLORS.button else COLORS.option) else COLORS.card,
			LayoutOrder = index,
		}, { UIKit.corner(10) })
		UIKit.label("Day", { Text = "Dzień " .. index, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 4), TextSize = 15, TextColor3 = COLORS.title }).Parent = cell
		UIKit.label("Reward", { Text = tostring(label), Size = UDim2.new(1, -6, 0, 44), Position = UDim2.fromOffset(3, 26), TextSize = 13 }).Parent = cell
		cell.Parent = days
	end
	days.Parent = refs.content

	local claim = UIKit.button("Claim", if calendar.canClaim then "🎁 ODBIERZ NAGRODĘ DNIA" else "Wróć jutro po kolejną nagrodę!", if calendar.canClaim then COLORS.button else COLORS.locked, {
		Size = UDim2.new(1, -10, 0, 44),
		TextSize = 20,
		LayoutOrder = 3,
		AutoButtonColor = calendar.canClaim,
	})
	if calendar.canClaim then
		claim.Activated:Connect(function()
			if claiming then
				return
			end
			claiming = true
			actions.claimDaily()
			progress = actions.getProgress() or progress
			claiming = false
			render()
		end)
	end
	claim.Parent = refs.content

	header("Zadania dnia (" .. tostring(progress.dailyReward) .. " za każde)", 4)
	for index, quest in progress.daily or {} do
		taskRow(tostring(quest.text), tonumber(quest.progress) or 0, tonumber(quest.target) or 0, quest.done == true, nil, 4 + index)
	end
	if progress.server then
		header("Wspólne wyzwanie serwera (+" .. tostring(progress.server.reward) .. " kluczy dla pomocników)", 10)
		taskRow(tostring(progress.server.text), tonumber(progress.server.progress) or 0, tonumber(progress.server.target) or 0, false, nil, 11)
	end
end

local function renderWeek()
	header(string.format("Wyzwania tygodnia: zostało %d dni (%s za każde)", tonumber(progress.daysLeftInWeek) or 0, tostring(progress.weeklyReward)), 1)
	for index, challenge in progress.weekly or {} do
		taskRow(tostring(challenge.text), tonumber(challenge.progress) or 0, tonumber(challenge.target) or 0, challenge.done == true, nil, 1 + index)
	end
end

local function renderAchievements()
	local unlocked = 0
	for _, achievement in progress.achievements or {} do
		if achievement.unlocked then
			unlocked += 1
		end
	end
	header(string.format("Osiągnięcia: %d/%d", unlocked, #(progress.achievements or {})), 1)
	for index, achievement in progress.achievements or {} do
		local title = tostring(achievement.name) .. ": " .. tostring(achievement.description)
		taskRow(
			(if achievement.unlocked then "" else "🔒 ") .. title,
			tonumber(achievement.progress) or 0,
			tonumber(achievement.target) or 0,
			achievement.unlocked == true,
			tostring(achievement.reward),
			1 + index
		)
	end
end

local function renderRanking()
	if not ranking then
		header("Wczytywanie rankingu...", 1)
		return
	end
	local switcher = UIKit.create("Frame", { Name = "Boards", Size = UDim2.new(1, -10, 0, 40), BackgroundTransparency = 1, LayoutOrder = 1 }, {
		UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for index, board in ranking.boards or {} do
		local boardButton = UIKit.button("Board" .. index, tostring(board.name), if index == currentBoard then COLORS.option else COLORS.locked, {
			Size = UDim2.fromOffset(190, 36),
			TextSize = 16,
			LayoutOrder = index,
		})
		boardButton.Activated:Connect(function()
			currentBoard = index
			render()
		end)
		boardButton.Parent = switcher
	end
	switcher.Parent = refs.content

	local board = ranking.boards and ranking.boards[currentBoard]
	if not board then
		return
	end
	header("Ranking tego tygodnia (odświeżany co " .. tostring(ranking.refreshSeconds) .. " s). Twój wynik: " .. tostring(board.yours), 2)
	if not ranking.available then
		header("Ranking chwilowo niedostępny.", 3)
	elseif #board.entries == 0 then
		header("Nikt jeszcze nie ma wyniku w tym tygodniu. Zajmij pierwsze miejsce!", 3)
	end
	for index, entry in board.entries do
		local medal = ({ "🥇", "🥈", "🥉" })[tonumber(entry.rank) or 0] or (tostring(entry.rank) .. ".")
		local row = UIKit.create("Frame", { Name = "Entry", Size = UDim2.new(1, -10, 0, 34), BackgroundColor3 = COLORS.card, LayoutOrder = 3 + index }, { UIKit.corner(8) })
		UIKit.label("Name", {
			Text = medal .. "  " .. tostring(entry.name),
			Size = UDim2.new(0.7, 0, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = row
		UIKit.label("Value", {
			Text = tostring(entry.value),
			Size = UDim2.new(0.3, -20, 1, 0),
			Position = UDim2.new(0.7, 10, 0, 0),
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = COLORS.title,
		}).Parent = row
		row.Parent = refs.content
	end
end

render = function()
	if not progress then
		return
	end
	clearContent()
	for tabId, tabButton in refs.tabs do
		tabButton.BackgroundColor3 = if tabId == currentTab then COLORS.option else COLORS.locked
	end
	if currentTab == "today" then
		renderToday()
	elseif currentTab == "week" then
		renderWeek()
	elseif currentTab == "achievements" then
		renderAchievements()
	else
		renderRanking()
	end
end

function ProgressController.Open()
	local fresh = actions.getProgress()
	if type(fresh) ~= "table" then
		return
	end
	progress = fresh
	render()
	UIKit.popIn(refs.panel)
end

function ProgressController.Toggle()
	if refs.panel.Visible then
		refs.panel.Visible = false
	else
		ProgressController.Open()
	end
end

-- Serwer dał znać, że coś się zmieniło: odśwież, jeśli panel jest otwarty
function ProgressController.OnUpdate()
	if refs.panel and refs.panel.Visible and currentTab ~= "ranking" then
		progress = actions.getProgress() or progress
		render()
	end
end

-- Znalezione krasnale są u gracza wyblakłe i bez podpowiedzi
function ProgressController.ApplyState(snapshot: any)
	if type(snapshot) ~= "table" or type(snapshot.gnomes) ~= "table" then
		return
	end
	local map = Workspace:FindFirstChild("Map")
	local gnomes = map and map:FindFirstChild("Gnomes")
	if not gnomes then
		return
	end
	local found = {}
	for _, index in snapshot.gnomes do
		found[index] = true
	end
	for _, gnome in gnomes:GetChildren() do
		if found[gnome:GetAttribute("GnomeIndex")] then
			for _, descendant in gnome:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Transparency = 0.85
				elseif descendant:IsA("ProximityPrompt") then
					descendant.Enabled = false
				end
			end
		end
	end
end

-- newActions: getProgress(), claimDaily(), getLeaderboard()
function ProgressController.Init(newActions)
	actions = newActions
	local gui = UIKit.screenGui("ProgressUI", 6)
	local panel = UIKit.panel("Progress", UDim2.fromOffset(680, 500), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	refs.panel = panel
	UIKit.label("Title", {
		Text = "📋 ZADANIA",
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
	for index, tab in TABS do
		local tabButton = UIKit.button("Tab" .. tab.id, tab.name, COLORS.locked, {
			Size = UDim2.fromOffset(152, 38),
			Position = UDim2.fromOffset(20 + (index - 1) * 160, 56),
			TextSize = 18,
		})
		tabButton.Activated:Connect(function()
			currentTab = tab.id
			if tab.id == "ranking" then
				ranking = nil
				render()
				ranking = actions.getLeaderboard()
			end
			render()
		end)
		tabButton.Parent = panel
		refs.tabs[tab.id] = tabButton
	end

	refs.content = UIKit.create("ScrollingFrame", {
		Name = "Content",
		Size = UDim2.new(1, -32, 1, -116),
		Position = UDim2.fromOffset(16, 104),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, {
		UIKit.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.content.Parent = panel
	panel.Parent = gui
end

return ProgressController

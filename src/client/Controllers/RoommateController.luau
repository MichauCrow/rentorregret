-- Panel "Ekipa": wspólne mieszkanie, zaproszenia, drzwi otwarte, obowiązki domowe i okienko zaproszenia.
-- Wszystkie decyzje podejmuje serwer (RoommateService); klient wysyła tylko akcje.
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local RoommateController = {}

local COLORS = UIKit.COLORS
local refs = {}
local actions = {}
local inviteToken = 0

local STATUS_TEXT = {
	together = "🏠 mieszka z Tobą",
	busy = "ma już ekipę",
}

local function render(state)
	if type(state) ~= "table" then
		return
	end
	local names = {}
	for _, member in state.members or {} do
		table.insert(names, (if member.isHost then "🔑 " else "") .. tostring(member.name))
	end
	local home = string.format("Mieszkanie: %s   (osób: %d)\n%s", tostring(state.hostName), tonumber(state.size) or 1, table.concat(names, ", "))
	if (tonumber(state.discount) or 0) > 0 then
		home ..= string.format("\nZniżka na czynsz: -%d%%", state.discount)
	else
		home ..= "\nZaproś kogoś: wspólne mieszkanie = tańszy czynsz (-10%, od 3 osób -15%)"
	end
	refs.home.Text = home

	refs.door.Visible = state.isHost == true
	refs.door.Text = if state.doorOpen then "🚪 Drzwi: OTWARTE" else "🚪 Drzwi: zamknięte"
	refs.door.BackgroundColor3 = if state.doorOpen then COLORS.button else COLORS.locked
	local size = tonumber(state.size) or 1
	refs.leave.Visible = size > 1
	refs.leave.Text = if state.isHost then "Rozwiąż ekipę" else "Wyprowadź się"

	for _, child in refs.list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local players = state.players or {}
	if #players == 0 then
		local empty = UIKit.create("Frame", { Name = "Empty", Size = UDim2.new(1, -8, 0, 40), BackgroundTransparency = 1 })
		UIKit.label("Text", { Text = "Na serwerze nie ma innych graczy.", Size = UDim2.fromScale(1, 1), TextSize = 16 }).Parent = empty
		empty.Parent = refs.list
	end
	for order, other in players do
		local row = UIKit.create("Frame", { Name = "Row", Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = COLORS.card, LayoutOrder = order }, { UIKit.corner(10) })
		UIKit.label("Name", {
			Text = tostring(other.name),
			Size = UDim2.new(1, -170, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = row
		if other.status == "free" and state.canInvite then
			local inviteButton = UIKit.button("Invite", "Zaproś", COLORS.button, {
				Size = UDim2.fromOffset(140, 30),
				Position = UDim2.new(1, -8, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				TextSize = 16,
			})
			inviteButton.Activated:Connect(function()
				actions.action("invite", other.userId)
				inviteButton.Text = "Wysłano"
				inviteButton.AutoButtonColor = false
			end)
			inviteButton.Parent = row
		else
			UIKit.label("Status", {
				Text = STATUS_TEXT[other.status] or "",
				Size = UDim2.fromOffset(160, 40),
				Position = UDim2.new(1, -8, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				TextSize = 15,
			}).Parent = row
		end
		row.Parent = refs.list
	end

	local chores = state.chores or {}
	local choresText = string.format(
		"Śmieci: %d   Plamy: %d   Naczynia: %d   Robaki: %d   Pleśń: %d",
		tonumber(chores.trash) or 0,
		tonumber(chores.stain) or 0,
		tonumber(chores.dishes) or 0,
		tonumber(chores.bug) or 0,
		tonumber(chores.mold) or 0
	)
	if type(chores.failures) == "table" and #chores.failures > 0 then
		choresText ..= "\nAwarie do naprawy: " .. table.concat(chores.failures, ", ")
	else
		choresText ..= "\nAwarie: brak 👍"
	end
	refs.chores.Text = choresText

	local parts = {}
	for _, entry in state.contributions or {} do
		table.insert(parts, string.format("%s: %d", tostring(entry.name), tonumber(entry.count) or 0))
	end
	refs.contributions.Text = "Kto ile posprzątał: " .. table.concat(parts, "   ")
end

function RoommateController.Open()
	local state = actions.getSocial()
	if type(state) == "table" then
		render(state)
		UIKit.popIn(refs.panel)
	end
end

function RoommateController.Toggle()
	if refs.panel.Visible then
		refs.panel.Visible = false
	else
		RoommateController.Open()
	end
end

function RoommateController.OnState(state: any)
	if refs.panel and refs.panel.Visible then
		render(state)
	end
end

function RoommateController.ShowInvite(payload: any)
	if type(payload) ~= "table" then
		return
	end
	refs.inviteText.Text = string.format(
		"%s zaprasza Cię do wspólnego mieszkania!\nCzynsz będzie tańszy o %d%%.",
		tostring(payload.hostName),
		tonumber(payload.discount) or 0
	)
	UIKit.popIn(refs.invite)
	inviteToken += 1
	local token = inviteToken
	task.delay(math.clamp(tonumber(payload.expiresIn) or 30, 1, 60), function()
		if token == inviteToken then
			refs.invite.Visible = false
		end
	end)
end

-- newActions: getSocial() -> stan, action(nazwa, wartość)
function RoommateController.Init(newActions)
	actions = newActions
	local gui = UIKit.screenGui("SocialUI", 6)

	local panel = UIKit.panel("Social", UDim2.fromOffset(580, 500), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	refs.panel = panel
	UIKit.label("Title", {
		Text = "👥 EKIPA",
		Size = UDim2.new(1, -80, 0, 36),
		Position = UDim2.fromOffset(20, 12),
		TextSize = 30,
		TextColor3 = COLORS.title,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel
	UIKit.closeButton(panel, function()
		panel.Visible = false
	end)

	refs.home = UIKit.label("Home", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 72),
		Position = UDim2.fromOffset(20, 52),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	refs.home.Parent = panel

	refs.door = UIKit.button("Door", "", COLORS.locked, { Size = UDim2.fromOffset(220, 36), Position = UDim2.fromOffset(20, 128), TextSize = 17 })
	refs.door.Activated:Connect(function()
		actions.action("toggleDoor")
	end)
	refs.door.Parent = panel
	refs.leave = UIKit.button("Leave", "", COLORS.cancel, { Size = UDim2.fromOffset(200, 36), Position = UDim2.fromOffset(250, 128), TextSize = 17 })
	refs.leave.Activated:Connect(function()
		actions.action("leave")
	end)
	refs.leave.Parent = panel

	UIKit.label("PlayersHeader", {
		Text = "Gracze na serwerze",
		Size = UDim2.new(1, -40, 0, 24),
		Position = UDim2.fromOffset(20, 172),
		TextSize = 19,
		TextColor3 = COLORS.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel
	refs.list = UIKit.create("ScrollingFrame", {
		Name = "Players",
		Size = UDim2.new(1, -40, 0, 140),
		Position = UDim2.fromOffset(20, 198),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, {
		UIKit.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.list.Parent = panel

	UIKit.label("ChoresHeader", {
		Text = "Obowiązki domowe",
		Size = UDim2.new(1, -40, 0, 24),
		Position = UDim2.fromOffset(20, 346),
		TextSize = 19,
		TextColor3 = COLORS.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel
	refs.chores = UIKit.label("Chores", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 48),
		Position = UDim2.fromOffset(20, 372),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	refs.chores.Parent = panel
	refs.contributions = UIKit.label("Contributions", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 48),
		Position = UDim2.fromOffset(20, 426),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	refs.contributions.Parent = panel
	panel.Parent = gui

	-- Okienko zaproszenia
	local invite = UIKit.panel("Invite", UDim2.fromOffset(460, 160), UDim2.new(0.5, 0, 1, -90), Vector2.new(0.5, 1))
	refs.invite = invite
	refs.inviteText = UIKit.label("Text", {
		Text = "",
		Size = UDim2.new(1, -30, 0, 70),
		Position = UDim2.fromOffset(15, 12),
		TextSize = 19,
	})
	refs.inviteText.Parent = invite
	local acceptButton = UIKit.button("Accept", "PRZYJMIJ", COLORS.button, { Size = UDim2.fromOffset(190, 48), Position = UDim2.new(0.5, -200, 1, -14), AnchorPoint = Vector2.new(0, 1), TextSize = 22 })
	acceptButton.Activated:Connect(function()
		invite.Visible = false
		inviteToken += 1
		actions.action("accept")
	end)
	acceptButton.Parent = invite
	local declineButton = UIKit.button("Decline", "ODRZUĆ", COLORS.cancel, { Size = UDim2.fromOffset(190, 48), Position = UDim2.new(0.5, 10, 1, -14), AnchorPoint = Vector2.new(0, 1), TextSize = 22 })
	declineButton.Activated:Connect(function()
		invite.Visible = false
		inviteToken += 1
		actions.action("decline")
	end)
	declineButton.Parent = invite
	invite.Parent = gui
end

return RoommateController

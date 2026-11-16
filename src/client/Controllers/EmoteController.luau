-- Emotki postaci (machanie, wiwat, śmiech, tańce): przycisk 💃 obok dźwięku otwiera pasek emotek.
-- Animacje grają na własnej postaci, więc Roblox sam pokazuje je innym graczom.
-- Emotka znika, gdy postać ruszy się z miejsca. Inne kontrolery wołają EmoteController.Play("cheer") przy sukcesach.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))

local EmoteController = {}

local player = Players.LocalPlayer

-- Domyślne animacje R15 (gdy skrypt Animate postaci ich nie ma)
local FALLBACK = {
	wave = { "rbxassetid://507770239" },
	point = { "rbxassetid://507770453" },
	cheer = { "rbxassetid://507770677" },
	laugh = { "rbxassetid://507770818" },
	dance = { "rbxassetid://507771019", "rbxassetid://507771955", "rbxassetid://507772104" },
	dance2 = { "rbxassetid://507776043", "rbxassetid://507776720", "rbxassetid://507776879" },
	dance3 = { "rbxassetid://507777268", "rbxassetid://507777451", "rbxassetid://507777623" },
}
local LOOPED = { dance = true, dance2 = true, dance3 = true }
local BUTTONS = {
	{ id = "wave", icon = "👋" },
	{ id = "cheer", icon = "🎉" },
	{ id = "laugh", icon = "😂" },
	{ id = "point", icon = "👉" },
	{ id = "dance", icon = "💃" },
	{ id = "dance2", icon = "🕺" },
	{ id = "dance3", icon = "🤖" },
}

local currentTrack: AnimationTrack? = nil
local moveWatch: RBXScriptConnection? = nil
local bar: Frame? = nil
local animations = {} -- [id] = { Animation }

local function stopCurrent()
	if moveWatch then
		moveWatch:Disconnect()
		moveWatch = nil
	end
	if currentTrack then
		currentTrack:Stop(0.2)
		currentTrack = nil
	end
end

local function animationsFor(id: string, character: Model)
	-- Najpierw animacje ze skryptu Animate postaci (pasują do jej typu ciała)
	local animate = character:FindFirstChild("Animate")
	local holder = animate and animate:FindFirstChild(id)
	if holder then
		local list = {}
		for _, child in holder:GetChildren() do
			if child:IsA("Animation") and child.AnimationId ~= "" then
				table.insert(list, child)
			end
		end
		if #list > 0 then
			return list
		end
	end
	if not animations[id] then
		animations[id] = {}
		for _, animationId in FALLBACK[id] or {} do
			local animation = Instance.new("Animation")
			animation.AnimationId = animationId
			table.insert(animations[id], animation)
		end
	end
	return animations[id]
end

-- Odtwarza emotkę na własnej postaci (nic się nie dzieje w trakcie jazdy na pojeździe)
function EmoteController.Play(id: string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character:GetAttribute("RidePose") then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local list = animationsFor(id, character)
	if not animator or #list == 0 then
		return
	end
	stopCurrent()
	local ok, track = pcall(function()
		return animator:LoadAnimation(list[math.random(1, #list)])
	end)
	if not ok or not track then
		return
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = LOOPED[id] == true
	track:Play(0.2)
	currentTrack = track
	-- Ruch albo skok kończy emotkę (start dopiero po chwili, żeby nie przerwało jej zatrzymywanie się)
	local startedAt = os.clock()
	moveWatch = RunService.Heartbeat:Connect(function()
		if currentTrack ~= track then
			return
		end
		local moving = humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Jump
		if (moving and os.clock() - startedAt > 0.35) or not track.IsPlaying or humanoid.Health <= 0 then
			stopCurrent()
		end
	end)
end

local function toggleBar()
	if bar then
		bar.Visible = not bar.Visible
		if bar.Visible then
			UIKit.popIn(bar)
		end
	end
end

function EmoteController.Init()
	local gui = UIKit.screenGui("EmoteUI", 1, "hud")
	local open = UIKit.button("Emotes", "💃", UIKit.COLORS.panel, {
		Size = UDim2.fromOffset(48, 44),
		Position = UDim2.fromOffset(272, 128),
		TextSize = 24,
	})
	open.Activated:Connect(toggleBar)
	open.Parent = gui

	bar = UIKit.create("Frame", {
		Name = "EmoteBar",
		Size = UDim2.fromOffset(0, 54),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(328, 123),
		BackgroundColor3 = UIKit.COLORS.panel,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, {
		UIKit.corner(14),
		UIKit.border(UIKit.COLORS.stroke, 2),
		UIKit.create("UIPadding", {
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		}),
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 5),
		}),
	})
	for order, entry in BUTTONS do
		local emote = UIKit.button(entry.id, entry.icon, UIKit.COLORS.option, {
			Size = UDim2.fromOffset(44, 44),
			TextSize = 24,
			LayoutOrder = order,
		})
		emote:SetAttribute("NoTranslate", true)
		emote.Activated:Connect(function()
			EmoteController.Play(entry.id)
			bar.Visible = false
		end)
		emote.Parent = bar
	end
	bar.Parent = gui
	player.CharacterAdded:Connect(function()
		currentTrack = nil
		stopCurrent()
	end)
end

return EmoteController

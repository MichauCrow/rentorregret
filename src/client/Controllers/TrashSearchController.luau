-- Minigra przeszukiwania kosza: klikaj szybko "SZUKAJ!", kosz się trzęsie, wylatują śmieci,
-- a na końcu wyskakuje nagroda (butelki, monety, dynia albo klucz). Nagrodę losuje serwer.
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local TrashSearchController = {}

local COLORS = UIKit.COLORS
local JUNK = { "🍌", "📰", "🥫", "🧦", "🍂", "🦴", "🧃", "🍕" }
local REWARDS = {
	bottles = { emoji = "🍾", color = Color3.fromRGB(120, 210, 255) },
	coins = { emoji = "💰", color = Color3.fromRGB(255, 210, 60) },
	pumpkin = { emoji = "🎃", color = Color3.fromRGB(255, 150, 40) },
	keys = { emoji = "🔑", color = Color3.fromRGB(255, 230, 120) },
}

local refs = {}
local actions = {}
local game_ = nil -- { clicks, needed, done }

local function close()
	game_ = nil
	refs.panel.Visible = false
	ProximityPromptService.Enabled = true
end

local function cancel()
	if game_ and not game_.done then
		actions.send("cancel")
	end
	close()
end

local function popJunk()
	local junk = UIKit.label("Junk", {
		Text = JUNK[math.random(1, #JUNK)],
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.new(0.5, math.random(-40, 40), 0, 150),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextSize = 44,
		ZIndex = 5,
	})
	junk.Parent = refs.panel
	local target = UDim2.new(0.5 + (math.random() - 0.5) * 0.9, 0, 0, math.random(-30, 30))
	TweenService:Create(junk, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target, Rotation = math.random(-200, 200), TextTransparency = 1 }):Play()
	task.delay(0.65, function()
		junk:Destroy()
	end)
end

local function search()
	if not game_ or game_.done then
		return
	end
	game_.clicks += 1
	popJunk()
	SoundController.Play("UIClick", 0.9 + game_.clicks * 0.12)
	refs.bin.Rotation = (if game_.clicks % 2 == 0 then -14 else 14)
	TweenService:Create(refs.bin, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
	refs.binPop.Scale = 1.15
	TweenService:Create(refs.binPop, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local progress = math.clamp(game_.clicks / game_.needed, 0, 1)
	TweenService:Create(refs.fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(progress, 1) }):Play()
	refs.status.Text = string.format("Klikaj szybko! %d/%d", math.min(game_.clicks, game_.needed), game_.needed)
	if game_.clicks >= game_.needed then
		game_.done = true
		refs.status.Text = "Coś tu jest..."
		refs.button.Visible = false
		actions.send("done")
	end
end

local function showResult(result)
	if not game_ then
		return
	end
	local style = REWARDS[result.kind] or REWARDS.coins
	local amount = tonumber(result.amount) or 0
	local text
	if result.kind == "bottles" then
		text = string.format("+%d %s!", amount, if amount == 1 then "butelka" elseif amount < 5 then "butelki" else "butelek")
		if (tonumber(result.coins) or 0) > 0 then
			text ..= string.format("\nWorek pełny: +%d monet", tonumber(result.coins))
		end
	elseif result.kind == "keys" then
		text = string.format("+%d klucz!", amount)
	elseif result.kind == "pumpkin" then
		text = string.format("Dynia! +%d monet", amount)
	else
		text = string.format("+%d monet!", amount)
	end
	refs.reward.Text = style.emoji
	refs.rewardText.Text = text
	refs.rewardText.TextColor3 = style.color
	refs.reward.Visible = true
	refs.rewardText.Visible = true
	refs.bin.Visible = false
	refs.rewardPop.Scale = 0
	TweenService:Create(refs.rewardPop, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	refs.status.Text = "Znalezione!"
	SoundController.Play("Success")
	SoundController.Play("Coins", 1.2)
	if result.kind == "keys" or result.kind == "pumpkin" then
		UIKit.confetti(refs.gui, 70)
	end
	task.delay(2, function()
		if game_ and game_.done then
			close()
		end
	end)
end

function TrashSearchController.OnServer(action: any, data: any)
	if action == "open" then
		game_ = { clicks = 0, needed = math.clamp(tonumber(type(data) == "table" and data.clicks) or 6, 1, 20), done = false }
		refs.fill.Size = UDim2.fromScale(0, 1)
		refs.status.Text = string.format("Klikaj szybko! 0/%d", game_.needed)
		refs.button.Visible = true
		refs.bin.Visible = true
		refs.reward.Visible = false
		refs.rewardText.Visible = false
		ProximityPromptService.Enabled = false
		UIKit.popIn(refs.panel)
	elseif action == "result" and type(data) == "table" then
		showResult(data)
	end
end

-- newActions: send("done" | "cancel")
function TrashSearchController.Init(newActions)
	actions = newActions
	local gui = UIKit.screenGui("TrashUI", 7)
	refs.gui = gui
	local panel = UIKit.panel("TrashSearch", UDim2.fromOffset(420, 360), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	refs.panel = panel
	UIKit.label("Title", { Text = "🗑️ Przeszukaj kosz!", Size = UDim2.new(1, -70, 0, 34), Position = UDim2.fromOffset(16, 12), TextSize = 26, TextColor3 = COLORS.title, TextXAlignment = Enum.TextXAlignment.Left }).Parent = panel
	UIKit.closeButton(panel, cancel)
	refs.bin = UIKit.label("Bin", { Text = "🗑️", Size = UDim2.fromOffset(120, 120), Position = UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0.5), TextSize = 96 })
	refs.binPop = UIKit.create("UIScale", {})
	refs.binPop.Parent = refs.bin
	refs.bin.Parent = panel
	refs.reward = UIKit.label("Reward", { Text = "", Size = UDim2.fromOffset(140, 120), Position = UDim2.new(0.5, 0, 0, 112), AnchorPoint = Vector2.new(0.5, 0.5), TextSize = 100, Visible = false })
	refs.rewardPop = UIKit.create("UIScale", {})
	refs.rewardPop.Parent = refs.reward
	refs.reward.Parent = panel
	refs.rewardText = UIKit.label("RewardText", { Text = "", Size = UDim2.new(1, -40, 0, 60), Position = UDim2.fromOffset(20, 176), TextSize = 30, Visible = false })
	refs.rewardText.Parent = panel
	local bar = UIKit.create("Frame", {
		Name = "Bar",
		Size = UDim2.new(1, -60, 0, 26),
		Position = UDim2.fromOffset(30, 242),
		BackgroundColor3 = COLORS.card,
		ClipsDescendants = true,
	}, { UIKit.corner(13), UIKit.border(COLORS.stroke, 2) })
	refs.fill = UIKit.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(90, 230, 110) }, { UIKit.corner(13) })
	UIKit.gloss(refs.fill)
	refs.fill.Parent = bar
	bar.Parent = panel
	refs.status = UIKit.label("Status", { Text = "", Size = UDim2.new(1, -40, 0, 24), Position = UDim2.fromOffset(20, 214), TextSize = 19 })
	refs.status.Parent = panel
	refs.button = UIKit.button("Search", "🔍 SZUKAJ!", COLORS.button, {
		Size = UDim2.fromOffset(240, 60),
		Position = UDim2.new(0.5, 0, 1, -16),
		AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 28,
		Modal = true,
	})
	refs.button.Activated:Connect(search)
	refs.button.Parent = panel
	panel.Parent = gui

	UserInputService.InputBegan:Connect(function(input, processed)
		if game_ and not processed and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA) then
			search()
		end
	end)
end

return TrashSearchController

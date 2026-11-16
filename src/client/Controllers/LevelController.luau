-- Poziom gracza: panel pod monetami (odznaka, ranga, pasek XP), wyskakujące "+XP" i "+monety" nad głową
-- oraz pokaz nowego poziomu (promienie, błysk, konfetti, nagrody i wiwat postaci).
-- Pokaz czeka, aż skończy się cut scena albo zniknie okno wyniku zmiany.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Modules"):WaitForChild("Format"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))
local EmoteController = require(script.Parent:WaitForChild("EmoteController"))

local LevelController = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 215, 60)
local XP_COLOR = Color3.fromRGB(120, 220, 255)
local XP_FILL = Color3.fromRGB(70, 200, 255)
local BAR_BACK = Color3.fromRGB(35, 22, 80)
local SHOW_TIME = 4.5

local refs = {}
local animatingUntil = 0
local barToken = 0
local queue = {}
local showing = false
local lastCoins = nil
local lastLevel = nil

-- Panel poziomu -------------------------------------------------------------------

local function buildPanel()
	local gui = UIKit.screenGui("LevelUI", 1, "hud")
	refs.gui = gui
	local panel = UIKit.create("Frame", {
		Name = "LevelPanel",
		Size = UDim2.fromOffset(200, 44),
		Position = UDim2.fromOffset(12, 76),
		BackgroundColor3 = UIKit.COLORS.panel,
		BackgroundTransparency = 0.1,
	}, { UIKit.corner(14), UIKit.border(UIKit.COLORS.stroke, 3) })
	UIKit.gloss(panel)

	local badge = UIKit.create("Frame", {
		Name = "Badge",
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.new(0, -6, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = GOLD,
		ZIndex = 3,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.border(UIKit.COLORS.stroke, 3),
	})
	UIKit.gloss(badge)
	refs.badgeBump = UIKit.create("UIScale", {})
	refs.badgeBump.Parent = badge
	refs.levelText = UIKit.label("Level", {
		Text = "1",
		Size = UDim2.fromScale(1, 1),
		TextSize = 24,
		TextWrapped = false,
		ZIndex = 4,
	})
	refs.levelText.Parent = badge
	badge.Parent = panel

	refs.rankText = UIKit.label("Rank", {
		Text = "",
		Size = UDim2.new(1, -56, 0, 16),
		Position = UDim2.fromOffset(50, 4),
		TextSize = 14,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
	})
	refs.rankText.Parent = panel

	local bar = UIKit.create("Frame", {
		Name = "XpBar",
		Size = UDim2.new(1, -58, 0, 16),
		Position = UDim2.fromOffset(50, 22),
		BackgroundColor3 = BAR_BACK,
		ClipsDescendants = true,
	}, { UIKit.corner(8) })
	refs.xpFill = UIKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = XP_FILL,
	}, { UIKit.corner(8) })
	UIKit.gloss(refs.xpFill)
	refs.xpFill.Parent = bar
	refs.xpText = UIKit.label("Text", {
		Text = "",
		Size = UDim2.fromScale(1, 1),
		TextSize = 12,
		TextWrapped = false,
		ZIndex = 2,
	})
	refs.xpText.Parent = bar
	bar.Parent = panel
	panel.Parent = gui
	refs.panel = panel
end

local function setTexts(level: number, xp: number, need: number)
	refs.levelText.Text = tostring(level)
	refs.xpText.Text = Format.Number(xp) .. " / " .. Format.Number(need) .. " XP"
end

local function setBar(level: number, xp: number, need: number, animate: boolean)
	setTexts(level, xp, need)
	local fraction = if need > 0 then math.clamp(xp / need, 0, 1) else 0
	if animate then
		TweenService:Create(refs.xpFill, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(fraction, 1),
		}):Play()
	else
		refs.xpFill.Size = UDim2.fromScale(fraction, 1)
	end
end

local function bump(scale: UIScale, size: number)
	scale.Scale = size
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Pasek dobija do końca, błyska i zaczyna od nowa na nowym poziomie
local function animateLevelUp(level: number, xp: number, need: number)
	barToken += 1
	local token = barToken
	animatingUntil = os.clock() + 1.3
	TweenService:Create(refs.xpFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, 1) }):Play()
	task.delay(0.4, function()
		if token ~= barToken then
			return
		end
		refs.xpFill.BackgroundColor3 = Color3.new(1, 1, 1)
		TweenService:Create(refs.xpFill, TweenInfo.new(0.4), { BackgroundColor3 = XP_FILL }):Play()
		bump(refs.badgeBump, 1.5)
		refs.xpFill.Size = UDim2.fromScale(0, 1)
		setBar(level, xp, need, true)
	end)
end

-- Wyskakujące napisy -------------------------------------------------------------

local function hudPopup(text: string, color: Color3)
	local popup = UIKit.label("XpPopup", {
		Text = text,
		Size = UDim2.fromOffset(150, 30),
		Position = UDim2.fromOffset(218, 84),
		TextSize = 24,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
	})
	popup.Parent = refs.gui
	local tween = TweenService:Create(popup, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(218, 52),
		TextTransparency = 1,
	})
	local stroke = popup:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(1.1), { Transparency = 1 }):Play()
	end
	tween.Completed:Once(function()
		popup:Destroy()
	end)
	tween:Play()
end

-- Napis nad własną głową (widzi go tylko gracz)
local function worldPopup(text: string, color: Color3, height: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local side = (math.random() - 0.5) * 2.4
	local billboard = UIKit.create("BillboardGui", {
		Name = "GainPopup",
		Adornee = root,
		Size = UDim2.fromOffset(170, 40),
		StudsOffset = Vector3.new(side, height, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
	})
	local text_ = UIKit.label("Text", {
		Text = text,
		Size = UDim2.fromScale(1, 1),
		TextSize = 28,
		TextWrapped = false,
		TextColor3 = color,
	})
	local pop = UIKit.create("UIScale", { Scale = 0.4 })
	pop.Parent = text_
	text_.Parent = billboard
	billboard.Parent = player:WaitForChild("PlayerGui")
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(billboard, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(side, height + 2.6, 0),
	}):Play()
	task.delay(0.8, function()
		TweenService:Create(text_, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		local stroke = text_:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end
		task.wait(0.7)
		billboard:Destroy()
	end)
end

-- Pokaz nowego poziomu --------------------------------------------------------------

local function buildShow()
	local gui = UIKit.screenGui("LevelUpUI", 40)
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	refs.show = gui

	refs.backdrop = UIKit.create("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(4, 4),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(20, 10, 40),
		BackgroundTransparency = 1,
		ZIndex = 0,
	})
	refs.backdrop.Parent = gui

	local center = UIKit.create("Frame", {
		Name = "Center",
		Size = UDim2.fromOffset(560, 470),
		Position = UDim2.fromScale(0.5, 0.47),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	refs.center = center

	-- Promienie: długie paski przez środek, zanikające na końcach, kręcą się powoli
	local rays = UIKit.create("Frame", {
		Name = "Rays",
		Size = UDim2.fromOffset(820, 820),
		Position = UDim2.fromOffset(280, 190),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	for index = 0, 11 do
		local ray = UIKit.create("Frame", {
			Name = "Ray" .. index,
			Size = UDim2.new(0, 46, 1, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = index * 15,
			BackgroundColor3 = GOLD,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
		})
		UIKit.create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.35, 0.55),
				NumberSequenceKeypoint.new(0.5, 0.35),
				NumberSequenceKeypoint.new(0.65, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}).Parent = ray
		ray.Parent = rays
	end
	refs.raysScale = UIKit.create("UIScale", {})
	refs.raysScale.Parent = rays
	rays.Parent = center
	refs.rays = rays

	refs.glow = UIKit.create("Frame", {
		Name = "Glow",
		Size = UDim2.fromOffset(270, 270),
		Position = UDim2.fromOffset(280, 190),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 240, 160),
		BackgroundTransparency = 0.55,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	refs.glow.Parent = center

	local badge = UIKit.create("Frame", {
		Name = "Badge",
		Size = UDim2.fromOffset(200, 200),
		Position = UDim2.fromOffset(280, 190),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = GOLD,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.border(UIKit.COLORS.stroke, 6),
	})
	UIKit.gloss(badge)
	refs.badgeScale = UIKit.create("UIScale", {})
	refs.badgeScale.Parent = badge
	UIKit.label("Caption", {
		Text = "POZIOM",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 30),
		TextSize = 26,
	}).Parent = badge
	refs.showLevel = UIKit.label("Number", {
		Text = "2",
		Size = UDim2.new(1, 0, 0, 110),
		Position = UDim2.fromOffset(0, 58),
		TextSize = 100,
		TextWrapped = false,
	})
	refs.showLevel:SetAttribute("NoTranslate", true)
	refs.numberScale = UIKit.create("UIScale", {})
	refs.numberScale.Parent = refs.showLevel
	refs.showLevel.Parent = badge
	badge.Parent = center
	refs.badge = badge

	refs.title = UIKit.label("Title", {
		Text = "⭐ NOWY POZIOM! ⭐",
		Size = UDim2.new(1, 0, 0, 64),
		Position = UDim2.fromOffset(0, 0),
		TextSize = 54,
		TextWrapped = false,
		TextColor3 = GOLD,
	})
	local titleStroke = refs.title:FindFirstChildOfClass("UIStroke")
	if titleStroke then
		titleStroke.Thickness = 4
	end
	refs.titleShine = UIKit.create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 160, 220)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
		Offset = Vector2.new(-1, 0),
	})
	refs.titleShine.Parent = refs.title
	refs.title.Parent = center

	refs.rankLine = UIKit.label("Rank", {
		Text = "",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 300),
		TextSize = 26,
		TextColor3 = GOLD,
	})
	refs.rankLine.Parent = center

	refs.rewards = UIKit.create("Frame", {
		Name = "Rewards",
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.fromOffset(0, 338),
		BackgroundTransparency = 1,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	refs.rewards.Parent = center

	local ok = UIKit.button("Ok", "SUPER! ✨", UIKit.COLORS.button, {
		Size = UDim2.fromOffset(210, 56),
		Position = UDim2.new(0.5, 0, 0, 404),
		AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 28,
	})
	ok.Activated:Connect(function()
		if refs.closeShow then
			refs.closeShow()
		end
	end)
	ok.Parent = center
	center.Parent = gui

	refs.flash = UIKit.create("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(4, 4),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 10,
	})
	refs.flash.Parent = gui
end

local function rewardPill(text: string, color: Color3, order: number)
	local pill = UIKit.create("Frame", {
		Name = "Reward",
		Size = UDim2.fromOffset(0, 46),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = color,
		LayoutOrder = order,
	}, {
		UIKit.corner(14),
		UIKit.border(UIKit.COLORS.stroke, 3),
		UIKit.create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
	})
	UIKit.gloss(pill)
	UIKit.label("Text", {
		Text = text,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 24,
		TextWrapped = false,
	}).Parent = pill
	local pop = UIKit.create("UIScale", { Scale = 0 })
	pop.Parent = pill
	pill.Parent = refs.rewards
	task.delay(0.55 + order * 0.15, function()
		TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		SoundController.Play("UIClick", 1.2 + order * 0.15)
	end)
end

local function busy(): boolean
	local camera = Workspace.CurrentCamera
	if camera and camera.CameraType == Enum.CameraType.Scriptable then
		return true
	end
	local jobUi = player.PlayerGui:FindFirstChild("JobUI")
	local result = jobUi and jobUi:FindFirstChild("JobResult")
	return result ~= nil and result.Visible
end

local function fovPunch()
	local camera = Workspace.CurrentCamera
	if not camera or camera.CameraType == Enum.CameraType.Scriptable then
		return
	end
	local base = camera.FieldOfView
	local zoomIn = TweenService:Create(camera, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { FieldOfView = base - 9 })
	zoomIn.Completed:Once(function()
		TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Elastic), { FieldOfView = base }):Play()
	end)
	zoomIn:Play()
end

local function playShow(entry)
	showing = true
	local gui = refs.show
	for _, child in refs.rewards:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local up = entry.up
	refs.showLevel.Text = tostring(math.max(1, up.level - 1))
	refs.rankLine.Text = if up.rank then "Nowa ranga: " .. up.rank else ""
	rewardPill("+" .. Format.Number(up.coins) .. " 💰", Color3.fromRGB(255, 160, 40), 1)
	rewardPill("+1 🎡", Color3.fromRGB(170, 90, 255), 2)
	if (up.tokens or 0) > 0 then
		rewardPill("+" .. up.tokens .. " 🔑", Color3.fromRGB(70, 140, 255), 3)
	end

	gui.Enabled = true
	refs.backdrop.BackgroundTransparency = 1
	TweenService:Create(refs.backdrop, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()
	refs.flash.BackgroundTransparency = 0.15
	TweenService:Create(refs.flash, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
	refs.badgeScale.Scale = 0
	refs.badge.Rotation = -25
	TweenService:Create(refs.badgeScale, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(refs.badge, TweenInfo.new(0.7, Enum.EasingStyle.Elastic), { Rotation = 0 }):Play()
	refs.raysScale.Scale = 0.2
	TweenService:Create(refs.raysScale, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	refs.title.Position = UDim2.fromOffset(0, -70)
	refs.title.TextTransparency = 1
	TweenService:Create(refs.title, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
		Position = UDim2.fromOffset(0, 0),
		TextTransparency = 0,
	}):Play()
	refs.titleShine.Offset = Vector2.new(-1, 0)
	TweenService:Create(refs.titleShine, TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0.4), {
		Offset = Vector2.new(1, 0),
	}):Play()

	SoundController.Play("Success", 1)
	fovPunch()
	EmoteController.Play("cheer")
	task.delay(0.35, function()
		refs.showLevel.Text = tostring(up.level)
		bump(refs.numberScale, 1.6)
		SoundController.Play("RentPaid")
		UIKit.confetti(gui, 120)
	end)

	local spin = RunService.Heartbeat:Connect(function(dt)
		refs.rays.Rotation = (refs.rays.Rotation + dt * 22) % 360
		local pulse = 1 + math.sin(os.clock() * 5) * 0.06
		refs.glow.Size = UDim2.fromOffset(270 * pulse, 270 * pulse)
	end)

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		refs.closeShow = nil
		TweenService:Create(refs.backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(refs.badgeScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
		TweenService:Create(refs.raysScale, TweenInfo.new(0.25), { Scale = 0 }):Play()
		task.wait(0.28)
		spin:Disconnect()
		gui.Enabled = false
		showing = false
		if #queue > 0 then
			local nextEntry = table.remove(queue, 1)
			task.delay(0.2, playShow, nextEntry)
		end
	end
	refs.closeShow = function()
		task.spawn(close)
	end
	task.delay(SHOW_TIME, close)
end

local function enqueue(up)
	table.insert(queue, { up = up })
	if showing then
		return
	end
	showing = true
	task.spawn(function()
		-- Nie przerywamy cut sceny ani okna wyniku zmiany (najwyżej kilka sekund czekania)
		local waited = 0
		while busy() and waited < 20 do
			waited += task.wait(0.25)
		end
		local entry = table.remove(queue, 1)
		if entry then
			playShow(entry)
		else
			showing = false
		end
	end)
end

-- API ----------------------------------------------------------------------------------

-- Serwer: { amount, reason, golden, level, xp, need, ups = { { level, coins, tokens, rank } } }
function LevelController.OnXpGain(payload: any)
	if type(payload) ~= "table" or not refs.panel then
		return
	end
	local amount = tonumber(payload.amount) or 0
	local level = tonumber(payload.level) or 1
	local xp = tonumber(payload.xp) or 0
	local need = tonumber(payload.need) or 1
	if amount > 0 then
		local golden = payload.golden == true
		local text = "+" .. Format.Number(amount) .. " XP" .. (if golden then " ✨" else "")
		hudPopup(text, if golden then GOLD else XP_COLOR)
		worldPopup(text, if golden then GOLD else XP_COLOR, 3.6)
	end
	local ups = if type(payload.ups) == "table" then payload.ups else {}
	if #ups > 0 then
		animateLevelUp(level, xp, need)
		for _, up in ups do
			if type(up) == "table" then
				enqueue({
					level = tonumber(up.level) or level,
					coins = tonumber(up.coins) or 0,
					tokens = tonumber(up.tokens) or 0,
					rank = if type(up.rank) == "string" then up.rank else nil,
				})
			end
		end
	else
		barToken += 1
		animatingUntil = os.clock() + 0.5
		setBar(level, xp, need, true)
		bump(refs.badgeBump, 1.15)
	end
	lastLevel = level
end

function LevelController.ApplyState(snapshot: any)
	if type(snapshot) ~= "table" or not refs.panel then
		return
	end
	local level = tonumber(snapshot.level)
	if level and os.clock() > animatingUntil then
		setBar(level, tonumber(snapshot.xp) or 0, tonumber(snapshot.xpNeed) or 1, lastLevel == level)
		lastLevel = level
	end
	if type(snapshot.rank) == "string" then
		refs.rankText.Text = snapshot.rank
	end
	-- "+monety" nad głową przy każdym zarobku
	local coins = tonumber(snapshot.coins)
	if coins then
		if lastCoins and coins > lastCoins then
			worldPopup("+" .. Format.Number(coins - lastCoins) .. " 💰", GOLD, 2.6)
		end
		lastCoins = coins
	end
end

function LevelController.Init()
	buildPanel()
	buildShow()
end

return LevelController

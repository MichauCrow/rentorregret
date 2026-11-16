-- Złota godzina: baner obok miesiąca z odliczaniem, zapowiedź na środku ekranu, złote konfetti
-- i ciepły, złoty odcień świata na czas trwania. Czas bierze z atrybutów ReplicatedStorage (ustawia serwer).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Modules"):WaitForChild("Format"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local GoldenHourController = {}

local GOLD = Color3.fromRGB(255, 215, 60)
local SOON = 120 -- tyle sekund przed startem pokazujemy małe odliczanie

local refs = {}
local wasActive = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function build()
	local gui = UIKit.screenGui("GoldenHourUI", 2, "hud")
	refs.gui = gui

	-- Baner obok panelu miesiąca (prawa strona góry ekranu)
	local banner = UIKit.create("Frame", {
		Name = "Banner",
		Size = UDim2.fromOffset(240, 64),
		Position = UDim2.new(0.5, 142, 0, 12),
		BackgroundColor3 = Color3.fromRGB(255, 190, 40),
		Visible = false,
	}, { UIKit.corner(16), UIKit.border(Color3.new(1, 1, 1), 3) })
	refs.shine = UIKit.create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 220)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 60)),
		}),
		Rotation = 20,
	})
	refs.shine.Parent = banner
	refs.pulse = UIKit.create("UIScale", {})
	refs.pulse.Parent = banner
	refs.title = UIKit.label("Title", {
		Text = "✨ ZŁOTA GODZINA ×2",
		Size = UDim2.new(1, -12, 0, 28),
		Position = UDim2.fromOffset(6, 4),
		TextSize = 21,
		TextWrapped = false,
	})
	refs.title.Parent = banner
	refs.timer = UIKit.label("Timer", {
		Text = "",
		Size = UDim2.new(1, -12, 0, 28),
		Position = UDim2.fromOffset(6, 32),
		TextSize = 24,
		TextWrapped = false,
	})
	refs.timer.Parent = banner
	banner.Parent = gui
	refs.banner = banner

	-- Małe odliczanie przed startem
	refs.soon = UIKit.label("Soon", {
		Text = "",
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 142, 0, 14),
		TextSize = 18,
		TextWrapped = false,
		TextColor3 = GOLD,
		BackgroundColor3 = Color3.fromRGB(25, 18, 50),
		BackgroundTransparency = 0.25,
		Visible = false,
	})
	UIKit.corner(10).Parent = refs.soon
	UIKit.create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }).Parent = refs.soon
	refs.soon.Parent = gui

	-- Duża zapowiedź na środku (okno, nie HUD)
	local announceGui = UIKit.screenGui("GoldenHourAnnounce", 35)
	refs.announceGui = announceGui
	local announce = UIKit.create("Frame", {
		Name = "Announce",
		Size = UDim2.fromOffset(620, 150),
		Position = UDim2.fromScale(0.5, 0.32),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
	})
	refs.announceScale = UIKit.create("UIScale", {})
	refs.announceScale.Parent = announce
	local big = UIKit.label("Big", {
		Text = "✨ ZŁOTA GODZINA! ✨",
		Size = UDim2.new(1, 0, 0, 80),
		TextSize = 64,
		TextWrapped = false,
		TextColor3 = GOLD,
	})
	local bigStroke = big:FindFirstChildOfClass("UIStroke")
	if bigStroke then
		bigStroke.Thickness = 4
	end
	big.Parent = announce
	UIKit.label("Small", {
		Text = "Wypłaty i XP ×2 przez trzy minuty. Do pracy!",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 84),
		TextSize = 28,
	}).Parent = announce
	announce.Parent = announceGui
	refs.announce = announce
end

local function tint(on: boolean)
	local effect = Lighting:FindFirstChild("GoldenHourTint")
	if not effect then
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "GoldenHourTint"
		effect.TintColor = Color3.new(1, 1, 1)
		effect.Parent = Lighting
	end
	TweenService:Create(effect, TweenInfo.new(2), {
		TintColor = if on then Color3.fromRGB(255, 238, 205) else Color3.new(1, 1, 1),
		Saturation = if on then 0.15 else 0,
		Brightness = if on then 0.03 else 0,
	}):Play()
end

local function showAnnounce()
	local announce = refs.announce
	announce.Visible = true
	refs.announceScale.Scale = 0.3
	TweenService:Create(refs.announceScale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	SoundController.Play("Success", 0.9)
	task.delay(0.3, function()
		SoundController.Play("RentPaid", 1.1)
	end)
	UIKit.confetti(refs.announceGui, 110)
	task.delay(3.2, function()
		local out = TweenService:Create(refs.announceScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		out.Completed:Once(function()
			announce.Visible = false
		end)
		out:Play()
	end)
end

local function update()
	local endsAt = tonumber(ReplicatedStorage:GetAttribute("GoldenHourEndsAt")) or 0
	local nextAt = tonumber(ReplicatedStorage:GetAttribute("GoldenHourNextAt")) or 0
	local time = now()
	local active = time < endsAt
	if active ~= wasActive then
		wasActive = active
		tint(active)
		if active then
			showAnnounce()
			UIKit.popIn(refs.banner)
		end
	end
	refs.banner.Visible = active
	if active then
		refs.timer.Text = Format.Time(endsAt - time)
		refs.shine.Offset = Vector2.new((time * 0.6) % 2 - 1, 0)
		refs.pulse.Scale = 1 + math.sin(time * 4) * 0.03
	end
	local untilNext = nextAt - time
	local soon = not active and untilNext > 0 and untilNext <= SOON
	refs.soon.Visible = soon
	if soon then
		refs.soon.Text = "✨ Złota godzina za " .. Format.Time(untilNext)
	end
end

function GoldenHourController.Init()
	build()
	task.spawn(function()
		while true do
			update()
			task.wait(0.1)
		end
	end)
end

return GoldenHourController

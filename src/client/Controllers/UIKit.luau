-- Wspólne klocki interfejsu dla nowszych okien (sklep, ekipa): kolory, panele, przyciski, skalowanie.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIKit = {}

UIKit.FONT = Enum.Font.FredokaOne
-- Najmniejsza skala interfejsu: okna z przyciskami (sklep, minigry) nie mogą być za małe do klikania palcem,
-- stałe elementy ekranu (HUD, samouczek) mogą być mniejsze, żeby na telefonie było widać grę
UIKit.MIN_SCALE = 0.5
UIKit.MIN_HUD_SCALE = 0.38
UIKit.MAX_SCALE = 1.1

-- Wspólna skala dla ekranu: projektujemy pod 1280x720, mniejsze ekrany pomniejszają proporcjonalnie.
-- kind = "hud": stałe elementy na ekranie (mniejsze, żeby zasłaniały jak najmniej gry), nil: okna i minigry.
function UIKit.ScaleFor(viewport: Vector2, kind: string?): number
	local ratio = math.min(viewport.X / 1280, viewport.Y / 720)
	if kind == "hud" then
		return math.clamp(ratio * 0.8, UIKit.MIN_HUD_SCALE, UIKit.MAX_SCALE)
	end
	return math.clamp(ratio * 0.92, UIKit.MIN_SCALE, UIKit.MAX_SCALE)
end

-- Dźwięk naciśnięcia ustawia SoundController (UIKit nie zależy od dźwięków)
local pressSound = nil

function UIKit.SetPressSound(callback)
	pressSound = callback
end

UIKit.RAINBOW = {
	Color3.fromRGB(255, 80, 120),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(90, 230, 100),
	Color3.fromRGB(80, 180, 255),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 140, 40),
}

-- Błyszczący połysk: jasna góra, ciemniejszy dół (UIGradient mnoży kolor tła)
function UIKit.gloss(target: GuiObject)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Gloss"
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 235, 245)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 185, 205)),
	})
	gradient.Parent = target
	return gradient
end

-- Konfetti na cały ekran: kolorowe paski wystrzeliwują w górę i spadają z obrotem
function UIKit.confetti(gui: Instance, count: number?)
	local holder = Instance.new("Frame")
	holder.Name = "Confetti"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 50
	holder.Parent = gui
	Debris:AddItem(holder, 3)
	for _ = 1, count or 60 do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Size = UDim2.fromOffset(math.random(10, 18), math.random(6, 10))
		piece.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.2, 0.45)
		piece.Rotation = math.random(0, 360)
		piece.BackgroundColor3 = UIKit.RAINBOW[math.random(1, #UIKit.RAINBOW)]
		piece.BorderSizePixel = 0
		piece.ZIndex = 50
		piece.Parent = holder
		local x = 0.5 + (math.random() - 0.5) * 1.1
		local burst = TweenService:Create(piece, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale((0.5 + x) / 2, 0.08 + math.random() * 0.2),
			Rotation = piece.Rotation + math.random(-180, 180),
		})
		burst:Play()
		burst.Completed:Once(function()
			TweenService:Create(piece, TweenInfo.new(1.4 + math.random() * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(x, 1.1),
				Rotation = piece.Rotation + math.random(360, 900),
			}):Play()
		end)
	end
end

-- Przycisk lekko się powiększa pod myszką i zgniata przy naciśnięciu (mysz i dotyk)
function UIKit.squish(button: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local info = TweenInfo.new(0.08)
	local hovered = false
	button.MouseEnter:Connect(function()
		hovered = true
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1.06 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, info, { Scale = 0.92 }):Play()
		if pressSound then
			pressSound()
		end
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = if hovered then 1.06 else 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(function()
		hovered = false
		release()
	end)
end

-- Okno pojawia się z lekkim "wyskoczeniem"
function UIKit.popIn(panel: GuiObject)
	local scale = panel:FindFirstChild("PopScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "PopScale"
		scale.Parent = panel
	end
	scale.Scale = 0.85
	panel.Visible = true
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end
UIKit.COLORS = {
	panel = Color3.fromRGB(70, 45, 150),
	card = Color3.fromRGB(48, 30, 110),
	stroke = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(255, 255, 255),
	textStroke = Color3.fromRGB(25, 15, 45),
	title = Color3.fromRGB(255, 215, 60),
	accent = Color3.fromRGB(120, 220, 255),
	good = Color3.fromRGB(90, 220, 110),
	warn = Color3.fromRGB(255, 170, 40),
	bad = Color3.fromRGB(255, 80, 90),
	button = Color3.fromRGB(60, 190, 90),
	locked = Color3.fromRGB(95, 85, 130),
	option = Color3.fromRGB(70, 110, 200),
	cancel = Color3.fromRGB(200, 70, 80),
}

function UIKit.create(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end

function UIKit.corner(radius: number)
	return UIKit.create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function UIKit.border(color: Color3, thickness: number)
	return UIKit.create("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UIKit.label(name: string, props)
	local base = {
		Name = name,
		BackgroundTransparency = 1,
		Font = UIKit.FONT,
		TextColor3 = UIKit.COLORS.text,
		TextWrapped = true,
		TextSize = 18,
	}
	for key, value in props do
		base[key] = value
	end
	return UIKit.create("TextLabel", base, {
		UIKit.create("UIStroke", { Color = UIKit.COLORS.textStroke, Thickness = 2 }),
	})
end

function UIKit.button(name: string, text: string, color: Color3, props)
	local base = {
		Name = name,
		Text = text,
		BackgroundColor3 = color,
		Font = UIKit.FONT,
		TextSize = 20,
		TextColor3 = UIKit.COLORS.text,
		TextWrapped = true,
	}
	for key, value in props do
		base[key] = value
	end
	local button = UIKit.create("TextButton", base, { UIKit.corner(12), UIKit.border(UIKit.COLORS.stroke, 2) })
	UIKit.gloss(button)
	UIKit.squish(button)
	return button
end

function UIKit.panel(name: string, size: UDim2, position: UDim2, anchor: Vector2)
	local frame = UIKit.create("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = UIKit.COLORS.panel,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, { UIKit.corner(18), UIKit.border(UIKit.COLORS.stroke, 3) })
	UIKit.gloss(frame)
	return frame
end

-- ScreenGui skalowany do ekranu (komputer, telefon, tablet)
function UIKit.screenGui(name: string, displayOrder: number, kind: string?): ScreenGui
	local gui = UIKit.create("ScreenGui", { Name = name, ResetOnSpawn = false, DisplayOrder = displayOrder })
	local scale = UIKit.create("UIScale", {})
	scale.Parent = gui
	local function update()
		local camera = Workspace.CurrentCamera
		if camera then
			scale.Scale = UIKit.ScaleFor(camera.ViewportSize, kind)
		end
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	update()
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

-- Przycisk zamykania w prawym górnym rogu panelu
function UIKit.closeButton(panel: Frame, onClose)
	local close = UIKit.button("Close", "X", UIKit.COLORS.cancel, {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -12, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 24,
		ZIndex = 5,
	})
	close.Activated:Connect(onClose)
	close.Parent = panel
	return close
end

return UIKit

-- Okno wizyty Pana Klucznika: czynsz, stary dług, ile masz monet i duży przycisk "ZAPŁAĆ".
-- Klient tylko pokazuje dane i wysyła prośbę o zapłatę; kwoty liczy serwer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Format"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local LandlordDialogController = {}

local FONT = Enum.Font.FredokaOne
local COLORS = {
	panel = Color3.fromRGB(70, 45, 150),
	stroke = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(255, 255, 255),
	textStroke = Color3.fromRGB(25, 15, 45),
	title = Color3.fromRGB(255, 215, 60),
	good = Color3.fromRGB(90, 220, 110),
	warn = Color3.fromRGB(255, 170, 40),
	button = Color3.fromRGB(60, 190, 90),
}

local refs = {}
local openToken = 0
local paying = false

local function create(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end

local function label(name: string, props)
	local base = {
		Name = name,
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = COLORS.text,
		TextWrapped = true,
	}
	for key, value in props do
		base[key] = value
	end
	return create("TextLabel", base, {
		create("UIStroke", { Color = COLORS.textStroke, Thickness = 2 }),
	})
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera and refs.scale then
		refs.scale.Scale = UIKit.ScaleFor(camera.ViewportSize)
	end
end

-- onPay: wywoływane po kliknięciu "ZAPŁAĆ"
function LandlordDialogController.Init(onPay)
	local gui = create("ScreenGui", {
		Name = "LandlordDialog",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Enabled = false,
	})
	refs.gui = gui
	refs.scale = create("UIScale", {})
	refs.scale.Parent = gui

	local panel = create("Frame", {
		Name = "Panel",
		Size = UDim2.fromOffset(480, 260),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.05,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 18) }),
		create("UIStroke", { Color = COLORS.stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	UIKit.gloss(panel)
	refs.pop = create("UIScale", {})
	refs.pop.Parent = panel

	refs.title = label("Title", {
		Text = "PAN KLUCZNIK",
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 10),
		TextSize = 28,
		TextColor3 = COLORS.title,
	})
	refs.title.Parent = panel
	refs.line = label("Line", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 48),
		Position = UDim2.fromOffset(20, 46),
		TextSize = 20,
	})
	refs.line.Parent = panel
	refs.details = label("Details", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.fromOffset(20, 96),
		TextSize = 18,
	})
	refs.details.Parent = panel
	refs.coins = label("Coins", {
		Text = "",
		Size = UDim2.new(1, -40, 0, 26),
		Position = UDim2.fromOffset(20, 148),
		TextSize = 19,
	})
	refs.coins.Parent = panel

	refs.button = create("TextButton", {
		Name = "Pay",
		Size = UDim2.fromOffset(220, 56),
		Position = UDim2.new(0.5, 0, 1, -30),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = COLORS.button,
		Font = FONT,
		Text = "ZAPŁAĆ",
		TextSize = 30,
		TextColor3 = COLORS.text,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 14) }),
		create("UIStroke", { Color = COLORS.stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	UIKit.gloss(refs.button)
	UIKit.squish(refs.button)
	refs.button.Activated:Connect(function()
		if paying then
			return
		end
		paying = true
		refs.button.Text = "..."
		onPay()
	end)
	refs.button.Parent = panel

	refs.auto = label("Auto", {
		Text = "",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -26),
		TextSize = 15,
		TextTransparency = 0.2,
	})
	refs.auto.Parent = panel

	panel.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()
end

function LandlordDialogController.Open(payload: any)
	if type(payload) ~= "table" or not refs.gui then
		return
	end
	local rent = tonumber(payload.rent) or 0
	local debt = tonumber(payload.debt) or 0
	local due = tonumber(payload.due) or 0
	local coins = tonumber(payload.coins) or 0

	refs.title.Text = "PAN KLUCZNIK " .. tostring(payload.emoji or "")
	refs.line.Text = tostring(payload.line or "")
	local details = string.format("Czynsz za miesiąc %d: %s", tonumber(payload.month) or 1, Format.Number(rent))
	if debt > 0 then
		details ..= "\nStary dług: " .. Format.Number(debt)
	end
	details ..= "\nRazem: " .. Format.Number(due)
	refs.details.Text = details
	if coins >= due then
		refs.coins.Text = "Masz: " .. Format.Number(coins) .. " monet"
		refs.coins.TextColor3 = COLORS.good
	else
		refs.coins.Text = string.format("Masz: %s (brakuje %s, dostaniesz dogrywkę)", Format.Number(coins), Format.Number(due - coins))
		refs.coins.TextColor3 = COLORS.warn
	end

	paying = false
	refs.button.Text = "ZAPŁAĆ"
	refs.gui.Enabled = true
	refs.pop.Scale = 0.8
	TweenService:Create(refs.pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	openToken += 1
	local token = openToken
	local seconds = math.clamp(tonumber(payload.autoPayIn) or 0, 0, 60)
	task.spawn(function()
		for remaining = seconds, 1, -1 do
			if token ~= openToken then
				return
			end
			refs.auto.Text = "Pan Klucznik poczeka jeszcze " .. remaining .. " s"
			task.wait(1)
		end
	end)
end

function LandlordDialogController.Close()
	openToken += 1
	if refs.gui then
		refs.gui.Enabled = false
	end
end

return LandlordDialogController

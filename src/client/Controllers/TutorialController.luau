-- Samouczek po stronie gracza: na start wycieczka z drona po mieście (CutsceneController.PlayTour), potem duży
-- pasek z poleceniem nad przyciskami i przerywana linia do celu (GuideController). Przy kroku ze sklepem nad
-- przyciskiem SKLEP podskakuje strzałka. Dane (krok, tekst, cel) przychodzą z serwera w stanie gracza.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local GuideController = require(script.Parent:WaitForChild("GuideController"))
local CutsceneController = require(script.Parent:WaitForChild("CutsceneController"))

local TutorialController = {}

local COLORS = UIKit.COLORS
local POINTER_COLOR = Color3.fromRGB(255, 230, 80)

local player = Players.LocalPlayer
local refs = {}
local actions = {}
local currentStep = nil
local currentTarget = nil
local targetPart = nil -- niewidoczny punkt celu, do którego prowadzi przerywana linia
local introStarted = false
local pointer = nil -- { arrow, stroke } nad przyciskiem SKLEP
local sprinted = false -- gracz użył już biegu (Shift albo przycisk 🏃), więc podpowiedź znika
local SPRINT_STEPS = { park = true, skup = true, office = true } -- kroki poza domem

local function ensureTargetPart(): BasePart
	if not targetPart or not targetPart.Parent then
		targetPart = Instance.new("Part")
		targetPart.Name = "TutorialTarget"
		targetPart.Size = Vector3.new(0.2, 0.2, 0.2)
		targetPart.Transparency = 1
		targetPart.Anchored = true
		targetPart.CanCollide = false
		targetPart.CanQuery = false
		targetPart.CanTouch = false
		targetPart.Parent = Workspace
	end
	return targetPart
end

-- Strzałka i żółta obwódka przy przycisku SKLEP (krok "shop")
local function setShopPointer(on: boolean)
	if not on then
		if pointer then
			pointer.arrow:Destroy()
			pointer.stroke:Destroy()
			pointer = nil
		end
		return
	end
	if pointer then
		return
	end
	local hud = player.PlayerGui:FindFirstChild("HUD")
	local button = hud and hud:FindFirstChild("Shop", true)
	if not button then
		return
	end
	local arrow = UIKit.label("TutorialArrow", {
		Text = "⬇",
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.new(0.5, 0, 0, -6),
		AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 54,
		TextColor3 = POINTER_COLOR,
		ZIndex = 10,
	})
	arrow:SetAttribute("NoTranslate", true)
	arrow.Parent = button
	TweenService:Create(arrow, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(0.5, 0, 0, -22) }):Play()
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TutorialGlow"
	stroke.Color = POINTER_COLOR
	stroke.Thickness = 5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	TweenService:Create(stroke, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.6 }):Play()
	pointer = { arrow = arrow, stroke = stroke }
end

local function clearGuide()
	GuideController.SetFixedTarget(nil)
	setShopPointer(false)
end

function TutorialController.ApplyState(snapshot: any)
	if type(snapshot) ~= "table" or not refs.panel then
		return
	end
	local tutorial = snapshot.tutorial
	if type(tutorial) ~= "table" then
		refs.panel.Visible = false
		currentStep = nil
		currentTarget = nil
		refs.sprint.Visible = false
		clearGuide()
		return
	end
	-- Pierwszy raz: wycieczka z drona po mieście, potem kroki samouczka
	if tutorial.intro == true and not introStarted then
		introStarted = true
		CutsceneController.PlayTour(function()
			actions.introDone()
		end)
	end
	local step = tonumber(tutorial.step) or 1
	refs.title.Text = string.format("SAMOUCZEK  %d/%d", step, tonumber(tutorial.total) or 6)
	local text = tostring(tutorial.text or "")
	local goal = tonumber(tutorial.goal) or 1
	if goal > 1 then
		text ..= string.format("  (%d/%d)", tonumber(tutorial.progress) or 0, goal)
	end
	refs.text.Text = text
	refs.panel.Visible = true
	if step ~= currentStep then
		currentStep = step
		UIKit.popIn(refs.panel)
	end
	currentTarget = tutorial.target
	if typeof(tutorial.targetPosition) == "Vector3" then
		local part = ensureTargetPart()
		part.Position = tutorial.targetPosition
		GuideController.SetFixedTarget(part, tostring(tutorial.label or ""))
	else
		GuideController.SetFixedTarget(nil)
	end
	setShopPointer(currentTarget == "shop")
	refs.sprint.Visible = not sprinted and SPRINT_STEPS[currentTarget] == true
	-- Przy kroku ze sklepem pasek idzie wyżej, żeby nie zasłaniał strzałki nad przyciskiem SKLEP
	refs.panel.Position = UDim2.new(0.5, 0, 1, if currentTarget == "shop" then -170 else -92)
end

-- newActions: skip(), introDone(), shopOpened()
function TutorialController.Init(newActions)
	actions = newActions
	local gui = UIKit.screenGui("TutorialUI", 3, "hud")
	local panel = UIKit.panel("Tutorial", UDim2.fromOffset(660, 108), UDim2.new(0.5, 0, 1, -92), Vector2.new(0.5, 1))
	panel.BackgroundColor3 = Color3.fromRGB(30, 85, 160)
	refs.panel = panel
	refs.title = UIKit.label("Title", {
		Text = "",
		Size = UDim2.new(1, -150, 0, 26),
		Position = UDim2.fromOffset(18, 8),
		TextSize = 20,
		TextColor3 = COLORS.title,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.title.Parent = panel
	refs.text = UIKit.label("Text", {
		Text = "",
		Size = UDim2.new(1, -36, 0, 66),
		Position = UDim2.fromOffset(18, 36),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	refs.text.Parent = panel
	local skip = UIKit.button("Skip", "Pomiń", COLORS.locked, {
		Size = UDim2.fromOffset(110, 30),
		Position = UDim2.new(1, -12, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 16,
	})
	skip.Activated:Connect(function()
		actions.skip()
	end)
	skip.Parent = panel

	-- Podpowiedź o biegu nad paskiem (po wyjściu z domu): klawisz SHIFT albo przycisk 🏃 na telefonie
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local sprint = UIKit.create("Frame", {
		Name = "SprintHint",
		Size = UDim2.fromOffset(0, 52),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0, 0, 0, -10),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(25, 18, 50),
		BackgroundTransparency = 0.15,
		Visible = false,
	}, {
		UIKit.corner(14),
		UIKit.border(COLORS.stroke, 2),
		UIKit.create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 14) }),
		UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local key = UIKit.create("TextLabel", {
		Name = "Key",
		Size = UDim2.fromOffset(if touch then 40 else 104, 36),
		BackgroundColor3 = Color3.fromRGB(245, 245, 250),
		Font = UIKit.FONT,
		Text = if touch then "🏃" else "⇧ SHIFT",
		TextSize = 20,
		TextColor3 = Color3.fromRGB(40, 35, 60),
		LayoutOrder = 1,
	}, { UIKit.corner(8), UIKit.border(Color3.fromRGB(150, 145, 170), 3) })
	key:SetAttribute("NoTranslate", true)
	key.Parent = sprint
	local sprintText = UIKit.label("Text", {
		Text = if touch then "Naciśnij 🏃, żeby biec szybciej!" else "Przytrzymaj, żeby biec szybciej!",
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 19,
		TextWrapped = false,
		LayoutOrder = 2,
	})
	sprintText.Parent = sprint
	TweenService:Create(key, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundColor3 = Color3.fromRGB(255, 225, 120) }):Play()
	sprint.Parent = panel
	refs.sprint = sprint
	local function onSprint()
		if not sprinted and refs.sprint.Visible then
			sprinted = true
			task.delay(1.5, function()
				refs.sprint.Visible = false
			end)
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and (input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift) then
			onSprint()
		end
	end)
	task.spawn(function()
		local sprintGui = player.PlayerGui:WaitForChild("SprintUI", 15)
		local button = sprintGui and sprintGui:FindFirstChild("Sprint")
		if button then
			button.Activated:Connect(onSprint)
		end
	end)
	panel.Parent = gui

	-- Krok "shop": zaliczony, gdy gracz otworzy okno sklepu
	task.spawn(function()
		local shopGui = player.PlayerGui:WaitForChild("ShopUI", 30)
		local shop = shopGui and shopGui:WaitForChild("Shop", 10)
		if shop then
			shop:GetPropertyChangedSignal("Visible"):Connect(function()
				if shop.Visible and currentTarget == "shop" then
					actions.shopOpened()
				end
			end)
		end
	end)
end

return TutorialController

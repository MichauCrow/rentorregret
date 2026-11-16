-- Ustawianie mebli: po zakupie (albo "Przestaw" przy meblu) przed graczem pojawia się półprzezroczysty mebel.
-- Komputer: mebel idzie za myszką po podłodze, R = obrót, klik = postaw. Telefon: mebel stoi przed postacią,
-- przyciski OBRÓĆ / POSTAW / ANULUJ. Zielony = zmieści się, czerwony = nie. Ostateczną decyzję podejmuje serwer.
-- Mebel stawia się na piętrze, na którym stoi gracz. Kupiony mebel można też sprzedać (dwa kliknięcia: SPRZEDAJ, NA PEWNO?).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ApartmentConfig = require(Shared:WaitForChild("Config"):WaitForChild("ApartmentConfig"))
local FurnitureBuilder = require(Shared:WaitForChild("Modules"):WaitForChild("FurnitureBuilder"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local PlacementController = {}

local COLORS = UIKit.COLORS
local VALID = Color3.fromRGB(90, 230, 110)
local INVALID = Color3.fromRGB(255, 80, 90)
local ROTATE_STEP = 45
local GRID = 0.5

local refs = {}
local actions = {}
local current = nil -- { payload, tier, ghost, highlight, rot, x, z, valid, radius }

local function snap(value: number): number
	return math.floor(value / GRID + 0.5) * GRID
end

local function floorY(): number
	return current.payload.origin.Position.Y + (tonumber(current.payload.floorY) or 1)
end

local function stop()
	if current and current.ghost then
		current.ghost:Destroy()
	end
	current = nil
	refs.panel.Visible = false
	ProximityPromptService.Enabled = true
end

local function cancel()
	stop()
end

-- Punkt na podłodze mieszkania (współrzędne lokalne): myszka na komputerze, przed postacią na telefonie
local function targetPoint(): (number?, number?)
	local origin: CFrame = current.payload.origin
	local planeY = floorY()
	local camera = Workspace.CurrentCamera
	local world = nil
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled and camera then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		if math.abs(ray.Direction.Y) > 0.01 then
			local t = (planeY - ray.Origin.Y) / ray.Direction.Y
			if t > 0 and t < 200 then
				world = ray.Origin + ray.Direction * t
			end
		end
	end
	if not world then
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return nil, nil
		end
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		world = root.Position + (if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)) * (current.radius + 3)
	end
	local localPoint = origin:PointToObjectSpace(world)
	return snap(localPoint.X), snap(localPoint.Z)
end

local function update()
	if not current then
		return
	end
	-- Gracz wyszedł z domu albo zmienił piętro: zamykamy podgląd (mebel zostaje tam, gdzie był)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local inside = current.payload.origin:PointToObjectSpace(root.Position)
		local relativeY = inside.Y - (tonumber(current.payload.floorY) or 1)
		if math.abs(inside.X) > current.tier.width / 2 + 2 or math.abs(inside.Z) > current.tier.depth / 2 + 2 or relativeY < -3 or relativeY > 12 then
			stop()
			return
		end
	end
	local x, z = targetPoint()
	if not x then
		return
	end
	current.x, current.z = x, z
	local origin: CFrame = current.payload.origin
	current.ghost:PivotTo(origin * CFrame.new(x, tonumber(current.payload.floorY) or 1, z) * CFrame.Angles(0, math.rad(current.rot), 0))
	local ok = ApartmentConfig.CanPlaceFurniture(current.tier, x, z, current.radius, current.payload.rug == true, current.payload.others or {}, tonumber(current.payload.floor) or 0, tonumber(current.payload.rooms) or 0)
	current.valid = ok
	current.highlight.FillColor = if ok then VALID else INVALID
	current.highlight.OutlineColor = if ok then VALID else INVALID
	refs.status.Text = if ok then "Tu pasuje! Kliknij POSTAW" else "Tu się nie zmieści"
	refs.status.TextColor3 = if ok then VALID else INVALID
	refs.place.BackgroundColor3 = if ok then COLORS.button else COLORS.locked
end

local function rotate()
	if current then
		current.rot = (current.rot + ROTATE_STEP) % 360
		SoundController.Play("UIClick", 1.2)
	end
end

local function confirm()
	if not current then
		return
	end
	if not current.valid then
		SoundController.Play("Warning")
		return
	end
	actions.send(current.payload.index, "place", current.x, current.z, current.rot)
	SoundController.Play("Success")
	stop()
end

-- Sprzedaż: pierwsze kliknięcie pyta "NA PEWNO?", drugie sprzedaje
local function sell()
	if not current then
		return
	end
	local price = tonumber(current.payload.sellPrice) or 0
	if price <= 0 then
		return
	end
	if not current.sellArmed then
		current.sellArmed = true
		refs.sell.Text = string.format("❓ NA PEWNO? +%d", price)
		refs.sell.BackgroundColor3 = COLORS.bad
		SoundController.Play("UIClick", 0.9)
		return
	end
	actions.send(current.payload.index, "sell")
	SoundController.Play("Coins")
	stop()
end

function PlacementController.Start(payload: any)
	if type(payload) ~= "table" or type(payload.itemId) ~= "string" or typeof(payload.origin) ~= "CFrame" then
		return
	end
	local tier = ApartmentConfig.Tiers[tonumber(payload.tier) or 1]
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not tier or not root then
		return
	end
	-- Ustawiać można tylko w środku mieszkania
	local inside = payload.origin:PointToObjectSpace(root.Position)
	local relativeY = inside.Y - (tonumber(payload.floorY) or 1)
	if math.abs(inside.X) > tier.width / 2 or inside.Z < tier.doorZ or inside.Z > tier.depth / 2 or relativeY < -2 or relativeY > 12 then
		actions.toast(string.format("%s %s stoi już w mieszkaniu. Wejdź do domu i przytrzymaj R przy meblu, żeby go przestawić.", tostring(payload.emoji or ""), tostring(payload.name or "")), "info")
		return
	end
	if current then
		stop()
	end
	local ghost = FurnitureBuilder.Build(payload.itemId, CFrame.new())
	if not ghost then
		return
	end
	ghost.WorldPivot = CFrame.new() -- punkt obrotu = punkt na podłodze, jak przy stawianiu na serwerze
	for _, part in ghost:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = math.max(part.Transparency, 0.45)
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		elseif part:IsA("PointLight") then
			part.Enabled = false
		end
	end
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.65
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = ghost
	ghost.Name = "PlacementGhost"
	ghost.Parent = Workspace
	current = {
		payload = payload,
		tier = tier,
		ghost = ghost,
		highlight = highlight,
		rot = tonumber(payload.rot) or 0,
		radius = FurnitureBuilder.Footprint(payload.itemId),
		valid = false,
	}
	refs.title.Text = string.format("Ustaw: %s %s", tostring(payload.emoji or ""), tostring(payload.name or ""))
	local price = tonumber(payload.sellPrice) or 0
	refs.sell.Visible = price > 0
	refs.sell.Text = string.format("💰 SPRZEDAJ +%d", price)
	refs.sell.BackgroundColor3 = COLORS.warn
	-- Zamknij sklep, żeby było widać mieszkanie
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local shop = playerGui and playerGui:FindFirstChild("ShopUI")
	local shopPanel = shop and shop:FindFirstChild("Shop")
	if shopPanel then
		shopPanel.Visible = false
	end
	ProximityPromptService.Enabled = false
	UIKit.popIn(refs.panel)
	update()
end

-- newActions: send(index, "place", x, z, obrót), toast(tekst, rodzaj)
function PlacementController.Init(newActions)
	actions = newActions
	local gui = UIKit.screenGui("PlacementUI", 7)
	local panel = UIKit.panel("Placement", UDim2.fromOffset(740, 190), UDim2.new(0.5, 0, 1, -100), Vector2.new(0.5, 1))
	refs.panel = panel
	refs.title = UIKit.label("Title", { Text = "", Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, 10), TextSize = 26, TextColor3 = COLORS.title })
	refs.title.Parent = panel
	refs.status = UIKit.label("Status", { Text = "", Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 46), TextSize = 19 })
	refs.status.Parent = panel
	local hint = UIKit.label("Hint", {
		Text = if UserInputService.TouchEnabled then "Chodź po mieszkaniu, żeby wybrać miejsce" else "Myszka = miejsce   R = obróć   Klik = postaw",
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 72),
		TextSize = 16,
	})
	hint.Parent = panel
	local row = UIKit.create("Frame", {
		Name = "Buttons",
		Size = UDim2.new(1, -24, 0, 64),
		Position = UDim2.new(0, 12, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
	}, {
		UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local rotateButton = UIKit.button("Rotate", "↻ OBRÓĆ", COLORS.option, { Size = UDim2.fromOffset(160, 60), TextSize = 22, LayoutOrder = 1 })
	rotateButton.Activated:Connect(rotate)
	rotateButton.Parent = row
	refs.place = UIKit.button("Place", "✔ POSTAW", COLORS.button, { Size = UDim2.fromOffset(180, 60), TextSize = 24, LayoutOrder = 2, Modal = true })
	refs.place.Activated:Connect(confirm)
	refs.place.Parent = row
	local cancelButton = UIKit.button("Cancel", "✖ ANULUJ", COLORS.cancel, { Size = UDim2.fromOffset(160, 60), TextSize = 22, LayoutOrder = 3 })
	cancelButton.Activated:Connect(cancel)
	cancelButton.Parent = row
	refs.sell = UIKit.button("Sell", "💰 SPRZEDAJ", COLORS.warn, { Size = UDim2.fromOffset(170, 60), TextSize = 19, LayoutOrder = 4, Visible = false })
	refs.sell.Activated:Connect(sell)
	refs.sell.Parent = row
	row.Parent = panel
	panel.Parent = gui

	UserInputService.InputBegan:Connect(function(input, processed)
		if not current then
			return
		end
		if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonY then
			rotate()
		elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			cancel()
		elseif not processed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Return) then
			confirm()
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return PlacementController

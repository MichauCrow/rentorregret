-- Samouczek i cele: linia "Cel:" pod zegarem i strzałka nad celem w świecie (skrzynka, brama, zamknięte drzwi,
-- a w pierwszej rundzie także najbliższy mebel do przeszukania). Przy pierwszym wejściu na piętro w rundzie
-- duża podpowiedź, kto tam mieszka.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent.ClientState)
local HUDController = require(script.Parent.HUDController)
local UIKit = require(script.Parent.UIKit)

local ObjectiveController = {}

local FLOOR_TIPS = {
	[1] = "🤫 1. piętro: tu mieszka Cichy Sąsiad. Nie biegaj!",
	[2] = "🔦 2. piętro: tu śpi Mruczek. Gaś latarkę, gdy jest blisko!",
}
local SPOT_HINT_RADIUS = 45

local player = Players.LocalPlayer
local objectiveLabel = nil
local marker = nil
local markerArrow = nil
local markerDistance = nil
local building = nil
local floorsSeen = {}
local currentText = nil

-- Kamienica, w której jest gracz (najbliższa w folderze Rounds)
local function findBuilding(): Model?
	local character = player.Character
	local root = character and character.PrimaryPart
	local rounds = Workspace:FindFirstChild("Rounds")
	if not root or not rounds then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, model in rounds:GetChildren() do
		local geometry = model:FindFirstChild("Geometry")
		local box = geometry and geometry:FindFirstChild("RentBox")
		if box and box:IsA("BasePart") then
			local distance = (box.CFrame.Position - root.CFrame.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

local function find(folderName: string, name: string): BasePart?
	local folder = building and building:FindFirstChild(folderName)
	local found = folder and folder:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function nearestSpot(origin: Vector3, floorY: number): BasePart?
	local geometry = building and building:FindFirstChild("Geometry")
	if not geometry then
		return nil
	end
	local best, bestDistance = nil, SPOT_HINT_RADIUS
	for _, part in geometry:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("Spot") and not part:GetAttribute("Searched") then
			local position = part.CFrame.Position
			if math.abs(position.Y - floorY) < 8 then
				local distance = (position - origin).Magnitude
				if distance < bestDistance then
					best, bestDistance = part, distance
				end
			end
		end
	end
	return best
end

-- Zwraca tekst celu i część, nad którą ma być strzałka
local function decide(round): (string?, BasePart?)
	local profile = ClientState.profile
	local firstRound = profile == nil or not profile.tutorialDone
	local character = player.Character
	local root = character and character.PrimaryPart
	if round.status ~= "inside" then
		return nil, nil
	end
	if round.hidden then
		return "🤫 Siedź cicho. Wyjdź, gdy potwór odejdzie.", nil
	end
	local gate = find("Decor", "GateSign")
	local box = find("Geometry", "RentBox")
	if round.phase == "hunt" then
		return "🏃 Uciekaj do bramy na podwórku albo schowaj się w szafie!", gate
	end
	if round.rentPaid then
		if round.carried > 0 then
			return "💰 Wpłać jeszcze " .. round.carried .. " (premia x1.5) albo uciekaj do bramy!", box
		end
		return "🚪 Czynsz zapłacony! Uciekaj do bramy albo szukaj premii.", gate
	end
	if round.carried >= round.capacity then
		return "🎒 Kieszenie pełne! Zanieś monety do skrzynki w BIURZE.", box
	end
	if round.carried > 0 and round.deposited + round.carried >= round.rent then
		return "💰 Masz dość na czynsz! Zanieś monety do BIURA.", box
	end
	if round.hasKey then
		return "🔑 Masz klucz! Znajdź zamknięte mieszkanie na piętrze.", find("Geometry", "LockedDoor")
	end
	if round.timeLeft <= 60 and round.carried > 0 then
		return "⏰ Mało czasu! Zanieś monety do BIURA.", box
	end
	if round.carried > 0 and round.carried >= round.capacity * 0.6 then
		return "🔍 Szukaj dalej albo zanieś monety do BIURA (🎒 " .. round.carried .. ").", box
	end
	local spot = nil
	if firstRound and root then
		spot = nearestSpot(root.CFrame.Position, root.CFrame.Position.Y - 3)
	end
	return "🔍 Przeszukuj meble (E) i szukaj monet. Wyżej jest ich więcej!", spot
end

local function buildMarker()
	marker = UIKit.create("BillboardGui", {
		Name = "ObjectiveMarker",
		Size = UDim2.fromOffset(90, 110),
		StudsOffsetWorldSpace = Vector3.new(0, 4, 0),
		AlwaysOnTop = true,
		Enabled = false,
		ResetOnSpawn = false,
	})
	markerArrow = UIKit.label("Arrow", { Size = UDim2.new(1, 0, 0, 70), Text = "⬇", TextScaled = true, TextColor3 = Color3.fromRGB(255, 225, 90) })
	markerArrow.Parent = marker
	markerDistance = UIKit.label("Distance", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 74), Text = "", TextSize = 20 })
	markerDistance.Parent = marker
	marker.Parent = player:WaitForChild("PlayerGui")
end

local function update(round)
	if not round then
		building = nil
		floorsSeen = {}
		objectiveLabel.Visible = false
		marker.Enabled = false
		currentText = nil
		return
	end
	if not building or not building.Parent then
		building = findBuilding()
	end
	-- Pierwsze wejście na piętro w tej rundzie: podpowiedź
	if round.status == "inside" and not floorsSeen[round.floor] then
		floorsSeen[round.floor] = true
		if FLOOR_TIPS[round.floor] then
			HUDController.Alert(FLOOR_TIPS[round.floor], "info")
		end
	end
	local text, target = decide(round)
	objectiveLabel.Visible = text ~= nil
	if text and text ~= currentText then
		currentText = text
		objectiveLabel.Text = "🎯 " .. text
	end
	marker.Adornee = target
	marker.Enabled = target ~= nil
end

function ObjectiveController.Init()
	local gui = UIKit.screenGui("Objective", 4, "hud")
	objectiveLabel = UIKit.label("Objective", {
		Size = UDim2.fromOffset(640, 34),
		Position = UDim2.new(0.5, 0, 0, 108),
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "",
		TextSize = 20,
		TextColor3 = Color3.fromRGB(255, 250, 220),
		Visible = false,
	})
	objectiveLabel.Parent = gui
	buildMarker()
end

function ObjectiveController.Start()
	ClientState.OnRound(update)
	-- Strzałka podskakuje, a pod nią widać odległość
	RunService.RenderStepped:Connect(function()
		if not marker.Enabled or not marker.Adornee then
			return
		end
		local t = os.clock()
		markerArrow.Position = UDim2.fromOffset(0, math.abs(math.sin(t * 4)) * -10)
		local character = player.Character
		local root = character and character.PrimaryPart
		local target = marker.Adornee :: BasePart
		if root then
			markerDistance.Text = math.floor((target.CFrame.Position - root.CFrame.Position).Magnitude / 3) .. " m"
		end
	end)
end

return ObjectiveController

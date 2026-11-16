-- Samouczek i cele: linia celu pod linijką stanu i znacznik celu w świecie (skrzynka, brama, zamknięte
-- drzwi, szafa; w pierwszej rundzie także najbliższy mebel). Gdy cel jest poza ekranem, strzałka stoi na
-- brzegu ekranu i pokazuje kierunek. Przy pierwszym wejściu na piętro duża podpowiedź, kto tam mieszka.
-- Aktualizuje też zegary ścienne w kamienicy (ta sama godzina co w HUD).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent.ClientState)
local HUDController = require(script.Parent.HUDController)
local UIKit = require(script.Parent.UIKit)

local ObjectiveController = {}

local FLOOR_TIPS = {
	[1] = "🤫 1. piętro: tu mieszka Cichy Sąsiad. Nie biegaj i nie noś pełnych kieszeni!",
	[2] = "🔦 2. piętro: tu śpi Mruczek. Gaś latarkę, gdy jest blisko!",
}
local SPOT_HINT_RADIUS = 45
local EDGE_MARGIN = 70
local FORCED_TIME = 10

local player = Players.LocalPlayer
local objectiveLabel = nil
local marker = nil
local markerArrow = nil
local markerDistance = nil
local edgeGui = nil
local edgeArrow = nil
local building = nil
local floorsSeen = {}
local currentText = nil
local forced = nil -- { text, kind, untilTime } wymuszony cel (np. samouczek "schowaj się!")

local function rootPart(): BasePart?
	local character = player.Character
	return character and character.PrimaryPart
end

-- Kamienica, w której jest gracz (najbliższa w folderze Rounds)
local function findBuilding(): Model?
	local root = rootPart()
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

-- Najbliższa część o danej nazwie (albo z atrybutem Spot) na piętrze gracza
local function nearest(origin: Vector3, floorY: number, filter): BasePart?
	local geometry = building and building:FindFirstChild("Geometry")
	if not geometry then
		return nil
	end
	local best, bestDistance = nil, SPOT_HINT_RADIUS
	for _, part in geometry:GetChildren() do
		if part:IsA("BasePart") and filter(part) then
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

local function isSpot(part: BasePart): boolean
	return part:GetAttribute("Spot") == true and not part:GetAttribute("Searched")
end

local function isWardrobe(part: BasePart): boolean
	return part.Name == "Wardrobe"
end

-- Zwraca tekst celu i część, nad którą ma być strzałka
local function decide(round): (string?, BasePart?)
	local profile = ClientState.profile
	local firstRound = profile == nil or not profile.tutorialDone
	local root = rootPart()
	if round.status ~= "inside" then
		return nil, nil
	end
	if round.hidden then
		forced = nil
		return "🤫 Siedź cicho. Wyjdź, gdy potwór odejdzie.", nil
	end
	if forced and os.clock() < forced.untilTime and root then
		local feet = root.CFrame.Position
		return forced.text, nearest(feet, feet.Y - 3, isWardrobe)
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
		local feet = root.CFrame.Position
		spot = nearest(feet, feet.Y - 3, isSpot)
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
	markerDistance:SetAttribute("NoTranslate", true)
	markerDistance.Parent = marker
	marker.Parent = player:WaitForChild("PlayerGui")

	-- Strzałka na brzegu ekranu (cel poza widokiem)
	edgeGui = UIKit.create("ScreenGui", { Name = "ObjectiveEdge", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 4 })
	edgeArrow = UIKit.label("EdgeArrow", {
		Size = UDim2.fromOffset(64, 64),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = "➤",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 225, 90),
		Visible = false,
	})
	edgeArrow:SetAttribute("NoTranslate", true)
	edgeArrow.Parent = edgeGui
	edgeGui.Parent = player:WaitForChild("PlayerGui")
end

local function updateWallClocks(round)
	local root = rootPart()
	if not root then
		return
	end
	for _, label in CollectionService:GetTagged("WallClock") do
		if label:IsA("TextLabel") and label.Parent and label.Parent.Parent then
			local part = label.Parent.Parent
			if part:IsA("BasePart") and (part.CFrame.Position - root.CFrame.Position).Magnitude < 150 then
				label.Text = round.clock
				label.TextColor3 = if round.timeLeft <= 60 then Color3.fromRGB(200, 30, 30) else Color3.fromRGB(60, 30, 30)
			end
		end
	end
end

local function update(round)
	if not round then
		building = nil
		floorsSeen = {}
		forced = nil
		objectiveLabel.Visible = false
		marker.Enabled = false
		edgeArrow.Visible = false
		currentText = nil
		return
	end
	if not building or not building.Parent then
		building = findBuilding()
	end
	updateWallClocks(round)
	-- Pierwsze wejście na piętro w tej rundzie: podpowiedź
	if round.status == "inside" and not floorsSeen[round.floor] then
		floorsSeen[round.floor] = true
		if FLOOR_TIPS[round.floor] and not forced then
			HUDController.Alert(FLOOR_TIPS[round.floor], "info")
		end
	end
	local text, target = decide(round)
	objectiveLabel.Visible = text ~= nil
	if text and text ~= currentText then
		currentText = text
		objectiveLabel.Text = text
		objectiveLabel.TextColor3 = if forced and os.clock() < forced.untilTime then Color3.fromRGB(255, 140, 140) else Color3.fromRGB(255, 250, 220)
	end
	if target then
		marker.Adornee = target
	end
	marker.Enabled = target ~= nil
end

-- Wymuszony cel na kilka sekund (samouczek: "Szybko! Schowaj się w szafie!")
function ObjectiveController.Force(text: string)
	forced = { text = text, untilTime = os.clock() + FORCED_TIME }
	currentText = nil
	if ClientState.round then
		update(ClientState.round)
	end
end

local function updateEdgeArrow()
	local target = marker.Adornee
	local camera = Workspace.CurrentCamera
	if not marker.Enabled or not target or not target:IsA("BasePart") or not camera then
		edgeArrow.Visible = false
		return
	end
	local world = target.CFrame.Position + Vector3.new(0, 4, 0)
	local screen, onScreen = camera:WorldToViewportPoint(world)
	if onScreen then
		edgeArrow.Visible = false
		return
	end
	-- Kierunek do celu w płaszczyźnie ekranu (cel za plecami: odwracamy)
	local viewport = camera.ViewportSize
	local center = viewport / 2
	local direction = Vector2.new(screen.X, screen.Y) - center
	if screen.Z < 0 then
		direction = -direction
	end
	if direction.Magnitude < 1 then
		direction = Vector2.new(0, 1)
	end
	direction = direction.Unit
	local halfW, halfH = center.X - EDGE_MARGIN, center.Y - EDGE_MARGIN
	local scale = math.min(halfW / math.max(math.abs(direction.X), 1e-3), halfH / math.max(math.abs(direction.Y), 1e-3))
	local position = center + direction * scale
	edgeArrow.Position = UDim2.fromOffset(position.X, position.Y)
	edgeArrow.Rotation = math.deg(math.atan2(direction.Y, direction.X))
	edgeArrow.Visible = true
end

function ObjectiveController.Init()
	local gui = UIKit.screenGui("Objective", 4, "hud")
	objectiveLabel = UIKit.label("Objective", {
		Size = UDim2.fromOffset(660, 34),
		Position = UDim2.new(0.5, 0, 0, 140),
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
	ClientState.OnRoundEvent(function(kind, data)
		if kind == "tutorial" and type(data) == "table" and data.step == "hide" then
			HUDController.Alert("👂 Słyszysz? Ktoś idzie...", "bad")
			ObjectiveController.Force("🚪 Szybko! Schowaj się w szafie!")
		end
	end)
	-- Strzałka podskakuje, pod nią widać odległość; poza ekranem strzałka na brzegu
	RunService.RenderStepped:Connect(function()
		updateEdgeArrow()
		if not marker.Enabled or not marker.Adornee then
			return
		end
		markerArrow.Position = UDim2.fromOffset(0, math.abs(math.sin(os.clock() * 4)) * -10)
		local root = rootPart()
		local target = marker.Adornee :: BasePart
		if root then
			markerDistance.Text = math.floor((target.CFrame.Position - root.CFrame.Position).Magnitude / 3) .. " m"
		end
	end)
end

return ObjectiveController

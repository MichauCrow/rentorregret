-- Efekty w świecie: iskierki, kolorowe "wyskakujące" napisy +3, konfetti, deszcz monet i dźwięki.
-- Kaucjomat: butelki wlatują do automatu jedna po drugiej, ekran je liczy, na koniec sypią się monety
-- (a w Halloween czasem wyskakują też dynie z bonusem).
-- Czysto wizualne: o stanie gry decyduje wyłącznie serwer.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AssetsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AssetsConfig"))
local JobsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("JobsConfig"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local CleanFxController = {}

local SOUND_BY_KIND = {
	trash = "CleanTrash",
	stain = "CleanStain",
	dishes = "CleanDishes",
	window = "CleanStain",
	allClean = "AllClean",
}
local MAX_FX_DISTANCE = 80
local RAINBOW = {
	Color3.fromRGB(255, 80, 120),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(90, 230, 100),
	Color3.fromRGB(80, 180, 255),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 140, 40),
}
local RAINBOW_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, RAINBOW[1]),
	ColorSequenceKeypoint.new(0.25, RAINBOW[2]),
	ColorSequenceKeypoint.new(0.5, RAINBOW[3]),
	ColorSequenceKeypoint.new(0.75, RAINBOW[4]),
	ColorSequenceKeypoint.new(1, RAINBOW[5]),
})
local GOLD = Color3.fromRGB(255, 210, 50)
local GRASS = Color3.fromRGB(150, 255, 110)
local BOTTLES = JobsConfig.Jobs.cans
local SCREEN_IDLE = if BOTTLES.halloween then "WRZUĆ BUTELKI! 👻" else "WRZUĆ BUTELKI!"
local SCREEN_GLOW = if BOTTLES.halloween then Color3.fromRGB(255, 160, 40) else Color3.fromRGB(120, 255, 170)
local BOTTLE_GLASS = Color3.fromRGB(190, 235, 255)

local colorIndex = 0
local kaucjomatToken = 0

local function nextColor(): Color3
	colorIndex = colorIndex % #RAINBOW + 1
	return RAINBOW[colorIndex]
end

-- parent = nil: dźwięk bez kierunku (jak w interfejsie)
local function playKey(key: string, parent: Instance?, speed: number?, volume: number?)
	local soundId = AssetsConfig.Sounds[key]
	if type(soundId) ~= "string" or soundId == "" or not SoundController.SfxEnabled() then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or (AssetsConfig.Volumes and AssetsConfig.Volumes[key]) or 0.6
	sound.PlaybackSpeed = speed or 1
	sound.RollOffMaxDistance = 60
	sound.Parent = parent or SoundService
	sound:Play()
	local maxLength = AssetsConfig.SoundMaxLength and AssetsConfig.SoundMaxLength[key]
	if maxLength then
		task.delay(maxLength, function()
			if sound.Parent then
				TweenService:Create(sound, TweenInfo.new(0.3), { Volume = 0 }):Play()
			end
		end)
	end
	Debris:AddItem(sound, 5)
end

local function anchorAt(position: Vector3, lifetime: number): Part
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = Workspace
	Debris:AddItem(anchor, lifetime)
	return anchor
end

local function sparkle(position: Vector3, count: number, color: any)
	local anchor = anchorAt(position, 2.5)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = AssetsConfig.Textures.Sparkle
	emitter.Color = if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(count)
	return anchor
end

-- Kolorowe konfetti wystrzelone w górę, opada z grawitacją
local function confetti(position: Vector3, count: number)
	local anchor = anchorAt(position, 4)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = AssetsConfig.Textures.Sparkle
	emitter.Color = RAINBOW_SEQUENCE
	emitter.LightEmission = 0.5
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0.4) })
	emitter.Lifetime = NumberRange.new(1.4, 2.2)
	emitter.Speed = NumberRange.new(16, 26)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -28, 0)
	emitter.Drag = 1.5
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-300, 300)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(count)
end

-- Złote monety wyskakują i spadają
local function coinBurst(position: Vector3, count: number)
	for i = 1, count do
		local coin = Instance.new("Part")
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.18, 0.9, 0.9)
		coin.Color = GOLD
		coin.Material = Enum.Material.SmoothPlastic
		coin.Reflectance = 0.3
		coin.Anchored = true
		coin.CanCollide = false
		coin.CanQuery = false
		coin.CanTouch = false
		coin.CFrame = CFrame.new(position)
		coin.Parent = Workspace
		local angle = (i / count) * math.pi * 2
		local peak = position + Vector3.new(math.cos(angle) * 2.5, 2.5 + math.random() * 2, math.sin(angle) * 1.5 + 2)
		local rise = TweenService:Create(coin, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(peak) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
		})
		rise:Play()
		rise.Completed:Once(function()
			TweenService:Create(coin, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(peak.X, position.Y - 1.5, peak.Z) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
				Transparency = 1,
			}):Play()
		end)
		Debris:AddItem(coin, 1.2)
	end
end

-- Napis wyskakuje z "boing", unosi się i znika
local function floatingText(anchor: BasePart, text: string, color: Color3, big: boolean?)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = if big then UDim2.fromOffset(240, 90) else UDim2.fromOffset(140, 56)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.3, 0.3)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Rotation = math.random(-12, 12)
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(40, 20, 70)
	stroke.Parent = label

	TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
	local info = TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.25)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, 4.5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
end

local function kaucjomatScreen(): TextLabel?
	local map = Workspace:FindFirstChild("Map")
	local machine = map and map:FindFirstChild("Kaucjomat")
	local screen = machine and machine:FindFirstChild("Screen")
	local gui = screen and screen:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChild("Label")
	return if label and label:IsA("TextLabel") then label else nil
end

-- Dynie wyskakują z tacki, odbijają się przed automatem i znikają
local function pumpkinPop(tray: Vector3, pumpkins: number)
	for i = 1, pumpkins do
		task.delay((i - 1) * 0.25, function()
			local pumpkin = Instance.new("Part")
			pumpkin.Shape = Enum.PartType.Ball
			pumpkin.Size = Vector3.new(1.1, 1.1, 1.1)
			pumpkin.Color = Color3.fromRGB(255, 120, 20)
			pumpkin.Material = Enum.Material.SmoothPlastic
			pumpkin.Anchored = true
			pumpkin.CanCollide = false
			pumpkin.CanQuery = false
			pumpkin.CanTouch = false
			pumpkin.CFrame = CFrame.new(tray)
			local stem = Instance.new("Part")
			stem.Size = Vector3.new(0.18, 0.35, 0.18)
			stem.Color = Color3.fromRGB(70, 140, 40)
			stem.Material = Enum.Material.SmoothPlastic
			stem.CanCollide = false
			stem.CanQuery = false
			stem.CanTouch = false
			stem.Massless = true
			stem.CFrame = pumpkin.CFrame * CFrame.new(0, 0.62, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = pumpkin
			weld.Part1 = stem
			weld.Parent = stem
			stem.Parent = pumpkin
			pumpkin.Parent = Workspace
			Debris:AddItem(pumpkin, 3.5)
			local side = (i % 2 == 0) and 1 or -1
			local peak = tray + Vector3.new(side * (0.8 + i * 0.5), 3.2, 2)
			local land = tray + Vector3.new(side * (1.2 + i * 0.7), -1.05, 3.5)
			local up = TweenService:Create(pumpkin, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(peak) })
			up:Play()
			up.Completed:Once(function()
				local down = TweenService:Create(pumpkin, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = CFrame.new(land) })
				down:Play()
				down.Completed:Once(function()
					local anchor = sparkle(land + Vector3.new(0, 0.8, 0), 18, Color3.fromRGB(255, 150, 30))
					floatingText(anchor, "🎃 +" .. tostring(BOTTLES.pumpkinBonus or 0), Color3.fromRGB(255, 150, 30))
					playKey("Coins", nil, 1.3)
					task.delay(1.5, function()
						if pumpkin.Parent then
							TweenService:Create(pumpkin, TweenInfo.new(0.4), { Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 }):Play()
							stem.Transparency = 1
						end
					end)
				end)
			end)
		end)
	end
end

-- Butelki lecą łukiem od gracza do otworu, ekran liczy, na koniec monety, konfetti i dynie
local function playKaucjomat(slotPosition: Vector3, earned: number, count: number, pumpkins: number)
	count = math.clamp(math.floor(count), 1, 30)
	kaucjomatToken += 1
	local token = kaucjomatToken
	local screen = kaucjomatScreen()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local from = if root then root.Position + Vector3.new(0, 1, 0) else slotPosition + Vector3.new(0, 2, 5)
	local flight = 0.4
	local gap = math.clamp(1.8 / count, 0.07, 0.15)
	local inside = CFrame.new(slotPosition) * CFrame.Angles(0, math.rad(90), 0)

	task.spawn(function()
		for i = 1, count do
			-- Butelka: przezroczysty korpus i kolorowa nakrętka (przyspawana, leci razem z nią)
			local can = Instance.new("Part")
			can.Shape = Enum.PartType.Cylinder
			can.Size = Vector3.new(1.3, 0.6, 0.6)
			can.Color = BOTTLE_GLASS
			can.Material = Enum.Material.Glass
			can.Transparency = 0.3
			can.Reflectance = 0.2
			can.Anchored = true
			can.CanCollide = false
			can.CanQuery = false
			can.CanTouch = false
			can.CFrame = CFrame.new(from)
			local cap = Instance.new("Part")
			cap.Shape = Enum.PartType.Cylinder
			cap.Size = Vector3.new(0.25, 0.4, 0.4)
			cap.Color = RAINBOW[i % #RAINBOW + 1]
			cap.Material = Enum.Material.SmoothPlastic
			cap.CanCollide = false
			cap.CanQuery = false
			cap.CanTouch = false
			cap.Massless = true
			cap.CFrame = can.CFrame * CFrame.new(0.75, 0, 0)
			local capWeld = Instance.new("WeldConstraint")
			capWeld.Part0 = can
			capWeld.Part1 = cap
			capWeld.Parent = cap
			cap.Parent = can
			can.Parent = Workspace
			Debris:AddItem(can, 2)
			local mid = (from + slotPosition) / 2 + Vector3.new(0, 3, 0)
			local up = TweenService:Create(can, TweenInfo.new(flight / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(mid) * CFrame.Angles(0, 0, math.rad(180)),
			})
			up:Play()
			up.Completed:Once(function()
				local down = TweenService:Create(can, TweenInfo.new(flight / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = inside,
					Size = Vector3.new(0.6, 0.35, 0.35),
				})
				down:Play()
				down.Completed:Once(function()
					can:Destroy()
					if token ~= kaucjomatToken then
						return
					end
					if screen then
						screen.Text = "BUTELKI: " .. i
						screen.TextColor3 = RAINBOW[i % #RAINBOW + 1]
					end
					sparkle(slotPosition + Vector3.new(0, 0, 0.3), 6, RAINBOW_SEQUENCE)
					-- Każda kolejna butelka brzmi odrobinę wyżej
					playKey("UIClick", nil, 0.9 + i * 0.05, 0.45)
				end)
			end)
			task.wait(gap)
		end
		task.wait(flight + 0.2)
		if token ~= kaucjomatToken then
			return
		end
		if screen then
			screen.Text = "+" .. earned .. " MONET!"
			screen.TextColor3 = GOLD
		end
		local tray = slotPosition + Vector3.new(0, -2, 0.3)
		local anchor = sparkle(tray, 35, GOLD)
		confetti(slotPosition + Vector3.new(0, 1, 1), 60)
		coinBurst(tray, math.clamp(count, 6, 14))
		floatingText(anchor, "+" .. earned .. " 💰", GOLD, true)
		playKey("Coins", nil)
		playKey("Success", nil)
		if pumpkins > 0 then
			pumpkinPop(tray, math.min(pumpkins, 5))
		end
		task.delay(3, function()
			if token == kaucjomatToken and screen then
				screen.Text = SCREEN_IDLE
				screen.TextColor3 = SCREEN_GLOW
			end
		end)
	end)
end

-- extra: kolor iskierek z kosmetyku gracza (Color3) albo liczba butelek dla kaucjomatu;
-- extra2: liczba dyń z kaucjomatu (Halloween)
function CleanFxController.Play(position: any, kind: any, points: any, extra: any, extra2: any)
	if typeof(position) ~= "Vector3" or type(kind) ~= "string" then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > MAX_FX_DISTANCE then
		return
	end
	if kind == "kaucjomat" then
		playKaucjomat(position, tonumber(points) or 0, tonumber(extra) or 1, math.clamp(math.floor(tonumber(extra2) or 0), 0, 30))
		return
	end
	if kind == "allClean" then
		local anchor = sparkle(position + Vector3.new(0, 3, 0), 60, GOLD)
		confetti(position + Vector3.new(0, 2, 0), 80)
		floatingText(anchor, "CZYSTO! ✨", GOLD, true)
		playKey(SOUND_BY_KIND[kind], anchor)
		return
	end
	if kind == "pet" then
		local anchor = sparkle(position, 30, RAINBOW_SEQUENCE)
		confetti(position, 40)
		floatingText(anchor, "BRAWO! 💖", nextColor(), true)
		playKey("Success", nil)
		return
	end
	if kind == "grass" then
		local anchor = sparkle(position + Vector3.new(0, 1, 0), 8, GRASS)
		if type(points) == "number" and points > 0 then
			floatingText(anchor, "+" .. points, GRASS)
		end
		return
	end
	local color = if typeof(extra) == "Color3" then extra else nil
	local anchor = sparkle(position, 22, color or RAINBOW_SEQUENCE)
	if type(points) == "number" and points > 0 then
		floatingText(anchor, "+" .. points, nextColor())
	end
	local key = SOUND_BY_KIND[kind]
	if key then
		playKey(key, anchor, 0.95 + math.random() * 0.15)
	else
		-- Krótkie "pyk" przy butelkach, kwiatkach i zadaniach prac
		playKey("UIClick", anchor, 1.3 + math.random() * 0.3, 0.4)
	end
end

return CleanFxController

-- Wypożyczalnia hulajnóg elektrycznych: stacje na chodnikach, start 5 monet + 1 moneta co 10 s jazdy.
-- Hulajnoga jest przyspawana pod nogami gracza (szybsze chodzenie), Shift = wheelie (przód w górę).
-- Jazda kończy się przyciskiem, gdy zabraknie monet, przy starcie pracy albo po śmierci postaci.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local AssetsConfig = require(ReplicatedStorage.Shared.Config.AssetsConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local JobService = require(Services.JobService)
local ScooterBuilder = require(ServerScriptService.World.ScooterBuilder)

local RentalService = {}

local START_FEE = 5
local TICK_FEE = 1
local TICK_SECONDS = 10
local RIDE_SPEED = 28
local WHEELIE_ANGLE = math.rad(28)
local STATION_USE_DISTANCE = 12
-- Stacje: punkt na chodniku i kierunek hulajnogi (yaw)
local STATIONS = {
	{ position = Vector3.new(-75, 0.4, 6), yaw = math.rad(90) },
	{ position = Vector3.new(75, 0.4, 6), yaw = math.rad(90) },
	{ position = Vector3.new(-10, 0.4, 108.5), yaw = math.rad(-90) },
	{ position = Vector3.new(95, 0.4, 108.5), yaw = math.rad(-90) },
	{ position = Vector3.new(-40, 0.4, -96.5), yaw = math.rad(90) },
	{ position = Vector3.new(60, 0.4, 184.5), yaw = math.rad(-90) },
}
-- Wygląd jak popularna czarna hulajnoga elektryczna z grubymi kołami i pomarańczowymi akcentami
local COLORS = {
	frame = Color3.fromRGB(38, 40, 46),
	grip = Color3.fromRGB(20, 20, 24),
	accent = Color3.fromRGB(255, 120, 30),
	tire = Color3.fromRGB(28, 28, 32),
	metal = Color3.fromRGB(150, 155, 165),
	display = Color3.fromRGB(80, 220, 255),
}

local rides = {} -- [player] = { model, weld, baseC0, paid, started, nextCharge, character, humanoid }

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function buildStations(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "ScooterStations"
	for index, station in STATIONS do
		local ground = CFrame.new(station.position) * CFrame.Angles(0, station.yaw, 0)
		-- Zaparkowana hulajnoga na nóżce (lekko przechylona)
		local model = ScooterBuilder.Kick(ground * CFrame.Angles(0, 0, math.rad(6)), true)
		model.Name = "Scooter_" .. index
		local stand = Instance.new("Part")
		stand.Name = "Kickstand"
		stand.Size = Vector3.new(0.12, 0.9, 0.12)
		stand.Color = COLORS.metal
		stand.Material = Enum.Material.Metal
		stand.Anchored = true
		stand.CanCollide = false
		stand.CFrame = ground * CFrame.new(-0.7, 0.4, 0.3) * CFrame.Angles(0, 0, math.rad(-25))
		stand.Parent = model
		for _, child in model:GetDescendants() do
			if child:IsA("BasePart") then
				child.Anchored = true
			end
		end
		-- Słupek stacji z napisem
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Size = Vector3.new(0.6, 5, 0.6)
		post.Color = COLORS.frame
		post.Material = Enum.Material.Metal
		post.Anchored = true
		post.CFrame = ground * CFrame.new(1.8, 2.5, -1.5)
		post.Parent = model
		local sign = Instance.new("Part")
		sign.Name = "Sign"
		sign.Size = Vector3.new(0.3, 1.6, 2.6)
		sign.Color = COLORS.accent
		sign.Anchored = true
		sign.CFrame = ground * CFrame.new(1.8, 5.4, -1.5)
		sign.Parent = model
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 50
			gui.Parent = sign
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.Text = "🛴 HULAJNOGI"
			label.Parent = gui
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RentPrompt"
		prompt.ActionText = string.format("Jedź (%d 💰)", START_FEE)
		prompt.ObjectText = "Hulajnoga elektryczna"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = model.PrimaryPart
		prompt.Triggered:Connect(function(player)
			RentalService.StartRide(player, index)
		end)
		model.Parent = folder
	end
	folder.Parent = parent
end

local function send(player: Player, action: string, payload)
	RemoteService.Event(RemoteNames.Events.RentalState):FireClient(player, action, payload)
end

local function formatTime(seconds: number): string
	seconds = math.floor(seconds)
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function RentalService.StopRide(player: Player, reason: string?)
	local ride = rides[player]
	if not ride then
		return
	end
	rides[player] = nil
	ScooterBuilder.Detach(ride.vehicle)
	if ride.humanoid and ride.humanoid.Parent and ride.humanoid.Health > 0 then
		ride.humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
	end
	if ride.character then
		ride.character:SetAttribute("Riding", nil)
	end
	send(player, "stop", { reason = reason })
	if player.Parent then
		local text = string.format("🛴 Koniec jazdy: %s, zapłacono %d 💰.", formatTime(os.clock() - ride.started), ride.paid)
		if reason == "coins" then
			text = "🛴 Skończyły się monety. " .. text
		elseif reason == "job" then
			text = "🛴 Zaczynasz pracę, hulajnoga wraca na stację. " .. text
		end
		StateService.Notify(player, text, "info")
	end
end

function RentalService.StartRide(player: Player, stationIndex: number)
	local station = STATIONS[stationIndex]
	local character = player.Character
	local root = getRoot(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not station or not root or not humanoid or humanoid.Health <= 0 or rides[player] then
		return
	end
	if (root.Position - station.position).Magnitude > STATION_USE_DISTANCE then
		return
	end
	if JobService.GetSession(player) ~= nil then
		StateService.Notify(player, "Najpierw skończ pracę, potem jazda!", "warn")
		return
	end
	if not EconomyService.TrySpend(player, START_FEE, "rental") then
		StateService.Notify(player, string.format("Za mało monet (potrzeba %d 💰).", START_FEE), "warn")
		return
	end
	local ride = ScooterBuilder.Attach(character, "kick")
	if not ride then
		EconomyService.AddCoins(player, START_FEE, "rental:refund")
		return
	end
	local soundId = AssetsConfig.Sounds.ScooterEngine
	if type(soundId) == "string" and soundId ~= "" then
		-- Silnik elektryczny: ten sam dźwięk, ale wyżej i ciszej
		local motor = Instance.new("Sound")
		motor.Name = "Motor"
		motor.SoundId = soundId
		motor.Looped = true
		motor.PlaybackSpeed = 1.7
		motor.Volume = (AssetsConfig.Volumes.ScooterEngine or 0.35) * 0.5
		motor.RollOffMaxDistance = 40
		motor.Parent = ride.model.PrimaryPart
		motor:Play()
	end
	humanoid.WalkSpeed = RIDE_SPEED
	character:SetAttribute("Riding", true)
	local now = os.clock()
	rides[player] = {
		vehicle = ride,
		paid = START_FEE,
		started = now,
		nextCharge = now + TICK_SECONDS,
		character = character,
		humanoid = humanoid,
	}
	send(player, "start", { fee = START_FEE, perTick = TICK_FEE, tickSeconds = TICK_SECONDS, paid = START_FEE })
	StateService.Notify(player, string.format("🛴 Jazda! Shift = wheelie. Opłata: %d 💰 co %d s.", TICK_FEE, TICK_SECONDS), "good")
end

local function setWheelie(player: Player, on: boolean)
	local ride = rides[player]
	if ride then
		ScooterBuilder.SetWheelie(ride.vehicle, on, WHEELIE_ANGLE)
	end
end

local function onAction(player: Player, action: any, value: any)
	if action == "stop" then
		RentalService.StopRide(player, "button")
	elseif action == "wheelie" and type(value) == "boolean" then
		setWheelie(player, value)
	end
end

local function tick()
	local now = os.clock()
	for player, ride in rides do
		if not player.Parent or player.Character ~= ride.character or not ride.humanoid.Parent or ride.humanoid.Health <= 0 then
			RentalService.StopRide(player, "reset")
		elseif JobService.GetSession(player) ~= nil then
			RentalService.StopRide(player, "job")
		elseif now >= ride.nextCharge then
			if EconomyService.TrySpend(player, TICK_FEE, "rental") then
				ride.paid += TICK_FEE
				ride.nextCharge += TICK_SECONDS
				send(player, "tick", { paid = ride.paid })
			else
				RentalService.StopRide(player, "coins")
			end
		end
	end
end

function RentalService.StationPosition(index: number): Vector3?
	local station = STATIONS[index]
	return station and station.position
end

function RentalService.IsRiding(player: Player): boolean
	return rides[player] ~= nil
end

function RentalService.Init()
	buildStations(Workspace:FindFirstChild("Map") or Workspace)
	RemoteService.OnServerEvent(RemoteNames.Events.RentalAction, 10, onAction)
end

function RentalService.Start()
	Players.PlayerRemoving:Connect(function(player)
		rides[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			tick()
		end
	end)
end

return RentalService

-- Rzadkie zlecenia (od miesiąca 3): pojawiają się same w losowym momencie miesiąca,
-- mają limit czasu i nagrodę = najlepsza stawka miesiąca x 2.5. Działają równolegle ze zmianami w pracy.
-- Obiekty zlecenia są osobne dla gracza (folder z atrybutem JobOwner, inni widzą je wyblakłe).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local ApartmentConfig = require(ReplicatedStorage.Shared.Config.ApartmentConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Format = require(ReplicatedStorage.Shared.Modules.Format)
local ApartmentBuilder = require(ServerScriptService.World.ApartmentBuilder)
local PropBuilder = require(ServerScriptService.World.PropBuilder)
local HoldPrompt = require(ServerScriptService.Lib.HoldPrompt)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local ProgressService = require(Services.ProgressService)

local RareContractService = {}

local RARE = JobsConfig.RareContracts
local MIN_DELAY_AFTER_PREVIOUS = 20

local active = {} -- [player] = zlecenie
local schedule = {} -- [player] = { month, offered, nextAt }
local rng = Random.new()

local function maxPerMonth(month: number): number
	return if month >= RARE.lateFromMonth then RARE.maxPerMonthLate else RARE.maxPerMonthEarly
end

local function pickType(): string
	local total = 0
	for _, definition in RARE.types do
		total += definition.weight
	end
	local roll = rng:NextNumber(0, total)
	for typeId, definition in RARE.types do
		if roll <= definition.weight then
			return typeId
		end
		roll -= definition.weight
	end
	return "cat"
end

local function removeContract(player: Player)
	local contract = active[player]
	if contract then
		active[player] = nil
		contract.folder:Destroy()
	end
end

local function complete(player: Player, contract)
	if active[player] ~= contract then
		return
	end
	removeContract(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.stats.rareDone += 1
	ProgressService.Record(player, "rare", 1)
	EconomyService.AddCoins(player, contract.reward, "rare:" .. contract.type)
	local message = string.format("⭐ Zlecenie wykonane: %s! +%s monet", contract.name, Format.Number(contract.reward))
	if contract.tokens then
		data.tokens += contract.tokens
		message ..= string.format(" i +%d %s", contract.tokens, Format.Plural(contract.tokens, "klucz", "klucze", "kluczy"))
	end
	if contract.secret and not data.secrets[contract.secret] then
		data.secrets[contract.secret] = true
		message ..= ". Sekret odkryty!"
	end
	StateService.Notify(player, message, "good")
	StateService.Push(player)
end

local function ownedBy(contract, player: Player): boolean
	return active[player] == contract
end

-- Budowanie zleceń ---------------------------------------------------------------

local builders = {}

function builders.cat(player: Player, contract, definition)
	-- Drzewa w parku to modele z kilkoma kępami liści: kot siada na najwyższej
	local trees = {}
	for _, child in Workspace.Map.Park:GetChildren() do
		if child.Name == "Leaves" and child:IsA("BasePart") then
			table.insert(trees, child)
		elseif child:IsA("Model") and (child.Name == "Tree" or child.Name == "BigTree") then
			local top = nil
			for _, part in child:GetChildren() do
				if part.Name == "Leaves" and part:IsA("BasePart") and (not top or part.Position.Y > top.Position.Y) then
					top = part
				end
			end
			if top then
				table.insert(trees, top)
			end
		end
	end
	assert(#trees > 0, "Brak drzew w parku")
	local leaves = trees[rng:NextInteger(1, #trees)]
	local cat = PropBuilder.Cat(CFrame.new(leaves.Position + Vector3.new(0, leaves.Size.Y / 2 + 0.3, 0)))
	cat.Parent = contract.folder
	local base = Vector3.new(leaves.Position.X, 0, leaves.Position.Z)
	local ladder = PropBuilder.Ladder(CFrame.new(base + Vector3.new(1.4, 3.6, 0)) * CFrame.Angles(0, 0, math.rad(-12)))
	HoldPrompt.Create(ladder, { action = "Ściągnij kota", object = "Drabina", hold = definition.hold, activation = 8, maxDistance = 12 }, function(who)
		if who == player and ownedBy(contract, player) then
			RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, ladder.Position, "cat", 0)
			complete(player, contract)
		end
	end)
	ladder.Parent = contract.folder
	contract.hint = "Kot utknął na drzewie w parku. Szukaj 🐱 i drabiny!"
end

function builders.party(player: Player, contract, definition)
	local houses = Workspace.Map.JobSites.Houses:GetChildren()
	local house = houses[rng:NextInteger(1, #houses)]
	local door = house.Body.DoorAttachment.WorldPosition
	contract.remaining = definition.trash
	local trashHold = ApartmentConfig.Dirt.trash.holdTime
	for _ = 1, definition.trash do
		local x = door.X + rng:NextNumber(-6, 6)
		local z = door.Z + rng:NextNumber(-3, 3)
		local trash = ApartmentBuilder.CreateDirt("trash", CFrame.new(x, 0.9, z))
		trash.Name = "PartyTrash"
		HoldPrompt.Create(trash, { action = "Podnieś", object = "Śmieci po imprezie", hold = trashHold }, function(who)
			if who ~= player or not ownedBy(contract, player) or not trash.Parent then
				return
			end
			local position = trash.Position
			trash:Destroy()
			contract.remaining -= 1
			RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, position, "trash", 1)
			if contract.remaining <= 0 then
				complete(player, contract)
			else
				StateService.Push(player)
			end
		end)
		trash.Parent = contract.folder
	end
	local marker = Instance.new("Part")
	marker.Name = "PartyMarker"
	marker.Size = Vector3.new(1, 1, 1)
	marker.Position = door + Vector3.new(0, 9, 0)
	marker.Transparency = 1
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 46)
	gui.AlwaysOnTop = true
	gui.Parent = marker
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 120, 200)
	label.Text = "🎉 Tutaj!"
	label.Parent = gui
	marker.Parent = contract.folder
	contract.hint = "Posprzątaj śmieci po imprezie przy domu nr " .. tostring(house:GetAttribute("HouseNumber"))
end

function builders.goldenCan(player: Player, contract, definition)
	local area = Workspace.Map.Park.CanArea
	local position = Vector3.new(
		area.Position.X + rng:NextNumber(-area.Size.X / 2, area.Size.X / 2),
		0.9,
		area.Position.Z + rng:NextNumber(-area.Size.Z / 2, area.Size.Z / 2)
	)
	local can = PropBuilder.GoldenCan(position)
	HoldPrompt.Create(can, { action = "Podnieś", object = "Złota puszka", hold = definition.hold }, function(who)
		if who == player and ownedBy(contract, player) then
			RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, can.Position, "allClean", 0)
			complete(player, contract)
		end
	end)
	can.Parent = contract.folder
	contract.tokens = definition.tokens
	contract.secret = definition.secret
	contract.hint = "Gdzieś w parku błyszczy złota puszka ✨"
end

local function offer(player: Player, data)
	if active[player] then
		return
	end
	local typeId = pickType()
	local definition = RARE.types[typeId]
	local folder = Instance.new("Folder")
	folder.Name = "Contract_" .. player.UserId
	folder:SetAttribute("JobOwner", player.UserId)
	folder.Parent = Workspace.JobObjects
	local reward = math.floor(EconomyConfig.GetBestRate(data.month) * RARE.rewardRateMultiplier * (definition.rewardFactor or 1) + 0.5)
	local contract = {
		type = typeId,
		name = definition.name,
		reward = reward,
		endsAt = os.clock() + definition.time,
		folder = folder,
	}
	active[player] = contract
	local ok, err = pcall(builders[typeId], player, contract, definition)
	if not ok then
		warn("[RareContractService] Nie udało się zbudować zlecenia " .. typeId .. ": " .. tostring(err))
		removeContract(player)
		return
	end
	data.monthly.rareOffered += 1
	StateService.Notify(
		player,
		string.format("⭐ Rzadkie zlecenie: %s! Nagroda: %s monet. %s", definition.name, Format.Number(reward), contract.hint),
		"info"
	)
	StateService.Push(player)
end

local function tick()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data then
			local contract = active[player]
			if contract then
				if now >= contract.endsAt then
					removeContract(player)
					StateService.Notify(player, "Zlecenie przepadło. Następne pojawi się innym razem!", "warn")
					StateService.Push(player)
				end
			elseif data.month >= RARE.minMonth and data.monthly.rareOffered < maxPerMonth(data.month) then
				local plan = schedule[player]
				if not plan or plan.month ~= data.month or plan.offered ~= data.monthly.rareOffered then
					plan = {
						month = data.month,
						offered = data.monthly.rareOffered,
						nextAt = math.max(data.monthElapsed + MIN_DELAY_AFTER_PREVIOUS, rng:NextInteger(RARE.offerWindow[1], RARE.offerWindow[2])),
					}
					schedule[player] = plan
				end
				if data.monthElapsed >= plan.nextAt and data.monthElapsed < GameConfig.MONTH_DURATION then
					offer(player, data)
				end
			end
		end
	end
end

function RareContractService.HasActive(player: Player): boolean
	return active[player] ~= nil
end

-- Zlecenie od razu, niezależnie od miesiąca (komendy testowe i zdarzenie "Prośba sąsiada")
function RareContractService.ForceOffer(player: Player)
	local data = DataService.Get(player)
	if data then
		offer(player, data)
	end
end

function RareContractService.Init()
	StateService.AddProvider(function(player, snapshot)
		local contract = active[player]
		if contract then
			snapshot.contract = {
				name = contract.name,
				reward = contract.reward,
				endsIn = math.max(0, contract.endsAt - os.clock()),
				remaining = contract.remaining,
			}
		end
	end)
end

function RareContractService.Start()
	Players.PlayerRemoving:Connect(function(player)
		removeContract(player)
		schedule[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
end

return RareContractService

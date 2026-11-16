-- Zbieracz butelek: praca bez wymagań i bez porażek, zawsze dostępna.
-- Butelki kaucyjne w parku (wspólne dla wszystkich), worek na 15 sztuk, oddawanie w kaucjomacie.
-- Serwer pilnuje: odległości, czasu przytrzymania, odstępu między butelkami i pojemności worka.
-- Worek to osobny licznik (nie sesja pracy), więc pełny worek nie blokuje innych prac.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Format = require(ReplicatedStorage.Shared.Modules.Format)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local StateService = require(Services.StateService)
local JobService = require(Services.JobService)
local ProgressService = require(Services.ProgressService)
local TutorialService = require(Services.TutorialService)
local CleaningService = require(Services.CleaningService)
local DataService = require(Services.DataService)
local EconomyService = require(Services.EconomyService)
local HoldPrompt = require(ServerScriptService.Lib.HoldPrompt)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)

local CanCollectorJob = {
	JobId = "cans",
}

local CONFIG = JobsConfig.Jobs.cans
-- Kolory etykiet i nakrętek butelek
local CAN_COLORS = {
	Color3.fromRGB(255, 70, 90),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(90, 230, 100),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 140, 40),
}

local cansFolder = nil
local wildFolder = nil -- rzadkie butelki w trawie między domami (osobno od parku)
local lawns = {}
local area = nil
local sellAttachment = nil
local slot = nil
local holdStarts = {} -- [player] = { can, time }
local lastPickup = {} -- [player] = os.clock()
local pendingRespawns = 0
local rng = Random.new()

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local bags = {} -- [player] = liczba butelek w worku

-- Pojemność worka gracza: zwykły worek albo największy kupiony w sklepie (Duży / Wielki worek)
local function capacityOf(player: Player): number
	local capacity = CONFIG.bagCapacity
	local data = DataService.Get(player)
	if data then
		for itemId, owned in data.equipment do
			local item = owned and ShopConfig.Items[itemId]
			if item and item.bagCapacity then
				capacity = math.max(capacity, item.bagCapacity)
			end
		end
	end
	return capacity
end

local function targetCount(): number
	return CONFIG.baseCans + CONFIG.cansPerExtraPlayer * math.max(0, #Players:GetPlayers() - 1)
end

local function onPickup(player: Player, can: BasePart)
	if not can.Parent then
		return
	end
	local root = getRoot(player)
	if not root or (root.Position - can.Position).Magnitude > CONFIG.pickupDistance then
		return
	end
	local now = os.clock()
	local hold = holdStarts[player]
	holdStarts[player] = nil
	if not hold or hold.can ~= can or now - hold.time < CONFIG.pickupHold * JobsConfig.HOLD_TOLERANCE then
		return
	end
	if lastPickup[player] and now - lastPickup[player] < CONFIG.minPickupInterval then
		return
	end

	local count = bags[player] or 0
	if count >= capacityOf(player) then
		StateService.Notify(player, "Worek pełny! Wrzuć butelki do kaucjomatu przy ulicy.", "warn")
		return
	end

	lastPickup[player] = now
	local position = can.Position
	local wild = can:GetAttribute("Wild") == true
	can:Destroy()
	bags[player] = count + 1
	TutorialService.Event(player, "canPicked")
	if not wild then
		pendingRespawns += 1
		task.delay(CONFIG.respawnDelay, function()
			pendingRespawns -= 1
		end)
	else
		StateService.Notify(player, "🍀 Rzadka butelka w trawie! +1 do worka", "good")
	end

	RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, position, if wild then "pet" else "can", if wild then 0 else 1)
	if bags[player] >= capacityOf(player) then
		StateService.Notify(player, "Worek pełny! Wrzuć butelki do kaucjomatu przy ulicy.", "info")
	end
	StateService.Push(player)
end

-- Butelki znalezione w śmieciach w mieszkaniu trafiają do worka (do limitu worka). Zwraca, ile dodano.
local function addBottles(player: Player, amount: number, position: Vector3?, silent: boolean?): number
	if amount <= 0 then
		return 0
	end
	local space = capacityOf(player) - (bags[player] or 0)
	local added = math.clamp(amount, 0, space)
	if added <= 0 then
		if not silent then
			StateService.Notify(player, "🍾 W śmieciach były butelki, ale worek jest pełny!", "info")
		end
		return 0
	end
	bags[player] = (bags[player] or 0) + added
	if silent then
		StateService.Push(player)
		return added
	end
	if position then
		RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, position, "bottles", added)
	end
	StateService.Notify(player, string.format("🍾 Znalezione w śmieciach: %d %s! Worek: %d/%d", added, Format.Plural(added, "butelka", "butelki", "butelek"), bags[player], capacityOf(player)), "good")
	StateService.Push(player)
	return added
end

-- Kosze w mieście ---------------------------------------------------------------------------
local bins = {} -- [kosz] = część kosza (Body)
local binReadyAt = {} -- [player] = { [kosz] = os.clock(), od kiedy można znowu szukać }
local binSearches = {} -- [player] = { bin, started }

local function rollLoot()
	local entries = {}
	local total = 0
	for _, entry in CONFIG.binLoot do
		local weight = entry.weight
		if entry.kind == "pumpkin" and not CONFIG.halloween then
			weight = 0
		elseif entry.kind == "coins" and not CONFIG.halloween then
			-- poza Halloween waga dyń przechodzi na monety
			for _, other in CONFIG.binLoot do
				if other.kind == "pumpkin" then
					weight += other.weight
				end
			end
		end
		if weight > 0 then
			table.insert(entries, { entry = entry, weight = weight })
			total += weight
		end
	end
	local roll = rng:NextNumber(0, total)
	for _, item in entries do
		if roll <= item.weight then
			return item.entry.kind, rng:NextInteger(item.entry.min, item.entry.max)
		end
		roll -= item.weight
	end
	return "coins", 3
end

local function onBinPrompt(player: Player, bin: BasePart)
	local readyAt = binReadyAt[player] and binReadyAt[player][bin]
	local now = os.clock()
	if readyAt and now < readyAt then
		StateService.Notify(player, string.format("🗑️ Ten kosz jest już pusty. Zajrzyj za %d s!", math.ceil(readyAt - now)), "info")
		return
	end
	binSearches[player] = { bin = bin, started = now }
	RemoteService.Event(RemoteNames.Events.TrashGame):FireClient(player, "open", { clicks = rng:NextInteger(CONFIG.binClicks[1], CONFIG.binClicks[2]) })
end

-- Koniec minigry: serwer losuje i daje nagrodę (klient tylko ją pokazuje)
local function onTrashAction(player: Player, action: any)
	local search = binSearches[player]
	if not search or not RemoteService.IsOneOf(action, { "done", "cancel" }) then
		return
	end
	binSearches[player] = nil
	if action == "cancel" then
		return
	end
	local root = getRoot(player)
	if os.clock() - search.started < CONFIG.binMinTime or not root or (root.Position - search.bin.Position).Magnitude > 16 then
		return
	end
	binReadyAt[player] = binReadyAt[player] or {}
	binReadyAt[player][search.bin] = os.clock() + CONFIG.binCooldown

	local kind, amount = rollLoot()
	local result = { kind = kind, amount = amount }
	if kind == "bottles" then
		local added = addBottles(player, amount, nil, true)
		if added < amount then
			-- Pełny worek: reszta butelek zamienia się w monety
			local coins = (amount - added) * CONFIG.payPerItem
			EconomyService.AddCoins(player, coins, "trashbin")
			result.coins = coins
		end
		result.added = added
	elseif kind == "coins" then
		EconomyService.AddCoins(player, amount, "trashbin")
	elseif kind == "pumpkin" then
		amount = CONFIG.pumpkinBonus
		result.amount = amount
		EconomyService.AddCoins(player, amount, "trashbin:pumpkin")
	elseif kind == "keys" then
		local data = DataService.Get(player)
		if data then
			data.tokens += amount
			StateService.Push(player)
		end
	end
	RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, search.bin.Position + Vector3.new(0, 2.5, 0), "bin", 0)
	RemoteService.Event(RemoteNames.Events.TrashGame):FireClient(player, "result", result)
end

local function onSell(player: Player)
	local root = getRoot(player)
	if not root or (root.Position - sellAttachment.WorldPosition).Magnitude > CONFIG.sellDistance then
		return
	end
	local count = bags[player] or 0
	if count <= 0 then
		StateService.Notify(player, "Nie masz butelek. Zbieraj je w parku!", "info")
		return
	end
	-- Halloween: za każdą butelkę serwer losuje, czy z tacki wypadnie dynia (bonus do wypłaty)
	local pumpkins = 0
	if CONFIG.halloween then
		for _ = 1, count do
			if rng:NextNumber() < CONFIG.pumpkinChance then
				pumpkins += 1
			end
		end
	end
	-- Wypłata z premiami/karami gracza (te same mnożniki co w pracach); działa też w trakcie innej zmiany
	bags[player] = 0
	local earned = math.floor((count * CONFIG.payPerItem + pumpkins * CONFIG.pumpkinBonus) * JobService.GetPayMultiplier(player) + 0.5)
	if earned > 0 then
		EconomyService.AddCoins(player, earned, "job:cans:sell")
		StateService.Push(player)
		-- Klient pokazuje butelki wpadające do automatu, licznik na ekranie i wyskakujące dynie
		RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, slot.Position, "kaucjomat", earned, count, pumpkins)
		ProgressService.Record(player, "cans", count)
		TutorialService.Event(player, "cansSold")
		StateService.Notify(
			player,
			string.format(
				"Kaucjomat przyjął %d %s: +%d %s",
				count,
				Format.Plural(count, "butelkę", "butelki", "butelek"),
				earned,
				Format.Plural(earned, "moneta", "monety", "monet")
			),
			"good"
		)
		if pumpkins > 0 then
			local bonus = pumpkins * CONFIG.pumpkinBonus
			StateService.Notify(
				player,
				string.format("🎃 Wypadło %d %s! W tym +%d monet bonusu", pumpkins, Format.Plural(pumpkins, "dynia", "dynie", "dyń"), bonus),
				"good"
			)
		end
	end
end

-- Butelka kaucyjna w punkcie (x, z); groundY = wysokość ziemi (park: 0.3). Domyślnie losowe miejsce w parku.
local function spawnCan(x: number?, z: number?, groundY: number?, folder: Instance?): BasePart
	if not x or not z then
		local size = area.Size
		local center = area.Position
		x = rng:NextNumber(center.X - size.X / 2, center.X + size.X / 2)
		z = rng:NextNumber(center.Z - size.Z / 2, center.Z + size.Z / 2)
	end
	local lift = (groundY or 0.3) - 0.3

	-- Butelka kaucyjna: przezroczysty korpus, kolorowa etykieta, szyjka i nakrętka (stoi pionowo)
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local color = CAN_COLORS[rng:NextInteger(1, #CAN_COLORS)]
	local can = Instance.new("Part")
	can.Name = "Bottle"
	can.Shape = Enum.PartType.Cylinder
	can.Size = Vector3.new(1.5, 0.72, 0.72)
	can.CFrame = CFrame.new(x, 1.05 + lift, z) * upright
	can.Color = Color3.fromRGB(190, 235, 255)
	can.Material = Enum.Material.Glass
	can.Transparency = 0.3
	can.Reflectance = 0.2
	can.Anchored = true
	can.CanCollide = false
	can.CanTouch = false
	local function bottlePart(name: string, size: Vector3, y: number, partColor: Color3)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.CFrame = CFrame.new(x, y + lift, z) * upright
		p.Color = partColor
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Parent = can
	end
	bottlePart("Label", Vector3.new(0.55, 0.76, 0.76), 1.0, color)
	bottlePart("Neck", Vector3.new(0.4, 0.36, 0.36), 1.98, Color3.fromRGB(190, 235, 255))
	bottlePart("Cap", Vector3.new(0.2, 0.42, 0.42), 2.25, color)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Podnieś"
	prompt.ObjectText = "Butelka"
	prompt.HoldDuration = CONFIG.pickupHold
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.PromptButtonHoldBegan:Connect(function(player)
		holdStarts[player] = { can = can, time = os.clock() }
	end)
	prompt.Triggered:Connect(function(player)
		onPickup(player, can)
	end)
	prompt.Parent = can

	can.Parent = folder or cansFolder
	return can
end

-- Co jakiś czas na losowym trawniku pojawia się butelka (najwyżej CONFIG.wildMax naraz, każdy trawnik max 1)
local function spawnWild()
	if #wildFolder:GetChildren() >= (CONFIG.wildMax or 3) or #lawns == 0 then
		return
	end
	local used = {}
	for _, can in wildFolder:GetChildren() do
		used[can:GetAttribute("LawnIndex") or 0] = true
	end
	local free = {}
	for _, lawn in lawns do
		if not used[lawn:GetAttribute("LawnIndex")] then
			table.insert(free, lawn)
		end
	end
	if #free == 0 then
		return
	end
	local lawn = free[rng:NextInteger(1, #free)]
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(0, 3.2)
	local can = spawnCan(lawn.Position.X + math.cos(angle) * distance, lawn.Position.Z + math.sin(angle) * distance, lawn.Position.Y + lawn.Size.X / 2, wildFolder)
	can:SetAttribute("Wild", true)
	can:SetAttribute("LawnIndex", lawn:GetAttribute("LawnIndex"))
	-- Lekki błysk, żeby dało się ją wypatrzyć w trawie
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(190, 255, 200)
	sparkle.Parent = can
	-- Nikt nie podniósł? Po jakimś czasie znika
	task.delay(CONFIG.wildLifetime or 150, function()
		if can.Parent then
			can:Destroy()
		end
	end)
end

function CanCollectorJob.Init()
	local map = Workspace:WaitForChild("Map")
	area = map:WaitForChild("Park"):WaitForChild("CanArea")
	local machine = map:WaitForChild("Kaucjomat")
	sellAttachment = machine:WaitForChild("Counter"):WaitForChild("SellAttachment")
	slot = machine:WaitForChild("Slot")
	cansFolder = Instance.new("Folder")
	cansFolder.Name = "Cans"
	cansFolder.Parent = Workspace
	wildFolder = Instance.new("Folder")
	wildFolder.Name = "WildBottles"
	wildFolder.Parent = Workspace
	local lawnFolder = map:FindFirstChild("Lawns")
	if lawnFolder then
		for _, lawn in lawnFolder:GetChildren() do
			if lawn.Name == "Lawn" then
				table.insert(lawns, lawn)
			end
		end
	end

	-- Śmieci w mieszkaniu: losowo 0-3 butelki kaucyjne do worka osoby, która sprzątała
	CleaningService.OnCleaned(function(_owner, cleaner, kind)
		if kind ~= "trash" or typeof(cleaner) ~= "Instance" or not cleaner:IsA("Player") then
			return
		end
		local amount = CONFIG.trashBottles[rng:NextInteger(1, #CONFIG.trashBottles)]
		local root = getRoot(cleaner)
		addBottles(cleaner, amount, root and root.Position + Vector3.new(0, 2, 0))
	end)

	StateService.AddProvider(function(player, snapshot)
		local count = bags[player] or 0
		if count > 0 then
			snapshot.bag = { label = "Worek z butelkami", count = count, capacity = capacityOf(player) }
		end
	end)
end

function CanCollectorJob.Start()
	local trashBins = Workspace.Map:FindFirstChild("TrashBins")
	if trashBins then
		for _, bin in trashBins:GetChildren() do
			local body = bin:FindFirstChild("Body")
			if body then
				bins[bin] = body
				HoldPrompt.Create(body, { action = "Przeszukaj kosz", object = "Kosz na śmieci", hold = 0.3, activation = 8, maxDistance = 12 }, function(player)
					onBinPrompt(player, body)
				end)
			end
		end
	end
	RemoteService.OnServerEvent(RemoteNames.Events.TrashAction, 3, onTrashAction)
	sellAttachment:WaitForChild("SellPrompt").Triggered:Connect(onSell)
	Players.PlayerRemoving:Connect(function(player)
		bags[player] = nil
		binReadyAt[player] = nil
		binSearches[player] = nil
		holdStarts[player] = nil
		lastPickup[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(CONFIG.wildInterval[1], CONFIG.wildInterval[2]))
			spawnWild()
		end
	end)
	task.spawn(function()
		while true do
			local count = #cansFolder:GetChildren()
			while count + pendingRespawns < targetCount() do
				spawnCan()
				count += 1
			end
			task.wait(1)
		end
	end)
end

return CanCollectorJob

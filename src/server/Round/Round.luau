-- Jedna rozgrywka: własna kamienica, gracze (1-4), zegar do północy, monety, czynsz, szafy, duszki, potwory.
-- Tworzy ją RoundService. Cały stan rundy jest na serwerze; klient dostaje tylko RoundState do HUD.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local Format = require(ReplicatedStorage.Shared.Modules.Format)
local BuildingBuilder = require(ServerScriptService.World.BuildingBuilder)
local Parts = require(ServerScriptService.World.Parts)
local HoldPrompt = require(ServerScriptService.Lib.HoldPrompt)
local PlayerStateService = require(ServerScriptService.Services.PlayerStateService)
local RemoteService = require(ServerScriptService.Services.RemoteService)
local NeighborMonster = require(script.Parent.Monsters.Neighbor)
local CatMonster = require(script.Parent.Monsters.Cat)
local LandlordMonster = require(script.Parent.Monsters.Landlord)

local Round = {}
Round.__index = Round

local GHOST_TRANSPARENCY = 0.65
local STATE_INTERVAL = 0.25

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function within(position: Vector3, min: Vector3, max: Vector3): boolean
	return position.X >= min.X and position.X <= max.X and position.Y >= min.Y and position.Y <= max.Y and position.Z >= min.Z and position.Z <= max.Z
end

function Round.new(id: number, origin: Vector3, players: { Player }, parent: Instance, onFinished)
	local self = setmetatable({}, Round)
	self.id = id
	self.origin = origin
	self.onFinished = onFinished
	self.players = {}
	self.order = {}
	self.monsters = {}
	self.bags = {}
	self.phase = "play"
	self.timeLeft = GameConfig.ROUND_DURATION
	self.huntLeft = GameConfig.HUNT_DURATION
	self.rent = GameConfig.RENT_BASE + (#players - 1) * GameConfig.RENT_PER_EXTRA_PLAYER
	self.deposited = 0
	self.rentPaid = false
	self.paidAt = nil
	self.elapsed = 0
	self.alive = true
	self.building = BuildingBuilder.Build(origin, parent, math.random(1, 1e6))

	for _, player in players do
		local flashlight = PlayerStateService.UpgradeValue(player, "flashlight")
		self.players[player] = {
			status = "inside", -- inside | ghost | escaped | left
			carried = 0,
			deposited = 0,
			bonusDeposited = 0,
			found = 0,
			hasKey = false,
			hidden = nil, -- szafa, w której gracz siedzi
			flashlight = false,
			battery = flashlight.battery,
			batteryMax = flashlight.battery,
			lightRange = flashlight.range,
			capacity = PlayerStateService.UpgradeValue(player, "pockets"),
			hearing = PlayerStateService.UpgradeValue(player, "shoes"),
			lastPing = -math.huge,
			escapedUnpaid = false,
			finished = false,
		}
		table.insert(self.order, player)
	end
	return self
end

-- Pomocnicze ------------------------------------------------------------------------------------

function Round:Event(player: Player, kind: string, data: any?)
	RemoteService.Event("RoundEvent"):FireClient(player, kind, data)
end

function Round:EventAll(kind: string, data: any?)
	for player, state in self.players do
		if state.status ~= "left" and not state.finished then
			self:Event(player, kind, data)
		end
	end
end

function Round:Toast(player: Player, text: string, kind: string?)
	PlayerStateService.Notify(player, text, kind)
end

function Round:ToastAll(text: string, kind: string?)
	for player, state in self.players do
		if state.status ~= "left" and not state.finished then
			self:Toast(player, text, kind)
		end
	end
end

-- Numer piętra dla wysokości (0 = parter). Na schodach zaokrągla do najbliższego.
function Round:FloorOf(position: Vector3): number
	local relative = (position.Y - self.origin.Y) / BuildingBuilder.FLOOR_HEIGHT
	return math.clamp(math.floor(relative + 0.35), 0, BuildingBuilder.FLOORS - 1)
end

-- Gracze, których potwór może złapać: w środku, nie w szafie, z postacią
function Round:Targets()
	local list = {}
	for player, state in self.players do
		local root = rootOf(player)
		if state.status == "inside" and not state.hidden and root then
			table.insert(list, { player = player, root = root, state = state, floor = self:FloorOf(root.CFrame.Position) })
		end
	end
	return list
end

function Round:State(player: Player)
	return self.players[player]
end

-- Monety i meble --------------------------------------------------------------------------------

function Round:DistributeCoins()
	local building = self.building
	local total = BuildingBuilder.CoinsFor(self.rent)
	local weights = {}
	local sum = 0
	for i, spot in building.spots do
		spot.coins = 0
		if math.random() >= GameConfig.SPOT_EMPTY_CHANCE then
			local weight = (({ [0] = 0.6, [1] = 1, [2] = 1.4 })[spot.floor] or 1) * (0.5 + math.random())
			weights[i] = weight
			sum += weight
		end
	end
	for i, weight in weights do
		building.spots[i].coins = math.max(1, math.floor(total * weight / sum + 0.5))
	end
	-- Klucz do zamkniętego mieszkania: w losowym meblu (nigdy na parterze, żeby trzeba było pochodzić)
	local candidates = {}
	for _, spot in building.spots do
		if spot.floor >= 1 then
			table.insert(candidates, spot)
		end
	end
	if #candidates == 0 then
		candidates = building.spots
	end
	if #candidates > 0 then
		candidates[math.random(1, #candidates)].hasKey = true
	end
end

-- Gracz bierze monety z miejsca, ile zmieści w kieszeniach. Zwraca ile wziął.
function Round:TakeCoins(player: Player, amount: number): number
	local state = self.players[player]
	local room = state.capacity - state.carried
	local taken = math.clamp(amount, 0, room)
	state.carried += taken
	state.found += taken
	return taken
end

function Round:CanAct(player: Player): boolean
	local state = self.players[player]
	return self.alive and state ~= nil and state.status == "inside" and not state.hidden and self.phase ~= "ending"
end

function Round:SetupSpot(spot)
	local prompt
	prompt = HoldPrompt.Create(spot.part, { action = "Przeszukaj", object = spot.label, hold = GameConfig.SEARCH_TIME, activation = 8, maxDistance = 12 }, function(player)
		if not self:CanAct(player) or spot.searched then
			return
		end
		local state = self.players[player]
		local foundKey = false
		if spot.hasKey then
			spot.hasKey = false
			state.hasKey = true
			foundKey = true
			self:Event(player, "alert", { text = "🔑 Znalazłeś klucz! Gdzieś jest zamknięte mieszkanie...", kind = "good" })
		end
		if spot.coins > 0 then
			local taken = self:TakeCoins(player, spot.coins)
			spot.coins -= taken
			if taken > 0 then
				self:Event(player, "found", { amount = taken, position = spot.part.CFrame.Position })
			end
			if spot.coins > 0 then
				self:Toast(player, "🎒 Kieszenie pełne! Zanieś monety do skrzynki.", "warn")
				prompt.ObjectText = spot.label .. " (zostało " .. spot.coins .. ")"
				return
			end
		elseif not foundKey then
			self:Event(player, "found", { amount = 0, position = spot.part.CFrame.Position })
		end
		spot.searched = true
		spot.part:SetAttribute("Searched", true)
		prompt:Destroy()
	end)
	prompt:SetAttribute("Kind", "search")
	spot.part:SetAttribute("Spot", true)
	spot.prompt = prompt
end

function Round:SetupWardrobe(wardrobe)
	wardrobe.prompt = HoldPrompt.Create(wardrobe.part, { action = "Schowaj się", object = "Szafa", hold = 0, activation = 7, maxDistance = 10 }, function(player)
		local state = self.players[player]
		if not state or not self.alive then
			return
		end
		if wardrobe.occupant == player then
			self:LeaveWardrobe(player)
		elseif wardrobe.occupant == nil and self:CanAct(player) then
			self:EnterWardrobe(player, wardrobe)
		end
	end)
end

function Round:EnterWardrobe(player: Player, wardrobe)
	local state = self.players[player]
	local character = player.Character
	local root = rootOf(player)
	if not character or not root then
		return
	end
	wardrobe.occupant = player
	state.hidden = wardrobe
	self:SetFlashlight(player, false)
	character:PivotTo(wardrobe.inside)
	root.Anchored = true
	wardrobe.prompt.ActionText = "Wyjdź"
	wardrobe.eyes.Transparency = 0
	self:Event(player, "hidden", true)
end

function Round:LeaveWardrobe(player: Player)
	local state = self.players[player]
	local wardrobe = state and state.hidden
	if not wardrobe then
		return
	end
	wardrobe.occupant = nil
	state.hidden = nil
	wardrobe.prompt.ActionText = "Schowaj się"
	wardrobe.eyes.Transparency = 1
	local character = player.Character
	local root = rootOf(player)
	if character and root then
		root.Anchored = false
		if state.status == "inside" or state.status == "ghost" then
			character:PivotTo(wardrobe.outside)
		end
	end
	self:Event(player, "hidden", false)
end

function Round:SetupDeposit()
	local box = self.building.depositBox
	HoldPrompt.Create(box, { action = "Wpłać monety", object = "Skrzynka na czynsz", hold = 0.5, activation = 9, maxDistance = 13 }, function(player)
		if not self:CanAct(player) then
			return
		end
		local state = self.players[player]
		if state.carried <= 0 then
			self:Toast(player, "Nie masz monet. Przeszukuj meble!", "info")
			return
		end
		local amount = state.carried
		state.carried = 0
		if self.rentPaid then
			state.bonusDeposited += amount
		else
			state.deposited += amount
		end
		self.deposited += amount
		self:Event(player, "deposit", { amount = amount })
		if not self.rentPaid and self.deposited >= self.rent then
			self:PayRent(player)
		end
	end)
end

function Round:PayRent(player: Player)
	self.rentPaid = true
	self.paidAt = self.elapsed
	self:OpenFrontDoor()
	self:EventAll("paid", { by = player.DisplayName, time = Format.Time(self.elapsed) })
	self:ToastAll("🎉 Czynsz zapłacony! Drzwi otwarte. Uciekaj albo zbieraj dalej (premia x1.5)!", "good")
	if self.building.landlordModel then
		local label = self.building.landlordModel:FindFirstChildWhichIsA("BillboardGui", true)
		local text = label and label:FindFirstChildWhichIsA("TextLabel")
		if text then
			text.Text = "Pan Klucznik 😊"
		end
	end
end

function Round:OpenFrontDoor()
	local door = self.building.frontDoor
	if door and door.Parent then
		door.CanCollide = false
		door.Transparency = 0.85
		local billboard = door:FindFirstChildWhichIsA("BillboardGui")
		local label = billboard and billboard:FindFirstChild("Text")
		if label and label:IsA("TextLabel") then
			label.Text = "🚪 OTWARTE! Uciekaj do bramy"
			label.TextColor3 = Color3.fromRGB(120, 255, 140)
		end
	end
end

function Round:SetupLockedRoom()
	local locked = self.building.locked
	if not locked then
		return
	end
	HoldPrompt.Create(locked.door, { action = "Otwórz kluczem", object = "Zamknięte mieszkanie", hold = 1, activation = 8, maxDistance = 12 }, function(player)
		if not self:CanAct(player) or locked.opened then
			return
		end
		local state = self.players[player]
		if not state.hasKey then
			self:Toast(player, "🔒 Potrzebujesz klucza. Szukaj w meblach na piętrach!", "warn")
			return
		end
		state.hasKey = false
		locked.opened = true
		locked.door:Destroy()
		self:ToastAll("🔓 " .. player.DisplayName .. " otworzył zamknięte mieszkanie!", "good")
	end)
	locked.coins = math.floor(self.rent * GameConfig.JAR_COINS_RATIO)
	local jarPrompt
	jarPrompt = HoldPrompt.Create(locked.jar, { action = "Weź monety", object = "Słoik pełen monet", hold = 1, activation = 8, maxDistance = 12 }, function(player)
		if not self:CanAct(player) or not locked.opened or locked.coins <= 0 then
			return
		end
		local taken = self:TakeCoins(player, locked.coins)
		locked.coins -= taken
		if taken > 0 then
			self:Event(player, "found", { amount = taken, position = locked.jar.CFrame.Position, big = true })
		end
		if locked.coins <= 0 then
			jarPrompt:Destroy()
			locked.jar.Transparency = 0.8
		else
			self:Toast(player, "🎒 Kieszenie pełne! W słoiku zostało " .. locked.coins .. ".", "warn")
		end
	end)
end

-- Worek z monetami (i ewentualnie kluczem) po złapanym graczu
function Round:DropBag(position: Vector3, coins: number, hasKey: boolean)
	if coins <= 0 and not hasKey then
		return
	end
	local bag = Parts.Block(self.building.decor, "CoinBag", Vector3.new(1.6, 1.6, 1.6), CFrame.new(position.X, self:FloorY(position) + 0.8, position.Z), Color3.fromRGB(200, 160, 80), Enum.Material.Fabric)
	bag.Shape = Enum.PartType.Ball
	bag.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 210, 90)
	glow.Brightness = 1
	glow.Range = 8
	glow.Parent = bag
	local entry = { part = bag, coins = coins, hasKey = hasKey }
	table.insert(self.bags, entry)
	HoldPrompt.Create(bag, { action = "Podnieś", object = "Worek z monetami", hold = 0.5, activation = 7, maxDistance = 10 }, function(player)
		if not self:CanAct(player) or not bag.Parent then
			return
		end
		local state = self.players[player]
		if entry.hasKey then
			entry.hasKey = false
			state.hasKey = true
			self:Toast(player, "🔑 Masz klucz!", "good")
		end
		local taken = self:TakeCoins(player, entry.coins)
		entry.coins -= taken
		if taken > 0 then
			self:Event(player, "found", { amount = taken, position = bag.CFrame.Position })
		end
		if entry.coins <= 0 then
			bag:Destroy()
		end
	end)
	Debris:AddItem(bag, GameConfig.DROPPED_BAG_TIME)
end

function Round:FloorY(position: Vector3): number
	return self.building.floorY[self:FloorOf(position)]
end

-- Latarka ---------------------------------------------------------------------------------------

function Round:SetFlashlight(player: Player, on: boolean)
	local state = self.players[player]
	if not state then
		return
	end
	if on and (state.status ~= "inside" or state.hidden or state.battery <= 0) then
		on = false
	end
	state.flashlight = on
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local light = head:FindFirstChild("Flashlight")
	if not light then
		light = Instance.new("SpotLight")
		light.Name = "Flashlight"
		light.Face = Enum.NormalId.Front
		light.Angle = 55
		light.Brightness = 3.5
		light.Color = Color3.fromRGB(255, 245, 215)
		light.Shadows = true
		light.Parent = head
	end
	light.Range = state.lightRange
	light.Enabled = on
end

-- Duszki ---------------------------------------------------------------------------------------

local function setGhostLook(character: Model, ghost: boolean)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.Transparency = if ghost then GHOST_TRANSPARENCY else 0
			descendant.CastShadow = not ghost
		elseif descendant:IsA("Decal") then
			descendant.Transparency = if ghost then GHOST_TRANSPARENCY else 0
		end
	end
end

-- Potwór złapał gracza: zostaje duszkiem (bez krwi, bez umierania)
function Round:Catch(player: Player, monsterId: string)
	local state = self.players[player]
	if not state or state.status ~= "inside" or state.hidden or self.phase == "ending" then
		return
	end
	state.status = "ghost"
	self:SetFlashlight(player, false)
	local root = rootOf(player)
	if root then
		self:DropBag(root.CFrame.Position, state.carried, state.hasKey)
	end
	state.carried = 0
	state.hasKey = false
	local character = player.Character
	if character then
		setGhostLook(character, true)
		character:SetAttribute("Ghost", true)
	end
	self:Event(player, "caught", { monster = monsterId })
	for other, otherState in self.players do
		if other ~= player and otherState.status ~= "left" and not otherState.finished then
			self:Toast(other, "👻 " .. player.DisplayName .. " został złapany i jest teraz duszkiem!", "bad")
		end
	end
	self:CheckEveryoneOut()
end

-- Duszek wskazuje drużynie najbliższy mebel z monetami
function Round:GhostPing(player: Player)
	local state = self.players[player]
	local root = rootOf(player)
	if not state or state.status ~= "ghost" or not root then
		return
	end
	if self.elapsed - state.lastPing < GameConfig.GHOST_PING_COOLDOWN then
		return
	end
	local best, bestDistance = nil, math.huge
	for _, spot in self.building.spots do
		if not spot.searched and (spot.coins > 0 or spot.hasKey) and spot.part.Parent then
			local distance = (spot.part.CFrame.Position - root.CFrame.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = spot, distance
			end
		end
	end
	if not best then
		self:Toast(player, "Nie ma już nic do znalezienia w pobliżu.", "info")
		return
	end
	state.lastPing = self.elapsed
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(150, 230, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.5
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = best.part
	highlight.Parent = best.part
	Debris:AddItem(highlight, GameConfig.GHOST_PING_TIME)
	self:EventAll("ping", { by = player.DisplayName, position = best.part.CFrame.Position, label = best.label })
end

-- Wyjście i koniec ------------------------------------------------------------------------------

function Round:Reward(_player: Player, state, outcome: string): number
	local reward = state.deposited * GameConfig.REWARD_DEPOSIT_SHARE + state.bonusDeposited * GameConfig.REWARD_BONUS_RATIO
	if self.rentPaid then
		reward += GameConfig.REWARD_RENT_PAID
	end
	if state.escapedUnpaid then
		reward += GameConfig.REWARD_ESCAPED_UNPAID
	end
	if outcome == "caught" then
		reward *= GameConfig.REWARD_CAUGHT_MULTIPLIER
	end
	return math.max(5, math.floor(reward))
end

-- Gracz kończy rundę: nagroda, statystyki, powrót do holu (od razu albo po ekranie podsumowania)
function Round:Finish(player: Player, outcome: string)
	local state = self.players[player]
	if not state or state.finished then
		return
	end
	state.finished = true
	if state.hidden then
		self:LeaveWardrobe(player)
	end
	self:SetFlashlight(player, false)
	if state.status == "left" then
		return
	end
	local reward = self:Reward(player, state, outcome)
	local summary = {
		outcome = outcome, -- escaped | caught | paidStayed | huntEnded
		reward = reward,
		rentPaid = self.rentPaid,
		deposited = state.deposited + state.bonusDeposited,
		found = state.found,
		teamDeposited = self.deposited,
		rent = self.rent,
		time = if self.paidAt then Format.Time(self.paidAt) else nil,
	}
	self.onFinished(player, summary, state)
	self:Event(player, "end", summary)
	local character = player.Character
	if character then
		setGhostLook(character, false)
		character:SetAttribute("Ghost", nil)
	end
end

function Round:CheckEscapes()
	if not (self.rentPaid or self.phase == "hunt") then
		return
	end
	local min, max = self.building.exitMin, self.building.exitMax
	for player, state in self.players do
		if not state.finished and (state.status == "inside" or state.status == "ghost") then
			local root = rootOf(player)
			if root and within(root.CFrame.Position, min, max) then
				if state.status == "inside" then
					state.status = "escaped"
					if self.phase == "hunt" and not self.rentPaid then
						state.escapedUnpaid = true
					end
					self:Finish(player, "escaped")
				else
					self:Finish(player, "caught")
				end
				for other, otherState in self.players do
					if other ~= player and not otherState.finished and otherState.status ~= "left" then
						self:Toast(other, "🏃 " .. player.DisplayName .. " wyszedł z kamienicy.", "info")
					end
				end
			end
		end
	end
	self:CheckEveryoneOut()
end

-- Gdy nikt już nie jest w środku (wszyscy wyszli albo są duszkami), runda się kończy
function Round:CheckEveryoneOut()
	if self.phase == "ending" then
		return
	end
	for _, state in self.players do
		if state.status == "inside" and not state.finished then
			return
		end
	end
	self:End()
end

function Round:Midnight()
	if self.rentPaid then
		self:End()
		return
	end
	self.phase = "hunt"
	self:OpenFrontDoor()
	self:EventAll("midnight", {})
	self:ToastAll("🕛 PÓŁNOC! Czynsz niezapłacony... Klucznik się zmienia! Uciekaj do bramy albo schowaj się!", "bad")
	local cframe = self.building.landlordCFrame
	if self.building.landlordModel then
		self.building.landlordModel:Destroy()
		self.building.landlordModel = nil
	end
	task.delay(MonsterConfig.Landlord.spawnDelay, function()
		if self.alive and self.phase == "hunt" then
			table.insert(self.monsters, LandlordMonster.new(self, cframe.Position))
		end
	end)
end

function Round:End()
	if self.phase == "ending" then
		return
	end
	self.phase = "ending"
	for player, state in self.players do
		if not state.finished and state.status ~= "left" then
			local outcome
			if state.status == "ghost" then
				outcome = "caught"
			elseif self.rentPaid then
				outcome = "paidStayed"
			else
				outcome = "huntEnded"
				state.status = "ghost"
			end
			self:Finish(player, if outcome == "huntEnded" then "caught" else outcome)
		end
	end
	for _, monster in self.monsters do
		monster:Destroy()
	end
	self.monsters = {}
	task.delay(GameConfig.END_SCREEN_TIME, function()
		self:Destroy()
	end)
end

-- Postać zginęła albo gracz się zresetował: kończy rundę jak złapany (pojawi się już w holu)
function Round:Forfeit(player: Player)
	local state = self.players[player]
	if not state or state.finished then
		return
	end
	if state.hidden then
		self:LeaveWardrobe(player)
	end
	if state.status == "inside" then
		state.status = "ghost"
		state.carried = 0
		state.hasKey = false
	end
	self:Finish(player, "caught")
	self:CheckEveryoneOut()
end

function Round:RemovePlayer(player: Player)
	local state = self.players[player]
	if not state then
		return
	end
	if state.hidden then
		self:LeaveWardrobe(player)
	end
	state.status = "left"
	state.finished = true
	self:CheckEveryoneOut()
end

-- Start i pętla -----------------------------------------------------------------------------------

function Round:Start(teleport)
	self:DistributeCoins()
	for _, spot in self.building.spots do
		self:SetupSpot(spot)
	end
	for _, wardrobe in self.building.wardrobes do
		self:SetupWardrobe(wardrobe)
	end
	self:SetupDeposit()
	self:SetupLockedRoom()

	for index, player in self.order do
		local offset = Vector3.new(((index - 1) % 2) * 3, 0, (index - 1) // 2 * 3 - 1.5)
		teleport(player, self.building.spawn + offset)
		self:SetFlashlight(player, false)
		self:Event(player, "start", {
			rent = self.rent,
			duration = GameConfig.ROUND_DURATION,
			players = #self.order,
		})
	end

	table.insert(self.monsters, NeighborMonster.new(self, self.building.neighborStart))
	table.insert(self.monsters, CatMonster.new(self, self.building.catBed))

	task.spawn(function()
		local stateTimer = 0
		local last = os.clock()
		while self.alive do
			task.wait(0.1)
			local now = os.clock()
			local dt = now - last
			last = now
			if self.phase ~= "ending" then
				self:Tick(dt)
			end
			stateTimer += dt
			if stateTimer >= STATE_INTERVAL then
				stateTimer = 0
				self:PushState()
			end
		end
	end)
end

function Round:Tick(dt: number)
	self.elapsed += dt
	-- Baterie latarek
	for player, state in self.players do
		if state.flashlight then
			state.battery = math.max(0, state.battery - GameConfig.BATTERY_DRAIN * dt)
			if state.battery <= 0 then
				self:SetFlashlight(player, false)
				self:Toast(player, "🔋 Bateria się wyczerpała. Zgaś latarkę na chwilę, sama się naładuje.", "warn")
			end
		else
			state.battery = math.min(state.batteryMax, state.battery + GameConfig.BATTERY_REGEN * dt)
		end
	end
	-- Potwory
	for _, monster in self.monsters do
		monster:Update(dt)
	end
	-- Zegar
	if self.phase == "play" then
		self.timeLeft -= dt
		if self.timeLeft <= 0 then
			self.timeLeft = 0
			self:Midnight()
		end
	elseif self.phase == "hunt" then
		self.huntLeft -= dt
		if self.huntLeft <= 0 then
			self:ToastAll("😴 Klucznik się zmęczył i poszedł spać...", "info")
			self:End()
			return
		end
	end
	self:CheckEscapes()
end

-- Godzina na zegarze w grze (20:00 -> 24:00)
function Round:ClockText(): string
	local progress = 1 - self.timeLeft / GameConfig.ROUND_DURATION
	local minutes = math.floor(progress * (24 - GameConfig.CLOCK_START_HOUR) * 60)
	local hour = GameConfig.CLOCK_START_HOUR + minutes // 60
	return string.format("%02d:%02d", hour % 24, minutes % 60)
end

function Round:PushState()
	local team = {}
	for _, player in self.order do
		local state = self.players[player]
		table.insert(team, { name = player.DisplayName, status = state.status, carried = state.carried })
	end
	local clock = self:ClockText()
	for player, state in self.players do
		if not state.finished and state.status ~= "left" then
			local root = rootOf(player)
			RemoteService.Event("RoundState"):FireClient(player, {
				phase = self.phase,
				clock = clock,
				timeLeft = math.ceil(self.timeLeft),
				huntLeft = math.ceil(self.huntLeft),
				rent = self.rent,
				deposited = self.deposited,
				rentPaid = self.rentPaid,
				carried = state.carried,
				capacity = state.capacity,
				battery = math.floor(state.battery),
				batteryMax = state.batteryMax,
				flashlight = state.flashlight,
				status = state.status,
				hasKey = state.hasKey,
				hidden = state.hidden ~= nil,
				floor = if root then self:FloorOf(root.CFrame.Position) else 0,
				pingReady = state.status == "ghost" and self.elapsed - state.lastPing >= GameConfig.GHOST_PING_COOLDOWN,
				team = team,
			})
		end
	end
end

function Round:Destroy()
	if not self.alive then
		return
	end
	self.alive = false
	for _, monster in self.monsters do
		monster:Destroy()
	end
	self.monsters = {}
	self.building.model:Destroy()
	if self.onDestroyed then
		self.onDestroyed(self)
	end
end

return Round

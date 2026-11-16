-- Cichy Sąsiad (1. piętro). ZASADA: słyszy hałas (bieg, brzęk pełnych kieszeni). Kto idzie powoli z lekkimi
-- kieszeniami, jest bezpieczny; z bliska widzi tylko tych, którzy się ruszają.
-- Stany: patrol -> nasłuch (idzie sprawdzić hałas) -> rozglądanie się (czasem zagląda do szafy) -> pościg.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local Noise = require(ReplicatedStorage.Shared.Modules.Noise)
local MonsterModels = require(ServerScriptService.World.MonsterModels)
local Monster = require(script.Parent.Parent.Monster)

local Neighbor = {}
Neighbor.__index = Neighbor
setmetatable(Neighbor, { __index = Monster })

local FLOOR = 1
local CFG = MonsterConfig.Neighbor
local ALERT_COOLDOWN = 6
local WARDROBE_RADIUS = 10
local MOODS = { investigate = "curious", lookAround = "curious", checking = "curious", chase = "alert" }

function Neighbor.new(round, position: Vector3)
	local self = Monster.new(round, "neighbor", MonsterModels.Neighbor(), position)
	setmetatable(self, Neighbor)
	self.state = "patrol"
	self.waitUntil = 0
	self.patrolIndex = 1
	self.target = nil
	self.lastSeen = 0
	self.alerted = {}
	self.sinceRepath = 0
	return self
end

function Neighbor:Alert(player: Player, text: string)
	local now = os.clock()
	if (self.alerted[player] or 0) + ALERT_COOLDOWN > now then
		return
	end
	self.alerted[player] = now
	self.round:Event(player, "alert", { text = text, kind = "bad", monster = "neighbor" })
end

function Neighbor:NextPatrolPoint(): Vector3
	local building = self.round.building
	if math.random() < CFG.peekChance and #building.peeks[FLOOR] > 0 then
		return building.peeks[FLOOR][math.random(1, #building.peeks[FLOOR])]
	end
	local points = building.patrol[FLOOR]
	self.patrolIndex = self.patrolIndex % #points + 1
	return points[self.patrolIndex]
end

-- Najbliższy słyszalny gracz na piętrze (zasięg z modułu Noise: bieg, brzęk kieszeni, Cichobiegi)
function Neighbor:Listen()
	local best, bestDistance = nil, math.huge
	for _, target in self.round:Targets() do
		if target.floor == FLOOR then
			local radius = Noise.Radius(Monster.SpeedOf(target.root), target.state.carried, target.state.capacity, target.state.hearing)
			local distance = self:DistanceTo(target.root.CFrame.Position)
			if radius > 0 and distance <= radius and distance < bestDistance then
				best, bestDistance = target, distance
			end
		end
	end
	return best
end

-- Ruszający się gracz blisko i w zasięgu wzroku
function Neighbor:Look()
	for _, target in self.round:Targets() do
		if target.floor == FLOOR and Monster.SpeedOf(target.root) > GameConfig.MOVING_SPEED then
			if self:DistanceTo(target.root.CFrame.Position) <= CFG.seeRadius and self:CanSee(target.root) then
				return target
			end
		end
	end
	return nil
end

function Neighbor:StartChase(target)
	if self.state ~= "chase" then
		self:Alert(target.player, "😱 Sąsiad Cię zobaczył! Uciekaj albo schowaj się w szafie!")
	end
	self.state = "chase"
	self.target = target.player
	self.lastSeen = os.clock()
	self.sinceRepath = math.huge
end

function Neighbor:StopChase()
	self.state = "lookAround"
	self.target = nil
	self.waitUntil = os.clock() + CFG.lookAroundTime
	self.lookedForWardrobe = false
	self:Stop()
end

-- Reżyser nocy / samouczek: idź sprawdzić to miejsce (o ile nikogo nie gonisz)
function Neighbor:Investigate(position: Vector3)
	if self.state == "chase" or self.state == "checking" then
		return
	end
	self.state = "investigate"
	self:MoveTo(position, self:Speed(CFG.investigateSpeed))
end

function Neighbor:Update(dt: number)
	if not self.alive then
		return
	end
	self:SetMood(MOODS[self.state])
	-- Łapie tylko w pościgu: kto stoi nieruchomo albo idzie powoli, jest bezpieczny
	if self.state == "chase" then
		self:TryCatch()
	end
	local now = os.clock()

	if self.state == "chase" then
		local found = nil
		for _, target in self.round:Targets() do
			if target.player == self.target then
				found = target
			end
		end
		if not found or found.floor ~= FLOOR or self:DistanceTo(found.root.CFrame.Position) > CFG.chaseGiveUpRadius then
			self:StopChase()
			return
		end
		if self:CanSee(found.root) then
			self.lastSeen = now
		elseif now - self.lastSeen > MonsterConfig.LOSE_SIGHT_TIME then
			self:StopChase()
			return
		end
		self.sinceRepath += dt
		if self.sinceRepath >= MonsterConfig.REPATH_INTERVAL then
			self.sinceRepath = 0
			self:MoveTo(found.root.CFrame.Position - Vector3.new(0, 3, 0), self:Speed(CFG.chaseSpeed))
		end
		return
	end

	if self.state == "checking" then
		-- Zagląda do szafy: czeka, aż minigra się skończy
		if now >= self.waitUntil then
			self.state = "patrol"
			self.waitUntil = 0
		end
		return
	end

	local seen = self:Look()
	if seen then
		self:StartChase(seen)
		return
	end
	local heard = self:Listen()
	if heard then
		local running = Monster.SpeedOf(heard.root) > GameConfig.NOISY_SPEED
		self:Alert(heard.player, if running then "🤫 Ćśś! Sąsiad usłyszał Twoje kroki... Idź powoli!" else "🎒 Brzęk! Sąsiad usłyszał monety w Twoich kieszeniach!")
		self.state = "investigate"
		self:MoveTo(heard.root.CFrame.Position - Vector3.new(0, 3, 0), self:Speed(CFG.investigateSpeed))
		return
	end

	if self.state == "investigate" then
		if not self:IsMoving() then
			self.state = "lookAround"
			self.waitUntil = now + CFG.lookAroundTime
			self.lookedForWardrobe = false
		end
	elseif self.state == "lookAround" then
		-- Rozgląda się: obraca się powoli w miejscu, a czasem zagląda do pobliskiej szafy
		self.look = (CFrame.Angles(0, dt * 1.5, 0) * CFrame.new(self.look)).Position
		if not self.lookedForWardrobe then
			self.lookedForWardrobe = true
			local wardrobe = self.round:FindOccupiedWardrobe(self.position, WARDROBE_RADIUS)
			if wardrobe and math.random() < CFG.wardrobeCheckChance and self.round:CheckWardrobe(wardrobe, self.id) then
				self.state = "checking"
				self.look = (wardrobe.part.CFrame.Position - self.position) * Vector3.new(1, 0, 1)
				self.waitUntil = now + GameConfig.BREATH_TIME + 1.5
				return
			end
		end
		if now >= self.waitUntil then
			self.state = "patrol"
		end
	elseif self.state == "patrol" then
		if not self:IsMoving() then
			if self.waitUntil == 0 then
				self.waitUntil = now + math.random(10, 25) / 10
			elseif now >= self.waitUntil then
				self.waitUntil = 0
				self:MoveTo(self:NextPatrolPoint(), self:Speed(CFG.patrolSpeed))
			end
		end
	end
end

return Neighbor
